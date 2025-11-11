const express = require('express');
const router = express.Router();
const gmailOAuthController = require('../controllers/gmailOAuthController');
const outlookOAuthController = require('../controllers/outlookOAuthController');

// Gmail OAuth routes
router.get('/gmail/authorize', gmailOAuthController.authorize);
router.get('/gmail/callback', gmailOAuthController.callback);
router.post('/gmail/disconnect', gmailOAuthController.disconnect);
router.get('/gmail/status', gmailOAuthController.status);

// Outlook OAuth routes
router.get('/outlook/authorize', outlookOAuthController.authorize);
router.get('/outlook/callback', outlookOAuthController.callback);
router.post('/outlook/disconnect', outlookOAuthController.disconnect);
router.get('/outlook/status', outlookOAuthController.status);

module.exports = router;
