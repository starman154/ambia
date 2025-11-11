const msal = require('@azure/msal-node');
const axios = require('axios');
const mysql = require('mysql2/promise');
const { encrypt, decrypt } = require('../utils/oauthEncryption');

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

const msalConfig = {
  auth: {
    clientId: process.env.OUTLOOK_CLIENT_ID,
    authority: 'https://login.microsoftonline.com/common',
    clientSecret: process.env.OUTLOOK_CLIENT_SECRET
  }
};

const pca = new msal.ConfidentialClientApplication(msalConfig);

const SCOPES = [
  'Mail.Read',
  'Mail.ReadBasic',
  'Calendars.Read', // Read calendar events for ambient intelligence
  'User.Read',
  'offline_access'
];

/**
 * GET /api/oauth/outlook/authorize
 * Initiates Outlook OAuth flow
 */
exports.authorize = (req, res) => {
  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ error: 'userId is required' });
  }

  const authCodeUrlParameters = {
    scopes: SCOPES,
    redirectUri: process.env.OUTLOOK_REDIRECT_URI,
    state: userId,
    prompt: 'select_account' // Force account selection - allows choosing between work/personal accounts
  };

  pca.getAuthCodeUrl(authCodeUrlParameters)
    .then((response) => {
      res.redirect(response);
    })
    .catch((error) => {
      console.error('Outlook auth error:', error);
      res.status(500).send('Failed to generate auth URL');
    });
};

/**
 * GET /api/oauth/outlook/callback
 * Handles OAuth callback from Microsoft
 */
exports.callback = async (req, res) => {
  const { code, state: userId } = req.query;

  if (!code || !userId) {
    return res.status(400).send('Authorization failed: Missing code or userId');
  }

  try {
    const tokenRequest = {
      code,
      scopes: SCOPES,
      redirectUri: process.env.OUTLOOK_REDIRECT_URI
    };

    const response = await pca.acquireTokenByCode(tokenRequest);
    const { accessToken, account, expiresOn } = response;

    // Get refresh token from cache
    const tokenCache = pca.getTokenCache();
    const cacheData = tokenCache.serialize();
    const cache = JSON.parse(cacheData);

    // Extract refresh token from cache
    let refreshToken = null;
    if (cache.RefreshToken) {
      const refreshTokenKeys = Object.keys(cache.RefreshToken);
      if (refreshTokenKeys.length > 0) {
        refreshToken = cache.RefreshToken[refreshTokenKeys[0]].secret;
      }
    }

    if (!refreshToken) {
      throw new Error('No refresh token received - please ensure offline_access scope is granted');
    }

    // Get user's email from Microsoft Graph
    const graphResponse = await axios.get('https://graph.microsoft.com/v1.0/me', {
      headers: { Authorization: `Bearer ${accessToken}` }
    });
    const emailAddress = graphResponse.data.mail || graphResponse.data.userPrincipalName;

    // Encrypt tokens
    const encryptedAccessToken = encrypt(accessToken);
    const encryptedRefreshToken = encrypt(refreshToken);

    // Store in database
    await pool.query(`
      INSERT INTO email_oauth_tokens
      (user_id, provider, access_token, refresh_token, token_expiry, email_address, scopes, is_active)
      VALUES (?, 'outlook', ?, ?, ?, ?, ?, TRUE)
      ON DUPLICATE KEY UPDATE
        access_token = VALUES(access_token),
        refresh_token = VALUES(refresh_token),
        token_expiry = VALUES(token_expiry),
        email_address = VALUES(email_address),
        scopes = VALUES(scopes),
        is_active = TRUE,
        updated_at = CURRENT_TIMESTAMP
    `, [userId, encryptedAccessToken, encryptedRefreshToken, expiresOn, emailAddress, JSON.stringify(SCOPES)]);

    console.log(`Outlook authorized for user ${userId} (${emailAddress})`);

    res.send(`
      <html>
        <body>
          <h1>Outlook Connected!</h1>
          <p>Successfully connected ${emailAddress}</p>
          <p>You can close this window.</p>
          <script>window.close();</script>
        </body>
      </html>
    `);
  } catch (error) {
    console.error('Outlook OAuth error:', error);
    res.status(500).send('Failed to authorize Outlook: ' + error.message);
  }
};

/**
 * POST /api/oauth/outlook/disconnect
 * Disconnects Outlook for a user
 */
exports.disconnect = async (req, res) => {
  const { userId } = req.body;

  if (!userId) {
    return res.status(400).json({ error: 'userId is required' });
  }

  try {
    await pool.query(`
      UPDATE email_oauth_tokens
      SET is_active = FALSE
      WHERE user_id = ? AND provider = 'outlook'
    `, [userId]);

    res.json({ success: true, message: 'Outlook disconnected' });
  } catch (error) {
    console.error('Outlook disconnect error:', error);
    res.status(500).json({ error: 'Failed to disconnect Outlook' });
  }
};

/**
 * GET /api/oauth/outlook/status
 * Check if user has Outlook connected
 */
exports.status = async (req, res) => {
  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ error: 'userId is required' });
  }

  try {
    const [rows] = await pool.query(`
      SELECT email_address, is_active, last_synced_at
      FROM email_oauth_tokens
      WHERE user_id = ? AND provider = 'outlook'
    `, [userId]);

    if (rows.length === 0) {
      return res.json({ connected: false });
    }

    res.json({
      connected: true,
      email: rows[0].email_address,
      active: Boolean(rows[0].is_active),
      lastSynced: rows[0].last_synced_at
    });
  } catch (error) {
    console.error('Outlook status error:', error);
    res.status(500).json({ error: 'Failed to check Outlook status' });
  }
};

/**
 * Helper function to get a refreshed access token
 * Used by email scanner service
 */
module.exports.getRefreshedToken = async (userId) => {
  try {
    const [rows] = await pool.query(`
      SELECT access_token, refresh_token, token_expiry
      FROM email_oauth_tokens
      WHERE user_id = ? AND provider = 'outlook' AND is_active = TRUE
    `, [userId]);

    if (rows.length === 0) {
      throw new Error('No Outlook token found');
    }

    const { access_token, refresh_token, token_expiry } = rows[0];
    const decryptedAccessToken = decrypt(access_token);
    const decryptedRefreshToken = decrypt(refresh_token);

    // Check if token is expired
    const now = new Date();
    const expiry = new Date(token_expiry);

    if (now >= expiry) {
      // Refresh token using MSAL
      const refreshRequest = {
        refreshToken: decryptedRefreshToken,
        scopes: SCOPES
      };

      const response = await pca.acquireTokenByRefreshToken(refreshRequest);
      const { accessToken, expiresOn } = response;

      // Update database
      const encryptedNewAccessToken = encrypt(accessToken);
      await pool.query(`
        UPDATE email_oauth_tokens
        SET access_token = ?, token_expiry = ?
        WHERE user_id = ? AND provider = 'outlook'
      `, [encryptedNewAccessToken, expiresOn, userId]);

      return accessToken;
    }

    return decryptedAccessToken;
  } catch (error) {
    console.error('Outlook token refresh error:', error);
    throw error;
  }
};
