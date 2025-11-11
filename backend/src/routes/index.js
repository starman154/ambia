// API Routes for Ambia
const express = require('express');
const router = express.Router();

const conversationController = require('../controllers/conversationController');
const messageController = require('../controllers/messageController');
const userController = require('../controllers/userController');
const ambiaController = require('../controllers/ambiaController');
const adminController = require('../controllers/adminController');
const ambientEventsController = require('../controllers/ambientEventsController');
const calendarController = require('../controllers/calendarController');

// User routes
router.post('/users/auth', userController.getOrCreateUser);
router.put('/users/:userId/preferences', userController.updatePreferences);

// Conversation routes
router.get('/users/:userId/conversations', conversationController.getUserConversations);
router.get('/conversations/:conversationId', conversationController.getConversation);
router.post('/conversations', conversationController.createConversation);
router.delete('/conversations/:conversationId', conversationController.deleteConversation);

// Message routes
router.post('/messages', messageController.createMessage);
router.post('/interactions', messageController.trackInteraction);

// Ambia AI routes - Claude API Proxy
router.post('/ambia/generate', ambiaController.generateComponents);
router.post('/ambia/feedback', ambiaController.saveFeedback);
router.get('/ambia/preferences/:userId', ambiaController.getPreferences);

// Admin routes - Database migrations
router.post('/admin/migrate', adminController.runMigration);
router.get('/admin/migration-status', adminController.checkMigrationStatus);

// Ambient Events routes - iOS Live Activities, Dynamic Island, Notifications
router.get('/ambient/events/:userId', ambientEventsController.getActiveEvents);
router.get('/ambient/events/details/:eventId', ambientEventsController.getEvent);
router.post('/ambient/events/test', ambientEventsController.createTestEvent); // Test endpoint
router.post('/ambient/events/:eventId/interact', ambientEventsController.trackInteraction);
router.post('/ambient/devices/register', ambientEventsController.registerDevice);
router.put('/ambient/devices/:deviceId/preferences', ambientEventsController.updateDevicePreferences);
router.get('/ambient/layout/:eventId', ambientEventsController.generateLayout); // Claude-powered layout generation

// Calendar routes - Apple Calendar integration
router.post('/calendar/sync', calendarController.syncCalendar);
router.get('/calendar/events', calendarController.getEvents);
router.post('/calendar/test-llama', calendarController.testLlama); // DEBUG endpoint

// Health check
router.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

module.exports = router;
