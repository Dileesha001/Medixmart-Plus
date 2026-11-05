/**
 * Database Schema Initializer.
 * Applies base tables and migrations.
 */
const fs = require('fs');
const path = require('path');
const db = require('../config/db');

const applySchema = async () => {
  const schemaPath = path.join(__dirname, '01_create_users_table.sql');
  const sql = fs.readFileSync(schemaPath, 'utf8');

  console.log('[DB] Applying users table schema...');
  await db.query(sql);
  console.log('[DB] Users table schema applied successfully.');
};

if (require.main === module) {
  applySchema()
    .then(async () => {
      await db.closePool();
      process.exit(0);
    })
    .catch(async (err) => {
      console.error('[DB ERROR] Failed to apply schema:', err);
      await db.closePool();
      process.exit(1);
    });
}

module.exports = applySchema;

