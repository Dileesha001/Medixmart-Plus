/**
 * Server entry point.
 * Binds the Express app to host and port, handles startup verification and graceful shutdown.
 */
const http = require('http');
const config = require('./config/environment');
const db = require('./config/db');
const app = require('./app');

const server = http.createServer(app);

const startServer = async () => {
  try {
    // Test database connection at startup
    const dbTest = await db.testConnection();
    if (dbTest.ok) {
      console.log(`[DB] Connected to PostgreSQL '${dbTest.database}' as '${dbTest.user}'`);
    } else {
      console.warn(`[DB WARNING] Database connection failed at startup: ${dbTest.error}`);
    }

    // Bind to 0.0.0.0 to enable local network (LAN) access for desktop & Android
    server.listen(config.port, '0.0.0.0', () => {
      console.log(`=======================================================`);
      console.log(` Medixmart Plus Backend API`);
      console.log(` Running in:   ${config.env} mode`);
      console.log(` Local URL:    http://127.0.0.1:${config.port}`);
      console.log(` Health check: http://127.0.0.1:${config.port}/api/health`);
      console.log(` Timezone:     ${config.business.timezone}`);
      console.log(`=======================================================`);
    });
  } catch (err) {
    console.error('[FATAL] Error starting server:', err);
    process.exit(1);
  }
};

// Graceful shutdown logic
const gracefulShutdown = async (signal) => {
  console.log(`\n[SHUTDOWN] Received ${signal}. Closing HTTP server...`);
  server.close(async () => {
    console.log('[SHUTDOWN] HTTP server closed.');
    try {
      await db.closePool();
      console.log('[SHUTDOWN] Database pool closed. Exiting process.');
      process.exit(0);
    } catch (err) {
      console.error('[SHUTDOWN ERROR] Error during database shutdown:', err);
      process.exit(1);
    }
  });

  // Force close if graceful shutdown takes too long
  setTimeout(() => {
    console.error('[SHUTDOWN] Forced shutdown after timeout.');
    process.exit(1);
  }, 10000);
};

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));

process.on('unhandledRejection', (reason, promise) => {
  console.error('[UNHANDLED REJECTION]', reason);
});

process.on('uncaughtException', (err) => {
  console.error('[UNCAUGHT EXCEPTION]', err);
  process.exit(1);
});

startServer();

