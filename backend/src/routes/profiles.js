const express = require('express');
const jwt = require('jsonwebtoken');
const router = express.Router();
const logger = require('../utils/logger');
const { query } = require('../db');
const multer = require('multer');
const storageService = require('../services/storageService');
const { verifyToken, createUserRateLimit } = require('../middleware/auth');

// Multer config for avatar uploads (memory storage)
const avatarUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: parseInt(process.env.MAX_AVATAR_UPLOAD_SIZE) || 5 * 1024 * 1024 }, // 5MB default
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Invalid avatar file type'));
  },
});

/**
 * PROFILES & ARTISTS API
 * 
 * This API manages user profiles and artist information.
 * 
 * STORAGE STRATEGY:
 * - On-chain: Wallet address, token balances, NFT ownership
 * - Off-chain: Profile metadata, social info, preferences
 * - Hybrid: Reference on-chain NFT as profile verification
 * 
 * Profile data is stored in PostgreSQL/MongoDB with wallet address as primary key.
 * Solana wallet stores only verification NFTs and token ownership.
 */

// ============================================
// GET PROFILE BY WALLET ADDRESS
// ============================================
router.get('/:walletAddress', async (req, res) => {
  try {
    const { walletAddress } = req.params;
    
    logger.info(`Fetching profile for wallet: ${walletAddress}`);
    
    // Fetch from database
    const result = await query(
      'SELECT * FROM profiles WHERE wallet_address = $1',
      [walletAddress]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Profile not found',
        message: 'No profile exists for this wallet address'
      });
    }
    
    const profile = {
      id: result.rows[0].id,
      walletAddress: result.rows[0].wallet_address,
      username: result.rows[0].username,
      displayName: result.rows[0].display_name,
      bio: result.rows[0].bio,
      avatar: result.rows[0].avatar_url,
      coverImage: result.rows[0].cover_image_url,
      social: {
        twitter: result.rows[0].twitter,
        instagram: result.rows[0].instagram,
        discord: result.rows[0].discord,
        website: result.rows[0].website
      },
      isArtist: result.rows[0].is_artist,
      isVerified: result.rows[0].is_verified,
      createdAt: result.rows[0].created_at,
      updatedAt: result.rows[0].updated_at
    };
    
    res.json({
      success: true,
      data: profile
    });
  } catch (error) {
    logger.error('Error fetching profile:', error);
    res.status(500).json({
      success: false,
      error: 'Server error',
      message: error.message
    });
  }
});

// ============================================
// CREATE/UPDATE PROFILE
// ============================================
router.post('/', async (req, res) => {
  try {
    const {
      walletAddress,
      username,
      displayName,
      bio,
      avatar,
      coverImage,
      social,
      isArtist,
      artistInfo,
      preferences
    } = req.body;
    
    // Validation
    if (!walletAddress) {
      return res.status(400).json({
        success: false,
        error: 'Validation error',
        message: 'Wallet address is required'
      });
    }
    
    logger.info(`Creating/updating profile for wallet: ${walletAddress}`);
    
    // Save to database with UPSERT
    const result = await query(
      `INSERT INTO profiles (
        wallet_address, username, display_name, bio, avatar_url, 
        cover_image_url, twitter, instagram, discord, website, is_artist
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      ON CONFLICT (wallet_address) 
      DO UPDATE SET 
        username = EXCLUDED.username,
        display_name = EXCLUDED.display_name,
        bio = EXCLUDED.bio,
        avatar_url = EXCLUDED.avatar_url,
        cover_image_url = EXCLUDED.cover_image_url,
        twitter = EXCLUDED.twitter,
        instagram = EXCLUDED.instagram,
        discord = EXCLUDED.discord,
        website = EXCLUDED.website,
        is_artist = EXCLUDED.is_artist,
        updated_at = CURRENT_TIMESTAMP
      RETURNING *`,
      [
        walletAddress,
        username,
        displayName,
        bio,
        avatar,
        coverImage,
        social?.twitter,
        social?.instagram,
        social?.discord,
        social?.website,
        isArtist || false
      ]
    );
    
    const profile = {
      id: result.rows[0].id,
      walletAddress: result.rows[0].wallet_address,
      username: result.rows[0].username,
      displayName: result.rows[0].display_name,
      bio: result.rows[0].bio,
      avatar: result.rows[0].avatar_url,
      coverImage: result.rows[0].cover_image_url,
      social: {
        twitter: result.rows[0].twitter,
        instagram: result.rows[0].instagram,
        discord: result.rows[0].discord,
        website: result.rows[0].website
      },
      isArtist: result.rows[0].is_artist,
      createdAt: result.rows[0].created_at,
      updatedAt: result.rows[0].updated_at
    };
    
    // Generate JWT token for authenticated requests (like avatar upload)
    const token = jwt.sign(
      { id: profile.id, walletAddress: profile.walletAddress, role: 'user' },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );
    
    res.json({
      success: true,
      data: profile,
      token, // Return JWT token so Flutter can store it for authenticated uploads
      message: 'Profile saved successfully'
    });
  } catch (error) {
    logger.error('Error saving profile:', error);
    res.status(500).json({
      success: false,
      error: 'Server error',
      message: error.message
    });
  }
});

// ============================================
// GET ALL ARTISTS
// ============================================
router.get('/artists/list', async (req, res) => {
  try {
    const { verified, featured, limit = 50, offset = 0 } = req.query;
    
    logger.info('Fetching artists list', { verified, featured, limit, offset });
    
    // Build query with filters
    let queryText = `
      SELECT 
        p.id, p.wallet_address, p.username, p.display_name, p.bio,
        p.avatar_url, p.cover_image_url, p.is_artist, p.is_verified,
        p.twitter, p.instagram, p.website, p.created_at, p.updated_at,
        ps.artworks_created, ps.followers_count
      FROM profiles p
      LEFT JOIN profile_stats ps ON p.id = ps.profile_id
      WHERE p.is_artist = true
    `;
    const queryParams = [];
    let paramCount = 1;
    
    if (verified === 'true') {
      queryText += ` AND p.is_verified = true`;
    }
    
    queryText += ` ORDER BY ps.followers_count DESC NULLS LAST, p.created_at DESC`;
    queryText += ` LIMIT $${paramCount++} OFFSET $${paramCount++}`;
    queryParams.push(parseInt(limit), parseInt(offset));
    
    const result = await query(queryText, queryParams);
    
    const artists = result.rows.map(row => ({
      id: row.id,
      walletAddress: row.wallet_address,
      username: row.username,
      displayName: row.display_name,
      bio: row.bio,
      avatar: row.avatar_url,
      coverImage: row.cover_image_url,
      isArtist: row.is_artist,
      isVerified: row.is_verified,
      social: {
        twitter: row.twitter,
        instagram: row.instagram,
        website: row.website
      },
      stats: {
        artworksCount: row.artworks_created || 0,
        followersCount: row.followers_count || 0
      },
      createdAt: row.created_at
    }));
    
    // Get total count for pagination
    const countResult = await query(
      `SELECT COUNT(*) FROM profiles WHERE is_artist = true ${verified === 'true' ? 'AND is_verified = true' : ''}`
    );
    const totalCount = parseInt(countResult.rows[0].count);
    
    res.json({
      success: true,
      count: artists.length,
      data: artists,
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        total: artists.length
      }
    });
  } catch (error) {
    logger.error('Error fetching artists:', error);
    res.status(500).json({
      success: false,
      error: 'Server error',
      message: error.message
    });
  }
});

// ============================================
// GET ARTIST ARTWORKS
// ============================================
router.get('/:walletAddress/artworks', async (req, res) => {
  try {
    const { walletAddress } = req.params;
    const { status, limit = 20, offset = 0 } = req.query;
    
    logger.info(`Fetching artworks for artist: ${walletAddress}`);
    
    // Build query with filters
    let queryText = `
      SELECT 
        id, title, description, image_url, image_cid,
        category, tags, location_name, location_lat, location_lng,
        is_ar_enabled, model_3d_url, model_3d_cid,
        is_nft, nft_mint_address, price, currency, is_for_sale,
        is_public, views_count, likes_count, comments_count, shares_count,
        created_at, updated_at
      FROM artworks
      WHERE wallet_address = $1 AND is_public = true
    `;
    const queryParams = [walletAddress];
    let paramCount = 2;
    
    if (status) {
      queryText += ` AND is_for_sale = $${paramCount++}`;
      queryParams.push(status === 'for_sale');
    }
    
    queryText += ` ORDER BY created_at DESC LIMIT $${paramCount++} OFFSET $${paramCount++}`;
    queryParams.push(parseInt(limit), parseInt(offset));
    
    const result = await query(queryText, queryParams);
    
    const artworks = result.rows.map(row => ({
      id: row.id,
      title: row.title,
      description: row.description,
      imageUrl: row.image_url,
      imageCid: row.image_cid,
      category: row.category,
      tags: row.tags || [],
      location: row.location_name ? {
        name: row.location_name,
        latitude: row.location_lat ? parseFloat(row.location_lat) : null,
        longitude: row.location_lng ? parseFloat(row.location_lng) : null
      } : null,
      arEnabled: row.is_ar_enabled,
      model3dUrl: row.model_3d_url,
      model3dCid: row.model_3d_cid,
      nft: row.is_nft ? {
        mintAddress: row.nft_mint_address,
        price: row.price ? parseFloat(row.price) : null,
        currency: row.currency
      } : null,
      isForSale: row.is_for_sale,
      stats: {
        viewsCount: row.views_count,
        likesCount: row.likes_count,
        commentsCount: row.comments_count,
        sharesCount: row.shares_count
      },
      createdAt: row.created_at,
      updatedAt: row.updated_at
    }));
    
    // Get total count
    const countResult = await query(
      `SELECT COUNT(*) FROM artworks WHERE wallet_address = $1 AND is_public = true`,
      [walletAddress]
    );
    const totalCount = parseInt(countResult.rows[0].count);
    
    res.json({
      success: true,
      count: artworks.length,
      data: artworks,
      pagination: {
        limit: parseInt(limit),
        offset: parseInt(offset),
        total: artworks.length
      }
    });
  } catch (error) {
    logger.error('Error fetching artist artworks:', error);
    res.status(500).json({
      success: false,
      error: 'Server error',
      message: error.message
    });
  }
});

// ============================================
// VERIFY ARTIST (ADMIN ONLY)
// ============================================
router.post('/:walletAddress/verify', async (req, res) => {
  try {
    // TODO: Add admin authentication middleware (requires middleware/auth.js with admin check)
    // For now, this endpoint should be protected by admin role in production
    
    const { walletAddress } = req.params;
    const { verified, verificationNFT } = req.body;
    
    logger.info(`Verifying artist: ${walletAddress}`);
    
    // Update database - set verified status
    const result = await query(
      `UPDATE profiles 
       SET is_verified = $1, updated_at = CURRENT_TIMESTAMP
       WHERE wallet_address = $2
       RETURNING id, wallet_address, username, display_name, is_artist, is_verified`,
      [verified === true || verified === 'true', walletAddress]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Profile not found',
        message: 'No profile exists for this wallet address'
      });
    }
    
    const profile = result.rows[0];
    
    // TODO: Optionally mint verification NFT on Solana
    // This would require integration with Solana NFT minting service
    // Example: await mintVerificationNFT(walletAddress, verificationNFT);
    
    logger.info(`Artist verification updated: ${walletAddress} - verified: ${verified}`);
    
    res.json({
      success: true,
      message: `Artist ${verified ? 'verified' : 'unverified'} successfully`,
      data: {
        id: profile.id,
        walletAddress: profile.wallet_address,
        username: profile.username,
        displayName: profile.display_name,
        isArtist: profile.is_artist,
        isVerified: profile.is_verified,
        verificationNFT
      }
    });
  } catch (error) {
    logger.error('Error verifying artist:', error);
    res.status(500).json({
      success: false,
      error: 'Server error',
      message: error.message
    });
  }
});

// ============================================
// GET USER STATS
// ============================================
router.get('/:walletAddress/stats', async (req, res) => {
  try {
    const { walletAddress } = req.params;
    
    logger.info(`Fetching stats for user: ${walletAddress}`);
    
    // Aggregate stats from multiple sources
    const statsQuery = `
      SELECT 
        p.wallet_address,
        ps.artworks_created,
        ps.artworks_discovered,
        ps.artworks_liked,
        ps.followers_count,
        ps.following_count,
        ps.total_views,
        ps.total_interactions,
        COUNT(DISTINCT cp.id) as posts_count,
        COUNT(DISTINCT c.id) as comments_count,
        COALESCE(SUM(CASE WHEN a.is_nft = true THEN 1 ELSE 0 END), 0) as nfts_minted
      FROM profiles p
      LEFT JOIN profile_stats ps ON p.id = ps.profile_id
      LEFT JOIN community_posts cp ON p.wallet_address = cp.wallet_address
      LEFT JOIN comments c ON c.author_id = (SELECT id FROM users WHERE wallet_address = p.wallet_address)
      LEFT JOIN artworks a ON p.wallet_address = a.wallet_address
      WHERE p.wallet_address = $1
      GROUP BY p.wallet_address, ps.artworks_created, ps.artworks_discovered, 
               ps.artworks_liked, ps.followers_count, ps.following_count,
               ps.total_views, ps.total_interactions
    `;
    
    const result = await query(statsQuery, [walletAddress]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Profile not found',
        message: 'No profile exists for this wallet address'
      });
    }
    
    const row = result.rows[0];
    
    // Count AR views
    const arViewsResult = await query(
      `SELECT COUNT(*) as ar_views FROM ar_markers WHERE artwork_id IN (
        SELECT id FROM artworks WHERE wallet_address = $1
      )`,
      [walletAddress]
    );
    
    // Note: KUB8 balance and SOL balance would need to be fetched from blockchain
    // This would require integration with Solana RPC
    
    const stats = {
      walletAddress: row.wallet_address,
      artworksCreated: row.artworks_created || 0,
      artworksDiscovered: row.artworks_discovered || 0,
      arViewsCount: parseInt(arViewsResult.rows[0].ar_views) || 0,
      nftsMinted: parseInt(row.nfts_minted) || 0,
      followersCount: row.followers_count || 0,
      followingCount: row.following_count || 0,
      postsCount: parseInt(row.posts_count) || 0,
      commentsCount: parseInt(row.comments_count) || 0,
      likesGiven: row.artworks_liked || 0,
      totalViews: row.total_views || 0,
      totalInteractions: row.total_interactions || 0,
      lastActive: new Date().toISOString()
      // Note: kub8Balance and solBalance require blockchain integration
      // kub8Balance: await getKUB8Balance(walletAddress),
      // solBalance: await getSOLBalance(walletAddress)
    };
    
    res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    logger.error('Error fetching user stats:', error);
    res.status(500).json({
      success: false,
      error: 'Server error',
      message: error.message
    });
  }
});

// ============================================
// MOCK DATA HELPERS
// ============================================

function getMockProfile(walletAddress) {
  return {
    id: `profile_${walletAddress.slice(0, 8)}`,
    walletAddress,
    username: `user_${walletAddress.slice(0, 8)}`,
    displayName: 'Demo User',
    bio: 'Art enthusiast exploring Web3 and AR',
    // No external DiceBear default in mocks; leave empty so clients show local icon/placeholder
    avatar: '',
    coverImage: 'https://picsum.photos/seed/' + walletAddress + '/1200/400',
    social: {
      twitter: '',
      instagram: '',
      website: ''
    },
    isArtist: false,
    preferences: {
      privacy: 'public',
      notifications: true,
      theme: 'auto'
    },
    stats: {
      artworksDiscovered: 15,
      artworksCreated: 0,
      nftsOwned: 3,
      kub8Balance: 150,
      achievementsUnlocked: 8,
      followersCount: 45,
      followingCount: 67
    },
    createdAt: new Date('2024-01-15').toISOString(),
    updatedAt: new Date().toISOString()
  };
}

function getMockArtists() {
  return [
    {
      id: 'artist_maya',
      walletAddress: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
      username: 'maya_chen',
      displayName: 'Maya Chen',
      bio: 'Digital artist bridging traditional and AR art',
      avatar: '',
      coverImage: 'https://picsum.photos/seed/maya/1200/400',
      isArtist: true,
      artistInfo: {
        verified: true,
        verificationNFT: 'artist_nft_123',
        specialty: ['digital-art', 'AR', 'installations'],
        yearsActive: 5,
        featured: true,
        artworksCount: 24,
        followersCount: 1234
      },
      social: {
        twitter: '@mayachenart',
        instagram: '@mayachenart',
        website: 'https://mayachen.art'
      },
      createdAt: new Date('2023-06-01').toISOString()
    },
    {
      id: 'artist_alex',
      walletAddress: '9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM',
      username: 'alex_rivera',
      displayName: 'Alex Rivera',
      bio: 'Street artist bringing blockchain to public spaces',
      avatar: '',
      coverImage: 'https://picsum.photos/seed/alex/1200/400',
      isArtist: true,
      artistInfo: {
        verified: true,
        verificationNFT: 'artist_nft_456',
        specialty: ['street-art', 'graffiti', 'AR'],
        yearsActive: 8,
        featured: true,
        artworksCount: 67,
        followersCount: 3456
      },
      social: {
        twitter: '@alexrivera',
        instagram: '@alexrivera_art',
        website: 'https://alexrivera.art'
      },
      createdAt: new Date('2023-03-15').toISOString()
    }
  ];
}

function getMockArtistArtworks(walletAddress) {
  return [
    {
      id: 'artwork_1',
      title: 'Digital Renaissance',
      artistWallet: walletAddress,
      imageUrl: 'https://picsum.photos/seed/art1/800/600',
      status: 'active',
      arEnabled: true,
      likesCount: 234,
      viewsCount: 1580,
      createdAt: new Date('2024-01-15').toISOString()
    }
  ];
}

function getMockUserStats(walletAddress) {
  return {
    walletAddress,
    artworksDiscovered: 15,
    artworksCreated: 0,
    arViewsCount: 45,
    nftsOwned: 3,
    nftsMinted: 0,
    kub8Balance: 150.0,
    solBalance: 2.5,
    achievementsUnlocked: 8,
    achievementsTotal: 25,
    followersCount: 45,
    followingCount: 67,
    postsCount: 12,
    commentsCount: 89,
    likesGiven: 234,
    likesReceived: 156,
    lastActive: new Date().toISOString()
  };
}

module.exports = router;

// ============================================
// AVATAR UPLOAD (POST /api/profiles/avatars)
// ============================================
// Accepts multipart/form-data with field `file` and updates profile.avatar_url
router.post('/avatars',
  verifyToken,
  createUserRateLimit(20, 60 * 60 * 1000), // 20 uploads per hour per user
  avatarUpload.single('file'),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ success: false, error: 'No file provided' });
      }

      const { buffer, originalname, mimetype, size } = req.file;
      let metadata = {};
      try {
        metadata = req.body.metadata ? JSON.parse(req.body.metadata) : {};
      } catch (_) {
        metadata = {};
      }

      // Attach uploader info
      metadata.uploadedBy = req.user?.id || null;
      metadata.uploadedAt = new Date().toISOString();
      metadata.mimetype = mimetype;
      metadata.originalName = originalname;

      logger.info(`Profile avatar upload requested by user: ${req.user?.id || 'unknown'}`);

      // Upload using storageService (may return ipfs and/or http url)
      // Ensure avatars are stored under a dedicated public folder so URLs are predictable
      metadata.uploadFolder = metadata.uploadFolder || 'profiles/avatars';
      const result = await storageService.uploadFile(buffer, originalname, metadata);

      // Determine final avatar URL preference: http URL > ipfs url > path
      let avatarUrl = result.url || result.ipfsUrl || result.path || null;

      // Normalize avatarUrl: ensure absolute http(s) when possible
      if (avatarUrl && !/^https?:\/\//i.test(avatarUrl)) {
        // If backend returned a filesystem path, convert basename to HTTP_BASE_URL path
        const pathModule = require('path');
        const fileName = pathModule.basename(String(avatarUrl));
        // Prefer storageService.httpBaseUrl (set at service init), fallback to env
        const httpBase = (storageService.httpBaseUrl || process.env.HTTP_BASE_URL || '').replace(/\/$/, '');
        if (httpBase) {
          avatarUrl = `${httpBase}/profiles/avatars/${fileName}`;
        }
      }

      if (!avatarUrl) {
        return res.status(500).json({ success: false, error: 'Failed to determine uploaded avatar URL', raw: result });
      }

      // Resolve wallet address from token or DB
      let walletAddress = req.user?.walletAddress;
      if (!walletAddress) {
        const r = await query('SELECT wallet_address FROM profiles WHERE user_id = $1', [req.user?.id]);
        walletAddress = r.rows[0]?.wallet_address;
      }

      if (!walletAddress) {
        return res.status(400).json({ success: false, error: 'Unable to determine wallet address for profile' });
      }

      // Update profiles table
      const updateRes = await query(
        `UPDATE profiles SET avatar_url = $1, updated_at = CURRENT_TIMESTAMP WHERE wallet_address = $2 RETURNING *`,
        [avatarUrl, walletAddress]
      );

      // Record upload in uploads table if present
      try {
        await query(
          `INSERT INTO uploads (uploader_id, filename, original_filename, mime_type, file_size, storage_provider, ipfs_cid, http_url, is_public) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
          [req.user?.id, originalname, originalname, mimetype, size, result.cid ? 'ipfs' : 'http', result.cid || null, result.url || null, true]
        );
      } catch (e) {
        logger.warn('Failed to insert uploads record: ' + e.message);
      }

      res.json({ success: true, message: 'Avatar uploaded', data: { avatar: avatarUrl, raw: result } });
    } catch (error) {
      logger.error('Error uploading avatar:', error);
      res.status(500).json({ success: false, error: 'Avatar upload failed', details: error.message });
    }
  }
);
