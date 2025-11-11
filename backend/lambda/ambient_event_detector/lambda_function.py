"""
AMBIENT EVENT DETECTOR LAMBDA
AWS Lambda function that detects time-sensitive moments and generates ambient events

PURPOSE:
Analyzes user context, calendar, location, and patterns to detect moments that deserve
Dynamic Island updates, Notifications, or Live Activities. NO HARDCODING - Claude generates
ANY type of event dynamically.

RUNS: Every 1 minute via EventBridge

FLOW:
1. Query users with active device tokens
2. For each user: Analyze current context (time, location, calendar, patterns)
3. Call Claude API to detect time-sensitive moments
4. Parse Claude's response (event structure)
5. Store generated events in ambient_events table
6. Trigger push notification if needed

EXAMPLES OF WHAT CLAUDE GENERATES:
- Amtrak departure in 45 mins → Live Activity
- Package delivery window starting → Notification
- Meeting in 10 mins → Dynamic Island
- Timer about to expire → Live Activity update
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
MAX_USERS_PER_RUN = 50

# Ambient Intelligence System Prompt for Event Detection
AMBIENT_EVENT_DETECTOR_PROMPT = """You are Ambia's ambient event detector - an AI that identifies time-sensitive moments in a user's life.

YOUR JOB:
Analyze the user's current context and detect moments that deserve immediate attention through:
- **Live Activities**: Ongoing events (travel, deliveries, timers, countdowns)
- **Dynamic Island**: Brief glanceable updates (quick status, progress, timers)
- **Notifications**: Important time-sensitive moments (reminders, arrivals, completions)

CORE PRINCIPLE:
Information should appear EXACTLY when it's needed, without the user asking.

USER CONTEXT PROVIDED:
- Current time and date
- Recent activity patterns
- Calendar events (if available)
- Location context (if available)
- Recent queries and interactions

RESPONSE FORMAT (return ONLY valid JSON):
{
  "events": [
    {
      "event_type": "live_activity" | "dynamic_island" | "notification",
      "priority": "critical" | "high" | "medium" | "low",
      "title": "Brief title (50 chars max)",
      "subtitle": "Optional subtitle",
      "body": "Longer description for notifications",
      "data": {
        // NO HARDCODING - You can put ANY fields here!
        // Examples:
        // For Amtrak: {"train": "Northeast Regional 190", "platform": "Track 7", "departure_time": "3:45 PM", "travel_time_mins": 18}
        // For Package: {"carrier": "UPS", "tracking": "1Z999AA10123456784", "delivery_window": "2:00 PM - 6:00 PM"}
        // For Timer: {"remaining_seconds": 180, "timer_name": "Pasta"}
      },
      "icon": "SF Symbol name (optional)",
      "color": "Hex color like #FF5733 (optional)",
      "start_time": "ISO 8601 timestamp when event becomes relevant",
      "end_time": "ISO 8601 timestamp when event expires",
      "confidence_score": 0.0-1.0
    }
  ]
}

IMPORTANT:
- Only generate events if there's a REAL, TIME-SENSITIVE moment happening NOW or SOON
- If nothing time-sensitive is happening, return {"events": []}
- Be proactive but not spammy
- Think about what would genuinely help the user RIGHT NOW
- NO HARDCODING - You can create events for ANY service, ANY type of activity
"""


def lambda_handler(event, context):
    """
    Main Lambda handler
    Triggered by EventBridge every 1 minute
    """
    logger.info("=== Ambient Event Detector Starting ===")

    connection = None
    try:
        # Connect to database
        connection = get_db_connection()
        logger.info("Database connected successfully")

        # Get active users (have device tokens and notifications enabled)
        users = get_active_users(connection)
        logger.info(f"Found {len(users)} active users")

        if not users:
            logger.info("No active users to process")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'users_processed': 0,
                    'events_generated': 0
                })
            }

        users_processed = 0
        events_generated = 0
        errors = 0

        # Process each user
        for user in users:
            user_id = user['user_id']
            device_token = user['device_token']

            logger.info(f"Processing user {user_id}")

            try:
                # Get user context
                user_context = get_user_context(connection, user_id)

                # Call Claude to detect ambient events
                detected_events = detect_ambient_events_with_claude(
                    user_id=user_id,
                    user_context=user_context
                )

                if detected_events and len(detected_events) > 0:
                    # Store events in ambient_events table
                    for event_data in detected_events:
                        event_id = store_ambient_event(
                            connection=connection,
                            user_id=user_id,
                            event_data=event_data
                        )

                        if event_id:
                            events_generated += 1
                            logger.info(f"Generated event {event_id}: {event_data['title']}")

                            # TODO: Trigger push notification if event_type is 'notification'
                            # This would use APNs (Apple Push Notification service)

                users_processed += 1

            except Exception as e:
                logger.error(f"Error processing user {user_id}: {str(e)}", exc_info=True)
                errors += 1
                continue

        logger.info(f"=== Ambient Event Detector Complete ===")
        logger.info(f"Users processed: {users_processed}")
        logger.info(f"Events generated: {events_generated}")
        logger.info(f"Errors: {errors}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'success': True,
                'users_processed': users_processed,
                'events_generated': events_generated,
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


def get_active_users(connection):
    """
    Get users who have notifications enabled and active device tokens
    Returns list of users to process
    """
    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT DISTINCT
                dt.user_id,
                dt.device_token,
                dt.notifications_enabled,
                dt.live_activities_enabled,
                dt.dynamic_island_enabled
            FROM device_tokens dt
            JOIN users u ON u.id = dt.user_id
            WHERE dt.notifications_enabled = TRUE
            AND dt.last_seen_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
            ORDER BY u.last_active_at DESC
            LIMIT %s
        """, (MAX_USERS_PER_RUN,))
        return cursor.fetchall()


def get_user_context(connection, user_id):
    """
    Gather comprehensive user context for Claude
    Returns context dict with time, activity patterns, recent queries, etc.
    """
    now = datetime.now()

    # Get recent activity
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
            AND timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
            ORDER BY timestamp DESC
            LIMIT 50
        """, (user_id,))
        recent_activity = cursor.fetchall()

    # Get active live activities
    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT
                id,
                event_type,
                title,
                data,
                start_time,
                end_time
            FROM ambient_events
            WHERE user_id = %s
            AND status = 'active'
            AND valid_until > NOW()
            ORDER BY created_at DESC
            LIMIT 10
        """, (user_id,))
        active_events = cursor.fetchall()

    # Get recent queries
    recent_queries = []
    time_patterns = {}
    for activity in recent_activity:
        if activity.get('query'):
            recent_queries.append({
                'query': activity['query'],
                'timestamp': activity['timestamp'].isoformat() if activity['timestamp'] else None
            })
        tod = activity.get('time_of_day')
        if tod:
            time_patterns[tod] = time_patterns.get(tod, 0) + 1

    context = {
        'current_time': now.isoformat(),
        'day_of_week': now.strftime('%A'),
        'time_of_day': get_time_of_day(now),
        'recent_queries': recent_queries[:10],
        'time_patterns': time_patterns,
        'active_events': [
            {
                'id': str(evt['id']),
                'type': evt['event_type'],
                'title': evt['title'],
                'data': json.loads(evt['data']) if evt['data'] else {}
            }
            for evt in active_events
        ],
        'total_recent_activities': len(recent_activity)
    }

    return context


def get_time_of_day(dt):
    """Categorize time of day"""
    hour = dt.hour
    if 5 <= hour < 12:
        return 'morning'
    elif 12 <= hour < 17:
        return 'afternoon'
    elif 17 <= hour < 21:
        return 'evening'
    else:
        return 'night'


def detect_ambient_events_with_claude(user_id, user_context):
    """
    Call Claude API to detect time-sensitive ambient events
    Returns: List of event objects or [] if none detected
    """
    try:
        # Build prompt
        prompt = f"""{AMBIENT_EVENT_DETECTOR_PROMPT}

USER CONTEXT:
{json.dumps(user_context, indent=2)}

Analyze this context and detect any time-sensitive moments that deserve immediate attention.
Return ONLY valid JSON with detected events, or {{"events": []}} if nothing is time-sensitive right now."""

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
        events = response_data.get('events', [])

        logger.info(f"Claude detected {len(events)} events for user {user_id}")
        return events

    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse Claude response as JSON: {str(e)}")
        logger.error(f"Response was: {response_text}")
        return []
    except Exception as e:
        logger.error(f"Claude API error: {str(e)}", exc_info=True)
        return []


def store_ambient_event(connection, user_id, event_data):
    """
    Store generated ambient event in ambient_events table
    Returns: event_id or None on failure
    """
    event_id = str(uuid4())

    try:
        # Extract fields from event_data
        event_type = event_data.get('event_type', 'notification')
        priority = event_data.get('priority', 'medium')
        title = event_data.get('title', '')
        subtitle = event_data.get('subtitle')
        body = event_data.get('body')
        data = event_data.get('data', {})
        icon = event_data.get('icon')
        color = event_data.get('color')
        confidence_score = event_data.get('confidence_score', 0.7)

        # Parse timestamps
        start_time = None
        end_time = None
        if event_data.get('start_time'):
            try:
                start_time = datetime.fromisoformat(event_data['start_time'].replace('Z', '+00:00'))
            except:
                pass

        if event_data.get('end_time'):
            try:
                end_time = datetime.fromisoformat(event_data['end_time'].replace('Z', '+00:00'))
            except:
                pass

        # Default validity: 1 hour from now
        valid_until = datetime.now() + timedelta(hours=1)
        if end_time:
            valid_until = end_time + timedelta(minutes=15)

        with connection.cursor() as cursor:
            cursor.execute("""
                INSERT INTO ambient_events (
                    id, user_id, event_type, priority,
                    title, subtitle, body, data,
                    icon, color,
                    start_time, end_time, valid_until,
                    status, confidence_score,
                    generation_source, created_at
                ) VALUES (
                    %s, %s, %s, %s,
                    %s, %s, %s, %s,
                    %s, %s,
                    %s, %s, %s,
                    %s, %s,
                    %s, NOW()
                )
            """, (
                event_id, user_id, event_type, priority,
                title, subtitle, body, json.dumps(data),
                icon, color,
                start_time, end_time, valid_until,
                'pending', confidence_score,
                'claude'
            ))
            connection.commit()

            logger.info(f"Stored ambient event {event_id}: {title}")
            return event_id

    except Exception as e:
        logger.error(f"Failed to store ambient event: {str(e)}", exc_info=True)
        connection.rollback()
        return None
