const { URLSearchParams } = require('url');
const axios = require('axios');
const crypto = require('crypto');
const logger = require('./logger');
const storageService = require('../services/storageService');

const PLACEHOLDER_PATH_REGEX = /\/(api\/)?avatar\//i;

function buildAvatarProxyUrl(seed, options = {}) {
  const base = (process.env.HTTP_BASE_URL || '').replace(/\/$/, '');
  const {
    style = 'identicon',
    format = 'png',
    raw = true,
    extraParams = {}
  } = options;

  const params = new URLSearchParams();
  params.set('style', style);
  params.set('format', format);
  Object.entries(extraParams).forEach(([key, value]) => {
    if (value === undefined || value === null) return;
    params.set(key, value.toString());
  });
  if (raw) {
    params.set('raw', raw === true ? 'true' : raw.toString());
  }

  const route = `/api/avatar/${encodeURIComponent(seed)}`;
  const prefix = base ? `${base}${route}` : route;
  const query = params.toString();
  return query ? `${prefix}?${query}` : prefix;
}

function isProxyPlaceholder(url) {
  if (!url) return true;
  const value = String(url).trim().toLowerCase();
  if (!value) return true;
  if (value.includes('dicebear.com')) return true;
  if (PLACEHOLDER_PATH_REGEX.test(value)) return true;
  if (value.includes('style=identicon')) return true;
  return false;
}

// Utility to normalize avatar URLs stored in DB or returned by external services
function normalizeAvatarUrl(rawUrl) {
  // Dynamic base URL: production uses api.kubus.site, development uses localhost:3000
  const defaultBase = process.env.NODE_ENV === 'production' 
    ? 'https://api.kubus.site' 
    : 'http://localhost:3000';
  const base = (process.env.HTTP_BASE_URL || defaultBase).replace(/\/$/, '');
  
  if (rawUrl && String(rawUrl).trim().length > 0) {
    const raw = String(rawUrl).trim();
    // Don't filter out internal avatar proxy URLs - they're valid!
    // Only filter out external DiceBear URLs (those should be replaced with internal proxy)
    const isExternalDicebear = raw.includes('dicebear.com');
    if (isExternalDicebear) return null;
    
    if (/^https?:\/\//i.test(raw)) return raw;
    if (raw.startsWith('/')) return base ? base + raw : raw;
    // if it looks like an internal path (api/avatar/...), prepend slash
    if (raw.startsWith('api/')) {
      return base ? base + '/' + raw : '/' + raw;
    }
    // default: prefix with base
    return base ? base + '/' + raw : raw;
  }
  return null;
}

async function fetchDicebearAvatar(seed, options = {}) {
  const style = options.style || 'identicon';
  const format = options.format || 'png';
  const dicebearVersion = process.env.DICEBEAR_VERSION || '9.x';
  const extraParams = options.extraParams || {};
  const params = new URLSearchParams({ seed });
  Object.entries(extraParams).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') return;
    params.set(key, value);
  });
  const remoteUrl = `https://api.dicebear.com/${dicebearVersion}/${encodeURIComponent(style)}/${encodeURIComponent(format)}?${params.toString()}`;
  const response = await axios.get(remoteUrl, {
    responseType: 'arraybuffer',
    timeout: 10000,
    headers: { 'User-Agent': 'art-kubus-avatar-prefetch/1.0' }
  });
  return {
    buffer: Buffer.from(response.data),
    contentType: response.headers['content-type'] || `image/${format}`,
    format
  };
}

async function ensureStoredDefaultAvatar(seed, options = {}) {
  const normalizedSeed = (seed || '').toString().trim() || 'anon';
  try {
    const { buffer, format } = await fetchDicebearAvatar(normalizedSeed, options);
    const hash = crypto.createHash('sha256').update(normalizedSeed).digest('hex').slice(0, 16);
    const safeFormat = (format || 'png').toLowerCase().replace(/[^a-z0-9]/g, '') || 'png';
    const filename = `${options.filenamePrefix || 'identicon'}_${hash}.${safeFormat}`;
    const uploadFolder = options.uploadFolder || 'avatars/generated';
    const uploadResult = await storageService.uploadToHTTP(buffer, filename, { uploadFolder });
    return uploadResult?.url || null;
  } catch (error) {
    logger.warn(`ensureStoredDefaultAvatar failed for seed ${normalizedSeed}: ${error.message}`);
    return null;
  }
}

module.exports = { normalizeAvatarUrl, buildAvatarProxyUrl, isProxyPlaceholder, ensureStoredDefaultAvatar };
