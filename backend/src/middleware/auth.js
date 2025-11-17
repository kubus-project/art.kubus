const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

/**
 * Verify JWT token
 */
const verifyToken = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const token = authHeader?.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    logger.debug('Auth middleware: missing Authorization header');
    return res.status(401).json({
      success: false,
      error: 'Authentication required',
    });
  }

  try {
    const secret = process.env.JWT_SECRET || 'dev-secret';
    const decoded = jwt.verify(token, secret);
    // Log the decoded payload keys for diagnostics (don't log the token itself)
    try {
      const keys = Object.keys(decoded);
      const walletKey = decoded.walletAddress || decoded.wallet || decoded.id || decoded.email || null;
      logger.debug(`Auth middleware: token verified. payloadKeys=${JSON.stringify(keys)}, userKey=${walletKey}`);
    } catch (e) {
      logger.debug('Auth middleware: token verified but failed to parse payload details');
    }
    req.user = decoded;
    // If debug endpoints enabled, expose a masked user header so clients can detect successful verification
    if (process.env.ENABLE_DEBUG_ENDPOINTS && process.env.ENABLE_DEBUG_ENDPOINTS.toLowerCase() === 'true') {
      try {
        const userKey = (decoded.walletAddress || decoded.wallet || decoded.id || decoded.email || 'unknown').toString();
        // Keep masked: show only last 6 characters
        const masked = userKey.length > 6 ? `***${userKey.slice(-6)}` : userKey;
        res.set('X-Auth-User', masked);
      } catch (e) { /* no-op */ }
    }
    next();
  } catch (error) {
    logger.warn(`Invalid token: ${error.message}`);
    return res.status(401).json({
      success: false,
      error: 'Invalid or expired token',
    });
  }
};

/**
 * Verify API key (for service-to-service authentication)
 */
const verifyApiKey = (req, res, next) => {
  const apiKey = req.headers['x-api-key'];

  if (!apiKey) {
    return res.status(401).json({
      success: false,
      error: 'API key required',
    });
  }

  // In production, validate against database or environment variable
  const validApiKeys = (process.env.API_KEYS || '').split(',').filter(Boolean);

  if (!validApiKeys.includes(apiKey)) {
    logger.warn(`Invalid API key attempt from IP: ${req.ip}`);
    return res.status(403).json({
      success: false,
      error: 'Invalid API key',
    });
  }

  next();
};

/**
 * Optional authentication (allows both authenticated and anonymous requests)
 */
const optionalAuth = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];

  if (token) {
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = decoded;
    } catch (error) {
      // Invalid token, but we allow request to continue
      logger.debug(`Optional auth failed: ${error.message}`);
    }
  }

  next();
};

/**
 * Check if user has required role
 */
const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Authentication required',
      });
    }

    if (!roles.includes(req.user.role)) {
      logger.warn(`Access denied for user ${req.user.id} - required roles: ${roles.join(', ')}`);
      return res.status(403).json({
        success: false,
        error: 'Insufficient permissions',
      });
    }

    next();
  };
};

/**
 * Rate limit by user ID or IP
 */
const createUserRateLimit = (maxRequests, windowMs) => {
  const requests = new Map();

  return (req, res, next) => {
    const identifier = req.user?.id || req.ip;
    const now = Date.now();
    const windowStart = now - windowMs;

    if (!requests.has(identifier)) {
      requests.set(identifier, []);
    }

    const userRequests = requests.get(identifier);
    
    // Remove old requests outside the window
    const recentRequests = userRequests.filter(time => time > windowStart);
    requests.set(identifier, recentRequests);

    if (recentRequests.length >= maxRequests) {
      return res.status(429).json({
        success: false,
        error: 'Rate limit exceeded',
        retryAfter: Math.ceil((recentRequests[0] + windowMs - now) / 1000),
      });
    }

    recentRequests.push(now);
    next();
  };
};

module.exports = {
  verifyToken,
  verifyApiKey,
  optionalAuth,
  requireRole,
  createUserRateLimit,
};
