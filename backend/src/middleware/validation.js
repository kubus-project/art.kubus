const { body, param, query, validationResult } = require('express-validator');

/**
 * Validation middleware to check for errors
 */
const validate = (req, res, next) => {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: errors.array().map(err => ({
        field: err.path,
        message: err.msg,
        value: err.value,
      })),
    });
  }
  
  next();
};

/**
 * AR Marker validation rules
 */
const arMarkerValidation = {
  create: [
    body('name')
      .trim()
      .notEmpty().withMessage('Name is required')
      .isLength({ min: 3, max: 100 }).withMessage('Name must be 3-100 characters'),
    body('description')
      .trim()
      .optional()
      .isLength({ max: 500 }).withMessage('Description must be max 500 characters'),
    body('position.lat')
      .isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
    body('position.lng')
      .isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
    body('artworkId')
      .notEmpty().withMessage('Artwork ID is required')
      .isUUID().withMessage('Invalid artwork ID'),
    body('modelCID')
      .optional()
      .matches(/^Qm[a-zA-Z0-9]{44}$/).withMessage('Invalid IPFS CID'),
    body('modelURL')
      .optional()
      .isURL().withMessage('Invalid URL'),
    body('scale')
      .optional()
      .isFloat({ min: 0.1, max: 10 }).withMessage('Scale must be between 0.1 and 10'),
    body('storageProvider')
      .optional()
      .isIn(['ipfs', 'http', 'hybrid']).withMessage('Invalid storage provider'),
    validate,
  ],
  
  update: [
    param('id').isUUID().withMessage('Invalid marker ID'),
    body('name')
      .optional()
      .trim()
      .isLength({ min: 3, max: 100 }).withMessage('Name must be 3-100 characters'),
    body('scale')
      .optional()
      .isFloat({ min: 0.1, max: 10 }).withMessage('Scale must be between 0.1 and 10'),
    validate,
  ],
  
  getById: [
    param('id').isUUID().withMessage('Invalid marker ID'),
    validate,
  ],
  
  getNearby: [
    query('lat')
      .isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
    query('lng')
      .isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
    query('radius')
      .optional()
      .isFloat({ min: 0.1, max: 100 }).withMessage('Radius must be between 0.1 and 100 km'),
    validate,
  ],
};

/**
 * Upload validation rules
 */
const uploadValidation = {
  file: [
    body('targetStorage')
      .optional()
      .isIn(['ipfs', 'http', 'both']).withMessage('Invalid target storage'),
    body('metadata')
      .optional()
      .custom((value) => {
        try {
          if (typeof value === 'string') {
            JSON.parse(value);
          }
          return true;
        } catch {
          throw new Error('Invalid JSON metadata');
        }
      }),
    validate,
  ],
};

/**
 * Artwork validation rules
 */
const artworkValidation = {
  create: [
    body('title')
      .trim()
      .notEmpty().withMessage('Title is required')
      .isLength({ min: 3, max: 200 }).withMessage('Title must be 3-200 characters'),
    body('artist')
      .trim()
      .notEmpty().withMessage('Artist is required')
      .isLength({ max: 100 }).withMessage('Artist name must be max 100 characters'),
    body('description')
      .trim()
      .optional()
      .isLength({ max: 2000 }).withMessage('Description must be max 2000 characters'),
    body('position.lat')
      .isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
    body('position.lng')
      .isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
    body('category')
      .notEmpty().withMessage('Category is required')
      .isIn(['sculpture', 'painting', 'installation', 'digital', 'street', 'other'])
      .withMessage('Invalid category'),
    body('rarity')
      .optional()
      .isIn(['common', 'rare', 'epic', 'legendary']).withMessage('Invalid rarity'),
    validate,
  ],
};

/**
 * Community post validation rules
 */
const communityValidation = {
  create: [
    body('content')
      .trim()
      .notEmpty().withMessage('Content is required')
      .isLength({ min: 1, max: 1000 }).withMessage('Content must be 1-1000 characters'),
    body('artworkId')
      .optional()
      .isUUID().withMessage('Invalid artwork ID'),
    body('tags')
      .optional()
      .isArray().withMessage('Tags must be an array')
      .custom((tags) => {
        return tags.every(tag => typeof tag === 'string' && tag.length <= 50);
      }).withMessage('Each tag must be a string with max 50 characters'),
    validate,
  ],
};

/**
 * Sanitize input to prevent XSS
 */
const sanitizeInput = (req, res, next) => {
  const sanitize = (obj) => {
    for (const key in obj) {
      if (typeof obj[key] === 'string') {
        // Remove potentially dangerous HTML/script tags
        obj[key] = obj[key]
          .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
          .replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, '')
          .trim();
      } else if (typeof obj[key] === 'object' && obj[key] !== null) {
        sanitize(obj[key]);
      }
    }
  };

  sanitize(req.body);
  sanitize(req.query);
  sanitize(req.params);
  
  next();
};

module.exports = {
  validate,
  arMarkerValidation,
  uploadValidation,
  artworkValidation,
  communityValidation,
  sanitizeInput,
};
