const express = require('express');
const { asyncHandler } = require('../middleware/errorHandler');
const { verifyToken, optionalAuth } = require('../middleware/auth');
const { arMarkerValidation, sanitizeInput } = require('../middleware/validation');
const logger = require('../utils/logger');
const { query } = require('../db');

const router = express.Router();

// Temporary in-memory storage (replace with PostgreSQL in production)
const markers = new Map();

/**
 * @route   GET /api/ar-markers
 * @desc    Get AR markers by location
 * @access  Public
 */
router.get(
  '/',
  optionalAuth,
  arMarkerValidation.getNearby,
  asyncHandler(async (req, res) => {
    const { lat, lng, radius = 1 } = req.query;
    
    // Geospatial query using ST_Distance for proximity search
    // radius is in kilometers, convert to meters for comparison
    const result = await query(
      `SELECT 
        m.id, m.artwork_id, m.marker_type, m.marker_data,
        m.latitude, m.longitude, m.altitude, m.activation_radius,
        m.position_x, m.position_y, m.position_z,
        m.rotation_x, m.rotation_y, m.rotation_z, m.scale,
        m.is_active, m.activation_count, m.last_activated,
        m.created_at, m.updated_at,
        a.title as artwork_title, a.image_url as artwork_image,
        a.model_3d_url, a.model_3d_cid,
        (
          6371 * acos(
            cos(radians($1)) * cos(radians(m.latitude)) *
            cos(radians(m.longitude) - radians($2)) +
            sin(radians($1)) * sin(radians(m.latitude))
          )
        ) AS distance
      FROM ar_markers m
      LEFT JOIN artworks a ON m.artwork_id = a.id
      WHERE m.is_active = true
      AND (
        6371 * acos(
          cos(radians($1)) * cos(radians(m.latitude)) *
          cos(radians(m.longitude) - radians($2)) +
          sin(radians($1)) * sin(radians(m.latitude))
        )
      ) <= $3
      ORDER BY distance
      LIMIT 100`,
      [parseFloat(lat), parseFloat(lng), parseFloat(radius)]
    );
    
    const nearbyMarkers = result.rows.map(row => ({
      id: row.id,
      artworkId: row.artwork_id,
      markerType: row.marker_type,
      markerData: row.marker_data,
      location: {
        latitude: parseFloat(row.latitude),
        longitude: parseFloat(row.longitude),
        altitude: row.altitude ? parseFloat(row.altitude) : null
      },
      activationRadius: parseFloat(row.activation_radius),
      transform: {
        position: {
          x: parseFloat(row.position_x),
          y: parseFloat(row.position_y),
          z: parseFloat(row.position_z)
        },
        rotation: {
          x: parseFloat(row.rotation_x),
          y: parseFloat(row.rotation_y),
          z: parseFloat(row.rotation_z)
        },
        scale: parseFloat(row.scale)
      },
      artwork: row.artwork_title ? {
        title: row.artwork_title,
        imageUrl: row.artwork_image,
        model3dUrl: row.model_3d_url,
        model3dCid: row.model_3d_cid
      } : null,
      distance: parseFloat(row.distance),
      activationCount: row.activation_count,
      lastActivated: row.last_activated,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    }));
    
    logger.info(`Found ${nearbyMarkers.length} AR markers within ${radius}km of (${lat}, ${lng})`);
    
    res.json({
      success: true,
      count: nearbyMarkers.length,
      data: nearbyMarkers,
    });
  })
);

/**
 * @route   POST /api/ar-markers
 * @desc    Create new AR marker
 * @access  Private
 */
router.post(
  '/',
  verifyToken,
  sanitizeInput,
  arMarkerValidation.create,
  asyncHandler(async (req, res) => {
    const marker = {
      id: `marker_${Date.now()}`,
      ...req.body,
      createdBy: req.user.id,
      createdAt: new Date().toISOString(),
      interactionCount: 0,
      viewCount: 0,
    };

    markers.set(marker.id, marker);

    // Emit WebSocket event
    const io = req.app.get('io');
    io.emit('ar-marker:created', marker);

    logger.info(`AR marker created: ${marker.name} by ${req.user.id}`);

    res.status(201).json({
      success: true,
      message: 'AR marker created successfully',
      data: marker,
    });
  })
);

/**
 * @route   GET /api/ar-markers/:id
 * @desc    Get AR marker by ID
 * @access  Public
 */
router.get(
  '/:id',
  arMarkerValidation.getById,
  asyncHandler(async (req, res) => {
    const marker = markers.get(req.params.id);

    if (!marker) {
      return res.status(404).json({
        success: false,
        error: 'AR marker not found',
      });
    }

    res.json({
      success: true,
      data: marker,
    });
  })
);

/**
 * @route   PUT /api/ar-markers/:id
 * @desc    Update AR marker
 * @access  Private
 */
router.put(
  '/:id',
  verifyToken,
  sanitizeInput,
  arMarkerValidation.update,
  asyncHandler(async (req, res) => {
    const marker = markers.get(req.params.id);

    if (!marker) {
      return res.status(404).json({
        success: false,
        error: 'AR marker not found',
      });
    }

    // Check ownership
    if (marker.createdBy !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        error: 'Not authorized to update this marker',
      });
    }

    const updatedMarker = {
      ...marker,
      ...req.body,
      updatedAt: new Date().toISOString(),
    };

    markers.set(marker.id, updatedMarker);

    logger.info(`AR marker updated: ${marker.id}`);

    res.json({
      success: true,
      message: 'AR marker updated successfully',
      data: updatedMarker,
    });
  })
);

/**
 * @route   DELETE /api/ar-markers/:id
 * @desc    Delete AR marker
 * @access  Private
 */
router.delete(
  '/:id',
  verifyToken,
  asyncHandler(async (req, res) => {
    const marker = markers.get(req.params.id);

    if (!marker) {
      return res.status(404).json({
        success: false,
        error: 'AR marker not found',
      });
    }

    // Check ownership
    if (marker.createdBy !== req.user.id && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        error: 'Not authorized to delete this marker',
      });
    }

    markers.delete(req.params.id);

    logger.info(`AR marker deleted: ${req.params.id}`);

    res.json({
      success: true,
      message: 'AR marker deleted successfully',
    });
  })
);

module.exports = router;
