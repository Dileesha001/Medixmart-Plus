/**
 * Express application setup and middleware registration.
 */
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const config = require('./config/environment');
const db = require('./config/db');
const { successResponse, errorResponse } = require('./utils/response');
const authRoutes = require('./routes/auth.routes');
const notFoundHandler = require('./middleware/notFound');
const errorHandler = require('./middleware/error');

const app = express();

// Security and utility middleware
app.use(helmet());
app.use(cors({
  origin: config.cors.origin === '*' ? '*' : config.cors.origin.split(','),
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// Development request logger
if (!config.isProduction) {
  app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
      const duration = Date.now() - start;
      console.log(`[HTTP] ${req.method} ${req.originalUrl} ${res.statusCode} (${duration}ms)`);
    });
    next();
  });
}

// Health and readiness endpoint
app.get('/api/health', async (req, res) => {
  const dbHealth = await db.testConnection();
  
  const response = {
    success: true,
    status: dbHealth.ok ? 'healthy' : 'degraded',
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
    environment: config.env,
    database: {
      connected: dbHealth.ok,
      ...(dbHealth.ok
        ? { database: dbHealth.database, user: dbHealth.user, serverTime: dbHealth.timestamp }
        : { error: 'Database connection failed' })
    }
  };

  // If DB connection fails, return 503 Service Unavailable, otherwise 200 OK
  const statusCode = dbHealth.ok ? 200 : 503;
  return res.status(statusCode).json(response);
});

// Root welcome route
app.get('/', (req, res) => {
  res.json({
    name: 'Medixmart Plus REST API',
    version: '1.0.0',
    documentation: '/docs/api',
    health: '/api/health'
  });
});

// Mount feature routes
app.use('/api/auth', authRoutes);

// 404 Catch-All Handler
app.use(notFoundHandler);

// Centralized Global Error Handler
app.use(errorHandler);

module.exports = app;

