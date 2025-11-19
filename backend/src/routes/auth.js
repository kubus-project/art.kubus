const express = require('express');
const jwt = require('jsonwebtoken');
const nacl = require('tweetnacl');
const bs58 = require('bs58');
const bcrypt = require('bcryptjs');
const { asyncHandler } = require('../middleware/errorHandler');
const { body } = require('express-validator');
const { validate } = require('../middleware/validation');
const logger = require('../utils/logger');
const { generateUsername } = require('../utils/usernameGenerator');
const { query, getClient } = require('../db');

const router = express.Router();

// In-memory challenge store: walletAddress -> { message, expiresAt }
const challenges = new Map();

const CHALLENGE_EXPIRY_MS = parseInt(process.env.CHALLENGE_EXPIRY_MS) || 5 * 60 * 1000; // 5 minutes

// Temporary in-memory user storage (replace with database in production)
const users = new Map();

/**
 * @route   POST /api/auth/register
 * @desc    Register new user
 * @access  Public
 */
router.post(
  '/register',
  [
    // Wallet address required for registration (accounts are blockchain-based)
    body('walletAddress').trim().isLength({ min: 3, max: 255 }).withMessage('walletAddress is required'),
    // Username still optional; generate using utility if omitted
    body('username').optional().trim().isLength({ min: 3, max: 50 }).withMessage('Username must be 3-50 characters'),
    validate,
  ],
  asyncHandler(async (req, res) => {
    const { username: rawUsername, walletAddress: rawWalletAddress } = req.body;

    // Check if user exists
    // Choose username: use provided username when set, otherwise generate one
    // Treat client-side placeholder usernames like 'user_...' as absent so server
    // uses the canonical generator.
    let username = (rawUsername || '').toString().trim();
    if (username.startsWith('user_')) {
      username = '';
    }
    const MAX_USERNAME_ATTEMPTS = 10;
    let attempt = 0;
    if (!username) {
      username = generateUsername();
    }

    // If a username collision happens (either provided or generated), try regenerating up to a limit
    while (
      Array.from(users.values()).some((u) => u.username === username) &&
      attempt < MAX_USERNAME_ATTEMPTS
    ) {
      username = generateUsername();
      attempt += 1;
    }

    if (Array.from(users.values()).some((u) => u.username === username)) {
      return res.status(409).json({ success: false, error: 'Username already exists' });
    }

    const walletAddress = (rawWalletAddress || '').toString().trim();
    if (!walletAddress) {
      return res.status(400).json({ success: false, error: 'walletAddress is required' });
    }

    const userExists = Array.from(users.values()).some((u) => u.walletAddress === walletAddress);

    if (userExists) {
      return res.status(409).json({
        success: false,
        error: 'User already exists',
      });
    }

    // No password in wallet-based registration; no password hash stored
    const hashedPassword = null;

    // Use DiceBear identicon as the default avatar. Use the username as the seed.
    const avatar_seed = username || `user${Date.now()}`;
    const seedEncoded = encodeURIComponent(avatar_seed);
    const avatarUrl = `https://api.dicebear.com/9.x/identicon/png?seed=${seedEncoded}.png`;

    // Try to persist the user/profile in the database when available; fall back to in-memory map for tests
    let user = null;
    try {
      // Wallet address is required by DB schema; for email/password users we generate a synthetic one
      const walletAddr = walletAddress;
      const client = await getClient();
      try {
        await client.query('BEGIN');
        // Check for existing wallet_address or username in DB
        const existing = await client.query('SELECT id, wallet_address, username FROM users WHERE wallet_address = $1 OR username = $2', [walletAddr, username]);
        if (existing.rowCount > 0) {
          // User already exists in DB - return existing record to make registration idempotent
          const existingRow = existing.rows[0];
          await client.query('ROLLBACK');
          const profileRes = await client.query('SELECT avatar_url, display_name FROM profiles WHERE wallet_address = $1', [existingRow.wallet_address]);
          const existingAvatar = profileRes.rows[0] ? profileRes.rows[0].avatar_url : null;
          const existingDisplay = profileRes.rows[0] ? profileRes.rows[0].display_name : null;
          const responseUser = {
            id: existingRow.id,
            username: existingRow.username,
            displayName: existingDisplay,
            email: null,
            role: existingRow.role || 'user',
            walletAddress: existingRow.wallet_address,
            avatar_url: existingAvatar
          };
          const tokenPayload = { id: responseUser.id, email: responseUser.email, role: responseUser.role };
          if (responseUser.walletAddress) tokenPayload.walletAddress = responseUser.walletAddress;
          const token = jwt.sign(tokenPayload, process.env.JWT_SECRET || 'dev-secret', { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });
          return res.status(200).json({ success: true, message: 'User already exists', data: { token, user: responseUser } });
        }

        const insertUserRes = await client.query(
          `INSERT INTO users (wallet_address, username, email, password_hash, role) VALUES ($1, $2, $3, $4, $5) RETURNING id, wallet_address`,
          [walletAddr, username, null, null, 'user']
        );

        const insertedUser = insertUserRes.rows[0];
        // Compute display name: capitalize the name part of username and preserve hash (e.g. bravelion_ab12 -> Bravelion_ab12)
        const parts = (username || '').split('_');
        const namePart = parts[0] || username || walletAddress;
        const hashPart = parts[1] ? `_${parts[1]}` : '';
        const displayName = namePart.charAt(0).toUpperCase() + namePart.slice(1) + hashPart;

        const insertProfileRes = await client.query(
          `INSERT INTO profiles (user_id, wallet_address, username, display_name, avatar_url) VALUES ($1, $2, $3, $4, $5) RETURNING id`,
          [insertedUser.id, walletAddress, username, displayName, avatarUrl]
        );

        await client.query('COMMIT');
        user = {
          id: insertedUser.id,
          username,
          displayName,
          email: null,
          role: 'user',
          walletAddress,
          avatar_url: avatarUrl
        };
      } catch (e) {
        await client.query('ROLLBACK');
        throw e;
      } finally {
        client.release();
      }
    } catch (dbErr) {
      // DB not available (or other error). Fallback to in-memory storage for lightweight flows (tests)
      logger.debug('DB unavailable or failed - falling back to in-memory user store for registration', { error: dbErr && dbErr.message });
      // Fallback in-memory user includes displayName
      const partsFb = (username || '').split('_');
      const nameFb = partsFb[0] || username || walletAddress;
      const hashFb = partsFb[1] ? `_${partsFb[1]}` : '';
      const displayFb = nameFb.charAt(0).toUpperCase() + nameFb.slice(1) + hashFb;
      user = {
        id: `user_${Date.now()}`,
        username,
        displayName: displayFb,
        email: null,
        role: 'user',
        createdAt: new Date().toISOString(),
        avatar_url: avatarUrl,
        walletAddress,
      };
      users.set(user.id, user);
    }

    // Generate JWT - include walletAddress if available
    const tokenPayload = { id: user.id, email: user.email, role: user.role };
    if (user.walletAddress) tokenPayload.walletAddress = user.walletAddress;
    const secret = process.env.JWT_SECRET || 'dev-secret';
    const token = jwt.sign(tokenPayload, secret, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });

    logger.info(`New user registered: ${username}`);

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: {
        token,
        user: {
          id: user.id,
          username: user.username,
          displayName: user.displayName,
          email: user.email,
          role: user.role,
          walletAddress: user.walletAddress,
          avatar_url: user.avatar_url,
        },
      },
    });
  })
);

/**
 * @route GET /api/auth/challenge?walletAddress=... 
 * @desc  Issue a challenge message for the wallet
 * @access Public
 */
router.get('/challenge', asyncHandler(async (req, res) => {
  const walletAddress = (req.query.walletAddress || '').toString().trim();
  if (!walletAddress) return res.status(400).json({ success: false, error: 'walletAddress query param required' });
  const nonce = Buffer.from(require('crypto').randomBytes(12)).toString('hex');
  const issuedAt = new Date().toISOString();
  const message = `Art.Kubus Login\nWallet: ${walletAddress}\nNonce: ${nonce}\nIssuedAt: ${issuedAt}`;
  const expiresAt = Date.now() + CHALLENGE_EXPIRY_MS;
  challenges.set(walletAddress, { message, expiresAt });
  res.json({ success: true, message, expiresAt });
}));

/**
 * @route   POST /api/auth/login
 * @desc    Login user
 * @access  Public
 */
router.post(
  '/login',
  [
    body('walletAddress').trim().notEmpty().withMessage('walletAddress required'),
    body('signature').notEmpty().withMessage('signature required'),
    validate,
  ],
  asyncHandler(async (req, res) => {
    // Signature login flow expects walletAddress and signature
    const { walletAddress, signature } = req.body;
    if (!walletAddress || !signature) {
      return res.status(400).json({ success: false, error: 'walletAddress and signature required' });
    }
    // Get expected challenge
    const entry = challenges.get(walletAddress);
    if (!entry || !entry.message) {
      return res.status(400).json({ success: false, error: 'No challenge for wallet; request a challenge first' });
    }
    // Check expiry
    if (Date.now() > entry.expiresAt) {
      challenges.delete(walletAddress);
      return res.status(400).json({ success: false, error: 'Challenge expired, request a new challenge' });
    }
    const message = entry.message;
    // Verify signature
    let sigBytes = null;
    try {
      // Try base64 first
      sigBytes = Buffer.from(signature, 'base64');
      if (sigBytes.length === 0) throw new Error('Empty signature');
    } catch (e) {
      try {
        // Try base58
        sigBytes = bs58.decode(signature);
      } catch (e2) {
        return res.status(400).json({ success: false, error: 'Invalid signature encoding' });
      }
    }

    // Convert walletAddress (public key) from base58
    let pubKeyBytes;
    try {
      pubKeyBytes = bs58.decode(walletAddress);
    } catch (e) {
      return res.status(400).json({ success: false, error: 'Invalid walletAddress' });
    }

    const messageBytes = Buffer.from(message, 'utf8');
    const verified = nacl.sign.detached.verify(new Uint8Array(messageBytes), new Uint8Array(sigBytes), new Uint8Array(pubKeyBytes));
    if (!verified) {
      return res.status(401).json({ success: false, error: 'Signature verification failed' });
    }

    // Signature is valid, fetch or create user
    let user = null;
    try {
      const dbRes = await query('SELECT id, wallet_address, username, role FROM users WHERE wallet_address = $1', [walletAddress]);
      if (dbRes.rows.length > 0) {
        const row = dbRes.rows[0];
        const profileRes = await query('SELECT avatar_url, display_name FROM profiles WHERE user_id = $1', [row.id]);
        const avatarUrl = profileRes.rows[0] ? profileRes.rows[0].avatar_url : null;
        const displayName = profileRes.rows[0] ? profileRes.rows[0].display_name : null;
        user = { id: row.id, walletAddress: row.wallet_address, username: row.username, displayName, role: row.role, avatar_url: avatarUrl };
      } else {
        // Create user/profile in DB
        const client = await getClient();
        try {
          await client.query('BEGIN');
          const genUsername = generateUsername();
          const insertUserRes = await client.query('INSERT INTO users (wallet_address, username, role) VALUES ($1,$2,$3) RETURNING id, wallet_address, username', [walletAddress, genUsername, 'user']);
          const inserted = insertUserRes.rows[0];
          const avatar_seed = inserted.username || walletAddress;
          const seedEncoded = encodeURIComponent(avatar_seed);
          const avatarProxy = `https://api.dicebear.com/9.x/identicon/png?seed=${seedEncoded}.png`;
          // Compute display name
          const partsNew = (inserted.username || '').split('_');
          const nameNew = partsNew[0] || inserted.username || walletAddress;
          const hashNew = partsNew[1] ? `_${partsNew[1]}` : '';
          const displayNew = nameNew.charAt(0).toUpperCase() + nameNew.slice(1) + hashNew;
          await client.query('INSERT INTO profiles (user_id, wallet_address, username, display_name, avatar_url) VALUES ($1,$2,$3,$4,$5)', [inserted.id, walletAddress, inserted.username, displayNew, avatarProxy]);
          await client.query('COMMIT');
          user = { id: inserted.id, walletAddress: inserted.wallet_address, username: inserted.username, displayName: displayNew, role: 'user', avatar_url: avatarProxy };
        } catch (e) {
          await client.query('ROLLBACK');
          throw e;
        } finally {
          client.release();
        }
      }
    } catch (e) {
      logger.debug('DB unavailable at verify, falling back to in-memory', { error: e && e.message });
      // Look for in-memory user
      user = Array.from(users.values()).find(u => (u.walletAddress || '').toLowerCase() === (walletAddress || '').toLowerCase());
      if (!user) {
        // Create in-memory user
        const generatedUsername = generateUsername();
        const seedEncoded = encodeURIComponent(generatedUsername);
        const avatarProxy = `https://api.dicebear.com/9.x/identicon/png?seed=${seedEncoded}.png`;
        // Compute display name for in-memory user
        const partsGen = (generatedUsername || '').split('_');
        const nameGen = partsGen[0] || generatedUsername || walletAddress;
        const hashGen = partsGen[1] ? `_${partsGen[1]}` : '';
        const displayGen = nameGen.charAt(0).toUpperCase() + nameGen.slice(1) + hashGen;
        user = { id: `user_${Date.now()}`, username: generatedUsername, displayName: displayGen, walletAddress, role: 'user', avatar_url: avatarProxy };
        users.set(user.id, user);
      }
    }

    // Mark challenge used
    challenges.delete(walletAddress);

    const tokenPayload = { id: user.id, walletAddress: user.walletAddress, role: user.role };
    const secret = process.env.JWT_SECRET || 'dev-secret';
    const token = jwt.sign(tokenPayload, secret, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });

    res.json({ success: true, message: 'Login successful', data: { token, user } });
  })
);

module.exports = router;
