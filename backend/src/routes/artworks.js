const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const { optionalAuth } = require('../middleware/auth');

const router = express.Router();

const artworks = new Map();

/**
 * @route   GET /api/artworks
 * @desc    Get all artworks with optional filters
 * @access  Public
 */
router.get('/', optionalAuth, asyncHandler(async (req, res) => {
  const allArtworks = Array.from(artworks.values());
  
  res.json({
    success: true,
    count: allArtworks.length,
    data: allArtworks,
  });
}));

/**
 * @route   GET /api/artworks/:id
 * @desc    Get artwork by ID
 * @access  Public
 */
router.get('/:id', asyncHandler(async (req, res) => {
  const artwork = artworks.get(req.params.id);
  
  if (!artwork) {
    return res.status(404).json({
      success: false,
      error: 'Artwork not found',
    });
  }
  
  res.json({
    success: true,
    data: artwork,
  });
}));

module.exports = router;
