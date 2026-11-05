/**
 * Idempotent Administrator Seeding Script.
 * Ensures an active administrative account exists with a secure bcrypt-hashed password.
 */
const bcrypt = require('bcrypt');
const db = require('../config/db');

const BCRYPT_SALT_ROUNDS = 10;

/**
 * Seed default admin and initial pharmacist accounts if they don't already exist.
 * @param {object} [options]
 * @param {string} [options.adminUsername='admin']
 * @param {string} [options.adminPassword]
 * @param {boolean} [options.seedPharmacist=false]
 */
const seedUsers = async (options = {}) => {
  const adminUsername = options.adminUsername || process.env.ADMIN_USERNAME || 'admin';
  const adminPassword = options.adminPassword || process.env.ADMIN_INITIAL_PASSWORD || 'Admin@Medix123';

  console.log(`[SEED] Checking for existing administrator '${adminUsername}'...`);
  const checkRes = await db.query(
    'SELECT id, username, role, is_active FROM users WHERE username = $1',
    [adminUsername]
  );

  if (checkRes.rows.length > 0) {
    console.log(`[SEED] Administrator '${adminUsername}' already exists (ID: ${checkRes.rows[0].id}). Skipping seed.`);
    return checkRes.rows[0];
  }

  console.log(`[SEED] Hashing password with bcrypt (rounds: ${BCRYPT_SALT_ROUNDS})...`);
  const passwordHash = await bcrypt.hash(adminPassword, BCRYPT_SALT_ROUNDS);

  const insertRes = await db.query(
    `INSERT INTO users (username, password_hash, role, is_active)
     VALUES ($1, $2, 'admin', TRUE)
     RETURNING id, username, role, is_active, created_at`,
    [adminUsername, passwordHash]
  );

  console.log(`[SEED] Administrator created successfully (ID: ${insertRes.rows[0].id}, Username: ${insertRes.rows[0].username}).`);

  // Optionally seed a sample pharmacist for testing
  if (options.seedPharmacist) {
    const pharmUsername = 'pharmacist1';
    const pharmCheck = await db.query('SELECT id FROM users WHERE username = $1', [pharmUsername]);
    if (pharmCheck.rows.length === 0) {
      const pharmHash = await bcrypt.hash('Pharm@Medix123', BCRYPT_SALT_ROUNDS);
      await db.query(
        `INSERT INTO users (username, password_hash, role, is_active)
         VALUES ($1, $2, 'pharmacist', TRUE)`,
        [pharmUsername, pharmHash]
      );
      console.log(`[SEED] Test pharmacist account '${pharmUsername}' created.`);
    }
  }

  return insertRes.rows[0];
};

if (require.main === module) {
  seedUsers({ seedPharmacist: true })
    .then(async () => {
      await db.closePool();
      process.exit(0);
    })
    .catch(async (err) => {
      console.error('[SEED ERROR] Failed to seed admin user:', err);
      await db.closePool();
      process.exit(1);
    });
}

module.exports = seedUsers;

