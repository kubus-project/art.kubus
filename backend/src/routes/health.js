const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const storageService = require('../services/storageService');

const router = express.Router();

/**
 * @route   GET /health
 * @desc    Health check endpoint
 * @access  Public
 */
router.get('/', asyncHandler(async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    storage: {
      provider: storageService.getProvider(),
    },
  };

  // Test IPFS gateway if using IPFS
  if (storageService.getProvider() === 'ipfs' || storageService.getProvider() === 'hybrid') {
    const ipfsHealthy = await storageService.testIPFSGateway(storageService.ipfsGateways[0]);
    health.storage.ipfsGateway = ipfsHealthy ? 'healthy' : 'unhealthy';
  }

  res.json(health);
}));

/**
 * @route   GET /health/ready
 * @desc    Readiness probe for Kubernetes/Docker
 * @access  Public
 */
router.get('/ready', (req, res) => {
  // Check if all required services are ready
  const isReady = true; // Add actual readiness checks here
  
  if (isReady) {
    res.status(200).json({ ready: true });
  } else {
    res.status(503).json({ ready: false });
  }
});

/**
 * @route   GET /health/live
 * @desc    Liveness probe for Kubernetes/Docker
 * @access  Public
 */
router.get('/live', (req, res) => {
  res.status(200).json({ alive: true });
});

module.exports = router;
