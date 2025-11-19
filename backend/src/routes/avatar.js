const express = require('express');
const axios = require('axios');
const crypto = require('crypto');
const { URLSearchParams } = require('url');
const router = express.Router();

// Simple proxy for avatars.dicebear.com to ensure CORS headers are present
// Usage: GET /api/avatar/:seed?style=identicon&format=png&raw=true
// Example: /api/avatar/a3a5b91b-5df6-4aa0-a9af-ae88171555b2?style=identicon&format=png&raw=true

router.get('/:seed', async (req, res) => {
  // Normalize inputs and protect against UUID/conversation IDs being used as seeds
  const rawSeed = (req.params.seed || '').toString();
  const style = (req.query.style || 'identicon').toString();
  const format = (req.query.format || 'png').toString();

  // We used to strictly sanitize the seed to only keep alphanumerics and lowercase
  // to avoid upstream issues with special characters, dots, slashes and so on.
  // That prevented some seeds (emails, UUIDs) from being used directly and also
  // reduced entropy if two different seeds sanitize to the same value.
  //
  // To keep it safe but preserve uniqueness for new users, we default to a
  // cryptographic hash (hex) of the raw seed which is URL-safe and ensures
  // uniqueness without dangerous characters. If callers want the original
  // seed to be used by the remote API (e.g. for visual determinism), they can
  // opt-in with `?raw=true` and we'll use a sanitized-but-more-raw version.
  const useRawSeed = req.query.raw === 'true';
  const defaultAnon = 'anon';

  let seedForRemote;
  if (!rawSeed || rawSeed.trim().length === 0) {
    seedForRemote = defaultAnon;
  } else if (useRawSeed) {
    // Permit more characters but still remove truly problematic ones. Allow
    // '-', '_' and '.' to preserve many typical seeds like UUIDs and emails
    // while rejecting whitespace, control chars and slashes.
    const sanitized = rawSeed.replace(/[^-_.a-zA-Z0-9]/g, '').toLowerCase();
    seedForRemote = sanitized.length > 0 ? sanitized : defaultAnon;
    console.log('[avatar proxy] using raw seed for remote:', seedForRemote);
  } else {
    // Hash to hex to avoid any chance of reserved chars, and cut to 32 hex
    // characters to keep a reasonable URL length and entropy.
    seedForRemote = crypto.createHash('sha256').update(rawSeed).digest('hex').slice(0, 32);
  }

  // Build remote URL (always defined so logging in catch is safe)
  const dicebearVersion = process.env.DICEBEAR_VERSION || '9.x';
  const forwardedParams = new URLSearchParams();
  Object.entries(req.query).forEach(([key, value]) => {
    if (['style', 'format', 'raw'].includes(key)) return;
    if (value === undefined || value === null) return;
    forwardedParams.append(key, value.toString());
  });
  forwardedParams.set('seed', seedForRemote);
  const queryString = forwardedParams.toString();
  const remoteUrl = `https://api.dicebear.com/${dicebearVersion}/${encodeURIComponent(style)}/${encodeURIComponent(format)}${queryString ? `?${queryString}` : ''}`;

  try {
    console.log('[avatar proxy] fetching remoteUrl:', remoteUrl);
    const response = await axios.get(remoteUrl, {
      responseType: 'arraybuffer',
      timeout: 10000,
      headers: {
        'User-Agent': 'art-kubus-avatar-proxy/1.0'
      }
    });

    const contentType = response.headers['content-type'] || (format === 'svg' ? 'image/svg+xml' : 'image/png');

    // Ensure CORS is allowed for web clients
    res.set('Access-Control-Allow-Origin', process.env.CORS_ORIGIN || '*');
    res.set('Cache-Control', 'public, max-age=86400');
    res.type(contentType);
    return res.send(Buffer.from(response.data, 'binary'));
  } catch (err) {
    console.error('avatar proxy error', err && err.message ? err.message : err);
    // If upstream returned a 410 (Gone) or other error, return a small fallback SVG or local image
    const status = err && err.response && err.response.status ? err.response.status : null;
    if (status) {
      console.warn(`[avatar proxy] upstream responded with status ${status} for ${remoteUrl}`);
      const path = require('path');
      const fs = require('fs');
      // If client specifically requested PNG, try to serve a local PNG fallback if available
      if (format === 'png') {
        // Prefer a profile placeholder if present in repo assets
        const candidatePaths = [
          path.join(__dirname, '../../assets/images/profile.png'),
          path.join(__dirname, '../../assets/images/logo.png'),
          path.join(__dirname, '../../assets/images/belilogo.png')
        ];
        for (const p of candidatePaths) {
          try {
            if (fs.existsSync(p)) {
              res.set('Access-Control-Allow-Origin', process.env.CORS_ORIGIN || '*');
              res.set('Cache-Control', 'public, max-age=3600');
              return res.sendFile(p);
            }
          } catch (e) {
            // ignore and try next
          }
        }
      }

      // Fallback: serve a generic SVG avatar so clients don't fail
      const seed = rawSeed || 'anon';
      const colorHash = Math.abs(Array.from(seed).reduce((acc, ch) => acc * 31 + ch.charCodeAt(0), 7)) % 0xffffff;
      const color = `#${colorHash.toString(16).padStart(6, '0')}`;
      const firstChar = (String(seed).trim().charAt(0).toUpperCase() || 'A');
      const svg = `<?xml version="1.0" encoding="UTF-8"?>\n` +
        `<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128' viewBox='0 0 128 128'>` +
        `<rect width='100%' height='100%' fill='${color}'/>` +
        `<g transform='translate(64,64)'>` +
        `<circle r='36' fill='rgba(255,255,255,0.85)'/>` +
        `<text x='0' y='8' font-size='36' text-anchor='middle' fill='${color}' font-family='Arial, Helvetica, sans-serif'>` +
        `${firstChar}` +
        `</text></g></svg>`;

      res.set('Access-Control-Allow-Origin', process.env.CORS_ORIGIN || '*');
      res.set('Cache-Control', 'public, max-age=3600');
      res.type('image/svg+xml');
      return res.status(200).send(svg);
    }

    return res.status(502).json({ success: false, error: 'Failed to fetch avatar' });
  }
});

module.exports = router;
