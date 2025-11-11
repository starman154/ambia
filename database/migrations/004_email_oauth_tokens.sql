-- Migration 004: Email OAuth Tokens
-- Stores encrypted OAuth tokens for Gmail and Outlook integration

USE ambia;

-- ==============================================================================
-- EMAIL OAUTH TOKENS TABLE
-- ==============================================================================
-- Stores OAuth refresh tokens and metadata for email providers
-- Tokens are encrypted at rest for security

CREATE TABLE IF NOT EXISTS email_oauth_tokens (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    provider ENUM('gmail', 'outlook') NOT NULL,

    -- OAuth tokens (ENCRYPTED - use AES_ENCRYPT in application)
    access_token TEXT,
    refresh_token TEXT NOT NULL,
    token_expiry DATETIME,

    -- User's email address for this provider
    email_address VARCHAR(255) NOT NULL,

    -- Provider-specific metadata
    scopes TEXT, -- JSON array of granted scopes

    -- Status tracking
    is_active BOOLEAN DEFAULT TRUE,
    last_synced_at DATETIME,
    last_error TEXT,

    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Constraints
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_provider (user_id, provider),
    INDEX idx_user_active (user_id, is_active),
    INDEX idx_provider_active (provider, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ==============================================================================
-- EMAIL SYNC LOG TABLE
-- ==============================================================================
-- Tracks email scanning jobs and results

CREATE TABLE IF NOT EXISTS email_sync_log (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    provider ENUM('gmail', 'outlook') NOT NULL,

    -- Sync details
    sync_started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    sync_completed_at DATETIME,
    status ENUM('running', 'success', 'failed') DEFAULT 'running',

    -- Results
    emails_scanned INT DEFAULT 0,
    events_created INT DEFAULT 0,
    error_message TEXT,

    -- Timestamps
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_status (user_id, status),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SELECT 'Email OAuth tokens tables created' AS status;
