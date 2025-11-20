const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const { verifyToken, optionalAuth } = require('../middleware/auth');
const { communityValidation, sanitizeInput } = require('../middleware/validation');
const { query } = require('../db');
const logger = require('../utils/logger');
const { normalizeAvatarUrl } = require('../utils/avatar');
const notifications = require('./notifications');

const router = express.Router();

/**
 * COMMUNITY API - Full Database Integration
 * Handles posts, comments, likes, shares, and follows
 */

// ============================================
// POSTS ENDPOINTS
// ============================================

/**
 * @route   GET /api/community/posts
 * @desc    Get community posts with pagination
 * @access  Public
 */
router.get('/posts', optionalAuth, asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, arOnly, authorWallet } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);

  let queryText = `
    SELECT 
      cp.id, cp.wallet_address, cp.content, cp.media_urls, cp.media_cids,
      cp.artwork_id, cp.post_type, cp.likes_count, cp.comments_count, 
      cp.shares_count, cp.views_count, cp.created_at, cp.updated_at,
      p.username, p.display_name, p.avatar_url,
      a.title as artwork_title, a.image_url as artwork_image
    FROM community_posts cp
    LEFT JOIN profiles p ON cp.wallet_address = p.wallet_address
    LEFT JOIN artworks a ON cp.artwork_id = a.id
    WHERE cp.is_public = true
  `;
  
  const queryParams = [];
  let paramCount = 1;

  if (arOnly === 'true') {
    queryText += ` AND cp.artwork_id IS NOT NULL`;
  }

  if (authorWallet) {
    queryText += ` AND cp.wallet_address = $${paramCount++}`;
    queryParams.push(authorWallet);
  }

  queryText += ` ORDER BY cp.created_at DESC LIMIT $${paramCount++} OFFSET $${paramCount++}`;
  queryParams.push(parseInt(limit), offset);

  const result = await query(queryText, queryParams);

  const postsData = result.rows.map(row => ({
    id: row.id,
    walletAddress: row.wallet_address,
    content: row.content,
    mediaUrls: row.media_urls || [],
    mediaCids: row.media_cids || [],
    artworkId: row.artwork_id,
    postType: row.post_type,
    author: {
      walletAddress: row.wallet_address,
      username: row.username,
      displayName: row.display_name,
      avatar: normalizeAvatarUrl(row.avatar_url)
    },
    artwork: row.artwork_id ? {
      id: row.artwork_id,
      title: row.artwork_title,
      imageUrl: row.artwork_image
    } : null,
    stats: {
      likes: row.likes_count,
      comments: row.comments_count,
      shares: row.shares_count,
      views: row.views_count
    },
    createdAt: row.created_at,
    updatedAt: row.updated_at
  }));

  // Get total count
  const countResult = await query(
    `SELECT COUNT(*) FROM community_posts WHERE is_public = true ${authorWallet ? 'AND wallet_address = $1' : ''}`,
    authorWallet ? [authorWallet] : []
  );

  res.json({
    success: true,
    count: postsData.length,
    total: parseInt(countResult.rows[0].count),
    page: parseInt(page),
    data: postsData,
  });
}));

/**
 * @route   GET /api/community/posts/:id
 * @desc    Get single post by ID
 * @access  Public
 */
router.get('/posts/:id', optionalAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;

  const result = await query(
    `SELECT 
      cp.id, cp.wallet_address, cp.content, cp.media_urls, cp.media_cids,
      cp.artwork_id, cp.post_type, cp.likes_count, cp.comments_count, 
      cp.shares_count, cp.views_count, cp.created_at, cp.updated_at,
      p.username, p.display_name, p.avatar_url,
      a.title as artwork_title, a.image_url as artwork_image
    FROM community_posts cp
    LEFT JOIN profiles p ON cp.wallet_address = p.wallet_address
    LEFT JOIN artworks a ON cp.artwork_id = a.id
    WHERE cp.id = $1`,
    [id]
  );

  if (result.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Post not found'
    });
  }

  const row = result.rows[0];
  const post = {
    id: row.id,
    walletAddress: row.wallet_address,
    content: row.content,
    mediaUrls: row.media_urls || [],
    mediaCids: row.media_cids || [],
    artworkId: row.artwork_id,
    postType: row.post_type,
    author: {
      walletAddress: row.wallet_address,
      username: row.username,
      displayName: row.display_name,
      avatar: normalizeAvatarUrl(row.avatar_url)
    },
    artwork: row.artwork_id ? {
      id: row.artwork_id,
      title: row.artwork_title,
      imageUrl: row.artwork_image
    } : null,
    stats: {
      likes: row.likes_count,
      comments: row.comments_count,
      shares: row.shares_count,
      views: row.views_count
    },
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };

  // Increment view count
  await query(
    `UPDATE community_posts SET views_count = views_count + 1 WHERE id = $1`,
    [id]
  );

  res.json({
    success: true,
    data: post
  });
}));

/**
 * @route   POST /api/community/posts
 * @desc    Create community post
 * @access  Private
 */
router.post(
  '/posts',
  verifyToken,
  sanitizeInput,
  asyncHandler(async (req, res) => {
    const { content, mediaUrls, mediaCids, artworkId, postType = 'text' } = req.body;
    const walletAddress = req.user.walletAddress;

    if (!content || content.trim().length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Content is required'
      });
    }

    const result = await query(
      `INSERT INTO community_posts (
        wallet_address, content, media_urls, media_cids, 
        artwork_id, post_type
      ) VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *`,
      [
        walletAddress,
        content,
        mediaUrls || [],
        mediaCids || [],
        artworkId || null,
        postType
      ]
    );

    const post = result.rows[0];

    // Get author profile
    const profileResult = await query(
      `SELECT username, display_name, avatar_url FROM profiles WHERE wallet_address = $1`,
      [walletAddress]
    );

    const postData = {
      id: post.id,
      walletAddress: post.wallet_address,
      content: post.content,
      mediaUrls: post.media_urls || [],
      mediaCids: post.media_cids || [],
      artworkId: post.artwork_id,
      postType: post.post_type,
      author: profileResult.rows[0] || { walletAddress },
      stats: {
        likes: 0,
        comments: 0,
        shares: 0,
        views: 0
      },
      createdAt: post.created_at
    };

    // Emit WebSocket event if available
    const io = req.app.get('io');
    if (io) io.emit('community:new_post', postData);

    logger.info(`Community post created: ${post.id} by ${walletAddress}`);

    res.status(201).json({
      success: true,
      message: 'Post created successfully',
      data: postData,
    });
  })
);

/**
 * @route   PUT /api/community/posts/:id
 * @desc    Update post
 * @access  Private (author only)
 */
router.put('/posts/:id', verifyToken, sanitizeInput, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { content, mediaUrls, mediaCids } = req.body;
  const walletAddress = req.user.walletAddress;

  // Check ownership
  const checkResult = await query(
    `SELECT wallet_address FROM community_posts WHERE id = $1`,
    [id]
  );

  if (checkResult.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'Post not found' });
  }

  if (checkResult.rows[0].wallet_address !== walletAddress) {
    return res.status(403).json({ success: false, error: 'Not authorized' });
  }

  const result = await query(
    `UPDATE community_posts 
     SET content = $1, media_urls = $2, media_cids = $3, updated_at = CURRENT_TIMESTAMP
     WHERE id = $4
     RETURNING *`,
    [content, mediaUrls || [], mediaCids || [], id]
  );

  res.json({
    success: true,
    message: 'Post updated successfully',
    data: result.rows[0]
  });
}));

/**
 * @route   DELETE /api/community/posts/:id
 * @desc    Delete post
 * @access  Private (author only)
 */
router.delete('/posts/:id', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const walletAddress = req.user.walletAddress;

  const checkResult = await query(
    `SELECT wallet_address FROM community_posts WHERE id = $1`,
    [id]
  );

  if (checkResult.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'Post not found' });
  }

  if (checkResult.rows[0].wallet_address !== walletAddress) {
    return res.status(403).json({ success: false, error: 'Not authorized' });
  }

  await query(`DELETE FROM community_posts WHERE id = $1`, [id]);

  logger.info(`Post deleted: ${id}`);

  res.json({
    success: true,
    message: 'Post deleted successfully'
  });
}));

// ============================================
// LIKES ENDPOINTS
// ============================================

/**
 * @route   POST /api/community/posts/:id/like
 * @desc    Like a post
 * @access  Private
 */
router.post('/posts/:id/like', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id;
  const senderWallet = req.user.walletAddress;

  // Check if post exists
  const postCheck = await query(
    `SELECT id FROM community_posts WHERE id = $1`,
    [id]
  );

  if (postCheck.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'Post not found' });
  }

  // Insert like (will fail if already liked due to unique constraint)
  try {
    await query(
      `INSERT INTO likes (user_id, target_type, target_id)
       VALUES ($1, 'post', $2)
       ON CONFLICT (user_id, target_type, target_id) DO NOTHING`,
      [userId, id]
    );

    // Update post likes count
    await query(
      `UPDATE community_posts 
       SET likes_count = (SELECT COUNT(*) FROM likes WHERE target_type = 'post' AND target_id = $1)
       WHERE id = $1`,
      [id]
    );

    res.json({
      success: true,
      message: 'Post liked successfully'
    });
      // Create a notification for the post author
      try {
        const postOwner = await query('SELECT wallet_address FROM community_posts WHERE id = $1', [id]);
        if (postOwner.rows.length > 0) {
          const targetWallet = postOwner.rows[0].wallet_address;
          if (targetWallet && targetWallet.toLowerCase() !== (senderWallet || '').toLowerCase()) {
            await notifications.createLikeNotification(targetWallet, senderWallet, 'post', id, req.app.get('io'));
          }
        }
      } catch (e) {
        logger.warn('Could not create like notification', e.message);
      }
  } catch (error) {
    logger.error('Error liking post:', error);
    res.status(500).json({ success: false, error: 'Failed to like post' });
  }
}));

/**
 * @route   DELETE /api/community/posts/:id/like
 * @desc    Unlike a post
 * @access  Private
 */
router.delete('/posts/:id/like', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id;

  await query(
    `DELETE FROM likes WHERE user_id = $1 AND target_type = 'post' AND target_id = $2`,
    [userId, id]
  );

  // Update post likes count
  await query(
    `UPDATE community_posts 
     SET likes_count = (SELECT COUNT(*) FROM likes WHERE target_type = 'post' AND target_id = $1)
     WHERE id = $1`,
    [id]
  );

  res.json({
    success: true,
    message: 'Post unliked successfully'
  });
}));

/**
 * @route   POST /api/community/posts/:id/share
 * @desc    Share a post
 * @access  Private
 */
router.post('/posts/:id/share', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;

  const senderWallet = req.user.walletAddress;

  await query(
    `UPDATE community_posts SET shares_count = shares_count + 1 WHERE id = $1`,
    [id]
  );

  res.json({
    success: true,
    message: 'Post shared successfully'
  });
  // Create share notification for the post author
  try {
    const postOwner = await query('SELECT wallet_address FROM community_posts WHERE id = $1', [id]);
    if (postOwner.rows.length > 0) {
      const targetWallet = postOwner.rows[0].wallet_address;
      if (targetWallet && targetWallet.toLowerCase() !== (senderWallet || '').toLowerCase()) {
        await notifications.createShareNotification(targetWallet, senderWallet, id, req.app.get('io'));
      }
    }
  } catch (e) {
    logger.warn('Could not create share notification', e.message);
  }
}));

// ============================================
// COMMENTS ENDPOINTS
// ============================================

/**
 * @route   GET /api/community/posts/:id/comments
 * @desc    Get comments for a post
 * @access  Public
 */
router.get('/posts/:id/comments', optionalAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { limit = 50, offset = 0 } = req.query;

  const currentUserId = req.user ? req.user.id : null;
  
  // Debug: Log the raw query to see what we're actually selecting
  logger.info(`GET comments - Fetching for post ${id}, currentUserId: ${currentUserId}`);
  
  const result = await query(
    `SELECT 
      c.id, c.content, c.likes_count, c.created_at, c.updated_at,
      c.parent_comment_id, c.author_id,
      u.wallet_address,
      COALESCE(p.username, u.username) as username,
      COALESCE(p.display_name, u.username) as display_name,
      p.avatar_url,
      c.author_name, c.author_avatar
      , (CASE WHEN $4::uuid IS NULL THEN FALSE ELSE EXISTS(SELECT 1 FROM likes WHERE user_id = $4::uuid AND target_type = 'comment' AND target_id = c.id) END) as is_liked
    FROM comments c
    LEFT JOIN users u ON c.author_id = u.id
    LEFT JOIN profiles p ON u.wallet_address = p.wallet_address OR p.user_id = u.id
    WHERE c.post_id = $1
    ORDER BY c.created_at ASC
    LIMIT $2 OFFSET $3`,
    [id, parseInt(limit), parseInt(offset), currentUserId]
  );
  
  // Debug: Log first row to see what JOIN returned
  if (result.rows.length > 0) {
    const firstRow = result.rows[0];
    logger.info(`GET comments - First row: author_id=${firstRow.author_id}, u.wallet_address=${firstRow.wallet_address}, display_name=${firstRow.display_name}, author_name=${firstRow.author_name}`);
  }

  const comments = result.rows.map(row => {
    // Prioritize profile data, fallback to snapshotted author data, then defaults
    const walletAddress = row.wallet_address;
    const displayName = row.display_name || row.author_name || row.username || 'User';
    const username = row.username || row.author_name || (walletAddress ? walletAddress.substring(0, 8) : null);
    let avatar = normalizeAvatarUrl(row.avatar_url || row.author_avatar);
    
    // If no avatar, generate a DiceBear fallback URL
    if (!avatar) {
      const avatarSeed = walletAddress || username || displayName || row.author_id || 'anonymous';
      // Return a relative path that will be normalized by the client or use the avatar proxy endpoint
      avatar = `/api/avatar/${encodeURIComponent(avatarSeed)}?style=identicon&format=png`;
    }
    
    return {
      id: row.id,
      content: row.content,
      likesCount: row.likes_count,
      parentCommentId: row.parent_comment_id,
      authorId: row.author_id, // FIXED: was missing, now included
      author: {
        walletAddress: walletAddress,
        username: username,
        displayName: displayName,
        avatar: avatar
      },
      isLiked: row.is_liked || false,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    };
  });

  res.json({
    success: true,
    count: comments.length,
    data: comments
  });
}));

/**
 * @route   POST /api/community/posts/:id/comments
 * @desc    Add comment to post
 * @access  Private
 */
router.post('/posts/:id/comments', verifyToken, sanitizeInput, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { content, parentCommentId } = req.body;
  
  // Debug: Log entire JWT payload
  logger.info(`POST comment - JWT payload keys: ${Object.keys(req.user).join(', ')}`);
  logger.info(`POST comment - JWT payload: ${JSON.stringify(req.user)}`);
  
  // Handle both old tokens (only walletAddress) and new tokens (id + walletAddress)
  const userWalletAddress = req.user.walletAddress || req.user.wallet;
  let userId = req.user.id;
  
  // If no userId but we have wallet, look up user by wallet
  if (!userId && userWalletAddress) {
    const userLookup = await query('SELECT id FROM users WHERE wallet_address = $1', [userWalletAddress]);
    if (userLookup.rows.length > 0) {
      userId = userLookup.rows[0].id;
      logger.info(`POST comment - Looked up userId from wallet: ${userId}`);
    }
  }

  if (!content || content.trim().length === 0) {
    return res.status(400).json({ success: false, error: 'Content is required' });
  }

  // Get author profile data to snapshot into the comment record
  // Query both users and profiles tables, ensuring we get user_id from profiles if it exists
  const profileRes = await query(
    `SELECT 
      u.id as user_id,
      u.wallet_address,
      COALESCE(p.username, u.username) as username,
      COALESCE(p.display_name, u.username) as display_name,
      p.avatar_url
    FROM users u 
    LEFT JOIN profiles p ON u.wallet_address = p.wallet_address OR p.user_id = u.id
    WHERE u.id = $1`,
    [userId]
  );
  const profileRow = (profileRes.rows && profileRes.rows[0]) || {};
  
  // Debug logging
  logger.info(`POST comment - userId: ${userId}, JWT wallet: ${userWalletAddress}`);
  logger.info(`POST comment - DB data: wallet=${profileRow.wallet_address}, username=${profileRow.username}, displayName=${profileRow.display_name}, avatar=${profileRow.avatar_url}`);
  
  // Use wallet from JWT if database doesn't have it
  const walletAddress = profileRow.wallet_address || userWalletAddress;
  const displayName = profileRow.display_name || profileRow.username || (walletAddress ? walletAddress.substring(0, 8) : 'User');
  const username = profileRow.username || profileRow.display_name || (walletAddress ? walletAddress.substring(0, 8) : null);
  const authorAvatar = profileRow.avatar_url || null;
  
  logger.info(`POST comment - Final values: wallet=${walletAddress}, displayName=${displayName}, username=${username}, avatar=${authorAvatar}`);

  logger.info(`POST comment - About to INSERT with author_id=${userId} (type: ${typeof userId})`);
  const insertResult = await query(
    `INSERT INTO comments (author_id, post_id, content, parent_comment_id, author_name, author_avatar)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [userId, id, content, parentCommentId || null, displayName, authorAvatar]
  );
  
  const inserted = insertResult.rows[0];
  logger.info(`POST comment - INSERT returned: id=${inserted.id}, author_id=${inserted.author_id}, author_name=${inserted.author_name}`);

  // Update post comments count
  await query(
    `UPDATE community_posts SET comments_count = comments_count + 1 WHERE id = $1`,
    [id]
  );
  
  // Generate avatar fallback if none exists
  let finalAvatar = normalizeAvatarUrl(authorAvatar);
  if (!finalAvatar) {
    const avatarSeed = walletAddress || username || displayName || userId || 'anonymous';
    finalAvatar = `/api/avatar/${encodeURIComponent(avatarSeed)}?style=identicon&format=png`;
  }
  
  // Build enriched comment response matching GET endpoint shape
  const authorObj = {
    walletAddress: walletAddress,
    username: username,
    displayName: displayName,
    avatar: finalAvatar
  };
  
  res.status(201).json({
    success: true,
    message: 'Comment added successfully',
    comment: {
      id: inserted.id,
      content: inserted.content,
      likesCount: inserted.likes_count,
      parentCommentId: inserted.parent_comment_id,
      authorId: userId,
      author: authorObj,
      createdAt: inserted.created_at,
      updatedAt: inserted.updated_at
    }
  });
  
  // Create comment notification for post author
  try {
    const postOwner = await query('SELECT wallet_address FROM community_posts WHERE id = $1', [id]);
    if (postOwner.rows.length > 0) {
      const targetWallet = postOwner.rows[0].wallet_address;
      const senderWallet = walletAddress; // Use the wallet we resolved above
      if (targetWallet && targetWallet.toLowerCase() !== (senderWallet || '').toLowerCase()) {
        await notifications.createCommentNotification(targetWallet, senderWallet, id, content, req.app.get('io'));
      }
    }
  } catch (e) {
    logger.warn('Could not create comment notification', e.message);
  }
}));

/**
 * @route   DELETE /api/community/comments/:id
 * @desc    Delete comment
 * @access  Private (author only)
 */
router.delete('/comments/:id', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id;

  const checkResult = await query(
    `SELECT author_id, post_id FROM comments WHERE id = $1`,
    [id]
  );

  if (checkResult.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'Comment not found' });
  }

  if (checkResult.rows[0].author_id !== userId) {
    return res.status(403).json({ success: false, error: 'Not authorized' });
  }

  const postId = checkResult.rows[0].post_id;

  await query(`DELETE FROM comments WHERE id = $1`, [id]);

  // Update post comments count
  if (postId) {
    await query(
      `UPDATE community_posts SET comments_count = comments_count - 1 WHERE id = $1`,
      [postId]
    );
  }

  res.json({
    success: true,
    message: 'Comment deleted successfully'
  });
}));

/**
 * @route   POST /api/community/comments/:id/like
 * @desc    Like a comment
 * @access  Private
 */
router.post('/comments/:id/like', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id;
  const senderWallet = req.user.walletAddress;

  await query(
    `INSERT INTO likes (user_id, target_type, target_id)
     VALUES ($1, 'comment', $2)
     ON CONFLICT (user_id, target_type, target_id) DO NOTHING`,
    [userId, id]
  );

  // Update comment likes count
  await query(
    `UPDATE comments 
     SET likes_count = (SELECT COUNT(*) FROM likes WHERE target_type = 'comment' AND target_id = $1)
     WHERE id = $1`,
    [id]
  );

  res.json({
    success: true,
    message: 'Comment liked successfully'
  });
  // Create a notification for the comment author
  try {
    const commentOwner = await query('SELECT u.wallet_address FROM comments c JOIN users u ON c.author_id = u.id WHERE c.id = $1', [id]);
    if (commentOwner.rows.length > 0) {
      const targetWallet = commentOwner.rows[0].wallet_address;
      if (targetWallet && targetWallet.toLowerCase() !== (senderWallet || '').toLowerCase()) {
        await notifications.createLikeNotification(targetWallet, senderWallet, 'comment', id, req.app.get('io'));
      }
    }
  } catch (e) {
    logger.warn('Could not create comment like notification', e.message);
  }
}));

/**
 * @route   DELETE /api/community/comments/:id/like
 * @desc    Unlike a comment
 * @access  Private
 */
router.delete('/comments/:id/like', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const userId = req.user.id;

  await query(
    `DELETE FROM likes WHERE user_id = $1 AND target_type = 'comment' AND target_id = $2`,
    [userId, id]
  );

  // Update comment likes count
  await query(
    `UPDATE comments 
     SET likes_count = (SELECT COUNT(*) FROM likes WHERE target_type = 'comment' AND target_id = $1)
     WHERE id = $1`,
    [id]
  );

  res.json({
    success: true,
    message: 'Comment unliked successfully'
  });
}));

// ============================================
// FOLLOW ENDPOINTS
// ============================================

/**
 * @route   POST /api/community/follow/:walletAddress
 * @desc    Follow a user
 * @access  Private
 */
router.post('/follow/:walletAddress', verifyToken, asyncHandler(async (req, res) => {
  const { walletAddress } = req.params;
  const followerId = req.user.id;
  const senderWallet = req.user.walletAddress;

  // Get target user ID
  const targetResult = await query(
    `SELECT id FROM users WHERE wallet_address = $1`,
    [walletAddress]
  );

  if (targetResult.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'User not found' });
  }

  const followingId = targetResult.rows[0].id;

  if (followerId === followingId) {
    return res.status(400).json({ success: false, error: 'Cannot follow yourself' });
  }

  await query(
    `INSERT INTO follows (follower_id, following_id)
     VALUES ($1, $2)
     ON CONFLICT (follower_id, following_id) DO NOTHING`,
    [followerId, followingId]
  );

  res.json({
    success: true,
    message: 'User followed successfully'
  });
  // Create follow notification for the target user
  try {
    const targetWallet = walletAddress;
    if (targetWallet && targetWallet.toLowerCase() !== (senderWallet || '').toLowerCase()) {
      await notifications.createFollowNotification(targetWallet, senderWallet, req.app.get('io'));
    }
  } catch (e) {
    logger.warn('Could not create follow notification', e.message);
  }
}));

/**
 * @route   DELETE /api/community/follow/:walletAddress
 * @desc    Unfollow a user
 * @access  Private
 */
router.delete('/follow/:walletAddress', verifyToken, asyncHandler(async (req, res) => {
  const { walletAddress } = req.params;
  const followerId = req.user.id;

  const targetResult = await query(
    `SELECT id FROM users WHERE wallet_address = $1`,
    [walletAddress]
  );

  if (targetResult.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'User not found' });
  }

  const followingId = targetResult.rows[0].id;

  await query(
    `DELETE FROM follows WHERE follower_id = $1 AND following_id = $2`,
    [followerId, followingId]
  );

  res.json({
    success: true,
    message: 'User unfollowed successfully'
  });
}));

/**
 * @route   GET /api/community/followers/:walletAddress
 * @desc    Get user's followers
 * @access  Public
 */
router.get('/followers/:walletAddress', optionalAuth, asyncHandler(async (req, res) => {
  const { walletAddress } = req.params;
  const { limit = 50, offset = 0 } = req.query;

  const result = await query(
    `SELECT 
      u.wallet_address, p.username, p.display_name, p.avatar_url,
      f.created_at as followed_at
    FROM follows f
    JOIN users u ON f.follower_id = u.id
    LEFT JOIN profiles p ON u.wallet_address = p.wallet_address
    WHERE f.following_id = (SELECT id FROM users WHERE wallet_address = $1)
    ORDER BY f.created_at DESC
    LIMIT $2 OFFSET $3`,
    [walletAddress, parseInt(limit), parseInt(offset)]
  );

  const followers = result.rows.map(row => ({
    walletAddress: row.wallet_address,
    username: row.username,
    displayName: row.display_name,
    avatar: normalizeAvatarUrl(row.avatar_url),
    followedAt: row.followed_at
  }));

  res.json({
    success: true,
    count: followers.length,
    data: followers
  });
}));

/**
 * @route   GET /api/community/following/:walletAddress
 * @desc    Get users that this user follows
 * @access  Public
 */
router.get('/following/:walletAddress', optionalAuth, asyncHandler(async (req, res) => {
  const { walletAddress } = req.params;
  const { limit = 50, offset = 0 } = req.query;

  const result = await query(
    `SELECT 
      u.wallet_address, p.username, p.display_name, p.avatar_url,
      f.created_at as followed_at
    FROM follows f
    JOIN users u ON f.following_id = u.id
    LEFT JOIN profiles p ON u.wallet_address = p.wallet_address
    WHERE f.follower_id = (SELECT id FROM users WHERE wallet_address = $1)
    ORDER BY f.created_at DESC
    LIMIT $2 OFFSET $3`,
    [walletAddress, parseInt(limit), parseInt(offset)]
  );

  const following = result.rows.map(row => ({
    walletAddress: row.wallet_address,
    username: row.username,
    displayName: row.display_name,
    avatar: normalizeAvatarUrl(row.avatar_url),
    followedAt: row.followed_at
  }));

  res.json({
    success: true,
    count: following.length,
    data: following
  });
}));

/**
 * @route   GET /api/community/feed
 * @desc    Get personalized feed (posts from followed users)
 * @access  Private
 */
router.get('/feed', verifyToken, asyncHandler(async (req, res) => {
  const { page = 1, limit = 20 } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);
  const userId = req.user.id;

  const result = await query(
    `SELECT 
      cp.id, cp.wallet_address, cp.content, cp.media_urls, cp.media_cids,
      cp.artwork_id, cp.post_type, cp.likes_count, cp.comments_count, 
      cp.shares_count, cp.views_count, cp.created_at, cp.updated_at,
      p.username, p.display_name, p.avatar_url,
      a.title as artwork_title, a.image_url as artwork_image
    FROM community_posts cp
    LEFT JOIN profiles p ON cp.wallet_address = p.wallet_address
    LEFT JOIN artworks a ON cp.artwork_id = a.id
    WHERE cp.is_public = true
    AND (
      cp.wallet_address IN (
        SELECT u.wallet_address 
        FROM follows f
        JOIN users u ON f.following_id = u.id
        WHERE f.follower_id = $1
      )
      OR cp.wallet_address = (SELECT wallet_address FROM users WHERE id = $1)
    )
    ORDER BY cp.created_at DESC
    LIMIT $2 OFFSET $3`,
    [userId, parseInt(limit), offset]
  );

  const posts = result.rows.map(row => ({
    id: row.id,
    walletAddress: row.wallet_address,
    content: row.content,
    mediaUrls: row.media_urls || [],
    mediaCids: row.media_cids || [],
    artworkId: row.artwork_id,
    postType: row.post_type,
    author: {
      walletAddress: row.wallet_address,
      username: row.username,
      displayName: row.display_name,
      avatar: normalizeAvatarUrl(row.avatar_url)
    },
    artwork: row.artwork_id ? {
      id: row.artwork_id,
      title: row.artwork_title,
      imageUrl: row.artwork_image
    } : null,
    stats: {
      likes: row.likes_count,
      comments: row.comments_count,
      shares: row.shares_count,
      views: row.views_count
    },
    createdAt: row.created_at
  }));

  res.json({
    success: true,
    count: posts.length,
    page: parseInt(page),
    data: posts
  });
}));

/**
 * @route   GET /api/community/trending
 * @desc    Get trending posts (by likes + comments)
 * @access  Public
 */
router.get('/trending', optionalAuth, asyncHandler(async (req, res) => {
  const { limit = 20, timeframe = '7' } = req.query; // days

  const result = await query(
    `SELECT 
      cp.id, cp.wallet_address, cp.content, cp.media_urls, cp.media_cids,
      cp.artwork_id, cp.post_type, cp.likes_count, cp.comments_count, 
      cp.shares_count, cp.views_count, cp.created_at, cp.updated_at,
      p.username, p.display_name, p.avatar_url,
      a.title as artwork_title, a.image_url as artwork_image,
      (cp.likes_count * 2 + cp.comments_count * 3 + cp.shares_count * 4) as engagement_score
    FROM community_posts cp
    LEFT JOIN profiles p ON cp.wallet_address = p.wallet_address
    LEFT JOIN artworks a ON cp.artwork_id = a.id
    WHERE cp.is_public = true
    AND cp.created_at > NOW() - INTERVAL '${parseInt(timeframe)} days'
    ORDER BY engagement_score DESC, cp.created_at DESC
    LIMIT $1`,
    [parseInt(limit)]
  );

  const posts = result.rows.map(row => ({
    id: row.id,
    walletAddress: row.wallet_address,
    content: row.content,
    mediaUrls: row.media_urls || [],
    mediaCids: row.media_cids || [],
    artworkId: row.artwork_id,
    postType: row.post_type,
    author: {
      walletAddress: row.wallet_address,
      username: row.username,
      displayName: row.display_name,
      avatar: normalizeAvatarUrl(row.avatar_url)
    },
    artwork: row.artwork_id ? {
      id: row.artwork_id,
      title: row.artwork_title,
      imageUrl: row.artwork_image
    } : null,
    stats: {
      likes: row.likes_count,
      comments: row.comments_count,
      shares: row.shares_count,
      views: row.views_count
    },
    engagementScore: row.engagement_score,
    createdAt: row.created_at
  }));

  res.json({
    success: true,
    count: posts.length,
    data: posts
  });
}));

module.exports = router;
