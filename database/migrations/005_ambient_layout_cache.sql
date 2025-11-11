-- Migration 005: Add layout caching to ambient_events
-- This enables pre-generation of Claude layouts so they're ready when users tap live activities

USE ambia;

-- Add generated_layout column to cache Claude-generated layouts
ALTER TABLE ambient_events
ADD COLUMN generated_layout JSON DEFAULT NULL COMMENT 'Pre-generated Claude layout for instant display';

-- Add calendar_event_id to link ambient events to calendar events
ALTER TABLE ambient_events
ADD COLUMN calendar_event_id CHAR(36) DEFAULT NULL COMMENT 'Reference to calendar_events table',
ADD INDEX idx_ambient_events_calendar (calendar_event_id);

-- Add layout generation timestamp
ALTER TABLE ambient_events
ADD COLUMN layout_generated_at TIMESTAMP NULL COMMENT 'When the layout was generated';
