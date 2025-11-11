-- Page Cache Table
-- Stores pre-generated pages for Tier 1/2/3 caching

CREATE TABLE IF NOT EXISTS page_cache (
  cache_key VARCHAR(255) PRIMARY KEY,
  user_id CHAR(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  query TEXT NOT NULL,
  components_json JSON NOT NULL,
  tier INT NOT NULL CHECK (tier IN (1, 2, 3)),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  access_count INT DEFAULT 1,

  INDEX idx_user_tier (user_id, tier),
  INDEX idx_created_at (created_at),
  INDEX idx_last_accessed (last_accessed_at),

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Add index for efficient cache lookups
CREATE INDEX idx_cache_lookup ON page_cache(cache_key, user_id);

-- Add index for cleanup queries
CREATE INDEX idx_cache_cleanup ON page_cache(tier, created_at);
