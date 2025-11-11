/**
 * PRIORITY ENGINE
 *
 * Scores information by importance in current context.
 * Decides what gets generated, when, and with what urgency.
 *
 * The ranking algorithm that makes Ambia selective.
 */

class PriorityEngine {
  constructor(contextEngine) {
    this.contextEngine = contextEngine;
  }

  /**
   * SCORE A POTENTIAL PAGE
   * Returns 0.0 (ignore) to 1.0 (critical)
   */
  scorePage(suggestion) {
    const { context } = this.contextEngine.contextState;
    if (!context) return 0.5; // Default moderate priority

    let score = suggestion.priority || 0.5; // Base priority from suggestion

    // Apply context multipliers
    score *= context.temporal.urgencyMultiplier;

    // Boost if user is actively engaged
    if (context.behavioral?.engagementScore > 0.7) {
      score *= 1.3;
    }

    // Reduce if user is disengaged
    if (context.behavioral?.engagementScore < 0.2) {
      score *= 0.6;
    }

    // Time-sensitive boost
    if (suggestion.type === 'transition') {
      score *= 1.5; // Transitions are high value
    }

    // Pattern-based boost
    if (suggestion.type === 'pattern_based') {
      score *= 1.2; // Learned patterns are valuable
    }

    // Cap at 1.0
    return Math.min(score, 1.0);
  }

  /**
   * RANK ALL SUGGESTIONS
   * Returns sorted list of what to generate
   */
  rankSuggestions(suggestions) {
    const scored = suggestions.map(suggestion => ({
      ...suggestion,
      finalScore: this.scorePage(suggestion),
      timestamp: new Date().toISOString()
    }));

    // Sort by score (highest first)
    return scored.sort((a, b) => b.finalScore - a.finalScore);
  }

  /**
   * FILTER BY THRESHOLD
   * Only return items worth generating
   */
  filterByThreshold(rankedSuggestions, threshold = 0.6) {
    return rankedSuggestions.filter(s => s.finalScore >= threshold);
  }

  /**
   * DECIDE GENERATION TIMING
   * When should each page be pre-generated?
   */
  scheduleGeneration(rankedSuggestions) {
    return rankedSuggestions.map(suggestion => {
      let scheduleMinutes = 0;

      if (suggestion.generateAt === 'now') {
        scheduleMinutes = 0; // Generate immediately
      } else if (suggestion.generateAt === 'next_30_min') {
        // Generate 30 min before predicted need
        scheduleMinutes = 0; // For now, just generate now
        // TODO: Implement actual scheduling system
      } else if (suggestion.generateAt === 'next_hour') {
        scheduleMinutes = 30; // Half hour before
      }

      return {
        ...suggestion,
        scheduleAt: new Date(Date.now() + scheduleMinutes * 60 * 1000).toISOString(),
        minutesUntilGeneration: scheduleMinutes
      };
    });
  }
}

module.exports = PriorityEngine;
