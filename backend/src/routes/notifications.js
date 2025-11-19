const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const { verifyToken } = require('../middleware/auth');
const { query } = require('../db');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * NOTIFICATIONS API
 * Manages user notifications (likes, comments, follows, achievements, etc.)
 */

/**
 * @route   GET /api/notifications
 * @desc    Get user's notifications
 * @access  Private
 */
router.get('/', verifyToken, asyncHandler(async (req, res) => {
  const { page = 1, limit = 50, unreadOnly = 'false', type } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);
  const userWallet = req.user.walletAddress;

  let queryText = `
    SELECT 
      n.id, n.user_wallet, n.type, n.title, n.message, n.data,
      n.is_read, n.action_url, n.created_at,
      n.sender_wallet,
      sender_p.username as sender_username,
      sender_p.display_name as sender_display_name,
      sender_p.avatar_url as sender_avatar
    FROM notifications n
    LEFT JOIN profiles sender_p ON n.sender_wallet = sender_p.wallet_address
    WHERE n.user_wallet = $1
  `;
  
  const queryParams = [userWallet];
  let paramCount = 2;

  if (unreadOnly === 'true') {
    queryText += ` AND n.is_read = false`;
  }

  if (type) {
    queryText += ` AND n.type = $${paramCount++}`;
    queryParams.push(type);
  }

  queryText += ` ORDER BY n.created_at DESC LIMIT $${paramCount++} OFFSET $${paramCount++}`;
  queryParams.push(parseInt(limit), offset);

  const result = await query(queryText, queryParams);

  const notifications = result.rows.map(row => ({
    id: row.id,
    type: row.type,
    title: row.title,
    message: row.message,
    data: row.data || {},
    isRead: row.is_read,
    actionUrl: row.action_url,
    sender: row.sender_wallet ? {
      walletAddress: row.sender_wallet,
      username: row.sender_username,
      displayName: row.sender_display_name,
      avatar: row.sender_avatar
    } : null,
    createdAt: row.created_at
  }));

  res.json({
    success: true,
    count: notifications.length,
    page: parseInt(page),
    data: notifications
  });
}));

/**
 * @route   GET /api/notifications/unread-count
 * @desc    Get count of unread notifications
 * @access  Private
 */
router.get('/unread-count', verifyToken, asyncHandler(async (req, res) => {
  const userWallet = req.user.walletAddress;

  const result = await query(
    `SELECT COUNT(*) as unread_count 
     FROM notifications 
     WHERE user_wallet = $1 AND is_read = false`,
    [userWallet]
  );

  res.json({
    success: true,
    unreadCount: parseInt(result.rows[0].unread_count)
  });
}));

/**
 * @route   POST /api/notifications
 * @desc    Create notification (internal use or system notifications)
 * @access  Private
 */
router.post('/', verifyToken, asyncHandler(async (req, res) => {
  const { 
    targetWallet, 
    type, 
    title, 
    message, 
    data, 
    actionUrl 
  } = req.body;
  const senderWallet = req.user.walletAddress;

  if (!targetWallet || !type || !title || !message) {
    return res.status(400).json({
      success: false,
      error: 'Missing required fields: targetWallet, type, title, message'
    });
  }

  const result = await query(
    `INSERT INTO notifications (user_wallet, sender_wallet, type, title, message, data, action_url)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [targetWallet, senderWallet, type, title, message, data || {}, actionUrl]
  );

  const notification = result.rows[0];

  // Emit WebSocket event if available
  const io = req.app.get('io');
  if (io) {
    io.to(`user:${(targetWallet || '').toString()}`).emit('notification:new', {
      id: notification.id,
      type: notification.type,
      title: notification.title,
      message: notification.message,
      data: notification.data,
      createdAt: notification.created_at
    });
  }

  logger.info(`Notification created: ${notification.id} for user ${targetWallet}`);

  res.status(201).json({
    success: true,
    message: 'Notification created successfully',
    data: notification
  });
}));

/**
 * @route   PUT /api/notifications/:id/read
 * @desc    Mark notification as read
 * @access  Private
 */
router.put('/:id/read', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userWallet = req.user.walletAddress;

  const result = await query(
    `UPDATE notifications 
     SET is_read = true, updated_at = CURRENT_TIMESTAMP
     WHERE id = $1 AND user_wallet = $2
     RETURNING *`,
    [id, userWallet]
  );

  if (result.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Notification not found'
    });
  }

  res.json({
    success: true,
    message: 'Notification marked as read'
  });
}));

/**
 * @route   PUT /api/notifications/read-all
 * @desc    Mark all notifications as read
 * @access  Private
 */
router.put('/read-all', verifyToken, asyncHandler(async (req, res) => {
  const userWallet = req.user.walletAddress;

  await query(
    `UPDATE notifications 
     SET is_read = true, updated_at = CURRENT_TIMESTAMP
     WHERE user_wallet = $1 AND is_read = false`,
    [userWallet]
  );

  res.json({
    success: true,
    message: 'All notifications marked as read'
  });
}));

/**
 * @route   DELETE /api/notifications/:id
 * @desc    Delete notification
 * @access  Private
 */
router.delete('/:id', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userWallet = req.user.walletAddress;

  const result = await query(
    `DELETE FROM notifications WHERE id = $1 AND user_wallet = $2`,
    [id, userWallet]
  );

  if (result.rowCount === 0) {
    return res.status(404).json({
      success: false,
      error: 'Notification not found'
    });
  }

  res.json({
    success: true,
    message: 'Notification deleted successfully'
  });
}));

/**
 * @route   DELETE /api/notifications
 * @desc    Delete all notifications (or filtered)
 * @access  Private
 */
router.delete('/', verifyToken, asyncHandler(async (req, res) => {
  const { readOnly = 'false', type } = req.query;
  const userWallet = req.user.walletAddress;

  let queryText = `DELETE FROM notifications WHERE user_wallet = $1`;
  const queryParams = [userWallet];
  let paramCount = 2;

  if (readOnly === 'true') {
    queryText += ` AND is_read = true`;
  }

  if (type) {
    queryText += ` AND type = $${paramCount++}`;
    queryParams.push(type);
  }

  const result = await query(queryText, queryParams);

  res.json({
    success: true,
    message: `${result.rowCount} notification(s) deleted successfully`,
    deletedCount: result.rowCount
  });
}));

/**
 * NOTIFICATION HELPER FUNCTIONS
 * Used by other routes to create notifications
 */

/**
 * Create a like notification
 */
async function createLikeNotification(targetWallet, senderWallet, targetType, targetId, io = null) {
  try {
    const profileResult = await query(
      `SELECT display_name, username FROM profiles WHERE wallet_address = $1`,
      [senderWallet]
    );
    
    const senderName = profileResult.rows.length > 0 
      ? (profileResult.rows[0].display_name || profileResult.rows[0].username)
      : 'Someone';

    let message = '';
    let actionUrl = '';

    if (targetType === 'post') {
      message = `${senderName} liked your post`;
      actionUrl = `/community/posts/${targetId}`;
    } else if (targetType === 'comment') {
      message = `${senderName} liked your comment`;
      actionUrl = `/community/comments/${targetId}`;
    } else if (targetType === 'artwork') {
      message = `${senderName} liked your artwork`;
      actionUrl = `/artworks/${targetId}`;
    }

    await query(
      `INSERT INTO notifications (user_wallet, sender_wallet, type, title, message, action_url, data)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT DO NOTHING`,
      [
        targetWallet,
        senderWallet,
        'like',
        'New Like',
        message,
        actionUrl,
        { targetType, targetId }
      ]
    );
    // Emit WebSocket event if io provided
    try {
      if (io) {
        io.to(`user:${(targetWallet || '').toString()}`).emit('notification:new', {
          type: 'like',
          title: 'New Like',
          message,
          data: { targetType, targetId },
          createdAt: new Date().toISOString(),
        });
      }
    } catch (err) {
      logger.warn('createLikeNotification: failed to emit socket event', err.message);
    }
  } catch (error) {
    logger.error('Error creating like notification:', error);
  }
}

/**
 * Create a comment notification
 */
async function createCommentNotification(targetWallet, senderWallet, postId, commentContent, io = null) {
  try {
    const profileResult = await query(
      `SELECT display_name, username FROM profiles WHERE wallet_address = $1`,
      [senderWallet]
    );
    
    const senderName = profileResult.rows.length > 0 
      ? (profileResult.rows[0].display_name || profileResult.rows[0].username)
      : 'Someone';

    await query(
      `INSERT INTO notifications (user_wallet, sender_wallet, type, title, message, action_url, data)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        targetWallet,
        senderWallet,
        'comment',
        'New Comment',
        `${senderName} commented on your post`,
        `/community/posts/${postId}`,
        { postId, commentPreview: commentContent.substring(0, 100) }
      ]
    );
    // Emit WebSocket event if io provided
    try {
      if (io) {
        io.to(`user:${(targetWallet || '').toString()}`).emit('notification:new', {
          type: 'comment',
          title: 'New Comment',
          message: `${senderName} commented on your post`,
          data: { postId, commentPreview: commentContent.substring(0, 100) },
          createdAt: new Date().toISOString(),
        });
      }
    } catch (err) {
      logger.warn('createCommentNotification: failed to emit socket event', err.message);
    }
  } catch (error) {
    logger.error('Error creating comment notification:', error);
  }
}

/**
 * Create a follow notification
 */
async function createFollowNotification(targetWallet, senderWallet, io = null) {
  try {
    const profileResult = await query(
      `SELECT display_name, username FROM profiles WHERE wallet_address = $1`,
      [senderWallet]
    );
    
    const senderName = profileResult.rows.length > 0 
      ? (profileResult.rows[0].display_name || profileResult.rows[0].username)
      : 'Someone';

    await query(
      `INSERT INTO notifications (user_wallet, sender_wallet, type, title, message, action_url, data)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        targetWallet,
        senderWallet,
        'follow',
        'New Follower',
        `${senderName} started following you`,
        `/profile/${senderWallet}`,
        { followerWallet: senderWallet }
      ]
    );
    // Emit WebSocket event if io provided
    try {
      if (io) {
        io.to(`user:${(targetWallet || '').toString()}`).emit('notification:new', {
          type: 'follow',
          title: 'New Follower',
          message: `${senderName} started following you`,
          data: { followerWallet: senderWallet },
          createdAt: new Date().toISOString(),
        });
      }
    } catch (err) {
      logger.warn('createFollowNotification: failed to emit socket event', err.message);
    }
  } catch (error) {
    logger.error('Error creating follow notification:', error);
  }
}

/**
 * Create a share notification
 */
async function createShareNotification(targetWallet, senderWallet, postId, io = null) {
  try {
    const profileResult = await query(
      `SELECT display_name, username FROM profiles WHERE wallet_address = $1`,
      [senderWallet]
    );

    const senderName = profileResult.rows.length > 0
      ? (profileResult.rows[0].display_name || profileResult.rows[0].username)
      : 'Someone';

    const message = `${senderName} shared your post`;
    const actionUrl = `/community/posts/${postId}`;

    await query(
      `INSERT INTO notifications (user_wallet, sender_wallet, type, title, message, action_url, data)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        targetWallet,
        senderWallet,
        'share',
        'New Share',
        message,
        actionUrl,
        { postId }
      ]
    );

    try {
      if (io) {
        io.to(`user:${(targetWallet || '').toString()}`).emit('notification:new', {
          type: 'share',
          title: 'New Share',
          message,
          data: { postId },
          createdAt: new Date().toISOString(),
        });
      }
    } catch (err) {
      logger.warn('createShareNotification: failed to emit socket event', err.message);
    }
  } catch (error) {
    logger.error('Error creating share notification:', error);
  }
}

/**
 * Create an achievement notification
 */
async function createAchievementNotification(userWallet, achievementId, achievementTitle, tokenReward) {
  try {
    await query(
      `INSERT INTO notifications (user_wallet, type, title, message, action_url, data)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        userWallet,
        'achievement',
        'Achievement Unlocked!',
        `You've unlocked "${achievementTitle}" and earned ${tokenReward} KUB8 tokens!`,
        '/achievements',
        { achievementId, tokenReward }
      ]
    );
  } catch (error) {
    logger.error('Error creating achievement notification:', error);
  }
}

module.exports = router;
module.exports.createLikeNotification = createLikeNotification;
module.exports.createCommentNotification = createCommentNotification;
module.exports.createFollowNotification = createFollowNotification;
module.exports.createShareNotification = createShareNotification;
module.exports.createAchievementNotification = createAchievementNotification;
