"""
LLAMA PREDICTION SCHEDULER
AWS Lambda function that runs every 5 minutes via EventBridge

PURPOSE:
Analyzes user activity patterns using Llama and queues high-confidence
predictions for Claude to generate later.

DOES:
1. Get active users (active in last 7 days)
2. Analyze activity_log (last 30 days)
3. Call Llama to find patterns
4. Queue predictions (confidence ≥0.7) to generation_queue

DOES NOT:
- Generate UI (that's Claude's job)
- Handle real-time requests
- Block user-facing operations
"""

import json
import os
import logging
from datetime import datetime, timedelta
from uuid import uuid4
import pymysql
import requests

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
DB_HOST = os.environ['DB_HOST']
DB_PORT = int(os.environ.get('DB_PORT', 3306))
DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
TOGETHER_AI_KEY = os.environ['TOGETHER_AI_KEY']

# Llama API configuration
LLAMA_API_URL = "https://api.together.xyz/v1/chat/completions"
LLAMA_MODEL = "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo"

# Thresholds
MIN_CONFIDENCE = 0.6  # Llama must have at least 60% confidence
QUEUE_CONFIDENCE = 0.7  # Only queue predictions with ≥70% confidence


def lambda_handler(event, context):
    """
    Main Lambda handler
    Triggered by EventBridge every 5 minutes
    """
    logger.info("=== Llama Prediction Scheduler Starting ===")

    connection = None
    try:
        # Connect to database
        connection = get_db_connection()
        logger.info("Database connected successfully")

        # Get active users
        active_users = get_active_users(connection)
        logger.info(f"Found {len(active_users)} active users")

        total_patterns = 0
        total_queued = 0

        # Process each user
        for user in active_users:
            user_id = user['user_id']
            logger.info(f"Processing user: {user_id}")

            try:
                # Get user activity
                activity = get_user_activity(connection, user_id)

                if not activity:
                    logger.info(f"No activity found for user {user_id}")
                    continue

                # Call Llama to analyze patterns
                patterns = analyze_patterns_with_llama(user_id, activity)
                total_patterns += len(patterns)

                if not patterns:
                    logger.info(f"No patterns detected for user {user_id}")
                    continue

                logger.info(f"Found {len(patterns)} patterns for user {user_id}")

                # Queue high-confidence predictions
                queued = queue_predictions(connection, user_id, patterns)
                total_queued += queued

                logger.info(f"Queued {queued} predictions for user {user_id}")

            except Exception as e:
                logger.error(f"Error processing user {user_id}: {str(e)}")
                # Continue with next user
                continue

        logger.info(f"=== Prediction Scheduler Complete ===")
        logger.info(f"Total patterns detected: {total_patterns}")
        logger.info(f"Total predictions queued: {total_queued}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'success': True,
                'active_users': len(active_users),
                'patterns_detected': total_patterns,
                'predictions_queued': total_queued
            })
        }

    except Exception as e:
        logger.error(f"Fatal error in lambda_handler: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'error': str(e)
            })
        }
    finally:
        if connection:
            connection.close()
            logger.info("Database connection closed")


def get_db_connection():
    """Establish MySQL database connection"""
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor
    )


def get_active_users(connection):
    """
    Get users who have been active in the last 7 days
    Returns: List of user_id dicts
    """
    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT DISTINCT user_id
            FROM activity_log
            WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
        """)
        return cursor.fetchall()


def get_user_activity(connection, user_id):
    """
    Get user activity from last 30 days
    Returns: List of activity records
    """
    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT
                action_type,
                query,
                components_shown,
                component_interacted,
                time_of_day,
                day_of_week,
                is_weekend,
                timestamp
            FROM activity_log
            WHERE user_id = %s
            AND timestamp >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            ORDER BY timestamp DESC
            LIMIT 100
        """, (user_id,))
        return cursor.fetchall()


def analyze_patterns_with_llama(user_id, activity):
    """
    Call Llama API to analyze activity patterns
    Returns: List of pattern predictions with confidence scores
    """
    # Build activity summary for Llama
    activity_summary = build_activity_summary(activity)

    # Create prompt for Llama
    prompt = f"""You are a pattern detection AI for Ambia. Analyze this user's activity and detect behavioral patterns.

USER ACTIVITY SUMMARY:
{activity_summary}

YOUR TASK:
Analyze these activities and identify patterns. For each pattern you detect:
1. What type of pattern is it? (time_based, query_based, event_based)
2. How confident are you? (0.0 to 1.0)
3. What will the user likely do next?
4. When will they likely do it?

Only include patterns with confidence ≥ {MIN_CONFIDENCE}.

RESPOND IN THIS EXACT JSON FORMAT:
{{
  "patterns": [
    {{
      "pattern_type": "time_based",
      "confidence": 0.85,
      "predicted_action": "User will ask about movies",
      "predicted_query": "what movies should i watch",
      "trigger_time": "2024-01-15T20:00:00",
      "reasoning": "User asks about movies every Friday evening"
    }}
  ]
}}"""

    try:
        # Call Llama API
        response = requests.post(
            LLAMA_API_URL,
            headers={
                "Authorization": f"Bearer {TOGETHER_AI_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "model": LLAMA_MODEL,
                "messages": [
                    {
                        "role": "system",
                        "content": "You are a pattern detection AI. Always respond with valid JSON."
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                "max_tokens": 1000,
                "temperature": 0.3,
                "response_format": {"type": "json_object"}
            },
            timeout=30
        )

        response.raise_for_status()

        # Parse Llama's response
        llama_response = response.json()
        content = llama_response['choices'][0]['message']['content']
        result = json.loads(content)

        patterns = result.get('patterns', [])

        # Filter by minimum confidence
        filtered_patterns = [
            p for p in patterns
            if p.get('confidence', 0) >= MIN_CONFIDENCE
        ]

        logger.info(f"Llama detected {len(filtered_patterns)} patterns for user {user_id}")
        return filtered_patterns

    except requests.exceptions.RequestException as e:
        logger.error(f"Llama API request failed: {str(e)}")
        return []
    except (KeyError, json.JSONDecodeError) as e:
        logger.error(f"Failed to parse Llama response: {str(e)}")
        return []


def build_activity_summary(activity):
    """Build a concise summary of user activity for Llama"""
    if not activity:
        return "No activity found"

    # Count action types
    action_counts = {}
    time_of_day_counts = {}
    day_of_week_counts = {}
    recent_queries = []

    for record in activity:
        # Count actions
        action_type = record.get('action_type', 'unknown')
        action_counts[action_type] = action_counts.get(action_type, 0) + 1

        # Count time patterns
        tod = record.get('time_of_day')
        if tod:
            time_of_day_counts[tod] = time_of_day_counts.get(tod, 0) + 1

        # Count day patterns
        dow = record.get('day_of_week')
        if dow:
            day_of_week_counts[dow] = day_of_week_counts.get(dow, 0) + 1

        # Collect recent queries
        query = record.get('query')
        if query and len(recent_queries) < 10:
            recent_queries.append(query)

    summary = f"""
Total Activities: {len(activity)}

Action Type Distribution:
{json.dumps(action_counts, indent=2)}

Time of Day Distribution:
{json.dumps(time_of_day_counts, indent=2)}

Day of Week Distribution:
{json.dumps(day_of_week_counts, indent=2)}

Recent Queries (last 10):
{json.dumps(recent_queries, indent=2)}
"""

    return summary


def queue_predictions(connection, user_id, patterns):
    """
    Queue high-confidence predictions to generation_queue
    Only queues patterns with confidence ≥ QUEUE_CONFIDENCE (0.7)
    """
    queued_count = 0

    with connection.cursor() as cursor:
        for pattern in patterns:
            confidence = pattern.get('confidence', 0)

            # Only queue high-confidence predictions
            if confidence < QUEUE_CONFIDENCE:
                logger.info(f"Skipping pattern (confidence {confidence} < {QUEUE_CONFIDENCE})")
                continue

            try:
                # Parse trigger time
                trigger_time_str = pattern.get('trigger_time')
                if trigger_time_str:
                    trigger_time = datetime.fromisoformat(trigger_time_str.replace('Z', '+00:00'))
                else:
                    # Default to 30 minutes from now
                    trigger_time = datetime.now() + timedelta(minutes=30)

                # Check if already in queue
                cursor.execute("""
                    SELECT id FROM generation_queue
                    WHERE user_id = %s
                    AND predicted_need = %s
                    AND status = 'queued'
                    AND scheduled_for > NOW()
                """, (user_id, pattern.get('predicted_action')))

                if cursor.fetchone():
                    logger.info(f"Prediction already queued for user {user_id}")
                    continue

                # Check if already in cache
                predicted_query = pattern.get('predicted_query', '')
                if predicted_query:
                    cache_key = generate_cache_key(user_id, predicted_query)
                    cursor.execute("""
                        SELECT id FROM page_cache
                        WHERE user_id = %s
                        AND cache_key = %s
                        AND valid_until > NOW()
                    """, (user_id, cache_key))

                    if cursor.fetchone():
                        logger.info(f"Prediction already cached for user {user_id}")
                        continue

                # Insert into generation_queue
                queue_id = str(uuid4())
                cursor.execute("""
                    INSERT INTO generation_queue (
                        id,
                        user_id,
                        job_type,
                        priority,
                        predicted_need,
                        context_data,
                        scheduled_for,
                        valid_until,
                        status,
                        created_at
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, NOW()
                    )
                """, (
                    queue_id,
                    user_id,
                    'prediction',
                    int(confidence * 100),  # Convert 0.0-1.0 to 0-100
                    pattern.get('predicted_action'),
                    json.dumps(pattern),
                    trigger_time,
                    trigger_time + timedelta(hours=1),  # Valid for 1 hour after trigger
                    'queued'
                ))

                connection.commit()
                queued_count += 1
                logger.info(f"Queued prediction {queue_id} for user {user_id}")

            except Exception as e:
                logger.error(f"Error queuing prediction: {str(e)}")
                connection.rollback()
                continue

    return queued_count


def generate_cache_key(user_id, query):
    """Generate cache key (same algorithm as backend)"""
    import hashlib
    normalized_query = query.lower().strip()
    hash_input = f"{user_id}:{normalized_query}"
    hash_value = hashlib.md5(hash_input.encode()).hexdigest()
    return hash_value[:16]
