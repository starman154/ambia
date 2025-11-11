/**
 * CONTEXT ENGINE
 *
 * The foundation of Ambia's ambient intelligence.
 * Continuously analyzes user context to understand:
 * - What matters RIGHT NOW
 * - What will matter SOON
 * - What patterns are emerging
 *
 * This is Layer 1 - The Brain
 */

const { DateTime } = require('luxon');

class ContextEngine {
  constructor(userId) {
    this.userId = userId;
    this.contextState = {
      temporal: null,    // Time-based context
      spatial: null,     // Location-based context
      behavioral: null,  // Usage patterns
      emotional: null,   // Urgency/mood signals
      environmental: null // External factors (weather, etc.)
    };
  }

  /**
   * TEMPORAL CONTEXT
   * What time means for this user
   */
  async analyzeTemporalContext() {
    const now = DateTime.now();
    const hour = now.hour;
    const dayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday
    const minute = now.minute;

    // Determine time-of-day context
    let timeContext = 'unknown';
    let urgencyMultiplier = 1.0;

    if (hour >= 5 && hour < 9) {
      timeContext = 'early_morning';
      urgencyMultiplier = 1.5; // Morning prep is high urgency
    } else if (hour >= 9 && hour < 12) {
      timeContext = 'late_morning';
      urgencyMultiplier = 1.2;
    } else if (hour >= 12 && hour < 14) {
      timeContext = 'lunch';
      urgencyMultiplier = 0.8; // Lower urgency during break
    } else if (hour >= 14 && hour < 17) {
      timeContext = 'afternoon';
      urgencyMultiplier = 1.0;
    } else if (hour >= 17 && hour < 20) {
      timeContext = 'evening';
      urgencyMultiplier = 0.9;
    } else if (hour >= 20 && hour < 23) {
      timeContext = 'night';
      urgencyMultiplier = 0.6; // Winding down
    } else {
      timeContext = 'late_night';
      urgencyMultiplier = 0.3; // Minimal interruptions
    }

    // Detect transition moments (high information need)
    const transitions = [];
    if (minute >= 55 || minute <= 5) {
      transitions.push('hour_boundary'); // Top of the hour
    }
    if (hour === 8 && minute >= 30 && minute <= 45) {
      transitions.push('workday_start'); // Typical work start
    }
    if (hour === 17 && minute >= 0 && minute <= 30) {
      transitions.push('workday_end'); // Typical work end
    }

    return {
      timestamp: now.toISO(),
      timeContext,
      hour,
      dayOfWeek,
      isWeekend: dayOfWeek >= 6,
      urgencyMultiplier,
      transitions,
      nextTransition: this._calculateNextTransition(now)
    };
  }

  /**
   * BEHAVIORAL CONTEXT
   * Pattern recognition from user history
   */
  async analyzeBehavioralContext(db) {
    // Query recent usage patterns
    const [recentQueries] = await db.query(`
      SELECT
        m.content,
        m.created_at,
        HOUR(m.created_at) as query_hour,
        DAYOFWEEK(m.created_at) as query_day
      FROM messages m
      WHERE m.user_id = ?
        AND m.role = 'user'
        AND m.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
      ORDER BY m.created_at DESC
      LIMIT 100
    `, [this.userId]);

    // Detect patterns
    const patterns = this._detectPatterns(recentQueries);

    // Calculate engagement score (how active is user right now?)
    const [recentActivity] = await db.query(`
      SELECT
        COUNT(*) as recent_queries,
        MAX(created_at) as last_query
      FROM messages
      WHERE user_id = ?
        AND role = 'user'
        AND created_at >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
    `, [this.userId]);

    const engagementScore = this._calculateEngagementScore(recentActivity[0]);

    return {
      recentQueryCount: recentQueries.length,
      patterns,
      engagementScore,
      lastQuery: recentActivity[0]?.last_query,
      isActiveSession: engagementScore > 0.5
    };
  }

  /**
   * PATTERN DETECTION
   * Find recurring behaviors
   */
  _detectPatterns(queries) {
    const patterns = {
      timePatterns: {},     // "User asks about weather at 7am"
      topicPatterns: {},    // "User frequently asks about sales data"
      sequencePatterns: []  // "Weather query often followed by calendar"
    };

    // Time-based patterns
    queries.forEach(q => {
      const hour = q.query_hour;
      const day = q.query_day;
      const key = `${day}_${hour}`;

      if (!patterns.timePatterns[key]) {
        patterns.timePatterns[key] = {
          count: 0,
          topics: []
        };
      }
      patterns.timePatterns[key].count++;
      patterns.timePatterns[key].topics.push(this._extractTopic(q.content));
    });

    // Find strongest time patterns
    const strongPatterns = Object.entries(patterns.timePatterns)
      .filter(([_, data]) => data.count >= 3) // Occurred at least 3 times
      .map(([timeKey, data]) => ({
        timeKey,
        strength: data.count,
        topics: [...new Set(data.topics)] // Unique topics
      }));

    return {
      strongPatterns,
      totalPatterns: Object.keys(patterns.timePatterns).length
    };
  }

  /**
   * EXTRACT TOPIC
   * Simple keyword-based topic extraction
   */
  _extractTopic(query) {
    const lowercaseQuery = query.toLowerCase();

    // Topic keywords
    if (lowercaseQuery.includes('weather')) return 'weather';
    if (lowercaseQuery.includes('calendar') || lowercaseQuery.includes('meeting')) return 'calendar';
    if (lowercaseQuery.includes('sales') || lowercaseQuery.includes('revenue')) return 'sales';
    if (lowercaseQuery.includes('fitness') || lowercaseQuery.includes('workout')) return 'fitness';
    if (lowercaseQuery.includes('news')) return 'news';
    if (lowercaseQuery.includes('email')) return 'email';

    return 'general';
  }

  /**
   * ENGAGEMENT SCORE
   * How engaged is the user right now?
   */
  _calculateEngagementScore(activity) {
    if (!activity || !activity.recent_queries) return 0;

    const queryCount = activity.recent_queries;
    const lastQuery = activity.last_query ? new Date(activity.last_query) : null;

    if (!lastQuery) return 0;

    const minutesSinceLastQuery = (Date.now() - lastQuery.getTime()) / (1000 * 60);

    // Scoring logic
    let score = 0;

    // More queries = higher engagement
    score += Math.min(queryCount / 10, 1.0) * 0.5;

    // Recent activity = higher engagement
    if (minutesSinceLastQuery < 5) score += 0.5;
    else if (minutesSinceLastQuery < 15) score += 0.3;
    else if (minutesSinceLastQuery < 30) score += 0.1;

    return Math.min(score, 1.0);
  }

  /**
   * CALCULATE NEXT TRANSITION
   * When will the next important time boundary occur?
   */
  _calculateNextTransition(now) {
    const hour = now.hour;
    const minute = now.minute;

    // Next hour boundary
    if (minute < 55) {
      return {
        type: 'hour_boundary',
        minutesUntil: 55 - minute
      };
    }

    // Work day transitions
    if (hour < 8 || (hour === 8 && minute < 30)) {
      const workStart = now.set({ hour: 8, minute: 30, second: 0 });
      return {
        type: 'workday_start',
        minutesUntil: workStart.diff(now, 'minutes').minutes
      };
    }

    if (hour < 17) {
      const workEnd = now.set({ hour: 17, minute: 0, second: 0 });
      return {
        type: 'workday_end',
        minutesUntil: workEnd.diff(now, 'minutes').minutes
      };
    }

    // Default to next hour
    const nextHour = now.plus({ hours: 1 }).set({ minute: 0, second: 0 });
    return {
      type: 'hour_boundary',
      minutesUntil: nextHour.diff(now, 'minutes').minutes
    };
  }

  /**
   * SYNTHESIZE CONTEXT
   * Combine all context sources into actionable intelligence
   */
  async synthesize(db) {
    const temporal = await this.analyzeTemporalContext();
    const behavioral = await this.analyzeBehavioralContext(db);

    // Context state
    this.contextState = {
      temporal,
      behavioral,
      lastUpdated: new Date().toISOString()
    };

    // Generate proactive suggestions based on context
    const suggestions = this._generateProactiveSuggestions();

    return {
      context: this.contextState,
      suggestions,
      readyForProactiveGeneration: suggestions.length > 0
    };
  }

  /**
   * GENERATE PROACTIVE SUGGESTIONS
   * What should Ambia pre-generate right now?
   */
  _generateProactiveSuggestions() {
    const suggestions = [];
    const { temporal, behavioral } = this.contextState;

    if (!temporal || !behavioral) return suggestions;

    // Morning routine suggestion
    if (temporal.timeContext === 'early_morning') {
      suggestions.push({
        type: 'proactive_page',
        query: 'morning briefing',
        reason: 'Morning routine detected',
        priority: 0.9,
        generateAt: 'now'
      });
    }

    // Pattern-based suggestions
    if (behavioral.patterns?.strongPatterns) {
      behavioral.patterns.strongPatterns.forEach(pattern => {
        const [day, hour] = pattern.timeKey.split('_').map(Number);

        // If we're approaching a pattern time
        if (day === temporal.dayOfWeek &&
            Math.abs(hour - temporal.hour) <= 1) {
          pattern.topics.forEach(topic => {
            suggestions.push({
              type: 'pattern_based',
              query: topic,
              reason: `Recurring pattern: ${topic} at ${hour}:00`,
              priority: 0.7,
              generateAt: 'next_30_min'
            });
          });
        }
      });
    }

    // Transition-based suggestions
    if (temporal.transitions?.includes('workday_end')) {
      suggestions.push({
        type: 'transition',
        query: 'end of day summary',
        reason: 'Work day ending',
        priority: 0.8,
        generateAt: 'now'
      });
    }

    return suggestions.sort((a, b) => b.priority - a.priority);
  }
}

module.exports = ContextEngine;
