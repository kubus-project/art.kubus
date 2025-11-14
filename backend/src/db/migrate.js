#!/usr/bin/env node

/**
 * Database Migration Script
 * Run with: npm run migrate
 * 
 * This script will:
 * 1. Create database if it doesn't exist
 * 2. Run all SQL migrations
 * 3. Set up initial data
 */

require('dotenv').config();
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

// Parse database URL
function parseDatabaseUrl(url) {
  const regex = /postgresql:\/\/([^:]+):([^@]+)@([^:]+):(\d+)\/(.+)/;
  const match = url.match(regex);
  
  if (!match) {
    throw new Error('Invalid DATABASE_URL format');
  }
  
  return {
    user: match[1],
    password: match[2],
    host: match[3],
    port: parseInt(match[4]),
    database: match[5],
  };
}

async function createDatabase() {
  const databaseUrl = process.env.DATABASE_URL;
  
  if (!databaseUrl) {
    throw new Error('DATABASE_URL environment variable is not set');
  }

  const config = parseDatabaseUrl(databaseUrl);
  const dbName = config.database;
  
  // Connect to postgres database to create our database
  const client = new Client({
    user: config.user,
    password: config.password,
    host: config.host,
    port: config.port,
    database: 'postgres', // Connect to default database
  });

  try {
    await client.connect();
    logger.info('Connected to PostgreSQL server');

    // Check if database exists
    const result = await client.query(
      `SELECT 1 FROM pg_database WHERE datname = $1`,
      [dbName]
    );

    if (result.rows.length === 0) {
      logger.info(`Creating database: ${dbName}`);
      await client.query(`CREATE DATABASE ${dbName}`);
      logger.info(`Database ${dbName} created successfully`);
    } else {
      logger.info(`Database ${dbName} already exists`);
    }
  } catch (error) {
    logger.error('Error creating database', { error: error.message });
    throw error;
  } finally {
    await client.end();
  }
}

async function runMigrations() {
  const databaseUrl = process.env.DATABASE_URL;
  const config = parseDatabaseUrl(databaseUrl);

  // Connect to our application database
  const client = new Client(config);

  try {
    await client.connect();
    logger.info(`Connected to database: ${config.database}`);

    // Read and execute schema.sql
    const schemaPath = path.join(__dirname, 'schema.sql');
    const schemaSql = fs.readFileSync(schemaPath, 'utf8');

    logger.info('Running database migrations...');
    await client.query(schemaSql);
    logger.info('Database migrations completed successfully');

    // Verify tables were created
    const tablesResult = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    `);

    logger.info('Created tables:', {
      count: tablesResult.rows.length,
      tables: tablesResult.rows.map(r => r.table_name),
    });

  } catch (error) {
    logger.error('Migration failed', { error: error.message });
    throw error;
  } finally {
    await client.end();
  }
}

async function verifySetup() {
  const databaseUrl = process.env.DATABASE_URL;
  const config = parseDatabaseUrl(databaseUrl);

  const client = new Client(config);

  try {
    await client.connect();

    // Check critical tables
    const criticalTables = ['users', 'profiles', 'artworks', 'ar_markers', 'community_posts'];
    
    for (const table of criticalTables) {
      const result = await client.query(`
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = $1
      `, [table]);
      
      if (result.rows[0].count === '0') {
        throw new Error(`Critical table ${table} not found`);
      }
    }

    // Check achievements
    const achievementsResult = await client.query('SELECT COUNT(*) FROM achievements');
    logger.info(`Achievements initialized: ${achievementsResult.rows[0].count} achievements`);

    logger.info('✅ Database setup verification passed');
    
  } catch (error) {
    logger.error('Database verification failed', { error: error.message });
    throw error;
  } finally {
    await client.end();
  }
}

async function main() {
  try {
    logger.info('🚀 Starting database migration...');
    logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
    
    // Step 1: Create database if needed
    await createDatabase();
    
    // Step 2: Run migrations
    await runMigrations();
    
    // Step 3: Verify setup
    await verifySetup();
    
    logger.info('✅ Database migration completed successfully');
    process.exit(0);
    
  } catch (error) {
    logger.error('❌ Database migration failed', { error: error.message });
    console.error(error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { createDatabase, runMigrations, verifySetup };
