/**
 * BACKGROUND JOBS
 *
 * Runs proactive intelligence in the background:
 * - Every 5 minutes: Think about what to generate
 * - Every hour: Pre-generate valuable pages
 * - Daily: Cache maintenance
 */

const AmbiaOrchestrator = require('./reasoning/AmbiaOrchestrator');
const LlamaReasoningService = require('./services/LlamaReasoningService');
const pool = require('./utils/database');
const https = require('https');

// Claude API configuration
const CLAUDE_API_URL = 'api.anthropic.com';
const CLAUDE_API_KEY = process.env.CLAUDE_API_KEY;
const CLAUDE_MODEL = 'claude-sonnet-4-5-20250929';

// Initialize orchestrator and reasoning service
const orchestrator = new AmbiaOrchestrator(pool);
const llamaService = new LlamaReasoningService(pool);

// Active user IDs to run proactive intelligence for
// In production, this would query database for recently active users
const ACTIVE_USERS = [
  '410b2520-e011-70d9-1ef0-10cead18dedd' // Jacob's user ID
];

/**
 * Build component prompt (same as controller)
 */
function buildComponentPrompt(userQuery) {
  return `You are Ambia, an ambient AI that generates beautiful, dynamic interfaces with COMPLETE information.

User Query: "${userQuery}"

CRITICAL PRINCIPLES:
1. PROVIDE ALL REQUESTED INFORMATION
2. FULFILL THE ENTIRE REQUEST
3. COMPONENTS SHOULD CONTAIN DATA
4. Think like both an AI assistant AND a UI designer
5. ONLY USE THE COMPONENT TYPES LISTED BELOW - Do not invent new types

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

4. MEDIA:
   - "image": {"type":"image","data":{"url":"string","caption":"string","aspect_ratio":1.5}}
   - "gallery": {"type":"gallery","data":{"images":[{"url":"string","caption":"string"}]}}
   - "map": {"type":"map","data":{"latitude":40.7128,"longitude":-74.0060,"title":"string","address":"string"}}

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

NOW generate components for the user's query using ONLY the component types above.`;
}

/**
 * Call Claude API
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
 * Parse component response
 */
function parseComponentResponse(claudeResponse) {
  try {
    const content = claudeResponse.content[0].text;
    let jsonStr = content.trim();

    if (jsonStr.startsWith('```')) {
      jsonStr = jsonStr.replace(/```json\n?/g, '').replace(/```\n?/g, '');
    }

    const components = JSON.parse(jsonStr);

    if (!Array.isArray(components)) {
      throw new Error('Response is not an array of components');
    }

    return components;
  } catch (error) {
    console.error('[Background Jobs] Error parsing component response:', error);
    throw new Error('Failed to parse component response from Claude');
  }
}

/**
 * Generate function for orchestrator
 */
async function generateComponents(query) {
  const prompt = buildComponentPrompt(query);
  const claudeResponse = await callClaudeAPI(prompt);
  return parseComponentResponse(claudeResponse);
}

/**
 * JOB 1: PROACTIVE THINKING
 * Runs every 5 minutes
 */
async function proactiveThinking() {
  console.log('[Ambia Background] Running proactive thinking...');

  for (const userId of ACTIVE_USERS) {
    try {
      const decision = await orchestrator.think(userId);

      if (decision.decision === 'generate') {
        console.log(`[Ambia Background] Pre-generating ${decision.pages.length} pages for ${userId}`);

        for (const page of decision.pages) {
          try {
            // Use smartGenerate to leverage cache
            await orchestrator.smartGenerate(
              userId,
              page.query,
              () => generateComponents(page.query)
            );
            console.log(`[Ambia Background] ✓ Pre-generated: "${page.query}"`);
          } catch (error) {
            console.error(`[Ambia Background] ✗ Failed to pre-generate "${page.query}":`, error.message);
          }
        }
      } else {
        console.log(`[Ambia Background] No pages to generate (reason: ${decision.reason})`);
      }
    } catch (error) {
      console.error(`[Ambia Background] Error in proactive thinking for ${userId}:`, error);
    }
  }
}

/**
 * JOB 2: AMBIENT INTELLIGENCE INSIGHTS
 * Scans calendar and generates proactive insights
 * Runs every 5 minutes
 */
async function generateAmbientInsights() {
  console.log('[Ambient Intelligence] Scanning for proactive insights...');

  for (const userId of ACTIVE_USERS) {
    try {
      const insights = await llamaService.generateProactiveInsights(userId);

      if (insights.length > 0) {
        console.log(`[Ambient Intelligence] ✓ Generated ${insights.length} insights for ${userId}`);
        insights.forEach(insight => {
          console.log(`  - ${insight.eventType}: ${insight.title}`);
        });
      } else {
        console.log(`[Ambient Intelligence] No insights generated (no relevant events)`);
      }
    } catch (error) {
      console.error(`[Ambient Intelligence] Error generating insights for ${userId}:`, error.message);
    }
  }
}

/**
 * JOB 3: PRE-GENERATE VALUABLE PAGES
 * Runs every hour to refresh Tier 1/2 cache
 */
async function pregenerateValuablePages() {
  console.log('[Ambia Background] Pre-generating valuable pages...');

  for (const userId of ACTIVE_USERS) {
    try {
      const results = await orchestrator.pregenerateValuablePages(
        userId,
        generateComponents
      );

      const succeeded = results.filter(r => r.success).length;
      console.log(`[Ambia Background] Pre-generated ${succeeded}/${results.length} valuable pages for ${userId}`);
    } catch (error) {
      console.error(`[Ambia Background] Error pre-generating pages for ${userId}:`, error);
    }
  }
}

/**
 * JOB 4: CACHE MAINTENANCE
 * Runs daily to clean up old cache entries
 */
async function cacheMaintenance() {
  console.log('[Ambia Background] Running cache maintenance...');

  try {
    await orchestrator.maintain();
    console.log('[Ambia Background] Cache maintenance complete');
  } catch (error) {
    console.error('[Ambia Background] Error in cache maintenance:', error);
  }
}

/**
 * Start all background jobs
 */
function startBackgroundJobs() {
  console.log('[Ambia Background] Starting background jobs...');

  // Ambient intelligence insights: every 5 minutes
  setInterval(generateAmbientInsights, 5 * 60 * 1000);
  console.log('[Ambia Background] ✓ Ambient intelligence job scheduled (every 5 minutes)');

  // Proactive thinking: every 5 minutes
  setInterval(proactiveThinking, 5 * 60 * 1000);
  console.log('[Ambia Background] ✓ Proactive thinking job scheduled (every 5 minutes)');

  // Pre-generate valuable pages: every hour
  setInterval(pregenerateValuablePages, 60 * 60 * 1000);
  console.log('[Ambia Background] ✓ Pre-generation job scheduled (every hour)');

  // Cache maintenance: daily
  setInterval(cacheMaintenance, 24 * 60 * 60 * 1000);
  console.log('[Ambia Background] ✓ Cache maintenance job scheduled (daily)');

  // Jobs will run on their scheduled intervals
  // No immediate execution to avoid deployment issues
  console.log('[Ambia Background] Jobs will start running on their scheduled intervals');
}

module.exports = {
  startBackgroundJobs
};
