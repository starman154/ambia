/**
 * CACHE ENGINE
 *
 * Implements the Tier 1/2/3 caching system.
 * Learns which queries are worth instant-loading.
 *
 * Tier 1: Instant (< 100ms) - Most frequent patterns
 * Tier 2: Fast (< 1s) - Common patterns
 * Tier 3: Generated (< 5s) - Everything else
 */

class CacheEngine {
  constructor(db) {
    this.db = db;
  }

  /**
   * ANALYZE QUERY FREQUENCY
   * Determine if query qualifies for caching
   */
  async analyzeQueryFrequency(userId, query) {
    const normalizedQuery = this._normalizeQuery(query);

    // Check how many times this query (or similar) has been made
    const [results] = await this.db.query(`
      SELECT COUNT(*) as frequency
      FROM messages
      WHERE user_id = ?
        AND role = 'user'
        AND (
          content = ? OR
          LOWER(content) LIKE ? OR
          LOWER(content) LIKE ?
        )
        AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
    `, [
      userId,
      query,
      `%${normalizedQuery}%`,
      `${normalizedQuery}%`
    ]);

    const frequency = results[0]?.frequency || 0;

    // Determine tier
    let tier = 3; // Default: generate on demand
    let shouldCache = false;

    if (frequency >= 10) {
      tier = 1; // Instant: Used 10+ times in 30 days
      shouldCache = true;
    } else if (frequency >= 5) {
      tier = 2; // Fast: Used 5-9 times in 30 days
      shouldCache = true;
    }

    return {
      tier,
      frequency,
      shouldCache,
      normalizedQuery
    };
  }

  /**
   * STORE CACHED RESULT
   * Save a page for instant retrieval
   */
  async storeCache(userId, query, components, tier) {
    const cacheKey = this._generateCacheKey(userId, query);

    // Store in database cache table
    await this.db.query(`
      INSERT INTO page_cache (
        cache_key,
        user_id,
        query,
        components_json,
        tier,
        created_at,
        last_accessed_at,
        access_count
      ) VALUES (?, ?, ?, ?, ?, NOW(), NOW(), 1)
      ON DUPLICATE KEY UPDATE
        components_json = VALUES(components_json),
        tier = VALUES(tier),
        last_accessed_at = NOW(),
        access_count = access_count + 1
    `, [cacheKey, userId, query, JSON.stringify(components), tier]);

    return cacheKey;
  }

  /**
   * RETRIEVE FROM CACHE
   * Fast path for frequently-requested pages
   */
  async retrieveCache(userId, query) {
    const cacheKey = this._generateCacheKey(userId, query);

    const [results] = await this.db.query(`
      SELECT components_json, tier, created_at
      FROM page_cache
      WHERE cache_key = ?
        AND user_id = ?
        AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    `, [cacheKey, userId]);

    if (results.length === 0) return null;

    const cached = results[0];

    // Update access stats
    await this.db.query(`
      UPDATE page_cache
      SET last_accessed_at = NOW(),
          access_count = access_count + 1
      WHERE cache_key = ?
    `, [cacheKey]);

    return {
      components: JSON.parse(cached.components_json),
      tier: cached.tier,
      cached_at: cached.created_at,
      fromCache: true
    };
  }

  /**
   * PREGENERATE HIGH-TIER PAGES
   * Background job to keep Tier 1/2 fresh
   */
  async pregenerateFrequentPages(userId) {
    // Find all Tier 1 and Tier 2 queries
    const [frequentQueries] = await this.db.query(`
      SELECT DISTINCT content, COUNT(*) as frequency
      FROM messages
      WHERE user_id = ?
        AND role = 'user'
        AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
      GROUP BY content
      HAVING frequency >= 5
      ORDER BY frequency DESC
      LIMIT 20
    `, [userId]);

    const needsRegeneration = [];

    for (const query of frequentQueries) {
      const cached = await this.retrieveCache(userId, query.content);

      // If not cached or older than 24 hours, mark for regeneration
      if (!cached ||
          new Date() - new Date(cached.cached_at) > 24 * 60 * 60 * 1000) {
        needsRegeneration.push({
          query: query.content,
          frequency: query.frequency,
          tier: query.frequency >= 10 ? 1 : 2
        });
      }
    }

    return needsRegeneration;
  }

  /**
   * NORMALIZE QUERY
   * Standardize query text for matching
   */
  _normalizeQuery(query) {
    return query
      .toLowerCase()
      .replace(/[^\w\s]/g, '') // Remove punctuation
      .trim()
      .slice(0, 50); // First 50 chars
  }

  /**
   * GENERATE CACHE KEY
   * Unique identifier for cached page
   */
  _generateCacheKey(userId, query) {
    const normalized = this._normalizeQuery(query);
    return `${userId}:${normalized}`;
  }

  /**
   * EVICT OLD CACHE
   * Remove stale entries
   */
  async evictStaleCache() {
    await this.db.query(`
      DELETE FROM page_cache
      WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)
        OR (tier = 3 AND created_at < DATE_SUB(NOW(), INTERVAL 1 DAY))
    `);
  }
}

module.exports = CacheEngine;
