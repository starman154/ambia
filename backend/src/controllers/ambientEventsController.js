/**
 * Ambient Events Controller
 * Handles iOS Live Activities, Dynamic Island, and Notification events
 */

const db = require('../utils/database');
const {v4: uuidv4} = require('uuid');
const https = require('https');

// Claude API configuration
const CLAUDE_API_KEY = process.env.CLAUDE_API_KEY;
const CLAUDE_MODEL = 'claude-sonnet-4-5-20250929';

/**
 * GET /ambient/events/:userId
 * Get active ambient events for a user
 */
exports.getActiveEvents = async (req, res) => {
  try {
    const { userId } = req.params;
    const { type } = req.query; // Filter by event_type if provided

    let query = `
      SELECT
        id,
        event_type,
        priority,
        title,
        subtitle,
        body,
        data,
        icon,
        color,
        start_time,
        end_time,
        valid_until,
        status,
        confidence_score,
        created_at
      FROM ambient_events
      WHERE user_id = ?
      AND status IN ('pending', 'active')
      AND valid_until > NOW()
    `;

    const params = [userId];

    if (type) {
      query += ' AND event_type = ?';
      params.push(type);
    }

    query += ' ORDER BY priority DESC, created_at DESC LIMIT 50';

    const [events] = await db.query(query, params);

    // Parse JSON data field
    const parsedEvents = events.map(event => ({
      ...event,
      data: typeof event.data === 'string' ? JSON.parse(event.data) : event.data
    }));

    res.json({
      success: true,
      events: parsedEvents
    });

  } catch (error) {
    console.error('Get active events error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve events'
    });
  }
};

/**
 * POST /ambient/events/:eventId/interact
 * Track user interaction with an event
 */
exports.trackInteraction = async (req, res) => {
  try {
    const { eventId } = req.params;
    const { userId, interactionType, metadata = {} } = req.body;

    const interactionId = uuidv4();

    // Insert interaction
    await db.query(`
      INSERT INTO event_interactions (
        id, event_id, user_id, interaction_type, metadata, created_at
      ) VALUES (?, ?, ?, ?, ?, NOW())
    `, [interactionId, eventId, userId, interactionType, JSON.stringify(metadata)]);

    // Update event timestamps based on interaction type
    switch (interactionType) {
      case 'shown':
        await db.query(`
          UPDATE ambient_events
          SET shown_at = NOW(), status = 'active'
          WHERE id = ?
        `, [eventId]);
        break;

      case 'tap':
      case 'expand':
        await db.query(`
          UPDATE ambient_events
          SET interacted_at = NOW()
          WHERE id = ?
        `, [eventId]);
        break;

      case 'dismiss':
      case 'swipe_away':
        await db.query(`
          UPDATE ambient_events
          SET dismissed_at = NOW(), status = 'completed'
          WHERE id = ?
        `, [eventId]);
        break;

      case 'complete':
        await db.query(`
          UPDATE ambient_events
          SET status = 'completed'
          WHERE id = ?
        `, [eventId]);
        break;
    }

    res.json({
      success: true,
      interactionId
    });

  } catch (error) {
    console.error('Track interaction error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to track interaction'
    });
  }
};

/**
 * POST /ambient/devices/register
 * Register or update device token for push notifications
 */
exports.registerDevice = async (req, res) => {
  try {
    const {
      userId,
      deviceToken,
      deviceType = 'ios',
      deviceName,
      osVersion,
      notificationsEnabled = true,
      liveActivitiesEnabled = true,
      dynamicIslandEnabled = true
    } = req.body;

    if (!userId || !deviceToken) {
      return res.status(400).json({
        success: false,
        error: 'userId and deviceToken are required'
      });
    }

    const deviceId = uuidv4();

    // Check if device token already exists
    const [existingDevices] = await db.query(`
      SELECT id FROM device_tokens WHERE device_token = ?
    `, [deviceToken]);

    if (existingDevices.length > 0) {
      // Update existing device
      await db.query(`
        UPDATE device_tokens
        SET
          user_id = ?,
          device_type = ?,
          device_name = ?,
          os_version = ?,
          notifications_enabled = ?,
          live_activities_enabled = ?,
          dynamic_island_enabled = ?,
          last_seen_at = NOW(),
          updated_at = NOW()
        WHERE device_token = ?
      `, [
        userId,
        deviceType,
        deviceName,
        osVersion,
        notificationsEnabled,
        liveActivitiesEnabled,
        dynamicIslandEnabled,
        deviceToken
      ]);

      res.json({
        success: true,
        deviceId: existingDevices[0].id,
        updated: true
      });
    } else {
      // Insert new device
      await db.query(`
        INSERT INTO device_tokens (
          id, user_id, device_token, device_type,
          device_name, os_version,
          notifications_enabled, live_activities_enabled, dynamic_island_enabled,
          created_at, last_seen_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
      `, [
        deviceId,
        userId,
        deviceToken,
        deviceType,
        deviceName,
        osVersion,
        notificationsEnabled,
        liveActivitiesEnabled,
        dynamicIslandEnabled
      ]);

      res.json({
        success: true,
        deviceId,
        created: true
      });
    }

  } catch (error) {
    console.error('Register device error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to register device'
    });
  }
};

/**
 * PUT /ambient/devices/:deviceId/preferences
 * Update device notification preferences
 */
exports.updateDevicePreferences = async (req, res) => {
  try {
    const { deviceId } = req.params;
    const {
      notificationsEnabled,
      liveActivitiesEnabled,
      dynamicIslandEnabled
    } = req.body;

    const updates = [];
    const values = [];

    if (notificationsEnabled !== undefined) {
      updates.push('notifications_enabled = ?');
      values.push(notificationsEnabled);
    }
    if (liveActivitiesEnabled !== undefined) {
      updates.push('live_activities_enabled = ?');
      values.push(liveActivitiesEnabled);
    }
    if (dynamicIslandEnabled !== undefined) {
      updates.push('dynamic_island_enabled = ?');
      values.push(dynamicIslandEnabled);
    }

    if (updates.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No preferences provided to update'
      });
    }

    updates.push('updated_at = NOW()');
    values.push(deviceId);

    await db.query(`
      UPDATE device_tokens
      SET ${updates.join(', ')}
      WHERE id = ?
    `, values);

    res.json({
      success: true
    });

  } catch (error) {
    console.error('Update device preferences error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update preferences'
    });
  }
};

/**
 * GET /ambient/events/:eventId
 * Get details of a specific event
 */
exports.getEvent = async (req, res) => {
  try {
    const { eventId } = req.params;

    const [events] = await db.query(`
      SELECT
        id,
        user_id,
        event_type,
        priority,
        title,
        subtitle,
        body,
        data,
        icon,
        color,
        start_time,
        end_time,
        valid_until,
        status,
        confidence_score,
        shown_at,
        interacted_at,
        dismissed_at,
        created_at
      FROM ambient_events
      WHERE id = ?
    `, [eventId]);

    if (events.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Event not found'
      });
    }

    const event = events[0];
    event.data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;

    res.json({
      success: true,
      event
    });

  } catch (error) {
    console.error('Get event error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to retrieve event'
    });
  }
};

/**
 * POST /ambient/events/test
 * Create a test ambient event (for debugging)
 */
exports.createTestEvent = async (req, res) => {
  try {
    const userId = req.body.userId || '410b2520-e011-70d9-1ef0-10cead18dedd';

    const testEvent = {
      id: `test-${Date.now()}`,
      user_id: userId,
      event_type: 'live_activity',
      title: '🎯 Test Meeting - Dynamic Page Demo',
      subtitle: 'Tap to see Claude-generated page',
      body: 'This is a test event to verify the dynamic ambient info page works!',
      priority: 'high',
      icon: 'star.fill',
      color: '#FF6B6B',
      status: 'active',
      data: JSON.stringify({
        progress: 0.75,
        location: 'Virtual Meeting Room',
        duration: '30 minutes',
        attendees: ['Alice', 'Bob', 'Charlie'],
        type: 'meeting'
      }),
      start_time: new Date(Date.now() + 30 * 60 * 1000), // 30 minutes from now
      end_time: new Date(Date.now() + 60 * 60 * 1000), // 1 hour from now
      valid_until: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours from now
    };

    await db.query(`
      INSERT INTO ambient_events
      (id, user_id, event_type, title, subtitle, body, priority, icon, color, status, data, start_time, end_time, valid_until, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    `, [
      testEvent.id,
      testEvent.user_id,
      testEvent.event_type,
      testEvent.title,
      testEvent.subtitle,
      testEvent.body,
      testEvent.priority,
      testEvent.icon,
      testEvent.color,
      testEvent.status,
      testEvent.data,
      testEvent.start_time,
      testEvent.end_time,
      testEvent.valid_until
    ]);

    res.json({
      success: true,
      message: 'Test event created! Restart your app or wait for next sync.',
      eventId: testEvent.id,
      deleteCommand: `DELETE FROM ambient_events WHERE id = '${testEvent.id}';`
    });

  } catch (error) {
    console.error('Create test event error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create test event',
      details: error.message
    });
  }
};

/**
 * GET /ambient/layout/:eventId
 * Generate dynamic Apple Weather-style page layout for an ambient event
 * Uses Claude to intelligently analyze event data and create contextual layouts
 * Checks for cached layouts first to improve performance
 */
exports.generateLayout = async (req, res) => {
  try {
    const { eventId } = req.params;

    console.log(`[Layout Generator] Fetching layout for event: ${eventId}`);

    // Fetch event data including cached layout
    const [events] = await db.query(`
      SELECT
        id,
        user_id,
        event_type,
        priority,
        title,
        subtitle,
        body,
        data,
        icon,
        color,
        start_time,
        end_time,
        valid_until,
        status,
        confidence_score,
        generated_layout,
        layout_generated_at,
        created_at
      FROM ambient_events
      WHERE id = ?
    `, [eventId]);

    if (events.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Event not found'
      });
    }

    const event = events[0];
    event.data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;

    // Check if we have a cached layout
    if (event.generated_layout) {
      console.log(`[Layout Generator] ✅ Returning cached layout for ${eventId}`);
      const cachedLayout = typeof event.generated_layout === 'string'
        ? JSON.parse(event.generated_layout)
        : event.generated_layout;

      return res.json({
        success: true,
        eventId,
        layout: cachedLayout,
        cached: true,
        generatedAt: event.layout_generated_at
      });
    }

    // No cached layout, generate new one
    console.log(`[Layout Generator] No cached layout, generating fresh layout for ${eventId}`);
    const layout = await callClaudeForLayout(event);

    // Store the generated layout for future requests
    await db.query(`
      UPDATE ambient_events
      SET generated_layout = ?, layout_generated_at = NOW()
      WHERE id = ?
    `, [JSON.stringify(layout), eventId]);

    res.json({
      success: true,
      eventId,
      layout,
      cached: false
    });

  } catch (error) {
    console.error('[Layout Generator] Error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to generate layout',
      details: error.message
    });
  }
};

/**
 * Helper: Call Claude API to generate intelligent Apple Weather-style layout
 */
async function callClaudeForLayout(event) {
  return new Promise((resolve, reject) => {
    const systemPrompt = `You are Ambia's layout designer. Your job is to analyze ambient events and generate STUNNING Apple Weather-style page layouts.

🎨 DESIGN PHILOSOPHY:
- Apple Weather aesthetic: Clean, spacious, variable-sized cards in a STAGGERED 2-COLUMN GRID
- Mix full-width cards with side-by-side cards for visual interest
- Information hierarchy: Most important info in larger hero cards
- Contextual intelligence: Design based on what the user needs NOW
- Rich detail: Fill cards with useful, contextual information
- Actionable: Include relevant CTAs

📐 LAYOUT STRUCTURE:
{
  "header": { "title": "...", "subtitle": "...", "icon": "star.fill", "color": "#FF6B6B" },
  "cards": [
    { "type": "hero|standard|compact", "title": "...", "content": {...}, "action": {...} },
    ...
  ]
}

🎴 CARD TYPES & GRID BEHAVIOR:
- "hero": FULL-WIDTH, tall (240px), prominent - Use for primary info
- "standard": HALF-WIDTH, medium (180px) - TWO can sit SIDE-BY-SIDE in a row
- "compact": HALF-WIDTH, short (120px) - TWO can sit SIDE-BY-SIDE in a row

📊 CARD CONTENT TYPES:
{
  "type": "text", "text": "..."
  OR "type": "progress", "progress": 0.75, "label": "..."
  OR "type": "list", "items": [{"label": "...", "value": "..."}]
  OR "type": "countdown", "targetTime": "ISO8601", "message": "..."
}

🎯 LAYOUT STRATEGY:
1. Start with a HERO card for the most important info
2. Mix standard and compact cards, placing them side-by-side
3. Create visual rhythm: hero → standard+standard → compact+compact → hero
4. Fill attendees, locations, times, durations, next steps, etc.
5. Make it info-rich and visually stunning!

EXAMPLE MEETING LAYOUT:
[Hero: Meeting Progress with Join button]
[Standard: Attendees list] [Standard: Location + Time]
[Compact: Duration] [Compact: Next Meeting]

Be creative! Make it look INSANE!`;

    const userPrompt = `Generate an Apple Weather-style layout for this ambient event:

Event Type: ${event.event_type}
Priority: ${event.priority}
Title: ${event.title}
Subtitle: ${event.subtitle}
Body: ${event.body}
Icon: ${event.icon}
Color: ${event.color}
Start Time: ${event.start_time}
End Time: ${event.end_time}
Additional Data: ${JSON.stringify(event.data, null, 2)}

Analyze this event and create a stunning, contextual page layout. Consider:
1. What information is most critical?
2. What actions might the user need to take?
3. What additional context would be helpful?
4. How can we make this beautiful and intuitive?

Return ONLY valid JSON with the layout structure. No markdown, no explanation.`;

    const requestData = JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: 4096,
      system: systemPrompt,
      messages: [
        {
          role: 'user',
          content: userPrompt
        }
      ]
    });

    const options = {
      hostname: 'api.anthropic.com',
      path: '/v1/messages',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': CLAUDE_API_KEY,
        'anthropic-version': '2023-06-01'
      }
    };

    const req = https.request(options, (response) => {
      let data = '';

      response.on('data', (chunk) => {
        data += chunk;
      });

      response.on('end', () => {
        try {
          const result = JSON.parse(data);

          if (result.error) {
            console.error('[Claude API] Error:', result.error);
            reject(new Error(result.error.message || 'Claude API error'));
            return;
          }

          if (result.content && result.content[0] && result.content[0].text) {
            const layoutText = result.content[0].text;

            // Parse Claude's JSON response
            let layout;
            try {
              // Remove markdown code blocks if present
              const jsonMatch = layoutText.match(/```json\n?([\s\S]*?)\n?```/) || layoutText.match(/```\n?([\s\S]*?)\n?```/);
              const cleanJson = jsonMatch ? jsonMatch[1] : layoutText;
              layout = JSON.parse(cleanJson.trim());
            } catch (parseError) {
              console.error('[Claude Response] JSON parse error:', parseError);
              console.error('[Claude Response] Raw text:', layoutText);
              // Fallback to basic layout
              layout = createFallbackLayout(event);
            }

            console.log('[Layout Generator] Successfully generated layout');
            resolve(layout);
          } else {
            reject(new Error('Unexpected Claude API response format'));
          }
        } catch (error) {
          console.error('[Claude API] Parse error:', error);
          reject(error);
        }
      });
    });

    req.on('error', (error) => {
      console.error('[Claude API] Request error:', error);
      reject(error);
    });

    req.write(requestData);
    req.end();
  });
}

/**
 * Helper: Create fallback layout when Claude fails
 */
function createFallbackLayout(event) {
  return {
    header: {
      title: event.title,
      subtitle: event.subtitle,
      icon: event.icon,
      color: event.color
    },
    cards: [
      {
        type: 'hero',
        title: event.title,
        content: {
          type: 'text',
          text: event.body
        }
      },
      {
        type: 'standard',
        title: 'Details',
        content: {
          type: 'list',
          items: [
            { label: 'Priority', value: event.priority },
            { label: 'Type', value: event.event_type },
            { label: 'Status', value: event.status }
          ]
        }
      }
    ]
  };
}

/**
 * Helper: Create ambient event with pre-generated layout
 * This is called by calendar sync to create ambient events in the background
 */
exports.createAmbientEventWithLayout = async function(eventData) {
  try {
    const eventId = eventData.id || uuidv4();

    console.log(`[Ambient Event] Creating event: ${eventData.title}`);

    // Insert ambient event into database
    await db.query(`
      INSERT INTO ambient_events (
        id, user_id, event_type, title, subtitle, body, priority,
        icon, color, status, data, start_time, end_time, valid_until,
        calendar_event_id, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    `, [
      eventId,
      eventData.user_id,
      eventData.event_type || 'live_activity',
      eventData.title,
      eventData.subtitle || null,
      eventData.body || null,
      eventData.priority || 'medium',
      eventData.icon || 'calendar',
      eventData.color || '#3B82F6',
      eventData.status || 'pending',
      JSON.stringify(eventData.data || {}),
      eventData.start_time,
      eventData.end_time,
      eventData.valid_until,
      eventData.calendar_event_id || null
    ]);

    console.log(`[Ambient Event] Event created: ${eventId}`);

    // Generate layout in the background (async, don't wait for it)
    generateAndStoreLayout(eventId).catch(err => {
      console.error(`[Ambient Event] Failed to generate layout for ${eventId}:`, err.message);
    });

    return eventId;
  } catch (error) {
    console.error('[Ambient Event] Error creating event:', error);
    throw error;
  }
};

/**
 * Helper: Generate layout and store it in the database
 * Called asynchronously after ambient event creation
 */
async function generateAndStoreLayout(eventId) {
  try {
    console.log(`[Layout Generator] Starting background generation for ${eventId}`);

    // Fetch event data
    const [events] = await db.query(`
      SELECT * FROM ambient_events WHERE id = ?
    `, [eventId]);

    if (events.length === 0) {
      console.error(`[Layout Generator] Event ${eventId} not found`);
      return;
    }

    const event = events[0];
    event.data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;

    // Generate layout using Claude
    const layout = await callClaudeForLayout(event);

    // Store layout in database
    await db.query(`
      UPDATE ambient_events
      SET generated_layout = ?, layout_generated_at = NOW()
      WHERE id = ?
    `, [JSON.stringify(layout), eventId]);

    console.log(`[Layout Generator] ✅ Layout generated and cached for ${eventId}`);
  } catch (error) {
    console.error(`[Layout Generator] Error generating layout for ${eventId}:`, error.message);
  }
}
