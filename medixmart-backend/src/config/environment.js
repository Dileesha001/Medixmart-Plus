/**
 * Environment configuration and startup validator.
 * Validates required configuration before allowing the server to boot.
 */
const path = require('path');
const dotenv = require('dotenv');

// Load .env file from medixmart-backend root
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const requiredEnvVars = [
  'PORT',
  'DB_HOST',
  'DB_PORT',
  'DB_NAME',
  'DB_USER',
  'DB_PASSWORD',
  'JWT_SECRET'
];

const missing = requiredEnvVars.filter((varName) => !process.env[varName] || process.env[varName].trim() === '');

if (missing.length > 0) {
  const errorMessage = `[FATAL] Missing required environment variables: ${missing.join(', ')}. Server startup aborted.`;
  console.error(errorMessage);
  throw new Error(errorMessage);
}

const config = {
  env: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',
  port: parseInt(process.env.PORT, 10) || 3000,
  
  db: {
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT, 10) || 5432,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    max: parseInt(process.env.DB_MAX_CONNECTIONS, 10) || 20,
    idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT_MS, 10) || 30000,
    connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT_MS, 10) || 5000
  },
  
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '8h'
  },
  
  cors: {
    origin: process.env.CORS_ORIGIN || '*'
  },
  
  business: {
    timezone: process.env.TIMEZONE || 'Asia/Colombo',
    expiryWindowMonths: parseInt(process.env.EXPIRY_WINDOW_MONTHS, 10) || 7
  }
};

module.exports = config;

