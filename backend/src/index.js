// Ambia Backend Server
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const routes = require('./routes');
const oauthRoutes = require('./routes/oauth');
const { startBackgroundJobs } = require('./backgroundJobs');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// API routes
app.use('/api', routes);
app.use('/api/oauth', oauthRoutes);

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'Ambia Backend API',
    version: '1.0.0',
    status: 'running'
  });
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`
╔══════════════════════════════════════╗
║   Ambia Backend API Server           ║
║                                      ║
║   Status: Running                    ║
║   Port: ${PORT}                         ║
║   Environment: ${process.env.NODE_ENV || 'development'}              ║
╚══════════════════════════════════════╝
  `);

  // Start background jobs for proactive intelligence
  startBackgroundJobs();
});

module.exports = app;
