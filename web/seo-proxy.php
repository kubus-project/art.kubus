<?php

declare(strict_types=1);

const KUBUS_SEO_UPSTREAM_ORIGIN = 'https://api.kubus.site';
const KUBUS_TAKEOVER_CSP = "default-src 'none'; script-src 'self' 'wasm-unsafe-eval' https://accounts.google.com/gsi/client; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' https: data: blob:; font-src 'self' data: https://fonts.gstatic.com; connect-src 'self' https: wss: blob:; media-src 'self' https: data: blob:; worker-src 'self' blob:; frame-src https://accounts.google.com; base-uri 'self'; form-action 'none'; frame-ancestors 'none'";

// Copy mirrors web/public_flutter_takeover.js exactly (the static gateway test checks parity).
const KUBUS_TAKEOVER_COPY = [
    'en' => [
        'label' => 'THE WORLD IS OPENING',
        'note' => 'Preparing the full interactive experience. You can keep exploring this page while it loads.',
        'loading' => 'The world of art is coming into focus…',
        'failure' => "The world of art couldn't open this time. Try refreshing the page or come back later.",
        'retry' => 'Retry',
        'app' => 'Go to app',
    ],
    'sl' => [
        'label' => 'SVET UMETNOSTI SE ODPIRA',
        'note' => 'Pripravljamo celotno interaktivno izkušnjo. Med nalaganjem lahko še naprej raziskujete to stran.',
        'loading' => 'Svet umetnosti se izrisuje …',
        'failure' => 'Svet umetnosti se tokrat ni mogel odpreti. Poskusite osvežiti stran ali se vrnite pozneje.',
        'retry' => 'Poskusi znova',
        'app' => 'Pojdi v aplikacijo',
    ],
];

// The WORLD HANDOFF section design. A byte-identical copy of the backend's takeoverStatusDesign.js (both repositories pin the same hash in a test);
// section-local tokens fall back to the document's own tokens, so it stays legible on a page without them.
const KUBUS_TAKEOVER_STATUS_CSS = '#flutter-takeover-status{--s-text:var(--color-text,#20251f);--s-muted:var(--color-muted,#626b61);--s-accent:var(--color-accent,#315b4d);--s-on:var(--color-on-accent,#fff);--s-rule:var(--color-border,#c9cec3);--s-bg:var(--color-bg,#f4f5f1);--s-focus:var(--color-focus,#0969da)}'
    . '@media(prefers-color-scheme:dark){#flutter-takeover-status{--s-text:var(--color-text,#eef1e9);--s-muted:var(--color-muted,#aeb8ab);--s-accent:var(--color-accent,#9ac4ae);--s-on:var(--color-on-accent,#06211f);--s-rule:var(--color-border,#3a433b);--s-bg:var(--color-bg,#151915);--s-focus:var(--color-focus,#9bc2ff)}}'
    . '#flutter-takeover-status{box-sizing:border-box;display:flex;flex-wrap:wrap;align-items:center;column-gap:.875rem;row-gap:.5rem;position:relative;width:100%;max-width:var(--content,76rem);margin:0 auto;padding:.75rem 1rem .875rem;border-bottom:1px solid var(--s-rule);color:var(--s-text);line-height:1.5}'
    . '#flutter-takeover-status[hidden]{display:none}'
    . 'html.kubus-takeover-capable #flutter-takeover-status[hidden][data-state=pending]{display:flex}'
    . '#flutter-takeover-status[data-state=slow]{color:var(--color-muted)}'
    . '#flutter-takeover-status .takeover-globe{--g:3.25rem;flex:none;display:grid;width:var(--g);height:var(--g);color:var(--s-accent)}'
    . '#flutter-takeover-status .takeover-head{flex:1 1 12rem;min-width:0;display:grid;gap:.125rem}'
    . '#flutter-takeover-status .takeover-label{font:400 .68rem/1.3 "Space Mono",ui-monospace,monospace;letter-spacing:.14em;color:var(--s-accent)}'
    . '#flutter-takeover-status [data-kubus-takeover-message]{display:block;margin:0;overflow-wrap:anywhere;font-size:clamp(1.5rem,1.1rem + 1.6vw,2.25rem);font-weight:600;line-height:1.12;letter-spacing:-.01em;text-wrap:balance;color:var(--s-text)}'
    . '#flutter-takeover-status .takeover-note{flex:1 1 100%;max-width:36rem;font-size:.875rem;line-height:1.4;color:var(--s-muted)}'
    . '#flutter-takeover-status .takeover-trace{position:absolute;left:0;right:0;bottom:0;overflow:hidden;width:auto;height:2px;background:var(--s-rule)}'
    . '#flutter-takeover-status .takeover-actions{flex:1 1 100%;display:grid;grid-template-columns:repeat(auto-fit,minmax(7.5rem,1fr));gap:.75rem;margin-top:.125rem}'
    . '#flutter-takeover-status [data-kubus-takeover-refresh],#flutter-takeover-status [data-kubus-takeover-app]{display:inline-flex;align-items:center;justify-content:center;min-height:2.75rem;padding:.5rem 1.25rem;border:1px solid var(--s-text);border-radius:.25rem;background:transparent;color:var(--s-text);font:inherit;font-weight:600;line-height:1.25;text-align:center;text-decoration:none;cursor:pointer}'
    . '#flutter-takeover-status [data-kubus-takeover-app],#flutter-takeover-status[data-state=failed] [data-kubus-takeover-refresh]{background:var(--s-accent);border-color:var(--s-accent);color:var(--s-on)}'
    . '#flutter-takeover-status[data-state=failed] [data-kubus-takeover-app]{background:transparent;border-color:var(--s-text);color:var(--s-text)}'
    . '#flutter-takeover-status [data-kubus-takeover-refresh]:disabled{border-style:dashed;background:transparent;color:var(--color-muted,#626b61);cursor:default}'
    . '#flutter-takeover-status [data-kubus-takeover-refresh]:focus-visible,#flutter-takeover-status [data-kubus-takeover-app]:focus-visible{outline:3px solid var(--s-focus);outline-offset:3px}'
    . '@media(min-width:760px){#flutter-takeover-status{display:grid;grid-template-columns:auto minmax(0,1fr);column-gap:2.5rem;padding:2rem 1.5rem 2.25rem}#flutter-takeover-status .takeover-globe{--g:8.5rem;grid-area:1/1/5/2}#flutter-takeover-status .takeover-head{grid-area:1/2;gap:.625rem}#flutter-takeover-status .takeover-note{grid-area:2/2;font-size:1rem;line-height:1.55}#flutter-takeover-status .takeover-trace{position:relative;left:auto;right:auto;bottom:auto;width:min(100%,22rem);grid-area:3/2}#flutter-takeover-status .takeover-actions{grid-area:4/2;display:flex;flex-wrap:wrap;margin-top:.75rem}html.kubus-takeover-capable #flutter-takeover-status[hidden][data-state=pending]{display:grid}}'
    . '#flutter-takeover-status .takeover-globe>*{grid-area:1/1;width:100%;height:100%}'
    . '#flutter-takeover-status .tg-d{fill:var(--s-bg)}'
    . '#flutter-takeover-status .tg-pose{opacity:0}'
    . '#flutter-takeover-status .tg-p0{opacity:1}'
    . '#flutter-takeover-status .tg-orbit{display:grid;place-items:center;transform:rotate(-24deg)}'
    . '#flutter-takeover-status .ts{width:calc(var(--g)*.0375);height:calc(var(--g)*.0375);border-radius:50%;background:currentColor;opacity:.65;transform:translate(calc(var(--g)*.475),0)}'
    . '#flutter-takeover-status:is([data-state=loading],[data-state=slow]) .tg-pose{animation:kubus-pose 8s linear infinite}#flutter-takeover-status:is([data-state=loading],[data-state=slow]) .tg-p1{animation-delay:-6s}#flutter-takeover-status:is([data-state=loading],[data-state=slow]) .tg-p2{animation-delay:-4s}#flutter-takeover-status:is([data-state=loading],[data-state=slow]) .tg-p3{animation-delay:-2s}#flutter-takeover-status:is([data-state=loading],[data-state=slow]) .ts{animation:kubus-orbit 8s linear infinite}#flutter-takeover-status:is([data-state=loading],[data-state=slow]) .takeover-trace::after{animation:kubus-trace 2.6s cubic-bezier(.45,0,.55,1) infinite}'
    . '#flutter-takeover-status .takeover-trace::after{content:"";position:absolute;inset:0 auto 0 0;width:34%;background:var(--s-accent);transform:translateX(-100%)}'
    . '@keyframes kubus-pose{0%{opacity:1}25%{opacity:0}75%{opacity:0}100%{opacity:1}}'
    . '@keyframes kubus-orbit{0%{transform:translate(calc(var(--g)*0.475),calc(var(--g)*0));opacity:0.65}6.25%{transform:translate(calc(var(--g)*0.4388),calc(var(--g)*0.0619));opacity:1}12.5%{transform:translate(calc(var(--g)*0.3359),calc(var(--g)*0.1143));opacity:1}18.75%{transform:translate(calc(var(--g)*0.1818),calc(var(--g)*0.1494));opacity:1}25%{transform:translate(calc(var(--g)*0),calc(var(--g)*0.1617));opacity:1}31.25%{transform:translate(calc(var(--g)*-0.1818),calc(var(--g)*0.1494));opacity:1}37.5%{transform:translate(calc(var(--g)*-0.3359),calc(var(--g)*0.1143));opacity:1}43.75%{transform:translate(calc(var(--g)*-0.4388),calc(var(--g)*0.0619));opacity:1}50%{transform:translate(calc(var(--g)*-0.475),calc(var(--g)*0));opacity:0.65}56.25%{transform:translate(calc(var(--g)*-0.4388),calc(var(--g)*-0.0619));opacity:0.3}62.5%{transform:translate(calc(var(--g)*-0.3359),calc(var(--g)*-0.1143));opacity:0.3}68.75%{transform:translate(calc(var(--g)*-0.1818),calc(var(--g)*-0.1494));opacity:0.3}75%{transform:translate(calc(var(--g)*0),calc(var(--g)*-0.1617));opacity:0.3}81.25%{transform:translate(calc(var(--g)*0.1818),calc(var(--g)*-0.1494));opacity:0.3}87.5%{transform:translate(calc(var(--g)*0.3359),calc(var(--g)*-0.1143));opacity:0.3}93.75%{transform:translate(calc(var(--g)*0.4388),calc(var(--g)*-0.0619));opacity:0.3}100%{transform:translate(calc(var(--g)*0.475),calc(var(--g)*0));opacity:0.65}}'
    . '@keyframes kubus-trace{from{transform:translateX(-100%)}to{transform:translateX(300%)}}'
    . '#flutter-takeover-status[data-state=failed] .takeover-label,#flutter-takeover-status[data-state=failed] .takeover-note,#flutter-takeover-status[data-state=failed] .takeover-trace,#flutter-takeover-status[data-state=failed] .tg-orbit{display:none}'
    . '#flutter-takeover-status[data-paused] .tg-pose,#flutter-takeover-status[data-paused] .ts,#flutter-takeover-status[data-paused] .takeover-trace::after{animation-play-state:paused!important}'
    . '@media(prefers-reduced-motion:reduce){#flutter-takeover-status .tg-pose,#flutter-takeover-status .ts,#flutter-takeover-status .takeover-trace::after{animation:none!important}#flutter-takeover-status .takeover-trace::after{display:none}}'
    . '#flutter-takeover-status[data-state=failed] .tg-pose:not(.tg-p0){opacity:0}'
    . '#flutter-takeover-status[data-state=failed]{row-gap:0}#flutter-takeover-status[data-state=failed] .takeover-actions{margin-top:.75rem}'
    . '@media(max-width:760px) and (min-height:800px){html:has(#flutter-takeover-status:not([hidden])) .entity-media img{max-height:min(55vh,max(18rem,calc(100svh - 32rem)))}}';

const KUBUS_TAKEOVER_GLOBE_SVG = '<span class="takeover-globe" aria-hidden="true"><svg viewBox="0 0 120 120" aria-hidden="true" focusable="false"><g transform="rotate(-24 60 60)"><g transform="translate(0 60) scale(1 .34) translate(0 -60)"><circle cx="60" cy="60" r="57" fill="none" stroke="currentColor" stroke-width="1" stroke-dasharray="2 4" vector-effect="non-scaling-stroke"/></g></g><circle class="tg-d" cx="60" cy="60" r="44"/><g fill="none" stroke="currentColor"><circle cx="60" cy="60" r="44" stroke-width="2"/><path d="M16 60h88M22 38h76M22 82h76M38 22h44M38 98h44" stroke-width="1.25" stroke-opacity=".4"/></g></svg><svg viewBox="0 0 120 120" aria-hidden="true" focusable="false" class="tg-pose tg-p0"><g fill="none" stroke="currentColor" stroke-width="1.25"><ellipse cx="60" cy="60" rx="5.7" ry="44"/><ellipse cx="60" cy="60" rx="40.7" ry="44"/><ellipse cx="60" cy="60" rx="34.9" ry="44"/></g></svg><svg viewBox="0 0 120 120" aria-hidden="true" focusable="false" class="tg-pose tg-p1"><g fill="none" stroke="currentColor" stroke-width="1.25"><ellipse cx="60" cy="60" rx="16.8" ry="44"/><ellipse cx="60" cy="60" rx="43.6" ry="44"/><ellipse cx="60" cy="60" rx="26.8" ry="44"/></g></svg><svg viewBox="0 0 120 120" aria-hidden="true" focusable="false" class="tg-pose tg-p2"><g fill="none" stroke="currentColor" stroke-width="1.25"><ellipse cx="60" cy="60" rx="26.8" ry="44"/><ellipse cx="60" cy="60" rx="43.6" ry="44"/><ellipse cx="60" cy="60" rx="16.8" ry="44"/></g></svg><svg viewBox="0 0 120 120" aria-hidden="true" focusable="false" class="tg-pose tg-p3"><g fill="none" stroke="currentColor" stroke-width="1.25"><ellipse cx="60" cy="60" rx="34.9" ry="44"/><ellipse cx="60" cy="60" rx="40.7" ry="44"/><ellipse cx="60" cy="60" rx="5.7" ry="44"/></g></svg><svg viewBox="0 0 120 120" aria-hidden="true" focusable="false"><g transform="rotate(-24 60 60)"><g transform="translate(0 60) scale(1 .34) translate(0 -60)"><path d="M3 60a57 57 0 0 0 114 0" fill="none" stroke="currentColor" stroke-width="1.5" vector-effect="non-scaling-stroke"/></g></g></svg><span class="tg-orbit"><span class="ts"></span></span></span>';

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
        . KUBUS_TAKEOVER_GLOBE_SVG
        . '<span class="takeover-head">'
        . '<span class="takeover-label">' . takeoverEscape($copy['label']) . '</span>'
        . '<span data-kubus-takeover-message role="status" aria-live="polite" aria-atomic="true">' . takeoverEscape($copy['loading']) . '</span>'
        . '</span>'
        . '<span class="takeover-note">' . takeoverEscape($copy['note']) . '</span>'
        . '<span class="takeover-trace" aria-hidden="true"></span>'
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
    // The capability handshake runs before first paint, so the section can be painted with no layout shift.
    // It is emitted once; a page that already carries it keeps its own tag.
    $capabilityScript = stripos($html, 'takeover_capability.js') === false
        ? '<script src="/takeover_capability.js"></script>'
        : '';
    $html = preg_replace('/<\/head>/i', $takeoverStyle . $capabilityScript . '</head>', $html, 1);
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
