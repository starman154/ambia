-- Ambia Database Schema (MySQL)
-- Migration 001: Initial schema for conversation tracking and user interactions

-- Create Ambia database if it doesn't exist
CREATE DATABASE IF NOT EXISTS ambia;
USE ambia;

-- Users table (for authentication and preferences)
CREATE TABLE IF NOT EXISTS users (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    email VARCHAR(255) UNIQUE,
    phone_number VARCHAR(20) UNIQUE,
    display_name VARCHAR(100),
    device_id VARCHAR(255) UNIQUE NOT NULL,

    -- User preferences
    preferences JSON DEFAULT ('{}'),

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_active_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Constraints
    CONSTRAINT users_contact_check CHECK (
        email IS NOT NULL OR phone_number IS NOT NULL
    ),
    INDEX idx_users_device_id (device_id),
    INDEX idx_users_email (email),
    INDEX idx_users_phone (phone_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Conversations table (chat sessions)
CREATE TABLE IF NOT EXISTS conversations (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,

    -- Conversation metadata
    title VARCHAR(255),
    context JSON DEFAULT ('{}'), -- User context (location, time, weather, etc.)

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_message_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_conversations_user_id (user_id),
    INDEX idx_conversations_updated_at (updated_at DESC),
    INDEX idx_conversations_last_message_at (last_message_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Messages table (individual messages and their layouts)
CREATE TABLE IF NOT EXISTS messages (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    conversation_id CHAR(36) NOT NULL,

    -- Message content
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,

    -- Layout JSON (for assistant messages)
    layout_json JSON, -- The full layout spec from Claude

    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    INDEX idx_messages_conversation_id (conversation_id),
    INDEX idx_messages_created_at (created_at DESC),
    INDEX idx_messages_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Interactions table (track user interactions with cards)
CREATE TABLE IF NOT EXISTS interactions (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    conversation_id CHAR(36) NOT NULL,
    message_id CHAR(36) NOT NULL,

    -- Interaction details
    interaction_type VARCHAR(50) NOT NULL, -- 'tap', 'expand', 'swipe', 'dismiss', etc.
    card_index INTEGER, -- Which card in the layout was interacted with
    metadata JSON DEFAULT ('{}'), -- Additional interaction data

    -- Timestamp
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    INDEX idx_interactions_user_id (user_id),
    INDEX idx_interactions_conversation_id (conversation_id),
    INDEX idx_interactions_message_id (message_id),
    INDEX idx_interactions_type (interaction_type),
    INDEX idx_interactions_created_at (created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Trigger to update conversation last_message_at when message is added
DELIMITER //

CREATE TRIGGER IF NOT EXISTS update_conversation_on_message
AFTER INSERT ON messages
FOR EACH ROW
BEGIN
    UPDATE conversations
    SET last_message_at = NEW.created_at
    WHERE id = NEW.conversation_id;
END//

DELIMITER ;
