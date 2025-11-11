-- Migration: Add user preferences table and feedback columns
-- Date: 2025-11-02

-- Create user_preferences table
CREATE TABLE IF NOT EXISTS user_preferences (
  id VARCHAR(36) PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  category VARCHAR(50) NOT NULL,
  preference VARCHAR(50) NOT NULL,
  context VARCHAR(50) DEFAULT 'general',
  description TEXT,
  strength INT DEFAULT 5,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_category (category),
  INDEX idx_strength (strength)
) COMMENT = 'Stores user preferences learned from feedback';
