const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const { verifyToken, optionalAuth } = require('../middleware/auth');
const { query } = require('../db');
const logger = require('../utils/logger');

const router = express.Router();

/**
 * COLLECTIONS API
 * Manages user collections (artwork groups)
 */

/**
 * @route   GET /api/collections
 * @desc    Get user's collections
 * @access  Public (filtered by user if walletAddress provided)
 */
router.get('/', optionalAuth, asyncHandler(async (req, res) => {
  const { walletAddress, page = 1, limit = 20 } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);

  let queryText = `
    SELECT 
      c.id, c.wallet_address, c.name, c.description, c.is_public,
      c.artworks_count as artwork_count, c.cover_image_url as thumbnail_url, c.created_at, c.updated_at,
      p.username, p.display_name, p.avatar_url
    FROM collections c
    LEFT JOIN profiles p ON c.wallet_address = p.wallet_address
    WHERE 1=1
  `;
  
  const queryParams = [];
  let paramCount = 1;

  if (walletAddress) {
    queryText += ` AND c.wallet_address = $${paramCount++}`;
    queryParams.push(walletAddress);
  } else {
    // Only show public collections if no specific user requested
    queryText += ` AND c.is_public = true`;
  }

  queryText += ` ORDER BY c.updated_at DESC LIMIT $${paramCount++} OFFSET $${paramCount++}`;
  queryParams.push(parseInt(limit), offset);

  const result = await query(queryText, queryParams);

  const collections = result.rows.map(row => ({
    id: row.id,
    walletAddress: row.wallet_address,
    name: row.name,
    description: row.description,
    isPublic: row.is_public,
    artworkCount: row.artwork_count || 0,
    thumbnailUrl: row.thumbnail_url,
    owner: {
      walletAddress: row.wallet_address,
      username: row.username,
      displayName: row.display_name,
      avatar: row.avatar_url
    },
    createdAt: row.created_at,
    updatedAt: row.updated_at
  }));

  res.json({
    success: true,
    count: collections.length,
    page: parseInt(page),
    data: collections
  });
}));

/**
 * @route   GET /api/collections/:id
 * @desc    Get collection by ID with artworks
 * @access  Public (if collection is public)
 */
router.get('/:id', optionalAuth, asyncHandler(async (req, res) => {
  const { id } = req.params;

  // Get collection info
  const collectionResult = await query(
    `SELECT 
      c.id, c.wallet_address, c.name, c.description, c.is_public,
      c.artworks_count as artwork_count, c.cover_image_url as thumbnail_url, c.created_at, c.updated_at,
      p.username, p.display_name, p.avatar_url
    FROM collections c
    LEFT JOIN profiles p ON c.wallet_address = p.wallet_address
    WHERE c.id = $1`,
    [id]
  );

  if (collectionResult.rows.length === 0) {
    return res.status(404).json({
      success: false,
      error: 'Collection not found'
    });
  }

  const row = collectionResult.rows[0];

  // Check if user has access (public or owner)
  if (!row.is_public && req.user?.walletAddress !== row.wallet_address) {
    return res.status(403).json({
      success: false,
      error: 'Access denied to private collection'
    });
  }

  // Get artworks in collection
  const artworksResult = await query(
    `SELECT 
      a.id, a.title, a.description, a.artist_name, a.artist_wallet,
      a.image_url, a.image_cid, a.category, a.tags,
      ca.added_at, ca.notes
    FROM collection_artworks ca
    JOIN artworks a ON ca.artwork_id = a.id
    WHERE ca.collection_id = $1
    ORDER BY ca.added_at DESC`,
    [id]
  );

  const collection = {
    id: row.id,
    walletAddress: row.wallet_address,
    name: row.name,
    description: row.description,
    isPublic: row.is_public,
    artworkCount: row.artwork_count || 0,
    thumbnailUrl: row.thumbnail_url,
    owner: {
      walletAddress: row.wallet_address,
      username: row.username,
      displayName: row.display_name,
      avatar: row.avatar_url
    },
    artworks: artworksResult.rows.map(artwork => ({
      id: artwork.id,
      title: artwork.title,
      description: artwork.description,
      artistName: artwork.artist_name,
      artistWallet: artwork.artist_wallet,
      imageUrl: artwork.image_url,
      imageCid: artwork.image_cid,
      category: artwork.category,
      tags: artwork.tags || [],
      addedAt: artwork.added_at,
      notes: artwork.notes
    })),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };

  res.json({
    success: true,
    data: collection
  });
}));

/**
 * @route   POST /api/collections
 * @desc    Create new collection
 * @access  Private
 */
router.post('/', verifyToken, asyncHandler(async (req, res) => {
  const { name, description, isPublic = true, thumbnailUrl } = req.body;
  const walletAddress = req.user.walletAddress;

  if (!name || name.trim().length === 0) {
    return res.status(400).json({
      success: false,
      error: 'Collection name is required'
    });
  }

  const result = await query(
    `INSERT INTO collections (wallet_address, name, description, is_public, cover_image_url)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [walletAddress, name, description, isPublic, thumbnailUrl]
  );

  const collection = result.rows[0];

  logger.info(`Collection created: ${collection.id} by ${walletAddress}`);

  res.status(201).json({
    success: true,
    message: 'Collection created successfully',
    data: {
      id: collection.id,
      walletAddress: collection.wallet_address,
      name: collection.name,
      description: collection.description,
      isPublic: collection.is_public,
      artworkCount: 0,
      thumbnailUrl: collection.thumbnail_url,
      createdAt: collection.created_at
    }
  });
}));

/**
 * @route   PUT /api/collections/:id
 * @desc    Update collection
 * @access  Private (owner only)
 */
router.put('/:id', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { name, description, isPublic, thumbnailUrl } = req.body;
  const walletAddress = req.user.walletAddress;

  // Check ownership
  const checkResult = await query(
    `SELECT wallet_address FROM collections WHERE id = $1`,
    [id]
  );

  if (checkResult.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'Collection not found' });
  }

  if (checkResult.rows[0].wallet_address !== walletAddress) {
    return res.status(403).json({ success: false, error: 'Not authorized' });
  }

  const result = await query(
    `UPDATE collections 
     SET name = COALESCE($1, name),
         description = COALESCE($2, description),
         is_public = COALESCE($3, is_public),
         cover_image_url = COALESCE($4, cover_image_url),
         updated_at = CURRENT_TIMESTAMP
     WHERE id = $5
     RETURNING *`,
    [name, description, isPublic, thumbnailUrl, id]
  );

  res.json({
    success: true,
    message: 'Collection updated successfully',
    data: result.rows[0]
  });
}));

/**
 * @route   DELETE /api/collections/:id
 * @desc    Delete collection
 * @access  Private (owner only)
 */
router.delete('/:id', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const walletAddress = req.user.walletAddress;

  const checkResult = await query(
    `SELECT wallet_address FROM collections WHERE id = $1`,
    [id]
  );

  if (checkResult.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'Collection not found' });
  }

  if (checkResult.rows[0].wallet_address !== walletAddress) {
    return res.status(403).json({ success: false, error: 'Not authorized' });
  }

  // Delete collection (cascade will remove collection_artworks entries)
  await query(`DELETE FROM collections WHERE id = $1`, [id]);

  logger.info(`Collection deleted: ${id}`);

  res.json({
    success: true,
    message: 'Collection deleted successfully'
  });
}));

/**
 * @route   POST /api/collections/:id/artworks
 * @desc    Add artwork to collection
 * @access  Private (owner only)
 */
router.post('/:id/artworks', verifyToken, asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { artworkId, notes } = req.body;
  const walletAddress = req.user.walletAddress;

  // Check ownership
  const checkResult = await query(
    `SELECT wallet_address FROM collections WHERE id = $1`,
    [id]
  );

  if (checkResult.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'Collection not found' });
  }

  if (checkResult.rows[0].wallet_address !== walletAddress) {
    return res.status(403).json({ success: false, error: 'Not authorized' });
  }

  // Check if artwork exists
  const artworkCheck = await query(
    `SELECT id FROM artworks WHERE id = $1`,
    [artworkId]
  );

  if (artworkCheck.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'Artwork not found' });
  }

  // Add artwork to collection
  try {
    await query(
      `INSERT INTO collection_artworks (collection_id, artwork_id, notes)
       VALUES ($1, $2, $3)
       ON CONFLICT (collection_id, artwork_id) DO NOTHING`,
      [id, artworkId, notes]
    );

    // Update artwork count
    await query(
      `UPDATE collections 
       SET artworks_count = (SELECT COUNT(*) FROM collection_artworks WHERE collection_id = $1),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [id]
    );

    res.json({
      success: true,
      message: 'Artwork added to collection successfully'
    });
  } catch (error) {
    logger.error('Error adding artwork to collection:', error);
    res.status(500).json({ success: false, error: 'Failed to add artwork' });
  }
}));

/**
 * @route   DELETE /api/collections/:id/artworks/:artworkId
 * @desc    Remove artwork from collection
 * @access  Private (owner only)
 */
router.delete('/:id/artworks/:artworkId', verifyToken, asyncHandler(async (req, res) => {
  const { id, artworkId } = req.params;
  const walletAddress = req.user.walletAddress;

  // Check ownership
  const checkResult = await query(
    `SELECT wallet_address FROM collections WHERE id = $1`,
    [id]
  );

  if (checkResult.rows.length === 0) {
    return res.status(404).json({ success: false, error: 'Collection not found' });
  }

  if (checkResult.rows[0].wallet_address !== walletAddress) {
    return res.status(403).json({ success: false, error: 'Not authorized' });
  }

  await query(
    `DELETE FROM collection_artworks WHERE collection_id = $1 AND artwork_id = $2`,
    [id, artworkId]
  );

  // Update artwork count
  await query(
    `UPDATE collections 
     SET artworks_count = (SELECT COUNT(*) FROM collection_artworks WHERE collection_id = $1),
         updated_at = CURRENT_TIMESTAMP
     WHERE id = $1`,
    [id]
  );

  res.json({
    success: true,
    message: 'Artwork removed from collection successfully'
  });
}));

module.exports = router;
