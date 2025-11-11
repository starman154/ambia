// Conversation controller for Ambia
const pool = require('../utils/database');
const { v4: uuidv4 } = require('uuid');

// Get all conversations for a user
exports.getUserConversations = async (req, res) => {
  try {
    const { userId } = req.params;

    const [conversations] = await pool.query(`
      SELECT
        c.id,
        c.title,
        c.context,
        c.created_at,
        c.updated_at,
        c.last_message_at,
        COUNT(m.id) as message_count,
        (SELECT content FROM messages WHERE conversation_id = c.id ORDER BY created_at DESC LIMIT 1) as last_message
      FROM conversations c
      LEFT JOIN messages m ON c.id = m.conversation_id
      WHERE c.user_id = ?
      GROUP BY c.id
      ORDER BY c.last_message_at DESC
    `, [userId]);

    res.json({
      success: true,
      conversations: conversations.map(c => ({
        ...c,
        context: typeof c.context === 'string' ? JSON.parse(c.context) : c.context
      }))
    });
  } catch (error) {
    console.error('Error fetching conversations:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch conversations'
    });
  }
};

// Get a specific conversation with all messages
exports.getConversation = async (req, res) => {
  try {
    const { conversationId } = req.params;

    // Get conversation details
    const [conversations] = await pool.query(`
      SELECT id, user_id, title, context, created_at, updated_at, last_message_at
      FROM conversations
      WHERE id = ?
    `, [conversationId]);

    if (conversations.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Conversation not found'
      });
    }

    // Get all messages
    const [messages] = await pool.query(`
      SELECT id, role, content, layout_json, created_at
      FROM messages
      WHERE conversation_id = ?
      ORDER BY created_at ASC
    `, [conversationId]);

    const conversation = conversations[0];
    res.json({
      success: true,
      conversation: {
        ...conversation,
        context: typeof conversation.context === 'string' ? JSON.parse(conversation.context) : conversation.context,
        messages: messages.map(m => ({
          ...m,
          layout_json: m.layout_json && typeof m.layout_json === 'string' ? JSON.parse(m.layout_json) : m.layout_json
        }))
      }
    });
  } catch (error) {
    console.error('Error fetching conversation:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch conversation'
    });
  }
};

// Create a new conversation
exports.createConversation = async (req, res) => {
  try {
    const { userId, title, context } = req.body;
    const conversationId = uuidv4();

    await pool.query(`
      INSERT INTO conversations (id, user_id, title, context)
      VALUES (?, ?, ?, ?)
    `, [conversationId, userId, title || 'New Conversation', JSON.stringify(context || {})]);

    res.status(201).json({
      success: true,
      conversationId
    });
  } catch (error) {
    console.error('Error creating conversation:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create conversation'
    });
  }
};

// Delete a conversation
exports.deleteConversation = async (req, res) => {
  try {
    const { conversationId } = req.params;

    await pool.query('DELETE FROM conversations WHERE id = ?', [conversationId]);

    res.json({
      success: true,
      message: 'Conversation deleted'
    });
  } catch (error) {
    console.error('Error deleting conversation:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete conversation'
    });
  }
};
