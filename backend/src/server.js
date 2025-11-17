const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const mongoSanitize = require('express-mongo-sanitize');
const hpp = require('hpp');
const http = require('http');
const socketIo = require('socket.io');
const rateLimit = require('express-rate-limit');

require('dotenv').config();

const logger = require('./utils/logger');
const { errorHandler, notFound } = require('./middleware/errorHandler');
const { verifyApiKey } = require('./middleware/auth');
const { initializePool, testConnection } = require('./db');

// Import routes
const arMarkersRouter = require('./routes/arMarkers');
const artworksRouter = require('./routes/artworks');
const communityRouter = require('./routes/community');
const uploadRouter = require('./routes/upload');
const storageRouter = require('./routes/storage');
const authRouter = require('./routes/auth');
const healthRouter = require('./routes/health');
const mockDataRouter = require('./routes/mockData');
const profilesRouter = require('./routes/profiles');
const achievementsRouter = require('./routes/achievements');
const collectionsRouter = require('./routes/collections');
const notificationsRouter = require('./routes/notifications');
const searchRouter = require('./routes/search');
const messagesRouter = require('./routes/messages');
const avatarRouter = require('./routes/avatar');
// Debug router (optional, controlled by env var)
let debugRouter = null;
if (process.env.ENABLE_DEBUG_ENDPOINTS && process.env.ENABLE_DEBUG_ENDPOINTS.toLowerCase() === 'true') {
  const expressDebug = require('express');
  const { verifyToken: verifyTokenMiddleware } = require('./middleware/auth');
  debugRouter = expressDebug.Router();
  debugRouter.get('/token', verifyTokenMiddleware, (req, res) => {
    try {
      // return decoded payload but mask sensitive fields
      const payload = Object.assign({}, req.user || {});
      if (payload.token) delete payload.token;
      res.json({ success: true, payload });
    } catch (e) {
      res.status(500).json({ success: false, error: 'Failed to decode token' });
    }
  });
  app.use('/api/debug', debugRouter);
  logger.info('Debug endpoints enabled: /api/debug/token');
}

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
    methods: ['GET', 'POST'],
  },
});

// Trust proxy (important for rate limiting behind reverse proxy)
app.set('trust proxy', 1);

// Security middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'", 'https://ipfs.io', 'https://gateway.pinata.cloud'],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'", 'https:'],
      frameSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false,
}));

// CORS configuration
const corsOptions = {
  origin: (origin, callback) => {
    const allowedOrigins = (process.env.CORS_ORIGIN || '*').split(',');
    
    if (allowedOrigins.includes('*') || !origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'X-API-KEY'],
  optionsSuccessStatus: 200,
};
app.use(cors(corsOptions));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Upload rate limiting (stricter)
const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: parseInt(process.env.UPLOAD_RATE_LIMIT) || 50,
  message: 'Too many uploads from this IP, please try again later.',
});
app.use('/api/upload', uploadLimiter);

// Body parsing middleware
app.use(express.json({ limit: process.env.JSON_LIMIT || '10mb' }));
app.use(express.urlencoded({ extended: true, limit: process.env.URL_LIMIT || '10mb' }));

// Compression
app.use(compression());

// Data sanitization against NoSQL injection
app.use(mongoSanitize());

// Prevent HTTP Parameter Pollution
app.use(hpp());

// Logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    ip: req.ip,
    userAgent: req.get('user-agent'),
  });
  next();
});

// Serve uploaded files statically (must be before API routes for correct precedence)
const path = require('path');
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
app.use('/profiles/avatars', express.static(path.join(__dirname, '../uploads/profiles/avatars')));
app.use('/profiles/media', express.static(path.join(__dirname, '../uploads/profiles/media')));
app.use('/profiles/posts', express.static(path.join(__dirname, '../uploads/profiles/posts')));

// Health check (no auth required)
app.use('/health', healthRouter);

// API routes
// Debug: verify imported routers are Express routers (log type/info)
const _routeChecks = {
  arMarkersRouter,
  artworksRouter,
  communityRouter,
  uploadRouter,
  storageRouter,
  authRouter,
  healthRouter,
  mockDataRouter,
  profilesRouter,
  achievementsRouter,
  collectionsRouter,
  notificationsRouter,
  searchRouter,
  messagesRouter,
  avatarRouter
};

Object.keys(_routeChecks).forEach((k) => {
  try {
    const val = _routeChecks[k];
    // router.stack exists for express routers
    if (val && typeof val === 'object' && val.stack) {
      console.log(`[route-check] ${k}: router (stack len=${val.stack.length})`);
    } else {
      console.log(`[route-check] ${k}: NOT router -`, typeof val, val && Object.keys(val).slice(0,5));
    }
  } catch (e) {
    console.log('[route-check] error checking', k, e && e.message);
  }
});

app.use('/api/auth', authRouter);
app.use('/api/ar-markers', arMarkersRouter);
app.use('/api/artworks', artworksRouter);
app.use('/api/community', communityRouter);
app.use('/api/upload', uploadRouter);
app.use('/api/storage', storageRouter);
app.use('/api/mock', mockDataRouter);
app.use('/api/profiles', profilesRouter);
app.use('/api/achievements', achievementsRouter);
app.use('/api/collections', collectionsRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/search', searchRouter);
app.use('/api/messages', messagesRouter);
app.use('/api/avatar', avatarRouter);

// API documentation
app.get('/api', (req, res) => {
  res.json({
    name: 'Art.Kubus API',
    version: '1.0.0',
    documentation: '/api/docs',
    endpoints: {
      health: '/health',
      auth: '/api/auth',
      arMarkers: '/api/ar-markers',
      artworks: '/api/artworks',
      community: '/api/community',
      upload: '/api/upload',
      storage: '/api/storage',
      mock: '/api/mock',
      profiles: '/api/profiles',
      achievements: '/api/achievements',
      collections: '/api/collections',
      notifications: '/api/notifications',
      search: '/api/search',
    },
  });
});

// WebSocket connection handling
io.on('connection', (socket) => {
  logger.info(`WebSocket client connected: ${socket.id}`);

  socket.on('subscribe:ar-marker', (markerId) => {
    socket.join(`ar-marker:${markerId}`);
    logger.debug(`Client ${socket.id} subscribed to ar-marker:${markerId}`);
  });

  socket.on('subscribe:artwork', (artworkId) => {
    socket.join(`artwork:${artworkId}`);
    logger.debug(`Client ${socket.id} subscribed to artwork:${artworkId}`);
  });

  // Conversation subscriptions for real-time messaging
  socket.on('subscribe:conversation', (conversationId) => {
    try {
      socket.join(`conversation:${conversationId}`);
      logger.debug(`Client ${socket.id} subscribed to conversation:${conversationId}`);
    } catch (e) {
      logger.warn(`Failed to subscribe socket ${socket.id} to conversation:${conversationId} - ${e.message}`);
    }
  });

  // Subscribe/unsubscribe to personal user room (notifications)
  socket.on('subscribe:user', (walletAddress) => {
    try {
      // Try to validate token from handshake (auth or headers)
      const jwt = require('jsonwebtoken');
      const token = socket.handshake?.auth?.token || (socket.handshake?.headers && socket.handshake.headers.authorization && socket.handshake.headers.authorization.split(' ')[1]);
      if (!token) {
        socket.emit('subscribe:error', { error: 'Authentication token required for subscribe:user' });
        return;
      }

      const secret = process.env.JWT_SECRET || 'dev-secret';
      let decoded = null;
      try {
        decoded = jwt.verify(token, secret);
      } catch (err) {
        socket.emit('subscribe:error', { error: 'Invalid or expired token' });
        return;
      }

      const userWallet = (decoded.walletAddress || decoded.wallet || decoded.sub || '').toString().toLowerCase();
      const requested = (walletAddress || '').toString().toLowerCase();
      if (!userWallet || userWallet !== requested) {
        socket.emit('subscribe:error', { error: 'Wallet address does not match token' });
        return;
      }

      socket.join(`user:${userWallet}`);
      logger.debug(`Client ${socket.id} subscribed to user:${userWallet}`);
      socket.emit('subscribe:ok', { room: `user:${userWallet}` });
    } catch (e) {
      logger.warn(`Failed to subscribe socket ${socket.id} to user room - ${e.message}`);
      socket.emit('subscribe:error', { error: e.message });
    }
  });

  socket.on('unsubscribe:user', (walletAddress) => {
    try {
      const nid = (walletAddress || '').toString().toLowerCase();
      socket.leave(`user:${nid}`);
      logger.debug(`Client ${socket.id} unsubscribed from user:${nid}`);
      socket.emit('subscribe:ok', { room: `user:${nid}`, unsubscribed: true });
    } catch (e) {
      logger.warn(`Failed to unsubscribe socket ${socket.id} from user room - ${e.message}`);
    }
  });

  socket.on('leave:conversation', (conversationId) => {
    try {
      socket.leave(`conversation:${conversationId}`);
      logger.debug(`Client ${socket.id} left conversation:${conversationId}`);
    } catch (e) {
      logger.warn(`Failed to remove socket ${socket.id} from conversation:${conversationId} - ${e.message}`);
    }
  });

  socket.on('disconnect', () => {
    logger.info(`WebSocket client disconnected: ${socket.id}`);
  });
});

// Make io available to routes
app.set('io', io);

// 404 handler
app.use(notFound);

// Error handler (must be last)
app.use(errorHandler);

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

const PORT = process.env.PORT || 3000;

// Initialize database and start server
async function startServer() {
  try {
    // Initialize database connection
    if (process.env.DATABASE_URL) {
      logger.info('Initializing database connection...');
      initializePool();
      const dbConnected = await testConnection();
      
      if (dbConnected) {
        logger.info('✅ Database connected successfully');
      } else {
        logger.warn('⚠️  Database connection failed - running without database');
      }
    } else {
      logger.warn('⚠️  DATABASE_URL not set - running without database');
    }

    // Start HTTP server
    server.listen(PORT, () => {
      logger.info(`🚀 Server running on port ${PORT} in ${process.env.NODE_ENV || 'development'} mode`);
      logger.info(`📡 CORS origin: ${process.env.CORS_ORIGIN || '*'}`);
      logger.info(`💾 Storage provider: ${process.env.DEFAULT_STORAGE_PROVIDER || 'hybrid'}`);
      logger.info(`🔐 Mock data: ${process.env.USE_MOCK_DATA === 'true' ? 'ENABLED' : 'DISABLED'}`);
    });
  } catch (error) {
    logger.error('Failed to start server', { error: error.message });
    process.exit(1);
  }
}

startServer();

module.exports = { app, server, io };
