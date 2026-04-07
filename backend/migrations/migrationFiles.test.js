/**
 * CI-only sanity: migration files exist and are non-empty text.
 * Does not connect to PostgreSQL.
 */
const fs = require('fs');
const path = require('path');

const MIGRATIONS_DIR = __dirname;

describe('SQL migration files', () => {
  it('has at least one .sql file', () => {
    const files = fs.readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith('.sql'));
    expect(files.length).toBeGreaterThan(0);
  });

  it.each(
    fs
      .readdirSync(MIGRATIONS_DIR)
      .filter((f) => f.endsWith('.sql'))
      .sort()
  )('%s is non-empty UTF-8 text without NUL bytes', (filename) => {
    const full = path.join(MIGRATIONS_DIR, filename);
    const stat = fs.statSync(full);
    expect(stat.size).toBeGreaterThan(0);
    const text = fs.readFileSync(full, 'utf8');
    expect(text.trim().length).toBeGreaterThan(0);
    expect(text.includes('\0')).toBe(false);
  });
});
