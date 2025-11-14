const { Pool } = require('pg');
const logger = require('../utils/logger');

// Database connection pool
let pool;

/**
 * Initialize database connection pool
 */
function initializePool() {
  if (pool) {
    return pool;
  }

  const databaseUrl = process.env.DATABASE_URL;
  
  if (!databaseUrl) {
    logger.warn('DATABASE_URL not set, database features will be disabled');
    return null;
  }

  try {
    pool = new Pool({
      connectionString: databaseUrl,
      ssl: process.env.NODE_ENV === 'production' && !databaseUrl.includes('localhost') && !databaseUrl.includes('postgres:')
        ? { rejectUnauthorized: false }
        : false,
      max: parseInt(process.env.DB_POOL_MAX) || 20,
      idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT) || 30000,
      connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT) || 2000,
    });

    pool.on('connect', () => {
      logger.debug('New database client connected');
    });

    pool.on('error', (err) => {
      logger.error('Unexpected database error', { error: err.message });
    });

    logger.info('Database pool initialized successfully');
    return pool;
  } catch (error) {
    logger.error('Failed to initialize database pool', { error: error.message });
    return null;
  }
}

/**
 * Get database pool instance
 */
function getPool() {
  if (!pool) {
    return initializePool();
  }
  return pool;
}

/**
 * Execute a query
 */
async function query(text, params) {
  const client = getPool();
  if (!client) {
    throw new Error('Database not initialized');
  }

  const start = Date.now();
  try {
    const result = await client.query(text, params);
    const duration = Date.now() - start;
    logger.debug('Executed query', { text, duration, rows: result.rowCount });
    return result;
  } catch (error) {
    logger.error('Query error', { text, error: error.message });
    throw error;
  }
}

/**
 * Get a client from the pool for transactions
 */
async function getClient() {
  const client = getPool();
  if (!client) {
    throw new Error('Database not initialized');
  }
  return await client.connect();
}

/**
 * Test database connection
 */
async function testConnection() {
  try {
    const result = await query('SELECT NOW()');
    logger.info('Database connection test successful', { 
      timestamp: result.rows[0].now 
    });
    return true;
  } catch (error) {
    logger.error('Database connection test failed', { 
      error: error.message,
      stack: error.stack,
      code: error.code 
    });
    return false;
  }
}

/**
 * Close database pool
 */
async function closePool() {
  if (pool) {
    await pool.end();
    pool = null;
    logger.info('Database pool closed');
  }
}

module.exports = {
  initializePool,
  getPool,
  query,
  getClient,
  testConnection,
  closePool,
};
