/**
 * Database Schema Initializer.
 * Applies base tables and migrations.
 */
const fs = require('fs');
const path = require('path');
const db = require('../config/db');

const applySchema = async () => {
  const sqlDir = __dirname;
  const files = fs
    .readdirSync(sqlDir)
    .filter((f) => /^\d+_create_.*\.sql$/.test(f))
    .sort();

  for (const file of files) {
    const filePath = path.join(sqlDir, file);
    const sql = fs.readFileSync(filePath, 'utf8');
    console.log(`[DB] Applying schema from ${file}...`);
    await db.query(sql);
    console.log(`[DB] Successfully applied ${file}.`);
  }
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

