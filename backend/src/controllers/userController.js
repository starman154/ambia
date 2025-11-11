// User controller for Ambia
const pool = require('../utils/database');
const { v4: uuidv4 } = require('uuid');

// Get or create user by device ID
exports.getOrCreateUser = async (req, res) => {
  try {
    const { deviceId, email, phoneNumber, displayName } = req.body;

    if (!deviceId) {
      return res.status(400).json({
        success: false,
        error: 'Device ID is required'
      });
    }

    // Check if user exists
    const [existingUsers] = await pool.query(
      'SELECT id, email, phone_number, display_name, preferences, created_at FROM users WHERE device_id = ?',
      [deviceId]
    );

    if (existingUsers.length > 0) {
      const user = existingUsers[0];
      return res.json({
        success: true,
        user: {
          ...user,
          preferences: typeof user.preferences === 'string' ? JSON.parse(user.preferences) : user.preferences
        },
        isNew: false
      });
    }

    // Create new user
    const userId = uuidv4();
    await pool.query(`
      INSERT INTO users (id, device_id, email, phone_number, display_name, preferences)
      VALUES (?, ?, ?, ?, ?, ?)
    `, [userId, deviceId, email || null, phoneNumber || null, displayName || null, JSON.stringify({})]);

    res.status(201).json({
      success: true,
      user: {
        id: userId,
        device_id: deviceId,
        email: email || null,
        phone_number: phoneNumber || null,
        display_name: displayName || null,
        preferences: {}
      },
      isNew: true
    });
  } catch (error) {
    console.error('Error getting/creating user:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get/create user'
    });
  }
};

// Update user preferences
exports.updatePreferences = async (req, res) => {
  try {
    const { userId } = req.params;
    const { preferences } = req.body;

    await pool.query(
      'UPDATE users SET preferences = ? WHERE id = ?',
      [JSON.stringify(preferences), userId]
    );

    res.json({
      success: true,
      message: 'Preferences updated'
    });
  } catch (error) {
    console.error('Error updating preferences:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update preferences'
    });
  }
};
