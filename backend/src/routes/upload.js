const express = require('express');
const multer = require('multer');
const { asyncHandler } = require('../middleware/errorHandler');
const { verifyToken, createUserRateLimit } = require('../middleware/auth');
const { uploadValidation, sanitizeInput } = require('../middleware/validation');
const storageService = require('../services/storageService');
const logger = require('../utils/logger');

const router = express.Router();

// Configure multer for memory storage
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: parseInt(process.env.MAX_UPLOAD_SIZE) || 50 * 1024 * 1024, // 50MB default
  },
  fileFilter: (req, file, cb) => {
    // Allowed file types for AR content, images, and videos
    const allowedTypes = [
      'model/gltf-binary',
      'model/gltf+json',
      'application/octet-stream',
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/gif',
      'video/mp4',
      'video/quicktime',
      'video/x-msvideo',
      'video/webm',
    ];

    const allowedExtensions = ['.glb', '.gltf', '.usdz', '.jpg', '.jpeg', '.png', '.webp', '.gif', '.mp4', '.mov', '.avi', '.webm'];
    const ext = file.originalname.toLowerCase().slice(file.originalname.lastIndexOf('.'));

    if (allowedTypes.includes(file.mimetype) || allowedExtensions.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error(`File type not allowed. Allowed types: ${allowedExtensions.join(', ')}`));
    }
  },
});

// Additional rate limiting for uploads
const uploadRateLimit = createUserRateLimit(10, 60 * 60 * 1000); // 10 uploads per hour per user

/**
 * @route   POST /api/upload
 * @desc    Upload file to storage (IPFS/HTTP)
 * @access  Private
 */
router.post(
  '/',
  verifyToken,
  uploadRateLimit,
  upload.single('file'),
  sanitizeInput,
  uploadValidation.file,
  asyncHandler(async (req, res) => {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        error: 'No file provided',
      });
    }

    const { buffer, originalname, mimetype, size } = req.file;
    const targetStorage = req.body.targetStorage || 'hybrid';
    const fileType = req.body.fileType || 'general'; // 'image', 'video', 'avatar', 'model', etc.
    const metadata = req.body.metadata ? JSON.parse(req.body.metadata) : {};

    logger.info(`Upload request: ${originalname} (${size} bytes, type: ${fileType}) to ${targetStorage}`);

    // Determine upload folder based on fileType
    let uploadFolder = '';
    if (fileType === 'avatar') {
      uploadFolder = 'profiles/avatars';
    } else if (fileType === 'post-image' || fileType === 'post-video') {
      uploadFolder = 'profiles/posts';
    } else if (fileType === 'image' || fileType === 'video') {
      uploadFolder = 'profiles/media';
    } else if (fileType === 'model') {
      uploadFolder = 'ar/models';
    }

    logger.info(`Determined uploadFolder: "${uploadFolder}" for fileType: "${fileType}"`);

    // Add user info and folder to metadata
    metadata.uploadedBy = req.user.id;
    metadata.uploadedAt = new Date().toISOString();
    metadata.mimetype = mimetype;
    metadata.originalName = originalname;
    metadata.fileType = fileType;
    if (uploadFolder) {
      metadata.uploadFolder = uploadFolder;
    }
    
    logger.info(`Metadata before upload:`, JSON.stringify(metadata));

    try {
      // Temporarily override storage provider if specified
      const originalProvider = storageService.getProvider();
      if (targetStorage === 'both') {
        storageService.setProvider('hybrid');
      } else if (targetStorage !== originalProvider) {
        storageService.setProvider(targetStorage);
      }

      const result = await storageService.uploadFile(buffer, originalname, metadata);

      // Restore original provider
      storageService.setProvider(originalProvider);

      // Normalize URL like avatar upload does - ensure absolute HTTP URL
      let finalUrl = result.url || result.ipfsUrl || result.path || null;
      
      if (finalUrl && !/^https?:\/\//i.test(finalUrl)) {
        // If backend returned a filesystem path, convert to HTTP URL
        const path = require('path');
        const fileName = path.basename(String(finalUrl));
        const httpBase = (storageService.httpBaseUrl || process.env.HTTP_BASE_URL || '').replace(/\/$/, '');
        
        if (httpBase && uploadFolder) {
          finalUrl = `${httpBase}/${uploadFolder}/${fileName}`;
        } else if (httpBase) {
          finalUrl = `${httpBase}/${fileName}`;
        }
      }

      // Emit WebSocket event
      const io = req.app.get('io');
      io.emit('upload:complete', {
        filename: originalname,
        url: finalUrl,
        ...result,
      });

      res.json({
        success: true,
        message: 'File uploaded successfully',
        data: {
          filename: originalname,
          size,
          mimetype,
          url: finalUrl, // Return normalized URL
          ...result,
        },
      });
    } catch (error) {
      logger.error('Upload failed:', error);
      res.status(500).json({
        success: false,
        error: 'Upload failed',
        details: error.message,
      });
    }
  })
);

/**
 * @route   POST /api/upload/multiple
 * @desc    Upload multiple files
 * @access  Private
 */
router.post(
  '/multiple',
  verifyToken,
  uploadRateLimit,
  upload.array('files', 10), // Max 10 files
  sanitizeInput,
  asyncHandler(async (req, res) => {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No files provided',
      });
    }

    const targetStorage = req.body.targetStorage || 'hybrid';
    const baseMetadata = req.body.metadata ? JSON.parse(req.body.metadata) : {};
    const results = [];

    for (const file of req.files) {
      try {
        const metadata = {
          ...baseMetadata,
          uploadedBy: req.user.id,
          uploadedAt: new Date().toISOString(),
          mimetype: file.mimetype,
          originalName: file.originalname,
        };

        const result = await storageService.uploadFile(file.buffer, file.originalname, metadata);
        results.push({
          filename: file.originalname,
          success: true,
          ...result,
        });
      } catch (error) {
        logger.error(`Failed to upload ${file.originalname}:`, error);
        results.push({
          filename: file.originalname,
          success: false,
          error: error.message,
        });
      }
    }

    const successCount = results.filter(r => r.success).length;

    res.json({
      success: successCount > 0,
      message: `${successCount}/${req.files.length} files uploaded successfully`,
      data: results,
    });
  })
);

/**
 * @route   GET /api/upload/:identifier
 * @desc    Get uploaded file
 * @access  Public
 */
router.get(
  '/:identifier',
  asyncHandler(async (req, res) => {
    const { identifier } = req.params;
    const storageType = req.query.type || 'auto';

    try {
      const fileData = await storageService.getFile(identifier, storageType);
      
      // Set appropriate headers
      res.setHeader('Content-Type', 'application/octet-stream');
      res.setHeader('Cache-Control', 'public, max-age=31536000'); // 1 year
      
      res.send(fileData);
    } catch (error) {
      logger.error(`Failed to retrieve file ${identifier}:`, error);
      res.status(404).json({
        success: false,
        error: 'File not found',
      });
    }
  })
);

module.exports = router;
