/**
 * Server entry point.
 * Binds the Express app to host and port, handles startup verification and graceful shutdown.
 */
const http = require('http');
const os = require('os');
const config = require('./config/environment');
const db = require('./config/db');
const app = require('./app');
const expiryJob = require('./jobs/expiryJob');

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

    // Bind to 0.0.0.0 (or configured HOST) to enable local network (LAN) access for desktop & Android
    server.listen(config.port, config.host, () => {
      console.log(`=======================================================`);
      console.log(` Medixmart Plus Backend API`);
      console.log(` Running in:       ${config.env} mode`);
      console.log(` Listening on:     ${config.host}:${config.port}`);
      console.log(` Local Loopback:   http://127.0.0.1:${config.port}`);

      // Enumerate and display active IPv4 interfaces for mobile and cross-device testing
      const interfaces = os.networkInterfaces();
      for (const name of Object.keys(interfaces)) {
        for (const net of interfaces[name]) {
          if (net.family === 'IPv4' && !net.internal) {
            console.log(` LAN Interface:    http://${net.address}:${config.port} (${name})`);
          }
        }
      }

      console.log(` Android Emulator: http://10.0.2.2:${config.port}`);
      console.log(` Health check:     http://127.0.0.1:${config.port}/api/health`);
      console.log(` Timezone:         ${config.business.timezone}`);
      console.log(`=======================================================`);

      // Initialize background jobs (scheduled daily 06:00 check + startup catch-up)
      expiryJob.start();
    });
  } catch (err) {
    console.error('[FATAL] Error starting server:', err);
    process.exit(1);
  }
};

// Graceful shutdown logic
const gracefulShutdown = async (signal) => {
  console.log(`\n[SHUTDOWN] Received ${signal}. Closing HTTP server...`);
  expiryJob.stop();
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

