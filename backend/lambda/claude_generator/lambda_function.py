"""
CLAUDE GENERATOR LAMBDA
AWS Lambda function that processes generation_queue and generates pages with Claude

PURPOSE:
Reads queued predictions from Llama, calls Claude to generate UI components,
and stores them in page_cache for instant delivery.

RUNS: Every 2 minutes via EventBridge

FLOW:
1. Query generation_queue for 'queued' jobs
2. For each job: Call Claude API with pattern context
3. Store generated components in page_cache
4. Update queue status to 'completed'
"""

import json
import os
import logging
from datetime import datetime, timedelta
from uuid import uuid4
import pymysql
from anthropic import Anthropic

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
DB_HOST = os.environ['DB_HOST']
DB_PORT = int(os.environ.get('DB_PORT', 3306))
DB_NAME = os.environ['DB_NAME']
DB_USER = os.environ['DB_USER']
DB_PASSWORD = os.environ['DB_PASSWORD']
CLAUDE_API_KEY = os.environ['CLAUDE_API_KEY']

# Claude configuration
CLAUDE_MODEL = "claude-sonnet-4-20250514"
MAX_JOBS_PER_RUN = 10
MAX_ATTEMPTS = 3

# Ambient Intelligence System Prompt
AMBIENT_INTELLIGENCE_PROMPT = """You are Ambia's ambient intelligence engine - an AI that generates contextual information before users ask.

CORE PRINCIPLE:
Information should appear when and where people need it, without them asking.

YOUR JOB:
1. Analyze the user's behavioral pattern detected by Llama
2. Generate a beautiful, contextual UI component structure
3. Return structured JSON optimized for their specific situation

The user doesn't know this page exists yet - you're pre-generating it based on predicted need.

RESPONSE FORMAT (return ONLY valid JSON):
{
  "components": [
    {
      "type": "weather" | "calendar" | "tasks" | "movies" | "books" | "news" | "recipes" | "sports",
      "title": "Component title",
      "priority": "high" | "medium" | "low",
      "data": {
        // Component-specific data
      }
    }
  ]
}

Make it feel like you're reading the user's mind. Be proactive, contextual, and helpful."""


def lambda_handler(event, context):
    """
    Main Lambda handler
    Triggered by EventBridge every 2 minutes
    """
    logger.info("=== Claude Generator Starting ===")

    connection = None
    try:
        # Connect to database
        connection = get_db_connection()
        logger.info("Database connected successfully")

        # Get pending jobs from queue
        jobs = get_pending_jobs(connection)
        logger.info(f"Found {len(jobs)} pending jobs")

        if not jobs:
            logger.info("No jobs to process")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'jobs_processed': 0,
                    'pages_generated': 0
                })
            }

        jobs_processed = 0
        pages_generated = 0
        errors = 0

        # Process each job
        for job in jobs:
            job_id = job['id']
            user_id = job['user_id']

            logger.info(f"Processing job {job_id} for user {user_id}")

            try:
                # Mark as processing
                update_job_status(connection, job_id, 'processing')

                # Parse context data
                context_data = json.loads(job['context_data']) if job['context_data'] else {}

                # Get user activity context
                user_context = get_user_context(connection, user_id)

                # Call Claude to generate components
                components = generate_components_with_claude(
                    user_id=user_id,
                    predicted_need=job['predicted_need'],
                    pattern=context_data,
                    user_context=user_context
                )

                if components:
                    # Store in page_cache
                    cache_id = store_in_page_cache(
                        connection=connection,
                        user_id=user_id,
                        components=components,
                        pattern=context_data
                    )

                    # Update job as completed
                    update_job_status(
                        connection=connection,
                        job_id=job_id,
                        status='completed',
                        result_cache_key=cache_id
                    )

                    jobs_processed += 1
                    pages_generated += 1
                    logger.info(f"Successfully generated page for job {job_id}")
                else:
                    # Failed to generate
                    handle_job_failure(connection, job, "Failed to generate components")
                    errors += 1

            except Exception as e:
                logger.error(f"Error processing job {job_id}: {str(e)}", exc_info=True)
                handle_job_failure(connection, job, str(e))
                errors += 1
                continue

        logger.info(f"=== Claude Generator Complete ===")
        logger.info(f"Jobs processed: {jobs_processed}")
        logger.info(f"Pages generated: {pages_generated}")
        logger.info(f"Errors: {errors}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'success': True,
                'jobs_processed': jobs_processed,
                'pages_generated': pages_generated,
                'errors': errors
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


def get_pending_jobs(connection):
    """
    Get pending jobs from generation_queue
    Prioritizes by priority (DESC) and scheduled_for (ASC)
    Skips jobs that have exceeded max attempts
    """
    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT
                id, user_id, job_type, priority, predicted_need,
                context_data, scheduled_for, valid_until, attempts
            FROM generation_queue
            WHERE status = 'queued'
            AND scheduled_for <= NOW()
            AND valid_until > NOW()
            AND attempts < %s
            ORDER BY priority DESC, scheduled_for ASC
            LIMIT %s
        """, (MAX_ATTEMPTS, MAX_JOBS_PER_RUN))
        return cursor.fetchall()


def get_user_context(connection, user_id):
    """
    Get user activity context from activity_log
    Returns recent activity summary for Claude
    """
    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT
                action_type,
                query,
                components_shown,
                time_of_day,
                day_of_week,
                timestamp
            FROM activity_log
            WHERE user_id = %s
            AND timestamp >= DATE_SUB(NOW(), INTERVAL 14 DAY)
            ORDER BY timestamp DESC
            LIMIT 50
        """, (user_id,))

        activity = cursor.fetchall()

        if not activity:
            return "No recent activity"

        # Build context summary
        recent_queries = []
        time_patterns = {}

        for record in activity:
            if record.get('query'):
                recent_queries.append(record['query'])

            tod = record.get('time_of_day')
            if tod:
                time_patterns[tod] = time_patterns.get(tod, 0) + 1

        return {
            'recent_queries': recent_queries[:10],
            'time_patterns': time_patterns,
            'total_activities': len(activity)
        }


def generate_components_with_claude(user_id, predicted_need, pattern, user_context):
    """
    Call Claude API to generate UI components
    Returns: List of component objects or None on failure
    """
    try:
        # Build prompt
        prompt = f"""{AMBIENT_INTELLIGENCE_PROMPT}

USER CONTEXT:
{json.dumps(user_context, indent=2)}

DETECTED PATTERN:
{json.dumps(pattern, indent=2)}

PREDICTED NEED:
{predicted_need}

Generate a contextual UI response for this prediction. Return ONLY valid JSON."""

        # Call Claude API
        client = Anthropic(api_key=CLAUDE_API_KEY)

        message = client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=2000,
            temperature=0.7,
            messages=[{
                "role": "user",
                "content": prompt
            }]
        )

        # Parse response
        response_text = message.content[0].text
        logger.info(f"Claude response: {response_text[:200]}...")

        # Parse JSON
        response_data = json.loads(response_text)
        components = response_data.get('components', [])

        if not components:
            logger.warning("Claude returned no components")
            return None

        logger.info(f"Claude generated {len(components)} components")
        return components

    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse Claude response as JSON: {str(e)}")
        logger.error(f"Response was: {response_text}")
        return None
    except Exception as e:
        logger.error(f"Claude API error: {str(e)}", exc_info=True)
        return None


def store_in_page_cache(connection, user_id, components, pattern):
    """
    Store generated components in page_cache
    Returns: cache_id
    """
    cache_id = str(uuid4())

    # Extract predicted query from pattern
    predicted_query = pattern.get('predicted_query', pattern.get('predicted_action', ''))

    # Generate cache key (same algorithm as backend)
    cache_key = generate_cache_key(user_id, predicted_query)

    # Calculate relevance score from pattern confidence
    relevance_score = pattern.get('confidence', 0.7)

    # Set validity (30 minutes from now)
    valid_until = datetime.now() + timedelta(minutes=30)

    with connection.cursor() as cursor:
        try:
            cursor.execute("""
                INSERT INTO page_cache (
                    id, user_id, cache_key, cache_type, query,
                    components, relevance_score, valid_until, created_at
                ) VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, NOW()
                )
            """, (
                cache_id,
                user_id,
                cache_key,
                'prediction',
                predicted_query,
                json.dumps(components),
                relevance_score,
                valid_until
            ))
            connection.commit()
            logger.info(f"Stored in page_cache: {cache_id}")
            return cache_id

        except pymysql.IntegrityError as e:
            # Duplicate cache_key - update existing
            logger.info(f"Cache key already exists, updating: {cache_key}")
            cursor.execute("""
                UPDATE page_cache
                SET components = %s,
                    relevance_score = %s,
                    valid_until = %s,
                    created_at = NOW()
                WHERE user_id = %s AND cache_key = %s
            """, (
                json.dumps(components),
                relevance_score,
                valid_until,
                user_id,
                cache_key
            ))
            connection.commit()
            return cache_key


def update_job_status(connection, job_id, status, result_cache_key=None):
    """Update generation_queue job status"""
    with connection.cursor() as cursor:
        if result_cache_key:
            cursor.execute("""
                UPDATE generation_queue
                SET status = %s,
                    result_cache_key = %s,
                    completed_at = NOW()
                WHERE id = %s
            """, (status, result_cache_key, job_id))
        elif status == 'processing':
            cursor.execute("""
                UPDATE generation_queue
                SET status = %s,
                    started_at = NOW()
                WHERE id = %s
            """, (status, job_id))
        else:
            cursor.execute("""
                UPDATE generation_queue
                SET status = %s
                WHERE id = %s
            """, (status, job_id))
        connection.commit()


def handle_job_failure(connection, job, error_message):
    """Handle job failure with retry logic"""
    job_id = job['id']
    attempts = job.get('attempts', 0) + 1

    with connection.cursor() as cursor:
        if attempts >= MAX_ATTEMPTS:
            # Max attempts reached - mark as failed
            logger.error(f"Job {job_id} failed after {attempts} attempts: {error_message}")
            cursor.execute("""
                UPDATE generation_queue
                SET status = 'failed',
                    attempts = %s,
                    error_message = %s,
                    completed_at = NOW()
                WHERE id = %s
            """, (attempts, error_message[:500], job_id))
        else:
            # Increment attempts and requeue
            logger.warning(f"Job {job_id} attempt {attempts} failed, requeuing: {error_message}")
            cursor.execute("""
                UPDATE generation_queue
                SET status = 'queued',
                    attempts = %s
                WHERE id = %s
            """, (attempts, job_id))

        connection.commit()


def generate_cache_key(user_id, query):
    """Generate cache key (same algorithm as backend)"""
    import hashlib
    normalized_query = query.lower().strip()
    hash_input = f"{user_id}:{normalized_query}"
    hash_value = hashlib.md5(hash_input.encode()).hexdigest()
    return hash_value[:16]
