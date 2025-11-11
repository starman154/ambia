/**
 * CALENDAR CONTROLLER
 *
 * Receives calendar events from iOS devices and stores them in the database.
 * The CalendarService (backend) will then classify these events and generate ambient intelligence insights.
 */

const pool = require('../utils/database');
const CalendarService = require('../services/CalendarService');
const { v4: uuidv4 } = require('uuid');
const ambientController = require('./ambientEventsController');
const LlamaReasoningService = require('../services/LlamaReasoningService');

/**
 * POST /api/calendar/sync
 * Syncs calendar events from device to backend
 */
exports.syncCalendar = async (req, res) => {
  try {
    const { userId, events } = req.body;

    if (!userId || !events || !Array.isArray(events)) {
      return res.status(400).json({
        error: 'Missing required fields: userId and events array'
      });
    }

    console.log(`[Calendar Sync] Received ${events.length} events from user ${userId}`);

    const calendarService = new CalendarService(pool);

    // Clear existing events for this user (we'll re-sync all)
    await pool.query(`
      DELETE FROM calendar_events WHERE user_id = ?
    `, [userId]);

    // Insert all events
    let insertedCount = 0;
    for (const event of events) {
      try {
        const eventId = uuidv4();

        await pool.query(`
          INSERT INTO calendar_events (
            id,
            user_id,
            external_id,
            calendar_id,
            title,
            description,
            start_time,
            end_time,
            location,
            all_day,
            attendees,
            organizer,
            recurrence_rule,
            url,
            created_at,
            updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
        `, [
          eventId,
          userId,
          event.id || null,
          event.calendarId || null,
          event.title || 'Untitled Event',
          event.description || null,
          event.start ? new Date(event.start) : null,
          event.end ? new Date(event.end) : null,
          event.location || null,
          event.allDay || false,
          event.attendees ? JSON.stringify(event.attendees) : null,
          event.organizer ? JSON.stringify(event.organizer) : null,
          event.recurrenceRule ? JSON.stringify(event.recurrenceRule) : null,
          event.url || null
        ]);

        // Classify the event and check if it needs ambient intelligence
        const parsedEvent = {
          id: eventId,
          subject: event.title,
          body: event.description || '',
          fullBody: event.description || '',
          startTime: event.start ? new Date(event.start) : new Date(),
          endTime: event.end ? new Date(event.end) : new Date(),
          location: event.location ? { displayName: event.location } : null,
          attendees: event.attendees || [],
          organizer: 'User',
          isAllDay: event.allDay || false,
        };

        const classification = calendarService.classifyEvent(parsedEvent);

        console.log(`[Calendar] Event "${event.title}" classified as: ${classification.type} (confidence: ${classification.confidence})`);

        insertedCount++;
      } catch (err) {
        console.error(`[Calendar] Error inserting event "${event.title}":`, err.message);
      }
    }

    console.log(`[Calendar Sync] Successfully inserted ${insertedCount}/${events.length} events`);

    // HYBRID AI SYSTEM: Use Llama to analyze calendar events and generate proactive ambient events
    // Llama (reasoning brain) decides which events need ambient intelligence
    // Claude (UI brain) generates beautiful layouts for those events (happens in background)
    console.log(`[Calendar Sync] 🧠 Triggering Llama reasoning engine to analyze calendar events...`);
    const llamaService = new LlamaReasoningService(pool);

    // Run Llama analysis in background (don't wait for it)
    llamaService.generateProactiveInsights(userId).then(insights => {
      console.log(`[Calendar Sync] ✅ Llama generated ${insights.length} ambient events`);
      console.log(`[Calendar Sync] 🎨 Claude will now generate layouts for these events in the background`);
    }).catch(err => {
      console.error(`[Calendar Sync] ⚠️ Llama analysis failed:`, err.message);
    });

    res.json({
      success: true,
      message: `Synced ${insertedCount} calendar events`,
      insertedCount,
      totalEvents: events.length
    });

  } catch (error) {
    console.error('[Calendar Sync] Error:', error);
    res.status(500).json({
      error: 'Failed to sync calendar events',
      message: error.message
    });
  }
};

/**
 * GET /api/calendar/events
 * Get calendar events for a user
 */
exports.getEvents = async (req, res) => {
  try {
    const { userId } = req.query;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const [rows] = await pool.query(`
      SELECT * FROM calendar_events
      WHERE user_id = ? AND start_time >= NOW()
      ORDER BY start_time ASC
      LIMIT 50
    `, [userId]);

    res.json({
      success: true,
      events: rows
    });

  } catch (error) {
    console.error('[Calendar] Error getting events:', error);
    res.status(500).json({
      error: 'Failed to get calendar events',
      message: error.message
    });
  }
};

/**
 * POST /api/calendar/test-llama
 * DEBUG: Manually trigger Llama analysis
 */
exports.testLlama = async (req, res) => {
  try {
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    console.log(`[DEBUG] Manually triggering Llama for user ${userId}`);

    const llamaService = new LlamaReasoningService(pool);
    const insights = await llamaService.generateProactiveInsights(userId);

    console.log(`[DEBUG] Llama generated ${insights.length} insights`);

    res.json({
      success: true,
      insightsGenerated: insights.length,
      insights: insights
    });

  } catch (error) {
    console.error('[DEBUG] Llama test failed:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      stack: error.stack
    });
  }
};
