// Admin Controller - Secure endpoints for database migrations
const pool = require('../utils/database');
const fs = require('fs').promises;
const path = require('path');

/**
 * Run database migrations
 * POST /api/admin/migrate
 * Body: { adminSecret, migrationName? }
 */
exports.runMigration = async (req, res) => {
  try {
    const { adminSecret, migrationName } = req.body;

    // Security: Verify admin secret
    if (adminSecret !== process.env.ADMIN_SECRET) {
      return res.status(403).json({
        success: false,
        error: 'Unauthorized: Invalid admin secret'
      });
    }

    console.log('[Admin] Running migration:', migrationName || 'page_cache');

    // Determine which migration to run
    const migration = migrationName || '002_page_cache';
    const migrationPath = path.join(__dirname, '../../database/migrations', `${migration}.sql`);

    // Read migration file
    const sql = await fs.readFile(migrationPath, 'utf8');

    // Split by semicolons and filter out empty statements
    const statements = sql
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));

    console.log(`[Admin] Executing ${statements.length} SQL statements...`);

    // Execute each statement
    const results = [];
    for (const statement of statements) {
      try {
        const [result] = await pool.query(statement);
        results.push({ success: true, statement: statement.substring(0, 50) + '...' });
        console.log(`[Admin] ✓ Executed: ${statement.substring(0, 50)}...`);
      } catch (error) {
        // Ignore "table already exists" errors
        if (error.code === 'ER_TABLE_EXISTS_ERROR') {
          console.log(`[Admin] ⚠ Table already exists, skipping...`);
          results.push({ success: true, statement: statement.substring(0, 50) + '...', skipped: true });
        } else {
          console.error(`[Admin] ✗ Failed: ${statement.substring(0, 50)}...`, error.message);
          results.push({ success: false, statement: statement.substring(0, 50) + '...', error: error.message });
        }
      }
    }

    const successCount = results.filter(r => r.success).length;
    console.log(`[Admin] Migration complete: ${successCount}/${results.length} statements succeeded`);

    res.json({
      success: true,
      migration: migration,
      statementsExecuted: results.length,
      statementsSucceeded: successCount,
      results
    });
  } catch (error) {
    console.error('[Admin] Error running migration:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to run migration'
    });
  }
};

/**
 * Check migration status
 * GET /api/admin/migration-status
 * Query: ?adminSecret=xxx
 */
exports.checkMigrationStatus = async (req, res) => {
  try {
    const { adminSecret } = req.query;

    // Security: Verify admin secret
    if (adminSecret !== process.env.ADMIN_SECRET) {
      return res.status(403).json({
        success: false,
        error: 'Unauthorized: Invalid admin secret'
      });
    }

    console.log('[Admin] Checking migration status...');

    // Check if page_cache table exists
    const [tables] = await pool.query(`
      SELECT TABLE_NAME
      FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'page_cache'
    `);

    const pageCacheExists = tables.length > 0;

    let cacheStats = null;
    if (pageCacheExists) {
      const [stats] = await pool.query(`
        SELECT
          COUNT(*) as total_entries,
          SUM(CASE WHEN tier = 1 THEN 1 ELSE 0 END) as tier1_count,
          SUM(CASE WHEN tier = 2 THEN 1 ELSE 0 END) as tier2_count,
          SUM(CASE WHEN tier = 3 THEN 1 ELSE 0 END) as tier3_count
        FROM page_cache
      `);
      cacheStats = stats[0];
    }

    res.json({
      success: true,
      migrations: {
        page_cache: pageCacheExists
      },
      cacheStats
    });
  } catch (error) {
    console.error('[Admin] Error checking migration status:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to check migration status'
    });
  }
};

module.exports = exports;
