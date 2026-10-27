<?php

declare(strict_types=1);

const KUBUS_SEO_UPSTREAM_ORIGIN = 'https://api.kubus.site';
const KUBUS_TAKEOVER_CSP = "default-src 'none'; script-src 'self' 'wasm-unsafe-eval' https://accounts.google.com/gsi/client; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' https: data: blob:; font-src 'self' data: https://fonts.gstatic.com; connect-src 'self' https: wss: blob:; media-src 'self' https: data: blob:; worker-src 'self' blob:; frame-src https://accounts.google.com; base-uri 'self'; form-action 'none'; frame-ancestors 'none'";

// Copy mirrors web/public_flutter_takeover.js exactly (the static gateway test checks parity).
const KUBUS_TAKEOVER_COPY = [
    'en' => [
        'loading' => 'The world of art is coming into focus…',
        'failure' => "The world of art couldn't open this time. Try refreshing the page or come back later.",
        'retry' => 'Retry',
        'app' => 'Go to app',
    ],
    'sl' => [
        'loading' => 'Svet umetnosti se izrisuje …',
        'failure' => 'Svet umetnosti se tokrat ni mogel odpreti. Poskusite osvežiti stran ali se vrnite pozneje.',
        'retry' => 'Poskusi znova',
        'app' => 'Pojdi v aplikacijo',
    ],
];

// Tokens are the site's custom properties; the fallbacks keep the section legible if a token is absent.
// The hidden rule is explicit because the author display value would otherwise override the UA hidden style.
const KUBUS_TAKEOVER_STATUS_CSS = '#flutter-takeover-status{box-sizing:border-box;display:flex;flex-wrap:wrap;align-items:center;gap:.75rem 1rem;width:min(100%,56rem);margin:1rem auto;padding:.75rem 1rem;border:1px solid var(--color-border,#d7d0c4);border-radius:.75rem;background:var(--color-surface,#fffdf8);color:var(--color-text,#1d1b16);font:inherit;line-height:1.5}'
    . '#flutter-takeover-status[hidden]{display:none}'
    . '#flutter-takeover-status [data-kubus-takeover-message]{flex:1 1 16rem;margin:0}'
    . '#flutter-takeover-status .takeover-actions{display:flex;flex-wrap:wrap;gap:.5rem}'
    . '#flutter-takeover-status [data-kubus-takeover-refresh],#flutter-takeover-status [data-kubus-takeover-app]{display:inline-flex;align-items:center;justify-content:center;min-height:2.75rem;padding:.5rem 1.1rem;border:1px solid var(--color-border,#8c8478);border-radius:999px;background:var(--color-surface,#fffdf8);color:var(--color-text,#1d1b16);font:inherit;font-weight:600;text-decoration:none;cursor:pointer}'
    . '#flutter-takeover-status [data-kubus-takeover-refresh]{background:var(--color-accent,#1d1b16);border-color:transparent;color:var(--color-on-accent,#fffdf8)}'
    . '#flutter-takeover-status [data-kubus-takeover-refresh]:disabled{border-style:dashed;background:transparent;color:var(--color-muted,#6b6357);cursor:default}'
    . '#flutter-takeover-status [data-kubus-takeover-refresh]:focus-visible,#flutter-takeover-status [data-kubus-takeover-app]:focus-visible{outline:3px solid var(--color-focus,#1a5fb4);outline-offset:2px}'
    . '@media(max-width:420px){#flutter-takeover-status .takeover-actions{flex:1 1 100%;width:100%}#flutter-takeover-status [data-kubus-takeover-refresh],#flutter-takeover-status [data-kubus-takeover-app]{flex:1 1 auto}}'
    . '@media(prefers-color-scheme:dark){#flutter-takeover-status{background:var(--color-surface,#1c1b19);color:var(--color-text,#f4efe6);border-color:var(--color-border,#4a463f)}#flutter-takeover-status [data-kubus-takeover-refresh],#flutter-takeover-status [data-kubus-takeover-app]{border-color:var(--color-border,#6d675d);background:var(--color-surface,#1c1b19);color:var(--color-text,#f4efe6)}#flutter-takeover-status [data-kubus-takeover-refresh]{background:var(--color-accent,#f4efe6);border-color:transparent;color:var(--color-on-accent,#1c1b19)}}';

function sendGatewayError(int $status, string $title, string $message): void
{
    http_response_code($status);
    header('Content-Type: text/html; charset=utf-8');
    header('Cache-Control: no-store, max-age=0');
    header('X-Robots-Tag: noindex, follow');
    header("Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'");

    $safeTitle = htmlspecialchars($title, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $safeMessage = htmlspecialchars($message, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    echo '<!doctype html><html lang="en"><head><meta charset="utf-8">';
    echo '<meta name="viewport" content="width=device-width,initial-scale=1">';
    echo '<meta name="robots" content="noindex, follow">';
    echo '<title>' . $safeTitle . ' | art.kubus</title></head><body>';
    echo '<main><h1>' . $safeTitle . '</h1><p>' . $safeMessage . '</p>';
    echo '<p><a href="/en/artworks">Explore public art</a></p></main></body></html>';
    exit;
}

function isPublicSeoPath(string $path): bool
{
    if (preg_match('/[\x00-\x1F\x7F\\\\]/', $path) === 1) {
        return false;
    }

    if (preg_match('#^/(?:robots\.txt|sitemap\.xml|sitemaps/[^/]+\.xml)$#', $path) === 1) {
        return true;
    }

    if (preg_match('#^/(?:en|sl)(?:/.*)?$#', $path) === 1) {
        return true;
    }

    return preg_match(
        '#^/(?:a|u|e|x|p|c|n|m|artwork|artworks|profile|profiles|user|users|post|posts|event|events|exhibition|exhibitions|collection|collections|nft|nfts|collectible|collectibles|marker|markers|art-marker|art-markers)/[^/]+/?$#',
        $path,
    ) === 1;
}

function takeoverTargetForPath(string $path): ?array
{
    if (preg_match('#^/(en|sl)/([^/]+)/([^/]+)/?$#', $path, $matches) !== 1) {
        return null;
    }

    $segments = [
        'en' => [
            'artworks' => 'artwork',
            'profiles' => 'profile',
            'events' => 'event',
            'exhibitions' => 'exhibition',
            'posts' => 'post',
            'collections' => 'collection',
            'map' => 'marker',
        ],
        'sl' => [
            'umetnine' => 'artwork',
            'profili' => 'profile',
            'dogodki' => 'event',
            'razstave' => 'exhibition',
            'objave' => 'post',
            'zbirke' => 'collection',
            'zemljevid' => 'marker',
        ],
    ];

    $locale = $matches[1];
    $segment = $matches[2];
    $type = $segments[$locale][$segment] ?? null;
    if (!is_string($type)) {
        return null;
    }

    $id = rawurldecode($matches[3]);
    if ($id === '' || strlen($id) > 255 || preg_match('/[\x00-\x1F\x7F<>]/', $id) === 1) {
        return null;
    }

    return [
        'type' => $type,
        'id' => $id,
        'path' => rtrim($path, '/'),
        'locale' => $locale,
    ];
}

function takeoverEscape(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/**
 * Inline loading section for the PHP gateway path. The backend renders the same markup and
 * attribute names (web/public_flutter_takeover.js reads them), so the two paths behave alike.
 * The section starts hidden; the takeover script reveals it at once.
 */
function takeoverStatusMarkup(string $locale): string
{
    $copy = KUBUS_TAKEOVER_COPY[$locale];
    $href = takeoverEscape('/map?lang=' . $locale);

    return '<div id="flutter-takeover-status" data-kubus-takeover-status data-state="pending" data-locale="' . takeoverEscape($locale) . '"'
        . ' data-loading-text="' . takeoverEscape($copy['loading']) . '" data-failure-text="' . takeoverEscape($copy['failure']) . '"'
        . ' data-refresh-label="' . takeoverEscape($copy['retry']) . '" data-app-label="' . takeoverEscape($copy['app']) . '"'
        . ' data-app-href="' . $href . '" hidden>'
        . '<span data-kubus-takeover-message role="status" aria-live="polite" aria-atomic="true">' . takeoverEscape($copy['loading']) . '</span>'
        . '<span class="takeover-actions" data-kubus-takeover-actions>'
        . '<button type="button" data-kubus-takeover-refresh>' . takeoverEscape($copy['retry']) . '</button>'
        . '<a data-kubus-takeover-app href="' . $href . '">' . takeoverEscape($copy['app']) . '</a>'
        . '</span></div>';
}

function injectTakeoverShell(string $html, array $target): ?string
{
    if (stripos($html, 'id="flutter-host"') !== false || stripos($html, "id='flutter-host'") !== false) {
        return $html;
    }
    if (stripos($html, '</head>') === false || stripos($html, '<body') === false || stripos($html, '</body>') === false) {
        return null;
    }

    $locale = (string) ($target['locale'] ?? '');
    if (!in_array($locale, ['en', 'sl'], true)) {
        return null;
    }

    $type = htmlspecialchars((string) $target['type'], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $id = htmlspecialchars((string) $target['id'], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $path = htmlspecialchars((string) $target['path'], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    $takeoverStyle = '<base href="/"><style id="kubus-takeover-edge-style">#flutter-host{position:fixed;inset:0;width:100%;height:100%;z-index:1000;visibility:visible;opacity:1;pointer-events:none;background:inherit}#public-document{position:relative;z-index:1001;min-height:100vh;background:inherit;opacity:1;transition:opacity 200ms ease}html.kubus-takeover-active #flutter-host{pointer-events:auto}html.kubus-takeover-active #public-document{opacity:0;pointer-events:none}html.kubus-takeover-complete #public-document{visibility:hidden}@media(prefers-reduced-motion:reduce){#public-document{transition-duration:.01ms!important}}' . KUBUS_TAKEOVER_STATUS_CSS . '</style>';
    $html = preg_replace('/<\/head>/i', $takeoverStyle . '</head>', $html, 1);
    if (!is_string($html)) {
        return null;
    }

    // Decided before the wrapper and host exist: a page that already carries a status section gets no second one.
    $needsStatus = stripos($html, 'data-kubus-takeover-status') === false;

    $documentOpen = '<div id="public-document">';
    $html = preg_replace('/(<body\b[^>]*>)/i', '$1' . $documentOpen, $html, 1);
    if (!is_string($html)) {
        return null;
    }

    if ($needsStatus) {
        // Same placement as the backend: after the first header of the public document, else first child.
        $insertAt = stripos($html, $documentOpen);
        if ($insertAt === false) {
            return null;
        }
        $insertAt += strlen($documentOpen);
        $headerEnd = stripos($html, '</header>', $insertAt);
        if ($headerEnd !== false) {
            $insertAt = $headerEnd + strlen('</header>');
        }
        $html = substr($html, 0, $insertAt) . takeoverStatusMarkup($locale) . substr($html, $insertAt);
    }

    $bootstrap = '</div><div id="flutter-host" aria-hidden="true" inert data-entity-type="' . $type . '" data-entity-id="' . $id . '" data-entity-path="' . $path . '" data-locale="' . takeoverEscape($locale) . '"></div>'
        . '<script src="/public_flutter_takeover.js" defer></script>'
        . '<script src="/flutter_bootstrap.js" defer></script>';
    $html = preg_replace('/<\/body>/i', $bootstrap . '</body>', $html, 1);

    return is_string($html) ? $html : null;
}

/**
 * Deployment revision identity.
 *
 * CI writes kubus-web-revision.txt into the immutable web artifact so a
 * deployed release can be matched against the exact tested commit. The value is
 * a commit SHA only - never a path, credential or host detail. When the file is
 * absent the header is omitted entirely rather than reporting a guessed or
 * stale revision.
 */
function webRevision(): ?string
{
    static $cached = false;
    static $value = null;

    if ($cached) {
        return $value;
    }
    $cached = true;

    $path = __DIR__ . '/kubus-web-revision.txt';
    if (!is_readable($path)) {
        return $value;
    }
    $raw = @file_get_contents($path);
    if (!is_string($raw)) {
        return $value;
    }
    $raw = trim($raw);
    if (preg_match('/^[0-9a-f]{7,64}$/i', $raw) !== 1) {
        return $value;
    }

    $value = $raw;
    return $value;
}

function appendForwardHeader(array &$headers, string $serverKey, string $headerName): void
{
    $value = $_SERVER[$serverKey] ?? null;
    if (!is_string($value) || $value === '' || strlen($value) > 2048) {
        return;
    }
    if (preg_match('/[\x00-\x1F\x7F]/', $value) === 1) {
        return;
    }
    $headers[] = $headerName . ': ' . $value;
}

$method = strtoupper((string) ($_SERVER['REQUEST_METHOD'] ?? 'GET'));
if ($method !== 'GET' && $method !== 'HEAD') {
    header('Allow: GET, HEAD');
    sendGatewayError(405, 'Method not allowed', 'This public document supports only GET and HEAD requests.');
}

$requestTarget = (string) ($_SERVER['REQUEST_URI'] ?? '/');
if ($requestTarget === '' || strlen($requestTarget) > 8192 || preg_match('/[\x00-\x1F\x7F]/', $requestTarget) === 1) {
    sendGatewayError(400, 'Invalid request', 'The requested public address is malformed.');
}

$parts = parse_url($requestTarget);
if (!is_array($parts) || !isset($parts['path']) || !is_string($parts['path']) || !isPublicSeoPath($parts['path'])) {
    sendGatewayError(404, 'Page not found', 'The requested public art page could not be found.');
}

if (!function_exists('curl_init')) {
    sendGatewayError(503, 'Public pages temporarily unavailable', 'Please try again shortly.');
}

$upstreamUrl = KUBUS_SEO_UPSTREAM_ORIGIN . $parts['path'];
if (isset($parts['query']) && is_string($parts['query']) && $parts['query'] !== '') {
    $upstreamUrl .= '?' . $parts['query'];
}

$requestHeaders = [
    'User-Agent: art.kubus-public-gateway/1.0',
    'X-Forwarded-Host: app.kubus.site',
    'X-Forwarded-Proto: https',
];
appendForwardHeader($requestHeaders, 'HTTP_ACCEPT', 'Accept');
appendForwardHeader($requestHeaders, 'HTTP_ACCEPT_LANGUAGE', 'Accept-Language');
appendForwardHeader($requestHeaders, 'HTTP_IF_NONE_MATCH', 'If-None-Match');
appendForwardHeader($requestHeaders, 'HTTP_IF_MODIFIED_SINCE', 'If-Modified-Since');

$remoteAddress = $_SERVER['REMOTE_ADDR'] ?? null;
if (is_string($remoteAddress) && filter_var($remoteAddress, FILTER_VALIDATE_IP) !== false) {
    $requestHeaders[] = 'X-Forwarded-For: ' . $remoteAddress;
}

$upstreamHeaders = [];
$curl = curl_init();
$options = [
    CURLOPT_URL => $upstreamUrl,
    CURLOPT_CUSTOMREQUEST => $method,
    CURLOPT_NOBODY => $method === 'HEAD',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => false,
    CURLOPT_CONNECTTIMEOUT => 5,
    CURLOPT_TIMEOUT => 20,
    CURLOPT_HTTPHEADER => $requestHeaders,
    CURLOPT_HEADERFUNCTION => static function ($handle, string $line) use (&$upstreamHeaders): int {
        $length = strlen($line);
        $trimmed = trim($line);
        if ($trimmed === '') {
            return $length;
        }
        if (strpos($trimmed, 'HTTP/') === 0) {
            $upstreamHeaders = [];
            return $length;
        }
        $separator = strpos($trimmed, ':');
        if ($separator === false) {
            return $length;
        }
        $name = strtolower(trim(substr($trimmed, 0, $separator)));
        $value = trim(substr($trimmed, $separator + 1));
        if ($name !== '' && $value !== '' && preg_match('/[\r\n]/', $value) !== 1) {
            $upstreamHeaders[$name] = $value;
        }
        return $length;
    },
];

if (defined('CURLOPT_PROTOCOLS') && defined('CURLPROTO_HTTPS')) {
    $options[CURLOPT_PROTOCOLS] = CURLPROTO_HTTPS;
}
if (defined('CURL_HTTP_VERSION_2TLS')) {
    $options[CURLOPT_HTTP_VERSION] = CURL_HTTP_VERSION_2TLS;
}

curl_setopt_array($curl, $options);
$body = curl_exec($curl);
$status = (int) curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
$failed = $body === false || $status < 100 || $status > 599;
curl_close($curl);

if ($failed) {
    sendGatewayError(503, 'Public pages temporarily unavailable', 'Please try again shortly.');
}

$takeoverTarget = $method === 'GET' && $status === 200 && is_string($body)
    ? takeoverTargetForPath($parts['path'])
    : null;
if ($takeoverTarget !== null) {
    $enhancedBody = injectTakeoverShell($body, $takeoverTarget);
    if ($enhancedBody !== null) {
        $body = $enhancedBody;
        $upstreamHeaders['content-security-policy'] = KUBUS_TAKEOVER_CSP;
        unset($upstreamHeaders['etag'], $upstreamHeaders['last-modified']);
    }
}

http_response_code($status);
$allowedResponseHeaders = [
    'cache-control' => 'Cache-Control',
    'content-language' => 'Content-Language',
    'content-security-policy' => 'Content-Security-Policy',
    'content-type' => 'Content-Type',
    'etag' => 'ETag',
    'last-modified' => 'Last-Modified',
    'link' => 'Link',
    'location' => 'Location',
    'retry-after' => 'Retry-After',
    'vary' => 'Vary',
    'x-robots-tag' => 'X-Robots-Tag',
    'x-kubus-backend-revision' => 'X-Kubus-Backend-Revision',
];

foreach ($allowedResponseHeaders as $sourceName => $responseName) {
    if (isset($upstreamHeaders[$sourceName])) {
        header($responseName . ': ' . $upstreamHeaders[$sourceName]);
    }
}
if ($status >= 400) {
    header('Cache-Control: no-store, max-age=0');
    header('X-Robots-Tag: noindex, follow');
}
if (!isset($upstreamHeaders['content-type'])) {
    header('Content-Type: text/html; charset=utf-8');
}
header('X-Content-Type-Options: nosniff');

$revision = webRevision();
if ($revision !== null) {
    header('X-Kubus-Web-Revision: ' . $revision);
}

if ($method !== 'HEAD' && $status !== 204 && $status !== 304) {
    echo $body;
}
