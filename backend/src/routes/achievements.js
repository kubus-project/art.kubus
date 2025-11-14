const express = require('express');
const router = express.Router();
const { query } = require('../db');
const { asyncHandler } = require('../middleware/errorHandler');
const { verifyToken } = require('../middleware/auth');
const logger = require('../utils/logger');

/**
 * GET /api/achievements
 * Get all available achievements
 */
router.get('/', asyncHandler(async (req, res) => {
  const result = await query(
    `SELECT id, code as type, name as title, description, reward_kub8 as token_reward, 
            is_poap, event_id, requirement_value as required_count, icon_url as icon, 
            rarity, requirement_type, created_at
     FROM achievements
     ORDER BY rarity DESC, reward_kub8 DESC`
  );

  res.json({
    success: true,
    achievements: result.rows,
    count: result.rows.length
  });
}));

/**
 * GET /api/achievements/user/:walletAddress
 * Get user's unlocked achievements and progress
 */
router.get('/user/:walletAddress', asyncHandler(async (req, res) => {
  const { walletAddress } = req.params;

  // Get unlocked achievements
  const unlockedResult = await query(
    `SELECT ua.id, ua.achievement_id, ua.unlocked_at, ua.event_data,
            a.code as type, a.name as title, a.description, a.reward_kub8 as token_reward, 
            a.is_poap, a.icon_url as icon, a.rarity
     FROM user_achievements ua
     JOIN achievements a ON ua.achievement_id = a.id
     WHERE ua.wallet_address = $1
     ORDER BY ua.unlocked_at DESC`,
    [walletAddress]
  );

  // Get achievement progress
  const progressResult = await query(
    `SELECT achievement_id, current_progress, is_completed, completed_at
     FROM achievement_progress
     WHERE wallet_address = $1`,
    [walletAddress]
  );

  // Get total earned tokens
  const tokenResult = await query(
    `SELECT COALESCE(SUM(a.reward_kub8), 0) as total_tokens
     FROM user_achievements ua
     JOIN achievements a ON ua.achievement_id = a.id
     WHERE ua.wallet_address = $1`,
    [walletAddress]
  );

  res.json({
    success: true,
    unlocked: unlockedResult.rows,
    progress: progressResult.rows,
    totalTokens: parseInt(tokenResult.rows[0]?.total_tokens || 0),
    count: unlockedResult.rows.length
  });
}));

/**
 * POST /api/achievements/unlock
 * Unlock an achievement for a user (requires auth)
 */
router.post('/unlock', verifyToken, asyncHandler(async (req, res) => {
  const { achievementType, data } = req.body;
  const walletAddress = req.user.walletAddress;

  // Get achievement definition
  const achievementResult = await query(
    'SELECT * FROM achievements WHERE code = $1',
    [achievementType]
  );

  if (achievementResult.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Achievement not found'
    });
  }

  const achievement = achievementResult.rows[0];

  // Check if already unlocked
  const existingResult = await query(
    'SELECT id FROM user_achievements WHERE wallet_address = $1 AND achievement_id = $2',
    [walletAddress, achievement.id]
  );

  if (existingResult.rows.length > 0) {
    return res.status(400).json({
      success: false,
      error: 'Achievement already unlocked'
    });
  }

  // Unlock achievement
  const unlockResult = await query(
    `INSERT INTO user_achievements (wallet_address, achievement_id, event_data)
     VALUES ($1, $2, $3)
     RETURNING id, unlocked_at`,
    [walletAddress, achievement.id, JSON.stringify(data || {})]
  );

  // Update achievement progress to completed
  await query(
    `INSERT INTO achievement_progress (wallet_address, achievement_id, current_progress, is_completed, completed_at)
     VALUES ($1, $2, $3, true, NOW())
     ON CONFLICT (wallet_address, achievement_id)
     DO UPDATE SET current_progress = $3, is_completed = true, completed_at = NOW()`,
    [walletAddress, achievement.id, achievement.requirement_value]
  );

  logger.info(`Achievement unlocked: ${achievement.title} for wallet ${walletAddress}`);

  res.json({
    success: true,
    achievement: {
      id: unlockResult.rows[0].id,
      type: achievement.code,
      title: achievement.name,
      description: achievement.description,
      tokenReward: achievement.reward_kub8,
      isPOAP: achievement.is_poap,
      icon: achievement.icon_url,
      rarity: achievement.rarity,
      unlockedAt: unlockResult.rows[0].unlocked_at
    }
  });
}));

/**
 * POST /api/achievements/progress
 * Update achievement progress for a user (requires auth)
 */
router.post('/progress', verifyToken, asyncHandler(async (req, res) => {
  const { achievementId, progress } = req.body;
  const walletAddress = req.user.walletAddress;

  if (!achievementId || progress === undefined) {
    return res.status(400).json({
      success: false,
      error: 'Achievement ID and progress are required'
    });
  }

  // Get achievement required count
  const achievementResult = await query(
    'SELECT requirement_value FROM achievements WHERE id = $1',
    [achievementId]
  );

  if (achievementResult.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Achievement not found'
    });
  }

  const requiredCount = achievementResult.rows[0].requirement_value;
  const isCompleted = progress >= requiredCount;

  // Update or insert progress
  const result = await query(
    `INSERT INTO achievement_progress (wallet_address, achievement_id, current_progress, is_completed, completed_at)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (wallet_address, achievement_id)
     DO UPDATE SET 
       current_progress = $3,
       is_completed = $4,
       completed_at = CASE WHEN $4 THEN NOW() ELSE achievement_progress.completed_at END
     RETURNING *`,
    [walletAddress, achievementId, progress, isCompleted, isCompleted ? new Date() : null]
  );

  res.json({
    success: true,
    progress: result.rows[0]
  });
}));

/**
 * GET /api/achievements/stats/:walletAddress
 * Get achievement statistics for a user
 */
router.get('/stats/:walletAddress', asyncHandler(async (req, res) => {
  const { walletAddress } = req.params;

  // Get total achievements
  const totalResult = await query('SELECT COUNT(*) as total FROM achievements');

  // Get unlocked count
  const unlockedResult = await query(
    'SELECT COUNT(*) as unlocked FROM user_achievements WHERE wallet_address = $1',
    [walletAddress]
  );

  // Get total tokens earned
  const tokensResult = await query(
    `SELECT COALESCE(SUM(a.token_reward), 0) as total_tokens
     FROM user_achievements ua
     JOIN achievements a ON ua.achievement_id = a.id
     WHERE ua.wallet_address = $1`,
    [walletAddress]
  );

  // Get achievements by rarity
  const rarityResult = await query(
    `SELECT a.rarity, COUNT(*) as count
     FROM user_achievements ua
     JOIN achievements a ON ua.achievement_id = a.id
     WHERE ua.wallet_address = $1
     GROUP BY a.rarity`,
    [walletAddress]
  );

  // Get recent achievements
  const recentResult = await query(
    `SELECT ua.unlocked_at, a.name as title, a.icon_url as icon, a.rarity, a.reward_kub8 as token_reward
     FROM user_achievements ua
     JOIN achievements a ON ua.achievement_id = a.id
     WHERE ua.wallet_address = $1
     ORDER BY ua.unlocked_at DESC
     LIMIT 5`,
    [walletAddress]
  );

  res.json({
    success: true,
    stats: {
      total: parseInt(totalResult.rows[0].total),
      unlocked: parseInt(unlockedResult.rows[0].unlocked),
      totalTokens: parseInt(tokensResult.rows[0].total_tokens),
      byRarity: rarityResult.rows,
      recent: recentResult.rows
    }
  });
}));

/**
 * GET /api/achievements/leaderboard
 * Get achievement leaderboard
 */
router.get('/leaderboard', asyncHandler(async (req, res) => {
  const { limit = 10, type = 'tokens' } = req.query;

  let orderBy = 'total_tokens DESC';
  if (type === 'count') {
    orderBy = 'achievement_count DESC';
  }

  const result = await query(
    `SELECT 
       ua.wallet_address,
       p.username,
       p.avatar_url,
       COUNT(ua.id) as achievement_count,
       COALESCE(SUM(a.reward_kub8), 0) as total_tokens
     FROM user_achievements ua
     JOIN achievements a ON ua.achievement_id = a.id
     LEFT JOIN profiles p ON ua.wallet_address = p.wallet_address
     GROUP BY ua.wallet_address, p.username, p.avatar_url
     ORDER BY ${orderBy}
     LIMIT $1`,
    [parseInt(limit)]
  );

  res.json({
    success: true,
    leaderboard: result.rows,
    count: result.rows.length
  });
}));

module.exports = router;
