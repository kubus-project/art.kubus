import { createReadStream, existsSync } from 'node:fs';
import fs from 'node:fs/promises';
import http from 'node:http';
import https from 'node:https';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, 'build/web');
const upstreamOrigin = new URL(
  process.env.QA_API_ORIGIN || process.env.KUBUS_BACKEND_URL || 'https://api.kubus.site',
);
const port = Number(process.env.PORT || process.env.QA_PORT || 8090);

const mimeTypes = new Map([
  ['.html', 'text/html; charset=utf-8'],
  ['.js', 'application/javascript; charset=utf-8'],
  ['.mjs', 'application/javascript; charset=utf-8'],
  ['.css', 'text/css; charset=utf-8'],
  ['.json', 'application/json; charset=utf-8'],
  ['.png', 'image/png'],
  ['.jpg', 'image/jpeg'],
  ['.jpeg', 'image/jpeg'],
  ['.svg', 'image/svg+xml'],
  ['.ico', 'image/x-icon'],
  ['.wasm', 'application/wasm'],
  ['.txt', 'text/plain; charset=utf-8'],
  ['.map', 'application/json; charset=utf-8'],
  ['.ttf', 'font/ttf'],
  ['.otf', 'font/otf'],
  ['.woff', 'font/woff'],
  ['.woff2', 'font/woff2'],
]);

function sendError(res, statusCode, message) {
  res.writeHead(statusCode, { 'content-type': 'text/plain; charset=utf-8' });
  res.end(message);
}

function resolveStaticPath(requestPath) {
  let pathname = '/';
  try {
    pathname = new URL(requestPath || '/', 'http://127.0.0.1').pathname;
  } catch (_) {
    pathname = requestPath || '/';
  }
  const sanitized = decodeURIComponent(pathname);
  const relative = sanitized === '/' ? 'index.html' : sanitized.replace(/^\/+/, '');
  const absolute = path.resolve(webRoot, relative);
  if (!absolute.startsWith(webRoot)) return null;
  return absolute;
}

async function serveStatic(req, res) {
  let filePath = resolveStaticPath(req.url || '/');
  if (filePath == null) {
    sendError(res, 400, 'Invalid path');
    return;
  }

  let exists = existsSync(filePath);
  if (!exists || (await fs.stat(filePath)).isDirectory()) {
    filePath = path.join(webRoot, 'index.html');
    exists = existsSync(filePath);
  }

  if (!exists) {
    sendError(res, 404, 'Run `flutter build web --release` before browser QA.');
    return;
  }

  const ext = path.extname(filePath);
  const contentType = mimeTypes.get(ext) || 'application/octet-stream';
  res.writeHead(200, { 'content-type': contentType });
  createReadStream(filePath).pipe(res);
}

function proxyRequest(clientReq, clientRes) {
  const upstreamUrl = new URL(clientReq.url || '/', upstreamOrigin);
  const headers = { ...clientReq.headers };
  delete headers.host;
  delete headers.origin;
  delete headers.referer;
  delete headers.connection;
  delete headers['content-length'];
  delete headers['accept-encoding'];
  delete headers['sec-fetch-dest'];
  delete headers['sec-fetch-mode'];
  delete headers['sec-fetch-site'];
  delete headers['sec-fetch-user'];
  delete headers['sec-ch-ua'];
  delete headers['sec-ch-ua-mobile'];
  delete headers['sec-ch-ua-platform'];
  headers.accept = headers.accept || 'application/json';
  headers['user-agent'] =
    headers['user-agent'] ||
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36';

  const proxyReq = https.request(
    upstreamUrl,
    {
      method: clientReq.method,
      headers,
    },
    (proxyRes) => {
      const responseHeaders = { ...proxyRes.headers };
      delete responseHeaders['access-control-allow-origin'];
      clientRes.writeHead(proxyRes.statusCode || 502, responseHeaders);
      proxyRes.pipe(clientRes);
    },
  );

  proxyReq.on('error', (error) => {
    sendError(clientRes, 502, `Proxy error: ${error.message}`);
  });

  clientReq.pipe(proxyReq);
}

const server = http.createServer((req, res) => {
  const url = req.url || '/';
  if (
    url.startsWith('/api/') ||
    url === '/api' ||
    url.startsWith('/health') ||
    url.startsWith('/uploads/')
  ) {
    proxyRequest(req, res);
    return;
  }
  serveStatic(req, res).catch((error) => {
    sendError(res, 500, `Static server error: ${error.message}`);
  });
});

server.listen(port, '127.0.0.1', () => {
  console.log(`QA proxy listening at http://127.0.0.1:${port}`);
  console.log(`Static root: ${webRoot}`);
  console.log(`API proxy: ${upstreamOrigin.href}`);
});
