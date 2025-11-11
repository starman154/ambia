-- Migration 003: User Preferences Structure
-- Documents the expected structure of the preferences JSON column
-- NO SCHEMA CHANGES - preferences column already exists in users table

USE ambia;

-- ==============================================================================
-- PREFERENCES JSON STRUCTURE
-- ==============================================================================
-- The users.preferences column stores user settings as JSON.
-- This migration documents the expected structure.

-- Example preferences JSON:
-- {
--   "calendar_enabled": false,
--   "ai_predictions_enabled": true,
--   "push_notifications_enabled": true,
--   "dynamic_island_enabled": false,
--   "gmail_enabled": false,
--   "outlook_enabled": false
-- }

-- ==============================================================================
-- DEFAULT VALUES
-- ==============================================================================
-- All preferences default to false except ai_predictions_enabled (true)
-- The backend API will merge user preferences with these defaults:
--   - calendar_enabled: false
--   - ai_predictions_enabled: true
--   - push_notifications_enabled: false
--   - dynamic_island_enabled: false
--   - gmail_enabled: false
--   - outlook_enabled: false

-- No actual migration needed - column already exists
-- This file exists for documentation and versioning purposes only
SELECT 'User preferences structure documented' AS status;
