const crypto = require('crypto');

// Get encryption key from environment
const ENCRYPTION_KEY = process.env.OAUTH_ENCRYPTION_KEY;
const ALGORITHM = 'aes-256-cbc';

if (!ENCRYPTION_KEY || ENCRYPTION_KEY.length !== 64) {
  console.warn('WARNING: OAUTH_ENCRYPTION_KEY not set or invalid (should be 64 hex chars). Tokens will NOT be encrypted!');
}

/**
 * Encrypt sensitive data (OAuth tokens)
 * @param {string} text - Plain text to encrypt
 * @returns {string} - Encrypted text in format: iv:encryptedData
 */
function encrypt(text) {
  if (!ENCRYPTION_KEY) {
    // Development fallback - DO NOT use in production
    return text;
  }

  const iv = crypto.randomBytes(16);
  const key = Buffer.from(ENCRYPTION_KEY, 'hex');
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');

  return `${iv.toString('hex')}:${encrypted}`;
}

/**
 * Decrypt sensitive data (OAuth tokens)
 * @param {string} encryptedText - Encrypted text in format: iv:encryptedData
 * @returns {string} - Plain text
 */
function decrypt(encryptedText) {
  if (!ENCRYPTION_KEY) {
    // Development fallback - DO NOT use in production
    return encryptedText;
  }

  const [ivHex, encrypted] = encryptedText.split(':');
  const iv = Buffer.from(ivHex, 'hex');
  const key = Buffer.from(ENCRYPTION_KEY, 'hex');
  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);

  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');

  return decrypted;
}

module.exports = {
  encrypt,
  decrypt
};
