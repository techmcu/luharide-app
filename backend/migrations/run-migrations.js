require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/config/database');

async function ensureMigrationsTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id SERIAL PRIMARY KEY,
      filename VARCHAR(255) NOT NULL UNIQUE,
      applied_at TIMESTAMP DEFAULT NOW()
    )
  `);
}

async function getAppliedMigrations(client) {
  const result = await client.query('SELECT filename FROM _migrations ORDER BY filename');
  return new Set(result.rows.map(r => r.filename));
}

/**
 * Bootstrap: on an existing DB where migrations were already applied without tracking,
 * detect the DB state and seed _migrations with all previously-applied files.
 * Detection: if _migrations is empty but core tables (users, trips, bookings) already exist,
 * this is an existing DB — mark all migrations up to the last known one as applied.
 */
async function bootstrapExistingDb(client, files) {
  const applied = await getAppliedMigrations(client);
  if (applied.size > 0) return false;

  const tableCheck = await client.query(`
    SELECT COUNT(*)::int AS cnt FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name IN ('users', 'trips', 'bookings')
  `);
  if (tableCheck.rows[0].cnt < 3) return false;

  console.log('📋 Existing database detected — seeding migration tracking with previously applied files...');

  // All files except brand-new ones (057+) are assumed already applied on existing DB
  const NEW_MIGRATION_CUTOFF = '057_';
  // 057+ are new migrations added with tracking — bootstrap marks everything before this as applied
  const previousFiles = files.filter(f => f < NEW_MIGRATION_CUTOFF);

  for (const file of previousFiles) {
    await client.query(
      'INSERT INTO _migrations (filename) VALUES ($1) ON CONFLICT DO NOTHING',
      [file]
    );
  }
  console.log(`   Marked ${previousFiles.length} existing migrations as applied.\n`);
  return true;
}

async function runMigrations() {
  const client = await pool.connect();
  try {
    console.log('🔄 Running database migrations...\n');

    await ensureMigrationsTable(client);

    const migrationsDir = __dirname;
    const files = fs
      .readdirSync(migrationsDir)
      .filter((file) => file.endsWith('.sql'))
      .sort();

    await bootstrapExistingDb(client, files);

    const applied = await getAppliedMigrations(client);
    let newCount = 0;

    for (const file of files) {
      if (applied.has(file)) {
        continue;
      }

      console.log(`Running migration: ${file}`);
      const filePath = path.join(migrationsDir, file);
      const sql = fs.readFileSync(filePath, 'utf8');

      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query(
          'INSERT INTO _migrations (filename) VALUES ($1)',
          [file]
        );
        await client.query('COMMIT');
        console.log(`✅ ${file} completed\n`);
        newCount++;
      } catch (err) {
        await client.query('ROLLBACK');
        if (err.code === '42P07' || err.code === '42701' || err.message?.includes('already exists')) {
          try {
            await client.query(
              'INSERT INTO _migrations (filename) VALUES ($1) ON CONFLICT DO NOTHING',
              [file]
            );
          } catch (_) {}
          console.log(`⏭️  ${file} skipped (already applied)\n`);
        } else {
          console.error(`❌ ${file} failed:`, err.message);
          throw err;
        }
      }
    }

    if (newCount === 0) {
      console.log('✅ All migrations already applied — nothing to do.');
    } else {
      console.log(`✅ ${newCount} new migration(s) applied successfully!`);
    }
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    client.release();
  }
}

runMigrations();
