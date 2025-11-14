const express = require('express');
const router = express.Router();
const logger = require('../utils/logger');

// Check if mock data is enabled via environment variable
const isMockDataEnabled = process.env.USE_MOCK_DATA === 'true';

// Middleware to check if mock data is enabled
const checkMockDataEnabled = (req, res, next) => {
  if (!isMockDataEnabled) {
    return res.status(403).json({ 
      error: 'Mock data endpoints are disabled',
      message: 'Set USE_MOCK_DATA=true in environment variables to enable'
    });
  }
  next();
};

// Apply middleware to all mock routes
router.use(checkMockDataEnabled);

// ============================================
// MOCK ARTWORKS
// ============================================
router.get('/artworks', (req, res) => {
  logger.info('Serving mock artworks data');
  
  const artworks = generateMockArtworks();
  
  res.json({
    success: true,
    count: artworks.length,
    data: artworks,
    meta: {
      source: 'mock',
      timestamp: new Date().toISOString()
    }
  });
});

// ============================================
// MOCK AR MARKERS
// ============================================
router.get('/ar-markers', (req, res) => {
  logger.info('Serving mock AR markers data');
  
  const markers = generateMockARMarkers();
  
  res.json({
    success: true,
    count: markers.length,
    data: markers,
    meta: {
      source: 'mock',
      timestamp: new Date().toISOString()
    }
  });
});

// ============================================
// MOCK COMMUNITY POSTS
// ============================================
router.get('/community-posts', (req, res) => {
  logger.info('Serving mock community posts data');
  
  const posts = generateMockCommunityPosts();
  
  res.json({
    success: true,
    count: posts.length,
    data: posts,
    meta: {
      source: 'mock',
      timestamp: new Date().toISOString()
    }
  });
});

// ============================================
// MOCK INSTITUTIONS
// ============================================
router.get('/institutions', (req, res) => {
  logger.info('Serving mock institutions data');
  
  const institutions = generateMockInstitutions();
  
  res.json({
    success: true,
    count: institutions.length,
    data: institutions,
    meta: {
      source: 'mock',
      timestamp: new Date().toISOString()
    }
  });
});

// ============================================
// MOCK DAOS
// ============================================
router.get('/daos', (req, res) => {
  logger.info('Serving mock DAOs data');
  
  const daos = generateMockDAOs();
  
  res.json({
    success: true,
    count: daos.length,
    data: daos,
    meta: {
      source: 'mock',
      timestamp: new Date().toISOString()
    }
  });
});

// ============================================
// MOCK WALLET DATA
// ============================================
router.get('/wallet', (req, res) => {
  logger.info('Serving mock wallet data');
  
  const wallet = generateMockWallet();
  
  res.json({
    success: true,
    data: wallet,
    meta: {
      source: 'mock',
      timestamp: new Date().toISOString()
    }
  });
});

// ============================================
// MOCK TRANSACTIONS
// ============================================
router.get('/transactions', (req, res) => {
  logger.info('Serving mock transactions data');
  
  const transactions = generateMockTransactions();
  
  res.json({
    success: true,
    count: transactions.length,
    data: transactions,
    meta: {
      source: 'mock',
      timestamp: new Date().toISOString()
    }
  });
});

// ============================================
// MOCK DATA GENERATORS
// ============================================

function generateMockArtworks() {
  return [
    {
      id: '1',
      title: 'Digital Renaissance',
      artist: 'Maya Chen',
      artistId: 'artist_maya_chen',
      description: 'A fusion of classical art and augmented reality',
      imageUrl: 'https://picsum.photos/seed/art1/800/600',
      location: {
        latitude: 46.0569,
        longitude: 14.5058,
        address: 'Ljubljana, Slovenia'
      },
      arEnabled: true,
      arMarkerId: 'marker_1',
      model3DCID: 'QmX1234abcd',
      model3DURL: 'https://ipfs.io/ipfs/QmX1234abcd',
      arScale: 1.5,
      status: 'active',
      tags: ['digital', 'AR', 'renaissance'],
      likesCount: 234,
      viewsCount: 1580,
      commentsCount: 45,
      discoveryCount: 89,
      createdAt: new Date('2024-01-15').toISOString(),
      updatedAt: new Date().toISOString()
    },
    {
      id: '2',
      title: 'Urban Echoes',
      artist: 'Alex Rivera',
      artistId: 'artist_alex_rivera',
      description: 'Street art meets blockchain technology',
      imageUrl: 'https://picsum.photos/seed/art2/800/600',
      location: {
        latitude: 46.0512,
        longitude: 14.5055,
        address: 'Prešeren Square, Ljubljana'
      },
      arEnabled: true,
      arMarkerId: 'marker_2',
      model3DCID: 'QmY5678efgh',
      model3DURL: 'https://ipfs.io/ipfs/QmY5678efgh',
      arScale: 2.0,
      status: 'active',
      tags: ['street-art', 'AR', 'urban'],
      likesCount: 567,
      viewsCount: 3420,
      commentsCount: 89,
      discoveryCount: 234,
      createdAt: new Date('2024-02-20').toISOString(),
      updatedAt: new Date().toISOString()
    },
    // Add more mock artworks as needed
  ];
}

function generateMockARMarkers() {
  return [
    {
      id: 'marker_1',
      artworkId: '1',
      position: {
        latitude: 46.0569,
        longitude: 14.5058
      },
      activationRadius: 50,
      name: 'Digital Renaissance Marker',
      status: 'active',
      createdAt: new Date('2024-01-15').toISOString()
    },
    {
      id: 'marker_2',
      artworkId: '2',
      position: {
        latitude: 46.0512,
        longitude: 14.5055
      },
      activationRadius: 75,
      name: 'Urban Echoes Marker',
      status: 'active',
      createdAt: new Date('2024-02-20').toISOString()
    }
  ];
}

function generateMockCommunityPosts() {
  return [
    {
      id: 'post_1',
      authorId: 'user_maya',
      authorName: 'Maya Chen',
      content: 'Just discovered an amazing AR artwork in Ljubljana! The way it blends with the architecture is incredible. 🎨✨',
      imageUrl: 'https://picsum.photos/seed/post1/800/600',
      timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
      tags: ['AR', 'Ljubljana', 'discovery'],
      likeCount: 89,
      commentCount: 23,
      shareCount: 12,
      viewCount: 456,
      isLiked: false,
      isBookmarked: false
    },
    {
      id: 'post_2',
      authorId: 'user_alex',
      authorName: 'Alex Rivera',
      content: 'New street art installation live! Come check it out at Prešeren Square. Bringing blockchain to the streets! 🚀',
      imageUrl: 'https://picsum.photos/seed/post2/800/600',
      timestamp: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString(),
      tags: ['street-art', 'blockchain', 'Ljubljana'],
      likeCount: 234,
      commentCount: 67,
      shareCount: 45,
      viewCount: 1234,
      isLiked: true,
      isBookmarked: false
    }
  ];
}

function generateMockInstitutions() {
  return [
    {
      id: 'inst_1',
      name: 'Ljubljana Modern Gallery',
      type: 'gallery',
      description: 'Leading contemporary art gallery in Slovenia',
      location: {
        latitude: 46.0504,
        longitude: 14.5061,
        address: 'Cankarjeva cesta 15, Ljubljana'
      },
      website: 'https://www.mg-lj.si',
      verified: true,
      artworksCount: 45,
      followersCount: 1234,
      createdAt: new Date('2023-01-01').toISOString()
    },
    {
      id: 'inst_2',
      name: 'Art.Kubus Community Space',
      type: 'community',
      description: 'Web3-powered art community and exhibition space',
      location: {
        latitude: 46.0519,
        longitude: 14.5066,
        address: 'Mestni trg 1, Ljubljana'
      },
      website: 'https://art.kubus.site',
      verified: true,
      artworksCount: 89,
      followersCount: 3456,
      createdAt: new Date('2024-01-01').toISOString()
    }
  ];
}

function generateMockDAOs() {
  return [
    {
      id: 'dao_1',
      name: 'Art.Kubus DAO',
      description: 'Decentralized governance for the Art.Kubus platform',
      tokenSymbol: 'KUB8',
      totalMembers: 2456,
      treasuryBalance: 125000,
      activeProposals: 7,
      completedProposals: 23,
      createdAt: new Date('2024-01-01').toISOString()
    }
  ];
}

function generateMockWallet() {
  return {
    id: 'wallet_demo',
    address: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
    network: 'Solana',
    balance: {
      SOL: 2.5,
      KUB8: 150.0,
      USDC: 100.0
    },
    tokens: [
      {
        id: 'token_sol',
        name: 'Solana',
        symbol: 'SOL',
        balance: 2.5,
        value: 250.0,
        decimals: 9,
        logoUrl: 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/So11111111111111111111111111111111111111112/logo.png'
      },
      {
        id: 'token_kub8',
        name: 'Kubus Token',
        symbol: 'KUB8',
        balance: 150.0,
        value: 15.0,
        decimals: 6,
        logoUrl: 'https://art.kubus.site/assets/kub8-logo.png'
      },
      {
        id: 'token_usdc',
        name: 'USD Coin',
        symbol: 'USDC',
        balance: 100.0,
        value: 100.0,
        decimals: 6,
        logoUrl: 'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v/logo.png'
      }
    ],
    totalValue: 365.0,
    lastUpdated: new Date().toISOString()
  };
}

function generateMockTransactions() {
  return [
    {
      id: 'tx_1',
      type: 'send',
      token: 'SOL',
      amount: 0.5,
      fromAddress: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
      toAddress: '9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM',
      timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
      status: 'confirmed',
      txHash: '3KqMXYzKr6NfJM8xqoVD2K9gYU2gBjKLPQN9vZrPXBj2',
      gasUsed: 5000,
      gasFee: 0.000005
    },
    {
      id: 'tx_2',
      type: 'receive',
      token: 'KUB8',
      amount: 25.0,
      fromAddress: '5QqMXYzKr6NfJM8xqoVD2K9gYU2gBjKLPQN9vZrPXBj4',
      toAddress: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
      timestamp: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
      status: 'confirmed',
      txHash: '2JpLXYzKr6NfJM8xqoVD2K9gYU2gBjKLPQN9vZrPXBj1',
      gasUsed: 3000,
      gasFee: 0.000003,
      metadata: {
        type: 'reward',
        reason: 'Artwork discovery achievement'
      }
    }
  ];
}

module.exports = router;
