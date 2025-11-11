/**
 * LLAMA REASONING SERVICE
 *
 * The "thinking brain" of Ambia's dual-AI architecture.
 *
 * Llama analyzes context and makes decisions:
 * - What information should be shown?
 * - When should it be shown?
 * - How urgent is it?
 * - What components are needed?
 *
 * Then passes those decisions to Claude for beautiful UI generation.
 */

const Together = require('together-ai');
const { v4: uuidv4 } = require('uuid');
const CalendarService = require('./CalendarService');
const WeatherService = require('./WeatherService');

class LlamaReasoningService {
  constructor(db) {
    this.db = db;
    this.together = new Together({
      apiKey: process.env.TOGETHER_AI_KEY
    });
    this.calendarService = new CalendarService(db);
    this.weatherService = new WeatherService();
  }

  /**
   * CORE REASONING FUNCTION
   * Analyzes user context and decides what to show
   */
  async analyzeAndDecide(userId, userQuery, contextSnapshot) {
    const startTime = Date.now();

    console.log(`[Llama Brain] Analyzing context for user ${userId}: "${userQuery}"`);

    // Build the reasoning prompt
    const prompt = this.buildReasoningPrompt(userQuery, contextSnapshot);

    // Call Llama
    const response = await this.callLlama(prompt);

    // Parse Llama's decision
    const decision = this.parseDecision(response);

    // Calculate execution time
    const executionTime = Date.now() - startTime;

    // Save decision to database
    const decisionId = await this.saveDecision({
      userId,
      query: userQuery,
      contextSnapshot,
      decision,
      executionTime
    });

    console.log(`[Llama Brain] Decision: ${decision.decision_type} (priority: ${decision.priority_score})`);

    return {
      ...decision,
      decisionId,
      executionTime
    };
  }

  /**
   * Build the prompt that tells Llama how to think
   */
  buildReasoningPrompt(userQuery, contextSnapshot) {
    const { timeOfDay, dayOfWeek, nextEventMinutes, eventsToday, recentActivity } = contextSnapshot;

    return `You are Ambia's reasoning engine. Your job is to analyze context and decide what information to show.

USER QUERY: "${userQuery}"

CURRENT CONTEXT:
- Time: ${timeOfDay} on ${dayOfWeek}
- Next Event: ${nextEventMinutes ? `in ${nextEventMinutes} minutes` : 'none'}
- Events Today: ${eventsToday || 0}
- Recent Activity: ${recentActivity || 'none'}

YOUR TASK:
Analyze this query in context and decide:

1. DECISION TYPE (choose one):
   - "show_now": Information is immediately relevant
   - "show_later": Schedule for later (provide time)
   - "cache": Pre-generate and cache for quick access
   - "ignore": Not relevant enough to act on

2. PRIORITY SCORE (0.0 to 1.0):
   How important is this right now?
   - 0.9-1.0: Critical/Urgent
   - 0.7-0.9: High priority
   - 0.4-0.7: Medium priority
   - 0.0-0.4: Low priority

3. URGENCY:
   - "critical": Needs immediate attention
   - "high": Important soon
   - "medium": Helpful to know
   - "low": Nice to have

4. RECOMMENDED COMPONENTS:
   What UI components would best show this information?

   COMPONENT SELECTION GUIDE:
   - Movies/TV/Books/Albums/Games → ["media_card", "expandable_list"] for rich detail cards
   - Lists with additional details → ["expandable_list"] so users can tap to see more
   - Calendar/schedule queries → ["calendar_event", "timeline"]
   - Weather/location queries → ["weather", "location", "map"]
   - Metrics/analytics → ["metric", "chart", "progress"]
   - Simple text information → ["text", "header"]
   - People/teams → ["person_list"]

   Examples: ["calendar_event", "weather", "traffic", "metric", "chart", "list", "media_card", "expandable_list"]

5. COMPONENT PRIORITIES:
   How important is each component? (JSON object with scores 0-1)

6. REASONING:
   Explain your decision in 1-2 sentences.

RESPOND IN THIS EXACT JSON FORMAT:
{
  "decision_type": "show_now",
  "priority_score": 0.8,
  "urgency": "high",
  "recommended_components": ["calendar_event", "weather"],
  "component_priorities": {
    "calendar_event": 0.9,
    "weather": 0.6
  },
  "reasoning": "User asking about tomorrow with next event in 30 minutes - calendar is most relevant"
}`;
  }

  /**
   * Call Llama via Together AI
   */
  async callLlama(prompt) {
    try {
      const response = await this.together.chat.completions.create({
        model: 'meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo',
        messages: [
          {
            role: 'system',
            content: 'You are a reasoning engine that analyzes context and makes decisions. Always respond with valid JSON.'
          },
          {
            role: 'user',
            content: prompt
          }
        ],
        max_tokens: 1000,
        temperature: 0.3, // Lower temperature for more consistent reasoning
        response_format: { type: 'json_object' }
      });

      return response.choices[0].message.content;
    } catch (error) {
      console.error('[Llama Brain] Error calling Together AI:', error);
      throw new Error(`Llama reasoning failed: ${error.message}`);
    }
  }

  /**
   * Parse Llama's JSON response
   */
  parseDecision(responseText) {
    try {
      const decision = JSON.parse(responseText);

      // Validate required fields
      if (!decision.decision_type || !decision.priority_score) {
        throw new Error('Missing required decision fields');
      }

      // Normalize priority score to 0-1 range
      if (decision.priority_score > 1.0) {
        decision.priority_score = decision.priority_score / 100;
      }

      return decision;
    } catch (error) {
      console.error('[Llama Brain] Failed to parse decision:', error);

      // Fallback to safe default
      return {
        decision_type: 'show_now',
        priority_score: 0.5,
        urgency: 'medium',
        recommended_components: ['text'],
        component_priorities: { 'text': 0.5 },
        reasoning: 'Fallback decision due to parsing error'
      };
    }
  }

  /**
   * Save decision to database
   */
  async saveDecision({ userId, query, contextSnapshot, decision, executionTime }) {
    const decisionId = uuidv4();

    try {
      await this.db.query(`
        INSERT INTO reasoning_decisions (
          id,
          user_id,
          query,
          context_snapshot,
          decision_type,
          priority_score,
          urgency,
          recommended_components,
          component_priorities,
          reasoning,
          execution_time_ms,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
      `, [
        decisionId,
        userId,
        query,
        JSON.stringify(contextSnapshot),
        decision.decision_type,
        decision.priority_score,
        decision.urgency,
        JSON.stringify(decision.recommended_components),
        JSON.stringify(decision.component_priorities),
        decision.reasoning,
        executionTime
      ]);

      return decisionId;
    } catch (error) {
      console.error('[Llama Brain] Failed to save decision:', error);
      // Don't throw - decision is still valid even if we can't save it
      return decisionId;
    }
  }

  /**
   * PROACTIVE INSIGHTS GENERATION
   * Scans upcoming events and generates ambient intelligence insights
   */
  async generateProactiveInsights(userId) {
    console.log(`[Llama Brain] Generating proactive insights for user ${userId}`);

    try {
      // Get upcoming events from database (not Outlook API)
      const [rows] = await this.db.query(`
        SELECT id, title as subject, description as body, description as fullBody,
               start_time as startTime, end_time as endTime,
               location, attendees, organizer, all_day as isAllDay
        FROM calendar_events
        WHERE user_id = ? AND start_time >= NOW()
        ORDER BY start_time ASC
        LIMIT 50
      `, [userId]);

      if (rows.length === 0) {
        console.log('[Llama Brain] No upcoming events found');
        return [];
      }

      // Transform database rows to event format
      const events = rows.map(row => ({
        ...row,
        location: row.location ? { displayName: row.location } : null,
        attendees: row.attendees
          ? (typeof row.attendees === 'string' ? JSON.parse(row.attendees) : row.attendees)
          : [],
        startTime: new Date(row.startTime),
        endTime: new Date(row.endTime)
      }));

      const insights = [];

      // Analyze each event
      for (const event of events) {
        const classification = this.calendarService.classifyEvent(event);
        const minutesUntil = this.calendarService.getMinutesUntilEvent(event);

        console.log(`[Llama Brain] Analyzing ${classification.type}: "${event.subject}" (in ${minutesUntil} mins, confidence: ${classification.confidence})`);

        // SIMPLIFIED: Create ambient events for ALL upcoming events within reasonable time windows
        // This allows Llama to be truly intelligent about what matters, not just keyword matching

        // Only filter by time, not by event type
        if (minutesUntil > 0 && minutesUntil <= 10080) { // 7 days
          // Determine priority based on how soon it is
          let priority = 'low';
          if (minutesUntil <= 60) priority = 'high';
          else if (minutesUntil <= 1440) priority = 'medium'; // 24 hours

          const insight = {
            userId,
            eventType: 'live_activity',  // Fixed: Must be one of the valid constraint values
            priority,
            title: event.subject,
            subtitle: `${Math.floor(minutesUntil / 60)} hours until event`,
            body: event.body || `Event starts at ${event.startTime.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}`,
            data: {
              originalEvent: {
                id: event.id,
                subject: event.subject,
                startTime: event.startTime,
                endTime: event.endTime,
                location: event.location,
                attendees: event.attendees
              },
              calendarEventType: classification.type || 'event'  // Store original type in data
            },
            icon: 'calendar',
            color: '#EC4899',
            startTime: event.startTime,
            endTime: event.endTime,
            validUntil: event.startTime,
            confidenceScore: 1.0,
            generationSource: 'llama'
          };

          insights.push(insight);
        }
      }

      console.log(`[Llama Brain] Generated ${insights.length} proactive insights`);

      // Save insights to ambient_events table
      for (const insight of insights) {
        await this.saveAmbientEvent(insight);
      }

      return insights;
    } catch (error) {
      console.error('[Llama Brain] Error generating proactive insights:', error);
      return [];
    }
  }

  /**
   * Generate flight preparation insight with weather data
   * @private
   */
  async generateFlightInsight(userId, event, classification, minutesUntil) {
    const { extractedData } = classification;
    const { destination, origin } = extractedData;

    let weatherData = null;
    let weatherInsights = [];

    // Get weather for destination if we have a location
    if (destination || event.location?.city) {
      const city = event.location?.city || this.getCityFromAirportCode(destination);

      if (city) {
        try {
          weatherData = await this.weatherService.getWeatherByCity(city);
          weatherInsights = this.weatherService.getWeatherInsights(weatherData);
        } catch (error) {
          console.log('[Flight Insight] Weather API not ready yet:', error.message);
        }
      }
    }

    // Determine priority based on time until flight
    let priority = 'medium';
    if (minutesUntil <= 120) priority = 'high'; // 2 hours
    if (minutesUntil <= 180) priority = 'medium'; // 3 hours
    else if (minutesUntil <= 1440) priority = 'low'; // 24 hours

    // Build insight body
    let body = `Your flight is coming up`;
    if (minutesUntil <= 120) {
      body = `Your flight departs in ${Math.floor(minutesUntil / 60)} hours ${minutesUntil % 60} minutes`;
    } else if (minutesUntil <= 1440) {
      body = `Your flight is tomorrow at ${event.startTime.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })}`;
    }

    if (weatherInsights.length > 0) {
      body += '\n\nWeather at destination:\n' + weatherInsights.join('\n');
    }

    return {
      userId,
      eventType: 'flight',
      priority,
      title: `Flight Preparation${destination ? ` to ${destination}` : ''}`,
      subtitle: event.subject,
      body,
      data: {
        ...extractedData,
        weather: weatherData,
        weatherInsights,
        originalEvent: {
          id: event.id,
          subject: event.subject,
          startTime: event.startTime,
          endTime: event.endTime
        }
      },
      icon: 'flight',
      color: '#2196F3',
      startTime: event.startTime,
      endTime: event.endTime,
      validUntil: event.startTime,
      confidenceScore: classification.confidence,
      generationSource: 'llama'
    };
  }

  /**
   * Generate meeting preparation insight
   * @private
   */
  generateMeetingInsight(userId, event, classification, minutesUntil) {
    const priority = minutesUntil <= 15 ? 'high' : 'medium';

    return {
      userId,
      eventType: 'meeting',
      priority,
      title: 'Upcoming Meeting',
      subtitle: event.subject,
      body: `Meeting starts in ${minutesUntil} minutes${event.location?.displayName ? ` at ${event.location.displayName}` : ''}`,
      data: {
        attendees: event.attendees,
        location: event.location,
        originalEvent: {
          id: event.id,
          subject: event.subject,
          startTime: event.startTime,
          webLink: event.webLink
        }
      },
      icon: 'meeting',
      color: '#4CAF50',
      startTime: event.startTime,
      endTime: event.endTime,
      validUntil: event.startTime,
      confidenceScore: classification.confidence,
      generationSource: 'llama'
    };
  }

  /**
   * Generate appointment reminder insight
   * @private
   */
  generateAppointmentInsight(userId, event, classification, minutesUntil) {
    const priority = minutesUntil <= 30 ? 'high' : 'medium';
    const hoursUntil = Math.floor(minutesUntil / 60);

    return {
      userId,
      eventType: 'appointment',
      priority,
      title: 'Upcoming Appointment',
      subtitle: event.subject,
      body: `Appointment in ${hoursUntil > 0 ? `${hoursUntil} hour${hoursUntil > 1 ? 's' : ''}` : `${minutesUntil} minutes`}${event.location?.displayName ? ` at ${event.location.displayName}` : ''}`,
      data: {
        location: event.location,
        originalEvent: {
          id: event.id,
          subject: event.subject,
          startTime: event.startTime
        }
      },
      icon: 'appointment',
      color: '#FF9800',
      startTime: event.startTime,
      endTime: event.endTime,
      validUntil: event.startTime,
      confidenceScore: classification.confidence,
      generationSource: 'llama'
    };
  }

  /**
   * Generate deadline reminder insight
   * @private
   */
  generateDeadlineInsight(userId, event, classification, minutesUntil) {
    const hoursUntil = Math.floor(minutesUntil / 60);
    const priority = hoursUntil <= 6 ? 'high' : hoursUntil <= 24 ? 'medium' : 'low';

    return {
      userId,
      eventType: 'deadline',
      priority,
      title: 'Upcoming Deadline',
      subtitle: event.subject,
      body: hoursUntil <= 24 ?
        `Due in ${hoursUntil} hours` :
        `Due ${event.startTime.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })}`,
      data: {
        originalEvent: {
          id: event.id,
          subject: event.subject,
          startTime: event.startTime
        }
      },
      icon: 'deadline',
      color: '#F44336',
      startTime: event.startTime,
      validUntil: event.startTime,
      confidenceScore: classification.confidence,
      generationSource: 'llama'
    };
  }

  /**
   * Save ambient event to database and trigger Claude layout generation
   * @private
   */
  async saveAmbientEvent(insight) {
    try {
      // Extract calendar event ID from insight data (if it exists)
      const calendarEventId = insight.data?.originalEvent?.id || null;

      // Check if an ambient event already exists for this calendar event
      let existingEvent = null;
      if (calendarEventId) {
        const [rows] = await this.db.query(`
          SELECT id, generated_layout FROM ambient_events
          WHERE calendar_event_id = ? AND user_id = ?
          LIMIT 1
        `, [calendarEventId, insight.userId]);

        if (rows.length > 0) {
          existingEvent = rows[0];
        }
      }

      if (existingEvent) {
        // Update existing event instead of creating a duplicate
        const eventId = existingEvent.id;

        await this.db.query(`
          UPDATE ambient_events
          SET
            priority = ?,
            title = ?,
            subtitle = ?,
            body = ?,
            data = ?,
            icon = ?,
            color = ?,
            start_time = ?,
            end_time = ?,
            valid_until = ?,
            confidence_score = ?,
            updated_at = NOW()
          WHERE id = ?
        `, [
          insight.priority,
          insight.title,
          insight.subtitle,
          insight.body,
          JSON.stringify(insight.data),
          insight.icon,
          insight.color,
          insight.startTime,
          insight.endTime,
          insight.validUntil,
          insight.confidenceScore,
          eventId
        ]);

        console.log(`[Llama Brain] ♻️ Updated existing: ${insight.eventType} - ${insight.title} (${eventId})`);

        // Only generate layout if it doesn't exist yet
        if (!existingEvent.generated_layout) {
          console.log(`[Llama Brain] 🎨 Triggering Claude to generate layout for ${eventId}...`);
          this.generateLayoutInBackground(eventId);
        } else {
          console.log(`[Llama Brain] ✅ Layout already exists for ${eventId}, skipping Claude generation`);
        }

        return eventId;
      } else {
        // Create new event
        const eventId = uuidv4();

        await this.db.query(`
          INSERT INTO ambient_events (
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
            confidence_score,
            generation_source,
            calendar_event_id,
            created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        `, [
          eventId,
          insight.userId,
          insight.eventType,
          insight.priority,
          insight.title,
          insight.subtitle,
          insight.body,
          JSON.stringify(insight.data),
          insight.icon,
          insight.color,
          insight.startTime,
          insight.endTime,
          insight.validUntil,
          insight.confidenceScore,
          insight.generationSource,
          calendarEventId
        ]);

        console.log(`[Llama Brain] ✅ Created new: ${insight.eventType} - ${insight.title} (${eventId})`);
        console.log(`[Llama Brain] 🎨 Triggering Claude to generate layout for ${eventId}...`);

        // Trigger Claude layout generation in the background
        this.generateLayoutInBackground(eventId);

        return eventId;
      }
    } catch (error) {
      console.error('[Ambient Event] Failed to save:', error.message);
      return null;
    }
  }

  /**
   * Trigger Claude layout generation for an ambient event (non-blocking)
   * @private
   */
  generateLayoutInBackground(eventId) {
    // Import dynamically to avoid circular dependency
    const { callClaudeForLayout } = require('../controllers/ambientEventsController');

    // Fetch event and generate layout asynchronously
    this.db.query('SELECT * FROM ambient_events WHERE id = ?', [eventId])
      .then(([events]) => {
        if (events.length === 0) return;

        const event = events[0];
        event.data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;

        // Call Claude to generate layout
        return this.callClaudeForLayoutWrapper(event);
      })
      .then((layout) => {
        if (!layout) return;

        // Store layout in database
        return this.db.query(`
          UPDATE ambient_events
          SET generated_layout = ?, layout_generated_at = NOW()
          WHERE id = ?
        `, [JSON.stringify(layout), eventId]);
      })
      .then(() => {
        console.log(`[Llama Brain → Claude] ✅ Layout generated and cached for ${eventId}`);
      })
      .catch((err) => {
        console.error(`[Llama Brain → Claude] ⚠️ Failed to generate layout for ${eventId}:`, err.message);
      });
  }

  /**
   * Wrapper to call Claude layout generation
   * @private
   */
  async callClaudeForLayoutWrapper(event) {
    const https = require('https');

    return new Promise((resolve, reject) => {
      const CLAUDE_API_KEY = process.env.CLAUDE_API_KEY;
      const CLAUDE_MODEL = 'claude-sonnet-4-5-20250929';

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

Return ONLY valid JSON with the layout structure. No markdown, no explanation.`;

      const requestData = JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 4096,
        system: systemPrompt,
        messages: [{ role: 'user', content: userPrompt }]
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
        response.on('data', (chunk) => { data += chunk; });
        response.on('end', () => {
          try {
            const result = JSON.parse(data);
            if (result.content && result.content[0] && result.content[0].text) {
              const layoutText = result.content[0].text;
              const jsonMatch = layoutText.match(/```json\n?([\s\S]*?)\n?```/) || layoutText.match(/```\n?([\s\S]*?)\n?```/);
              const cleanJson = jsonMatch ? jsonMatch[1] : layoutText;
              const layout = JSON.parse(cleanJson.trim());
              resolve(layout);
            } else {
              reject(new Error('Unexpected Claude API response format'));
            }
          } catch (error) {
            reject(error);
          }
        });
      });

      req.on('error', reject);
      req.write(requestData);
      req.end();
    });
  }

  /**
   * Helper to convert airport code to city name
   * @private
   */
  getCityFromAirportCode(code) {
    const airportMap = {
      'BOS': 'Boston',
      'NYC': 'New York',
      'JFK': 'New York',
      'LGA': 'New York',
      'EWR': 'Newark',
      'LAX': 'Los Angeles',
      'SFO': 'San Francisco',
      'ORD': 'Chicago',
      'DFW': 'Dallas',
      'ATL': 'Atlanta',
      'MIA': 'Miami',
      'SEA': 'Seattle',
      'DEN': 'Denver',
      'PHX': 'Phoenix',
      'LAS': 'Las Vegas',
      'MSP': 'Minneapolis',
      'DTW': 'Detroit',
      'PHL': 'Philadelphia',
      'BWI': 'Baltimore',
      'IAD': 'Washington',
      'DCA': 'Washington',
      'SAN': 'San Diego',
      'SYR': 'Syracuse'
    };

    return airportMap[code?.toUpperCase()] || null;
  }

  /**
   * Build context snapshot from current data
   */
  async buildContextSnapshot(userId) {
    // Determine time of day
    const now = new Date();
    const hour = now.getHours();
    let timeOfDay = 'night';
    if (hour >= 6 && hour < 12) timeOfDay = 'morning';
    else if (hour >= 12 && hour < 17) timeOfDay = 'afternoon';
    else if (hour >= 17 && hour < 22) timeOfDay = 'evening';

    const dayOfWeek = now.toLocaleDateString('en-US', { weekday: 'long' });
    const isWeekend = dayOfWeek === 'Saturday' || dayOfWeek === 'Sunday';

    // Pull calendar events
    let nextEventMinutes = null;
    let eventsToday = 0;
    let eventsTomorrow = 0;
    let upcomingEvents = [];

    try {
      // Get upcoming events
      const events = await this.calendarService.getUpcomingEvents(userId, 7);
      upcomingEvents = events;

      // Count today's events
      const todayEvents = await this.calendarService.getTodaysEvents(userId);
      eventsToday = todayEvents.length;

      // Get tomorrow's events
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);
      const dayAfterTomorrow = new Date(tomorrow);
      dayAfterTomorrow.setDate(dayAfterTomorrow.getDate() + 1);

      eventsTomorrow = events.filter(event =>
        event.startTime >= tomorrow && event.startTime < dayAfterTomorrow
      ).length;

      // Get next event
      const nextEvent = await this.calendarService.getNextEvent(userId);
      if (nextEvent) {
        nextEventMinutes = this.calendarService.getMinutesUntilEvent(nextEvent);
      }
    } catch (error) {
      console.log('[Context] Calendar not available for user:', error.message);
    }

    const context = {
      timestamp: now.toISOString(),
      timeOfDay,
      dayOfWeek,
      isWeekend,
      nextEventMinutes,
      eventsToday,
      eventsTomorrow,
      upcomingEvents: upcomingEvents.slice(0, 5), // Include first 5 events for context
      location_type: 'unknown',
      lastQuery: null,
      lastQueryTime: null,
      queriesLastHour: 0
    };

    // Save snapshot
    await this.saveContextSnapshot(userId, context);

    return context;
  }

  /**
   * Save context snapshot to database
   */
  async saveContextSnapshot(userId, context) {
    const snapshotId = uuidv4();

    try {
      await this.db.query(`
        INSERT INTO context_snapshots (
          id,
          user_id,
          timestamp,
          time_of_day,
          day_of_week,
          is_weekend,
          next_event_minutes,
          events_today,
          events_tomorrow,
          location_type,
          last_query,
          last_query_time,
          queries_last_hour,
          full_context
        ) VALUES (?, ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        snapshotId,
        userId,
        context.timeOfDay,
        context.dayOfWeek,
        context.isWeekend,
        context.nextEventMinutes,
        context.eventsToday,
        context.eventsTomorrow,
        context.location_type,
        context.lastQuery,
        context.lastQueryTime,
        context.queriesLastHour,
        JSON.stringify(context)
      ]);
    } catch (error) {
      console.error('[Llama Brain] Failed to save context snapshot:', error);
    }
  }
}

module.exports = LlamaReasoningService;
