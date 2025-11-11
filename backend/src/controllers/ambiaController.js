// Ambia AI Controller - Background Intelligence Architecture
// Claude handles real-time generation, Llama runs background services for prediction
const pool = require('../utils/database');
const { v4: uuidv4 } = require('uuid');
const https = require('https');
const AmbiaOrchestrator = require('../reasoning/AmbiaOrchestrator');
const crypto = require('crypto');

// Claude API configuration
const CLAUDE_API_URL = 'api.anthropic.com';
const CLAUDE_API_KEY = process.env.CLAUDE_API_KEY;
const CLAUDE_MODEL = 'claude-sonnet-4-5-20250929';

// Initialize orchestrator for caching
const orchestrator = new AmbiaOrchestrator(pool);

/**
 * Generate UI components using Background Intelligence Architecture
 * POST /api/ambia/generate
 * Body: { userId, conversationId?, userQuery, preferences? }
 *
 * Flow: Load conversation history → Check page_cache → Generate with Claude if needed → Log activity
 */
exports.generateComponents = async (req, res) => {
  const startTime = Date.now();

  try {
    const { userId, conversationId, userQuery, preferences } = req.body;

    // Validate required fields
    if (!userId || !userQuery) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: userId and userQuery'
      });
    }

    console.log(`\n[Ambia] Generating for user ${userId}: "${userQuery}"`);

    // STEP 1: Load conversation history if conversationId provided
    let conversationHistory = [];
    if (conversationId) {
      conversationHistory = await loadConversationHistory(conversationId);
      console.log(`[Conversation] Loaded ${conversationHistory.length} previous messages`);
    }

    // STEP 2: Check page_cache for pre-generated content (only for new conversations)
    let components, fromCache = false, cacheHitId = null;

    if (!conversationId || conversationHistory.length === 0) {
      const cacheKey = generateCacheKey(userId, userQuery);
      const cachedPage = await checkPageCache(userId, cacheKey);

      if (cachedPage) {
        // Cache hit! Return pre-generated page
        components = cachedPage.components;
        cacheHitId = cachedPage.id;
        fromCache = true;

        console.log(`[Cache HIT] Returning pre-generated page from ${cachedPage.cache_type} cache`);

        // Update cache access tracking
        await pool.query(`
          UPDATE page_cache
          SET last_accessed = NOW(), access_count = access_count + 1, was_shown = TRUE, shown_at = NOW()
          WHERE id = ?
        `, [cachedPage.id]);
      }
    }

    // STEP 3: If not from cache, generate with Claude using conversation history
    if (!fromCache) {
      console.log(`[Claude] Generating with conversation context (${conversationHistory.length} messages)`);

      const result = await orchestrator.smartGenerate(
        userId,
        userQuery,
        async () => {
          const claudeResponse = await callClaudeAPIWithHistory(userQuery, conversationHistory, preferences);
          return parseComponentResponse(claudeResponse);
        }
      );

      components = result.components;
      fromCache = result.fromCache; // Orchestrator's own caching

      console.log(`[Claude] Generated ${components.length} components`);
    }

    // STEP 4: Save to messages database
    const messageId = await saveComponentGeneration({
      userId,
      conversationId,
      userQuery,
      components,
      claudeResponse: null,
      reasoningDecisionId: null,
      cacheHit: fromCache,
      cacheKey: fromCache ? generateCacheKey(userId, userQuery) : null,
      generationSource: fromCache ? 'cached' : 'real_time'
    });

    // STEP 5: Log activity for pattern mining
    await logActivity({
      userId,
      actionType: 'query',
      query: userQuery,
      componentsShown: components,
      fromCache
    });

    const executionTime = Date.now() - startTime;

    res.json({
      success: true,
      messageId,
      components,
      conversationId: messageId ? (await getConversationIdForMessage(messageId)) : conversationId,
      metadata: {
        model: 'claude-sonnet-4.5',
        fromCache,
        cacheType: fromCache ? 'orchestrator' : 'none',
        executionTime,
        conversationLength: conversationHistory.length
      }
    });
  } catch (error) {
    console.error('[Ambia Error]', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to generate components'
    });
  }
};

/**
 * Save user feedback on generated components
 * POST /api/ambia/feedback
 * Body: { userId, messageId, feedback }
 */
exports.saveFeedback = async (req, res) => {
  try {
    const { userId, messageId, feedback } = req.body;

    if (!userId || !messageId || !feedback) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields'
      });
    }

    // Update the message with feedback
    await pool.query(
      'UPDATE messages SET user_feedback = ?, updated_at = NOW() WHERE id = ? AND user_id = ?',
      [feedback, messageId, userId]
    );

    // Extract and save preferences from feedback
    const preferences = await extractPreferencesFromFeedback(userId, feedback);

    res.json({
      success: true,
      extractedPreferences: preferences.length
    });
  } catch (error) {
    console.error('Error saving feedback:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to save feedback'
    });
  }
};

/**
 * Get user preferences
 * GET /api/ambia/preferences/:userId
 */
exports.getPreferences = async (req, res) => {
  try {
    const { userId } = req.params;

    const [preferences] = await pool.query(`
      SELECT category, preference, context, description, strength, created_at
      FROM user_preferences
      WHERE user_id = ?
      ORDER BY strength DESC, created_at DESC
    `, [userId]);

    res.json({
      success: true,
      preferences
    });
  } catch (error) {
    console.error('Error fetching preferences:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch preferences'
    });
  }
};

// ============= Helper Functions =============

/**
 * Generate a cache key for a user query
 */
function generateCacheKey(userId, userQuery) {
  const normalizedQuery = userQuery.toLowerCase().trim();
  const hash = crypto.createHash('md5').update(`${userId}:${normalizedQuery}`).digest('hex');
  return hash.substring(0, 16);
}

/**
 * Check page_cache for pre-generated content
 */
async function checkPageCache(userId, cacheKey) {
  try {
    const [cached] = await pool.query(`
      SELECT id, cache_key, cache_type, components, relevance_score, created_at, query
      FROM page_cache
      WHERE user_id = ? AND cache_key = ? AND valid_until > NOW()
      ORDER BY relevance_score DESC, created_at DESC
      LIMIT 1
    `, [userId, cacheKey]);

    if (cached && cached.length > 0) {
      const page = cached[0];
      // Parse JSON components
      page.components = JSON.parse(page.components);
      return page;
    }

    return null;
  } catch (error) {
    console.error('[Cache Error]', error);
    return null;
  }
}

/**
 * Load conversation history from database
 */
async function loadConversationHistory(conversationId) {
  try {
    const [messages] = await pool.query(`
      SELECT id, role, content, layout_json, created_at
      FROM messages
      WHERE conversation_id = ?
      ORDER BY created_at ASC
    `, [conversationId]);

    // Parse JSON fields
    return messages.map(msg => ({
      ...msg,
      layout_json: msg.layout_json && typeof msg.layout_json === 'string'
        ? JSON.parse(msg.layout_json)
        : msg.layout_json
    }));
  } catch (error) {
    console.error('[Conversation History Error]', error);
    return [];
  }
}

/**
 * Get conversation ID for a message
 */
async function getConversationIdForMessage(messageId) {
  try {
    const [result] = await pool.query(`
      SELECT conversation_id
      FROM messages
      WHERE id = ?
      LIMIT 1
    `, [messageId]);

    return result && result.length > 0 ? result[0].conversation_id : null;
  } catch (error) {
    console.error('[Get Conversation ID Error]', error);
    return null;
  }
}

/**
 * Log user activity for pattern mining
 */
async function logActivity({ userId, actionType, query, componentsShown, fromCache }) {
  const activityId = uuidv4();
  const now = new Date();
  const hour = now.getHours();
  let timeOfDay = 'night';
  if (hour >= 6 && hour < 12) timeOfDay = 'morning';
  else if (hour >= 12 && hour < 17) timeOfDay = 'afternoon';
  else if (hour >= 17 && hour < 22) timeOfDay = 'evening';

  const dayOfWeek = now.toLocaleDateString('en-US', { weekday: 'long' });
  const isWeekend = dayOfWeek === 'Saturday' || dayOfWeek === 'Sunday';

  try {
    await pool.query(`
      INSERT INTO activity_log (
        id, user_id, action_type, action_data, query, components_shown,
        timestamp, time_of_day, day_of_week, is_weekend
      ) VALUES (?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?)
    `, [
      activityId,
      userId,
      actionType,
      JSON.stringify({ fromCache }),
      query,
      JSON.stringify(componentsShown),
      timeOfDay,
      dayOfWeek,
      isWeekend
    ]);
  } catch (error) {
    console.error('[Activity Log Error]', error);
    // Don't throw - logging failure shouldn't break the request
  }
}

/**
 * Build the component generation prompt
 */
function buildComponentPrompt(userQuery, preferences, llamaDecision) {
  let preferencesSection = '';

  if (preferences && preferences.length > 0) {
    preferencesSection = '\n\nUSER\'S LEARNED PREFERENCES:\n';
    preferencesSection += 'Based on previous interactions, the user has expressed these preferences:\n';

    // Group by category
    const grouped = {};
    preferences.forEach(pref => {
      if (!grouped[pref.category]) grouped[pref.category] = [];
      grouped[pref.category].push(pref);
    });

    for (const [category, prefs] of Object.entries(grouped)) {
      preferencesSection += `\n${category.toUpperCase()}:\n`;
      prefs.forEach(pref => {
        const stars = '★'.repeat(Math.round(pref.strength / 2));
        preferencesSection += `  ${stars} ${pref.description} (${pref.preference})\n`;
      });
    }

    preferencesSection += '\nAPPLY THESE PREFERENCES when generating components.\n';
  }

  // Build Llama's guidance section
  let llamaGuidance = '';
  if (llamaDecision) {
    llamaGuidance = `\n\nCONTEXT-AWARE REASONING (From Llama AI):
Our reasoning engine analyzed the user's context and recommends:

Priority: ${llamaDecision.priority_score}/1.0 (${llamaDecision.urgency} urgency)
Decision: ${llamaDecision.decision_type}
Reasoning: ${llamaDecision.reasoning}

RECOMMENDED COMPONENT TYPES:
${llamaDecision.recommended_components.map((comp, i) => {
  const priority = llamaDecision.component_priorities[comp] || 0.5;
  const stars = '★'.repeat(Math.ceil(priority * 5));
  return `  ${stars} ${comp} (priority: ${priority})`;
}).join('\n')}

Use these recommendations to guide your component selection and prioritization.
Focus on the highest-priority components first.\n`;
  }

  return `You are Ambia, an ambient AI that generates beautiful, dynamic interfaces with PRECISE information.

User Query: "${userQuery}"

CRITICAL PRINCIPLES:
1. MATCH QUERY SPECIFICITY - Simple questions get simple answers. Don't overwhelm with unnecessary details.
   - "do I have a meeting tomorrow?" → Simple yes/no with count (e.g., "Yes, you have 2 meetings tomorrow")
   - "what's on my calendar tomorrow?" → Show full schedule breakdown
   - "when is my next meeting?" → Just show the next meeting, not all meetings

2. CALENDAR SEMANTIC AWARENESS - Different calendars represent different types of events:
   - Calendars with "class", "classes", "school", "course", "academic" → Academic classes, NOT meetings
   - Calendars with "appointment", "exchange", "work", "calendar" → Actual meetings/appointments
   - Calendars with "personal", "birthday", "holiday" → Personal events

   When filtering events:
   - "meeting" or "meetings" → EXCLUDE academic classes, only show appointments/work events
   - "class" or "classes" → ONLY show academic calendar events
   - "event" or "events" → Show ALL calendar items
   - "schedule" → Show ALL calendar items, organized by type if helpful

3. PROVIDE ALL REQUESTED INFORMATION - If user asks for a list of 8 movies, generate ALL 8 movies with details

4. FULFILL THE ENTIRE REQUEST - Don't create summary UIs without the actual data

5. COMPONENTS SHOULD CONTAIN DATA - Each component must have real, complete information

6. Think like both an AI assistant AND a UI designer - deliver information beautifully

7. ONLY USE THE COMPONENT TYPES LISTED BELOW - Do not invent new types
${preferencesSection}${llamaGuidance}

Your task is to generate a JSON array of UI components that FULLY answer the user's query with complete data.

AVAILABLE COMPONENT TYPES (use these exact types only):

1. DATA DISPLAY:
   - "header": {"type":"header","data":{"title":"string","subtitle":"string"}}
   - "text": {"type":"text","data":{"content":"string","markdown":false}}
   - "metric": {"type":"metric","data":{"label":"string","value":"string","change":"+5%","unit":"$","icon":"trending_up"}}
   - "stat": {"type":"stat","data":{"stats":[{"label":"string","value":"string"}]}}
   - "progress": {"type":"progress","data":{"label":"string","value":75,"max":100,"color":"blue"}}

2. LISTS:
   - "list": {"type":"list","data":{"title":"string","items":[{"title":"string","subtitle":"string","badge":"string"}]}}
   - "person_list": {"type":"person_list","data":{"title":"string","people":[{"name":"string","role":"string","avatar":"url"}]}}
   - "timeline": {"type":"timeline","data":{"title":"string","events":[{"time":"string","title":"string","description":"string"}]}}

3. ACTIONS:
   - "button": {"type":"button","data":{"label":"string","icon":"icon_name"}}
   - "action_row": {"type":"action_row","data":{"buttons":[{"label":"string","icon":"icon_name"}]}}
   - "chip_row": {"type":"chip_row","data":{"chips":[{"label":"string","icon":"icon_name"}]}}

4. MEDIA & CONTENT:
   - "image": {"type":"image","data":{"url":"string","caption":"string","aspect_ratio":1.5}}
   - "gallery": {"type":"gallery","data":{"images":[{"url":"string","caption":"string"}]}}
   - "map": {"type":"map","data":{"latitude":40.7128,"longitude":-74.0060,"title":"string","address":"string"}}
   - "media_card": {"type":"media_card","data":{"title":"Movie Title","subtitle":"2023 • 2h 15m","description":"Brief plot summary","image":"poster_url","metadata":{"rating":"8.5/10","director":"Name","cast":["Actor 1","Actor 2"],"genre":"Drama"}}}
     Use for movies, TV shows, books, albums, games - any media with rich details
   - "expandable_list": {"type":"expandable_list","data":{"title":"Section Title","items":[{"id":"unique_id","title":"Item Title","subtitle":"Brief info","details":{"key":"value","key2":"value2"},"image":"optional_image_url"}]}}
     Use when list items have additional details that can be revealed on tap

5. CONTEXTUAL:
   - "weather": {"type":"weather","data":{"condition":"sunny","temperature":72,"location":"string","icon":"sun"}}
   - "location": {"type":"location","data":{"name":"string","address":"string","distance":"2.5 mi","icon":"place"}}
   - "calendar_event": {"type":"calendar_event","data":{"title":"string","time":"string","location":"string"}}

6. VISUAL/DATA:
   - "chart": {"type":"chart","data":{"title":"string","chartType":"line","dataPoints":[{"label":"Jan","value":100},{"label":"Feb","value":150}]}}
     Chart types: "line", "bar", "pie"
   - "sparkline": {"type":"sparkline","data":{"label":"string","values":[1,2,3,4,5]}}

7. CONTAINERS:
   - "card": {"type":"card","data":{"title":"string","children":[...nested components...]}}
   - "section": {"type":"section","data":{"title":"string","children":[...nested components...]}}

RESPONSE FORMAT:
Return ONLY a valid JSON array of components. No markdown, no explanation, just the JSON array.

Example for "show me sales data":
[
  {"type":"header","data":{"title":"Sales Dashboard","subtitle":"Q4 2024"}},
  {"type":"metric","data":{"label":"Total Revenue","value":"$125,000","change":"+12%","unit":"$"}},
  {"type":"chart","data":{"title":"Monthly Sales","chartType":"line","dataPoints":[{"label":"Oct","value":40000},{"label":"Nov","value":45000},{"label":"Dec","value":40000}]}}
]

NOW generate components for the user's query using ONLY the component types above.`;
}

/**
 * Call Claude API using Node's built-in https module
 */
function callClaudeAPI(prompt) {
  return new Promise((resolve, reject) => {
    const requestBody = JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: 4096,
      messages: [
        {
          role: 'user',
          content: prompt
        }
      ]
    });

    const options = {
      hostname: CLAUDE_API_URL,
      path: '/v1/messages',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': CLAUDE_API_KEY,
        'anthropic-version': '2023-06-01',
        'Content-Length': Buffer.byteLength(requestBody)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            const parsed = JSON.parse(data);
            resolve(parsed);
          } catch (e) {
            reject(new Error('Failed to parse Claude API response'));
          }
        } else {
          reject(new Error(`Claude API error: ${res.statusCode} - ${data}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(new Error(`Network error calling Claude API: ${error.message}`));
    });

    req.write(requestBody);
    req.end();
  });
}

/**
 * Call Claude API with conversation history for contextual responses
 */
function callClaudeAPIWithHistory(userQuery, conversationHistory, preferences) {
  return new Promise((resolve, reject) => {
    // Build messages array with conversation history
    const messages = [];

    // Add conversation history (limit to last 20 messages to avoid token limits)
    const recentHistory = conversationHistory.slice(-20);

    // Add system context as first user message if this is the start
    if (recentHistory.length === 0) {
      const systemPrompt = buildComponentPrompt(userQuery, preferences, null);
      messages.push({
        role: 'user',
        content: systemPrompt
      });
    } else {
      // Add conversation history
      recentHistory.forEach((msg) => {
        if (msg.role === 'user') {
          messages.push({
            role: 'user',
            content: msg.content
          });
        } else if (msg.role === 'assistant') {
          // For assistant messages, include the components as JSON
          let assistantContent = msg.content;
          if (msg.layout_json && Array.isArray(msg.layout_json)) {
            assistantContent = JSON.stringify(msg.layout_json);
          }
          messages.push({
            role: 'assistant',
            content: assistantContent
          });
        }
      });

      // Add the new user query with system instructions
      const systemPrompt = buildComponentPrompt(userQuery, preferences, null);
      messages.push({
        role: 'user',
        content: systemPrompt
      });
    }

    const requestBody = JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: 4096,
      messages: messages
    });

    const options = {
      hostname: CLAUDE_API_URL,
      path: '/v1/messages',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': CLAUDE_API_KEY,
        'anthropic-version': '2023-06-01',
        'Content-Length': Buffer.byteLength(requestBody)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            const parsed = JSON.parse(data);
            resolve(parsed);
          } catch (e) {
            reject(new Error('Failed to parse Claude API response'));
          }
        } else {
          reject(new Error(`Claude API error: ${res.statusCode} - ${data}`));
        }
      });
    });

    req.on('error', (error) => {
      reject(new Error(`Network error calling Claude API: ${error.message}`));
    });

    req.write(requestBody);
    req.end();
  });
}

/**
 * Parse component response from Claude
 */
function parseComponentResponse(claudeResponse) {
  try {
    const content = claudeResponse.content[0].text;

    // Try to extract JSON from the response
    let jsonStr = content.trim();

    // Remove markdown code blocks if present
    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replace(/```json\n?/g, '').replace(/```\n?/g, '');
    }

    const components = JSON.parse(jsonStr);

    if (!Array.isArray(components)) {
      throw new Error('Response is not an array of components');
    }

    return components;
  } catch (error) {
    console.error('Error parsing component response:', error);
    throw new Error('Failed to parse component response from Claude');
  }
}

/**
 * Save the component generation to database (with Llama decision tracking)
 */
async function saveComponentGeneration({ userId, conversationId, userQuery, components, claudeResponse, reasoningDecisionId, cacheHit, cacheKey, generationSource }) {
  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    // Create conversation if not provided
    let convId = conversationId;
    if (!convId) {
      convId = uuidv4();
      await connection.query(
        'INSERT INTO conversations (id, user_id, title, created_at, updated_at, last_message_at) VALUES (?, ?, ?, NOW(), NOW(), NOW())',
        [convId, userId, userQuery.substring(0, 100)]
      );
    } else {
      // Update conversation timestamp
      await connection.query(
        'UPDATE conversations SET last_message_at = NOW(), updated_at = NOW() WHERE id = ?',
        [convId]
      );
    }

    // Save user message
    const userMessageId = uuidv4();
    await connection.query(
      'INSERT INTO messages (id, conversation_id, user_id, role, content, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
      [userMessageId, convId, userId, 'user', userQuery]
    );

    // Save assistant response with components and cache tracking
    const assistantMessageId = uuidv4();
    await connection.query(
      'INSERT INTO messages (id, conversation_id, user_id, role, content, layout_json, reasoning_decision_id, generated_by, cache_hit, cache_key, generation_source, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())',
      [assistantMessageId, convId, userId, 'assistant', 'Generated components', JSON.stringify(components), reasoningDecisionId, 'claude', cacheHit || false, cacheKey, generationSource || 'real_time']
    );

    await connection.commit();
    return assistantMessageId;
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

/**
 * Extract preferences from user feedback
 */
async function extractPreferencesFromFeedback(userId, feedback) {
  const preferences = [];
  const feedbackLower = feedback.toLowerCase();
  const timestamp = new Date();

  // Keyword-based preference extraction
  const keywordMap = [
    { keywords: ['cleaner', 'clean'], category: 'visualization', preference: 'cleaner', description: 'User prefers cleaner, more minimal layouts' },
    { keywords: ['organized', 'organize'], category: 'layout', preference: 'organized', description: 'User prefers well-organized, structured layouts' },
    { keywords: ['minimal', 'minimalist'], category: 'visualization', preference: 'minimalist', description: 'User prefers minimalist design approach' },
    { keywords: ['more detail', 'detailed'], category: 'data_presentation', preference: 'detailed', description: 'User prefers more detailed information' },
    { keywords: ['simpler', 'simple'], category: 'data_presentation', preference: 'simple', description: 'User prefers simpler, less complex presentations' },
    { keywords: ['compact'], category: 'layout', preference: 'compact', description: 'User prefers compact layouts with less spacing' },
    { keywords: ['spacious', 'more space'], category: 'layout', preference: 'spacious', description: 'User prefers spacious layouts with more breathing room' },
  ];

  for (const { keywords, category, preference, description } of keywordMap) {
    if (keywords.some(kw => feedbackLower.includes(kw))) {
      preferences.push({ category, preference, description });

      // Save to database
      const prefId = uuidv4();
      try {
        // Check if similar preference exists
        const [existing] = await pool.query(
          'SELECT id, strength FROM user_preferences WHERE user_id = ? AND category = ? AND preference = ?',
          [userId, category, preference]
        );

        if (existing.length > 0) {
          // Update existing preference strength
          const newStrength = Math.min(existing[0].strength + 1, 10);
          await pool.query(
            'UPDATE user_preferences SET strength = ?, updated_at = NOW() WHERE id = ?',
            [newStrength, existing[0].id]
          );
        } else {
          // Insert new preference
          await pool.query(
            'INSERT INTO user_preferences (id, user_id, category, preference, context, description, strength, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())',
            [prefId, userId, category, preference, 'general', description, 5]
          );
        }
      } catch (error) {
        console.error('Error saving preference:', error);
      }
    }
  }

  return preferences;
}

module.exports = exports;
