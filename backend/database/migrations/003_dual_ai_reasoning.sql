-- DUAL-AI REASONING TABLES
-- Powers Ambia's Llama (reasoning) + Claude (UI generation) architecture

-- Table to store Llama's reasoning decisions
CREATE TABLE IF NOT EXISTS reasoning_decisions (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  query TEXT NOT NULL,

  -- Context analyzed by Llama
  context_snapshot JSON,  -- time, location, calendar events, etc

  -- Llama's decision
  decision_type ENUM('show_now', 'show_later', 'cache', 'ignore') NOT NULL,
  priority_score DECIMAL(3,2), -- 0.0 to 1.0
  urgency ENUM('low', 'medium', 'high', 'critical'),

  -- What components Llama decided to show
  recommended_components JSON, -- ['calendar_event', 'weather', 'traffic']
  component_priorities JSON,  -- {'calendar_event': 0.9, 'weather': 0.6}

  -- Reasoning metadata
  reasoning TEXT,  -- Llama's explanation for the decision
  execution_time_ms INT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_user_decisions (user_id, created_at),
  INDEX idx_priority (priority_score DESC),
  INDEX idx_decision_type (decision_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table to store learned behavioral patterns
CREATE TABLE IF NOT EXISTS user_behavior_patterns (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,

  -- Pattern identification
  pattern_type ENUM('time_based', 'location_based', 'event_based', 'query_based') NOT NULL,
  pattern_name VARCHAR(255) NOT NULL,  -- 'morning_routine', 'commute_check', etc

  -- Pattern definition
  conditions JSON,  -- {'time': '7-9am', 'day': 'weekday'}
  typical_queries JSON,  -- Common queries in this pattern
  expected_components JSON,  -- Components usually needed

  -- Learning metadata
  confidence_score DECIMAL(3,2), -- 0.0 to 1.0
  occurrences INT DEFAULT 1,  -- How many times pattern observed
  last_occurrence TIMESTAMP,

  -- Pattern effectiveness
  success_rate DECIMAL(3,2),  -- How often it was useful
  avg_interaction_time_ms INT, -- How long user engaged

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_user_patterns (user_id, confidence_score DESC),
  INDEX idx_pattern_type (pattern_type),
  UNIQUE KEY unique_user_pattern (user_id, pattern_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table to track proactive predictions (pre-generated pages)
CREATE TABLE IF NOT EXISTS proactive_predictions (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,

  -- What was predicted
  predicted_need VARCHAR(255) NOT NULL,  -- 'morning_briefing', 'meeting_prep'
  trigger_pattern VARCHAR(36),  -- FK to user_behavior_patterns

  -- When to show it
  predicted_time TIMESTAMP NOT NULL,
  valid_until TIMESTAMP NOT NULL,

  -- What was pre-generated
  cached_components JSON,
  cache_key VARCHAR(255),

  -- Outcome tracking
  was_used BOOLEAN DEFAULT FALSE,
  actual_use_time TIMESTAMP NULL,
  user_feedback ENUM('helpful', 'neutral', 'not_helpful') NULL,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_user_predictions (user_id, predicted_time),
  INDEX idx_validity (valid_until),
  INDEX idx_was_used (was_used)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Table to store context snapshots (what Llama analyzed)
CREATE TABLE IF NOT EXISTS context_snapshots (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,

  -- Temporal context
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  time_of_day ENUM('morning', 'afternoon', 'evening', 'night'),
  day_of_week VARCHAR(10),
  is_weekend BOOLEAN,

  -- Calendar context
  next_event_minutes INT,  -- Minutes until next calendar event
  events_today INT,
  events_tomorrow INT,

  -- Location context (if available)
  location_type ENUM('home', 'work', 'other', 'unknown') DEFAULT 'unknown',

  -- Recent activity
  last_query TEXT,
  last_query_time TIMESTAMP,
  queries_last_hour INT,

  -- Full snapshot
  full_context JSON,

  INDEX idx_user_context (user_id, timestamp DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add column to messages table to track which AI generated what
ALTER TABLE messages
ADD COLUMN reasoning_decision_id VARCHAR(36) NULL COMMENT 'Links to Llama reasoning decision',
ADD COLUMN generated_by ENUM('claude', 'llama_claude') DEFAULT 'claude' COMMENT 'Which AI system generated this';

-- Index for the new columns
ALTER TABLE messages
ADD INDEX idx_reasoning_decision (reasoning_decision_id);
