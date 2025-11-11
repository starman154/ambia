// Message controller for Ambia
const pool = require('../utils/database');
const { v4: uuidv4 } = require('uuid');

// Add a message to a conversation
exports.createMessage = async (req, res) => {
  try {
    const { conversationId, role, content, layoutJson } = req.body;
    const messageId = uuidv4();

    await pool.query(`
      INSERT INTO messages (id, conversation_id, role, content, layout_json)
      VALUES (?, ?, ?, ?, ?)
    `, [messageId, conversationId, role, content, layoutJson ? JSON.stringify(layoutJson) : null]);

    res.status(201).json({
      success: true,
      messageId
    });
  } catch (error) {
    console.error('Error creating message:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create message'
    });
  }
};

// Track an interaction with a card
exports.trackInteraction = async (req, res) => {
  try {
    const { userId, conversationId, messageId, interactionType, cardIndex, metadata } = req.body;
    const interactionId = uuidv4();

    await pool.query(`
      INSERT INTO interactions (id, user_id, conversation_id, message_id, interaction_type, card_index, metadata)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `, [interactionId, userId, conversationId, messageId, interactionType, cardIndex, JSON.stringify(metadata || {})]);

    res.status(201).json({
      success: true,
      interactionId
    });
  } catch (error) {
    console.error('Error tracking interaction:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to track interaction'
    });
  }
};
