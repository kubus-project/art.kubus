<?php

declare(strict_types=1);

const KUBUS_SEO_UPSTREAM_ORIGIN = 'https://api.kubus.site';

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
    if (preg_match('/[\\x00-\\x1F\\x7F\\\\]/', $path) === 1) {
        return false;
    }

    if (preg_match('#^/(?:robots\\.txt|sitemap\\.xml|sitemaps/[^/]+\\.xml)$#', $path) === 1) {
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

function appendForwardHeader(array &$headers, string $serverKey, string $headerName): void
{
    $value = $_SERVER[$serverKey] ?? null;
    if (!is_string($value) || $value === '' || strlen($value) > 2048) {
        return;
    }
    if (preg_match('/[\\x00-\\x1F\\x7F]/', $value) === 1) {
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
if ($requestTarget === '' || strlen($requestTarget) > 8192 || preg_match('/[\\x00-\\x1F\\x7F]/', $requestTarget) === 1) {
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
        if ($name !== '' && $value !== '' && preg_match('/[\\r\\n]/', $value) !== 1) {
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

if ($method !== 'HEAD' && $status !== 204 && $status !== 304) {
    echo $body;
}
