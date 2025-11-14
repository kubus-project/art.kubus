const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const { verifyToken, optionalAuth } = require('../middleware/auth');
const storageService = require('../services/storageService');

const router = express.Router();

/**
 * @route   GET /api/storage/info
 * @desc    Get storage configuration info
 * @access  Public
 */
router.get('/info', asyncHandler(async (req, res) => {
  res.json({
    success: true,
    data: {
      provider: storageService.getProvider(),
      ipfsEnabled: storageService.getProvider() !== 'http',
      httpEnabled: storageService.getProvider() !== 'ipfs',
      ipfsGateways: storageService.ipfsGateways,
    },
  });
}));

/**
 * @route   GET /api/storage/stats
 * @desc    Get storage statistics
 * @access  Private (Admin only)
 */
router.get('/stats', verifyToken, asyncHandler(async (req, res) => {
  const stats = await storageService.getStats();
  
  res.json({
    success: true,
    data: stats,
  });
}));

/**
 * @route   POST /api/storage/test-gateway
 * @desc    Test IPFS gateway availability
 * @access  Public
 */
router.post('/test-gateway', asyncHandler(async (req, res) => {
  const { gateway } = req.body;
  
  if (!gateway) {
    return res.status(400).json({
      success: false,
      error: 'Gateway URL required',
    });
  }

  const isHealthy = await storageService.testIPFSGateway(gateway);
  
  res.json({
    success: true,
    data: {
      gateway,
      healthy: isHealthy,
      testedAt: new Date().toISOString(),
    },
  });
}));

module.exports = router;
