const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const { optionalAuth } = require('../middleware/auth');
const { query } = require('../db');
const logger = require('../utils/logger');
const { normalizeAvatarUrl } = require('../utils/avatar');

const router = express.Router();

/**
 * SEARCH API
 * Universal search across profiles, artworks, institutions, collections, and posts
 */

/**
 * @route   GET /api/search
 * @desc    Universal search across all entities
 * @access  Public
 */
router.get('/', optionalAuth, asyncHandler(async (req, res) => {
  const { 
    q, 
    type = 'all', // all, profiles, artworks, institutions, collections, posts
    limit = 20,
    page = 1 
  } = req.query;

  if (!q || q.trim().length === 0) {
    return res.status(400).json({
      success: false,
      error: 'Search query is required'
    });
  }

  const searchTerm = `%${q.toLowerCase()}%`;
  const offset = (parseInt(page) - 1) * parseInt(limit);
  const results = {};

  try {
    // Search profiles
    if (type === 'all' || type === 'profiles') {
      const profilesResult = await query(
        `SELECT 
          p.wallet_address, p.username, p.display_name, p.bio, p.avatar_url,
          ps.followers_count, ps.following_count, ps.artworks_created
        FROM profiles p
        LEFT JOIN profile_stats ps ON p.id = ps.profile_id
        WHERE 
          LOWER(p.username) LIKE $1 OR
          LOWER(p.display_name) LIKE $1 OR
          LOWER(p.bio) LIKE $1
        ORDER BY ps.followers_count DESC NULLS LAST
        LIMIT $2 OFFSET $3`,
        [searchTerm, parseInt(limit), offset]
      );

      results.profiles = profilesResult.rows.map(row => ({
        type: 'profile',
        walletAddress: row.wallet_address,
        username: row.username,
        displayName: row.display_name,
        bio: row.bio,
        avatar: normalizeAvatarUrl(row.avatar_url),
        stats: {
          followers: row.followers_count || 0,
          following: row.following_count || 0,
          artworks: row.artworks_created || 0
        }
      }));
    }

    // Search artworks
    if (type === 'all' || type === 'artworks') {
      const artworksResult = await query(
        `SELECT 
          a.id, a.title, a.description, a.wallet_address,
          a.image_url, a.image_cid, a.category, a.tags,
          a.likes_count, a.views_count, a.created_at,
          p.username, p.display_name
        FROM artworks a
        LEFT JOIN profiles p ON a.wallet_address = p.wallet_address
        WHERE 
          LOWER(a.title) LIKE $1 OR
          LOWER(a.description) LIKE $1 OR
          LOWER(p.username) LIKE $1 OR
          LOWER(p.display_name) LIKE $1 OR
          LOWER(a.category) LIKE $1 OR
          EXISTS (SELECT 1 FROM unnest(a.tags) tag WHERE LOWER(tag) LIKE $1)
        ORDER BY a.likes_count DESC, a.views_count DESC
        LIMIT $2 OFFSET $3`,
        [searchTerm, parseInt(limit), offset]
      );

      results.artworks = artworksResult.rows.map(row => ({
        type: 'artwork',
        id: row.id,
        title: row.title,
        description: row.description,
        artistName: row.display_name || row.username || 'Unknown Artist',
        artistWallet: row.wallet_address,
        imageUrl: row.image_url,
        imageCid: row.image_cid,
        category: row.category,
        tags: row.tags || [],
        stats: {
          likes: row.likes_count || 0,
          views: row.views_count || 0
        },
        createdAt: row.created_at
      }));
    }

    // Search institutions (optional - table may not exist)
    if (type === 'all' || type === 'institutions') {
      try {
        const institutionsResult = await query(
          `SELECT 
            i.id, i.name, i.description, i.type, i.website,
            i.location, i.latitude, i.longitude,
            i.logo_url, i.banner_url, i.artworks_count
          FROM institutions i
          WHERE 
            LOWER(i.name) LIKE $1 OR
            LOWER(i.description) LIKE $1 OR
            LOWER(i.type) LIKE $1 OR
            LOWER(i.location) LIKE $1
          ORDER BY i.artworks_count DESC
          LIMIT $2 OFFSET $3`,
          [searchTerm, parseInt(limit), offset]
        );

        results.institutions = institutionsResult.rows.map(row => ({
          type: 'institution',
          id: row.id,
          name: row.name,
          description: row.description,
          institutionType: row.type,
          website: row.website,
          location: row.location,
          coordinates: row.latitude && row.longitude ? {
            lat: parseFloat(row.latitude),
            lng: parseFloat(row.longitude)
          } : null,
          logoUrl: row.logo_url,
          bannerUrl: row.banner_url,
          artworkCount: row.artworks_count || 0
        }));
      } catch (error) {
        // Institutions table doesn't exist yet, skip
        results.institutions = [];
        logger.debug('Institutions table not found, skipping');
      }
    }

    // Search collections
    if (type === 'all' || type === 'collections') {
      const collectionsResult = await query(
        `SELECT 
          c.id, c.wallet_address, c.name, c.description,
          c.artworks_count, c.cover_image_url, c.is_public,
          p.username, p.display_name, p.avatar_url
        FROM collections c
        LEFT JOIN profiles p ON c.wallet_address = p.wallet_address
        WHERE 
          c.is_public = true AND
          (LOWER(c.name) LIKE $1 OR LOWER(c.description) LIKE $1)
        ORDER BY c.artworks_count DESC
        LIMIT $2 OFFSET $3`,
        [searchTerm, parseInt(limit), offset]
      );

      results.collections = collectionsResult.rows.map(row => ({
        type: 'collection',
        id: row.id,
        name: row.name,
        description: row.description,
        artworkCount: row.artworks_count || 0,
        thumbnailUrl: row.cover_image_url,
        owner: {
          walletAddress: row.wallet_address,
          username: row.username,
          displayName: row.display_name,
          avatar: normalizeAvatarUrl(row.avatar_url)
        }
      }));
    }

    // Search community posts
    if (type === 'all' || type === 'posts') {
      const postsResult = await query(
        `SELECT 
          cp.id, cp.wallet_address, cp.content, cp.post_type,
          cp.likes_count, cp.comments_count, cp.created_at,
          p.username, p.display_name, p.avatar_url
        FROM community_posts cp
        LEFT JOIN profiles p ON cp.wallet_address = p.wallet_address
        WHERE 
          cp.is_public = true AND
          LOWER(cp.content) LIKE $1
        ORDER BY cp.likes_count DESC, cp.created_at DESC
        LIMIT $2 OFFSET $3`,
        [searchTerm, parseInt(limit), offset]
      );

      results.posts = postsResult.rows.map(row => ({
        type: 'post',
        id: row.id,
        content: row.content,
        postType: row.post_type,
        author: {
          walletAddress: row.wallet_address,
          username: row.username,
          displayName: row.display_name,
          avatar: normalizeAvatarUrl(row.avatar_url)
        },
        stats: {
          likes: row.likes_count || 0,
          comments: row.comments_count || 0
        },
        createdAt: row.created_at
      }));
    }

    // Calculate total results
    const totalResults = Object.values(results).reduce((sum, arr) => sum + arr.length, 0);

    logger.info(`Search performed: "${q}" - ${totalResults} results found`);

    res.json({
      success: true,
      query: q,
      type,
      totalResults,
      page: parseInt(page),
      results
    });
  } catch (error) {
    logger.error('Search error:', error);
    res.status(500).json({
      success: false,
      error: 'Search failed',
      message: error.message
    });
  }
}));

/**
 * @route   GET /api/search/suggestions
 * @desc    Get search suggestions (autocomplete)
 * @access  Public
 */
router.get('/suggestions', optionalAuth, asyncHandler(async (req, res) => {
  const { q, limit = 10 } = req.query;

  if (!q || q.trim().length < 2) {
    return res.json({
      success: true,
      suggestions: []
    });
  }

  const searchTerm = `${q.toLowerCase()}%`; // Prefix match for autocomplete

  try {
    // Get profile suggestions
    const profileSuggestions = await query(
      `SELECT 
        'profile' as type,
        p.username as text,
        p.display_name as secondary_text,
        p.avatar_url as icon
      FROM profiles p
      LEFT JOIN profile_stats ps ON p.id = ps.profile_id
      WHERE LOWER(p.username) LIKE $1 OR LOWER(p.display_name) LIKE $1
      ORDER BY ps.followers_count DESC NULLS LAST
      LIMIT $2`,
      [searchTerm, Math.floor(parseInt(limit) / 3)]
    );

    // Get artwork suggestions
    const artworkSuggestions = await query(
      `SELECT 
        'artwork' as type,
        a.title as text,
        COALESCE(p.display_name, p.username, 'Unknown Artist') as secondary_text,
        a.image_url as icon
      FROM artworks a
      LEFT JOIN profiles p ON a.wallet_address = p.wallet_address
      WHERE LOWER(a.title) LIKE $1
      ORDER BY a.likes_count DESC
      LIMIT $2`,
      [searchTerm, Math.floor(parseInt(limit) / 3)]
    );

    // Get institution suggestions (optional - table may not exist)
    let institutionSuggestions = { rows: [] };
    try {
      institutionSuggestions = await query(
        `SELECT 
          'institution' as type,
          name as text,
          type as secondary_text,
          logo_url as icon
        FROM institutions
        WHERE LOWER(name) LIKE $1
        ORDER BY artworks_count DESC
        LIMIT $2`,
        [searchTerm, Math.floor(parseInt(limit) / 3)]
      );
    } catch (error) {
      logger.debug('Institutions table not found in suggestions, skipping');
    }

    const suggestions = [
      ...profileSuggestions.rows,
      ...artworkSuggestions.rows,
      ...institutionSuggestions.rows
    ].slice(0, parseInt(limit));

    res.json({
      success: true,
      query: q,
      count: suggestions.length,
      suggestions: suggestions.map(s => ({
        type: s.type,
        text: s.text,
        secondaryText: s.secondary_text,
        icon: s.icon
      }))
    });
  } catch (error) {
    logger.error('Suggestions error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get suggestions'
    });
  }
}));

/**
 * @route   GET /api/search/trending
 * @desc    Get trending search terms
 * @access  Public
 */
router.get('/trending', optionalAuth, asyncHandler(async (req, res) => {
  const { limit = 10 } = req.query;

  try {
    // Get trending tags from artworks
    const trendingTags = await query(
      `SELECT 
        tag,
        COUNT(*) as frequency
      FROM artworks, unnest(tags) as tag
      GROUP BY tag
      ORDER BY frequency DESC
      LIMIT $1`,
      [parseInt(limit)]
    );

    // Get trending artworks (by recent views/likes)
    const trendingArtworks = await query(
      `SELECT title
      FROM artworks
      WHERE created_at > NOW() - INTERVAL '7 days'
      ORDER BY (likes_count * 2 + views_count) DESC
      LIMIT $1`,
      [Math.floor(parseInt(limit) / 2)]
    );

    // Get trending artists (by follower growth)
    const trendingArtists = await query(
      `SELECT p.username, p.display_name
      FROM profiles p
      LEFT JOIN profile_stats ps ON p.id = ps.profile_id
      WHERE p.updated_at > NOW() - INTERVAL '7 days'
      ORDER BY ps.followers_count DESC NULLS LAST
      LIMIT $1`,
      [Math.floor(parseInt(limit) / 2)]
    );

    const trending = [
      ...trendingTags.rows.map(t => ({ term: t.tag, type: 'tag' })),
      ...trendingArtworks.rows.map(a => ({ term: a.title, type: 'artwork' })),
      ...trendingArtists.rows.map(a => ({ 
        term: a.display_name || a.username, 
        type: 'artist' 
      }))
    ].slice(0, parseInt(limit));

    res.json({
      success: true,
      count: trending.length,
      trending
    });
  } catch (error) {
    logger.error('Trending search error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get trending searches'
    });
  }
}));

module.exports = router;
