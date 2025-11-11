-- BACKGROUND INTELLIGENCE TABLES
-- Powers Ambia's ambient intelligence with background processing

-- Activity log for pattern mining
CREATE TABLE IF NOT EXISTS activity_log (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,

  -- Action tracking
  action_type ENUM('query', 'view', 'interaction', 'dismiss', 'save') NOT NULL,
  action_data JSON,  -- Flexible storage for different action types

  -- Context at time of action
  query TEXT,
  components_shown JSON,
  component_interacted VARCHAR(50),
  interaction_duration_ms INT,

  -- Temporal context
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  time_of_day ENUM('morning', 'afternoon', 'evening', 'night'),
  day_of_week VARCHAR(10),
  is_weekend BOOLEAN,

  -- Location context (if available)
  location_type ENUM('home', 'work', 'other', 'unknown') DEFAULT 'unknown',

  -- User satisfaction signals
  helpful BOOLEAN NULL,  -- Explicit feedback
  interaction_score DECIMAL(3,2),  -- Derived from behavior (0.0 to 1.0)

  INDEX idx_user_activity (user_id, timestamp DESC),
  INDEX idx_action_type (action_type),
  INDEX idx_helpful (helpful),
  INDEX idx_time_patterns (time_of_day, day_of_week, is_weekend)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Generation queue for background jobs
CREATE TABLE IF NOT EXISTS generation_queue (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,

  -- Job details
  job_type ENUM('prediction', 'pattern_analysis', 'data_organization', 'cost_optimization') NOT NULL,
  priority INT DEFAULT 50,  -- 0 (low) to 100 (urgent)

  -- What to generate
  predicted_need VARCHAR(255),  -- 'morning_briefing', 'meeting_prep', etc
  trigger_pattern_id VARCHAR(36),  -- FK to user_behavior_patterns

  -- Generation parameters
  context_data JSON,
  prompt_template VARCHAR(255),

  -- Scheduling
  scheduled_for TIMESTAMP NOT NULL,
  valid_until TIMESTAMP NOT NULL,

  -- Execution tracking
  status ENUM('queued', 'processing', 'completed', 'failed', 'cancelled') DEFAULT 'queued',
  attempts INT DEFAULT 0,
  max_attempts INT DEFAULT 3,

  -- Results
  result_cache_key VARCHAR(255),
  error_message TEXT,

  -- Timestamps
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  started_at TIMESTAMP NULL,
  completed_at TIMESTAMP NULL,

  INDEX idx_user_queue (user_id, scheduled_for),
  INDEX idx_status (status, scheduled_for),
  INDEX idx_priority (priority DESC, scheduled_for),
  INDEX idx_job_type (job_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Cache for pre-generated pages
CREATE TABLE IF NOT EXISTS page_cache (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,

  -- Cache key (unique identifier for this cached content)
  cache_key VARCHAR(255) NOT NULL,
  cache_type ENUM('prediction', 'pattern', 'frequent_query', 'scheduled') NOT NULL,

  -- Cached content
  query TEXT,  -- Original query/need this addresses
  components JSON NOT NULL,  -- Pre-generated component data
  generation_metadata JSON,  -- How it was generated, tokens used, etc

  -- Relevance scoring
  relevance_score DECIMAL(3,2),  -- 0.0 to 1.0
  trigger_conditions JSON,  -- When this should be shown

  -- Cache management
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  valid_until TIMESTAMP NOT NULL,
  last_accessed TIMESTAMP NULL,
  access_count INT DEFAULT 0,

  -- Usage tracking
  was_shown BOOLEAN DEFAULT FALSE,
  shown_at TIMESTAMP NULL,
  user_feedback ENUM('helpful', 'neutral', 'not_helpful') NULL,

  -- Performance
  generation_cost_tokens INT,
  generation_time_ms INT,

  UNIQUE KEY unique_cache (user_id, cache_key),
  INDEX idx_user_cache (user_id, valid_until DESC),
  INDEX idx_cache_key (cache_key),
  INDEX idx_validity (valid_until),
  INDEX idx_relevance (relevance_score DESC),
  INDEX idx_feedback (user_feedback, was_shown)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add columns to existing messages table for activity tracking
ALTER TABLE messages
ADD COLUMN cache_hit BOOLEAN DEFAULT FALSE COMMENT 'Was this served from cache?',
ADD COLUMN cache_key VARCHAR(255) NULL COMMENT 'Cache key if served from cache',
ADD COLUMN generation_source ENUM('real_time', 'cached', 'predicted') DEFAULT 'real_time';

-- Index for cache tracking
ALTER TABLE messages
ADD INDEX idx_cache_hit (cache_hit, created_at);
