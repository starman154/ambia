/**
 * AMBIA ORCHESTRATOR
 *
 * The maestro. Conducts all reasoning engines.
 * This is what makes Ambia truly ambient.
 *
 * Decides:
 * - What to show
 * - When to show it
 * - How to show it
 * - What to pre-generate
 *
 * WITHOUT THE USER ASKING.
 */

const ContextEngine = require('./ContextEngine');
const PriorityEngine = require('./PriorityEngine');
const CacheEngine = require('./CacheEngine');

class AmbiaOrchestrator {
  constructor(db) {
    this.db = db;
    this.cacheEngine = new CacheEngine(db);
  }

  /**
   * PROACTIVE INTELLIGENCE
   * Main decision loop - runs continuously in background
   */
  async think(userId) {
    console.log(`[Ambia Brain] Thinking for user ${userId}...`);

    // Initialize engines
    const contextEngine = new ContextEngine(userId);
    const priorityEngine = new PriorityEngine(contextEngine);

    // Analyze current context
    const analysis = await contextEngine.synthesize(this.db);

    if (!analysis.readyForProactiveGeneration) {
      return {
        decision: 'wait',
        reason: 'No high-priority suggestions at this time',
        context: analysis.context
      };
    }

    // Rank all suggestions
    const ranked = priorityEngine.rankSuggestions(analysis.suggestions);

    // Filter by threshold (only important ones)
    const worthGenerating = priorityEngine.filterByThreshold(ranked, 0.6);

    if (worthGenerating.length === 0) {
      return {
        decision: 'wait',
        reason: 'No suggestions above priority threshold',
        allSuggestions: ranked
      };
    }

    // Schedule generation
    const scheduled = priorityEngine.scheduleGeneration(worthGenerating);

    console.log(`[Ambia Brain] ${scheduled.length} pages ready for generation`);

    return {
      decision: 'generate',
      pages: scheduled,
      context: analysis.context,
      totalSuggestions: ranked.length,
      acceptedSuggestions: scheduled.length
    };
  }

  /**
   * SMART GENERATE
   * Decides whether to use cache or generate fresh
   */
  async smartGenerate(userId, query, generateFunction) {
    console.log(`[Ambia Brain] Smart generate for: "${query}"`);

    // Check cache first
    const cached = await this.cacheEngine.retrieveCache(userId, query);
    if (cached) {
      console.log(`[Ambia Brain] ✓ Cache hit (Tier ${cached.tier})`);
      return {
        ...cached,
        fromCache: true,
        tier: cached.tier,
        latency: '< 100ms'
      };
    }

    // Cache miss - generate fresh
    console.log(`[Ambia Brain] ✗ Cache miss - generating...`);
    const startTime = Date.now();

    const components = await generateFunction();

    const latency = Date.now() - startTime;

    // Analyze if worth caching
    const frequency = await this.cacheEngine.analyzeQueryFrequency(userId, query);

    if (frequency.shouldCache) {
      console.log(`[Ambia Brain] Caching result (Tier ${frequency.tier})`);
      await this.cacheEngine.storeCache(userId, query, components, frequency.tier);
    }

    return {
      components,
      fromCache: false,
      tier: frequency.tier,
      latency: `${latency}ms`,
      frequency: frequency.frequency
    };
  }

  /**
   * BACKGROUND JOB
   * Pre-generate high-value pages
   */
  async pregenerateValuablePages(userId, generateFunction) {
    console.log(`[Ambia Brain] Pre-generating valuable pages for ${userId}...`);

    const needsRegeneration = await this.cacheEngine.pregenerateFrequentPages(userId);

    const results = [];

    for (const item of needsRegeneration) {
      try {
        console.log(`[Ambia Brain] Pre-generating: "${item.query}" (Tier ${item.tier})`);

        const components = await generateFunction(item.query);

        await this.cacheEngine.storeCache(userId, item.query, components, item.tier);

        results.push({
          query: item.query,
          success: true,
          tier: item.tier
        });
      } catch (error) {
        console.error(`[Ambia Brain] Failed to pre-generate: ${item.query}`, error);
        results.push({
          query: item.query,
          success: false,
          error: error.message
        });
      }
    }

    console.log(`[Ambia Brain] Pre-generated ${results.filter(r => r.success).length}/${results.length} pages`);

    return results;
  }

  /**
   * MAINTENANCE
   * Clean up old cache entries
   */
  async maintain() {
    console.log(`[Ambia Brain] Running maintenance...`);
    await this.cacheEngine.evictStaleCache();
    console.log(`[Ambia Brain] Maintenance complete`);
  }
}

module.exports = AmbiaOrchestrator;
