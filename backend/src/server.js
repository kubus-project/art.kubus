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

// Health check (no auth required)
app.use('/health', healthRouter);

// API routes
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
