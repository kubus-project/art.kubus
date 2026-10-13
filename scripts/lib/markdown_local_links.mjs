import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

function withoutFencedCode(markdown) {
  return markdown.replace(/^\s*(```|~~~)[^\n]*\n[\s\S]*?^\s*\1\s*$/gm, '');
}

function localLinkTargets(markdown) {
  const prose = withoutFencedCode(markdown);
  const targets = [];
  const inline = /\[[^\]]+\]\(\s*(?:<([^>]+)>|([^\s)]+))(?:\s+(?:"[^"]*"|'[^']*'))?\s*\)/g;
  for (const match of prose.matchAll(inline)) targets.push(match[1] ?? match[2]);

  // Reference definitions are the source of their destination, including
  // collapsed and shortcut references, so checking definitions validates all
  // reference-style local links without needing a second label parser.
  const definitions = /^[ \t]{0,3}\[[^\]\r\n]+\]:[ \t]*(?:<([^>\r\n]+)>|(\S+))(?:[ \t]+(?:"[^"\r\n]*"|'[^'\r\n]*'|\([^)\r\n]*\)))?[ \t]*$/gm;
  for (const match of prose.matchAll(definitions)) targets.push(match[1] ?? match[2]);

  const htmlAttributes = /\b(?:href|src)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'`=<>]+))/gi;
  for (const match of prose.matchAll(htmlAttributes)) {
    targets.push(match[1] ?? match[2] ?? match[3]);
  }
  return targets;
}

function isNonFileUrl(target) {
  return (
    !target ||
    target.startsWith('#') ||
    target.startsWith('//') ||
    target.startsWith('/') ||
    /^[a-z][a-z\d+.-]*:/i.test(target)
  );
}

/** Validate local Markdown, reference-definition, and inline HTML file links. */
export function validateLocalMarkdownLinks(
  markdown,
  { sourcePath, rootDir, backendRoot, fileExists = existsSync },
) {
  const checked = [];
  const issues = [];
  const sourceFile = resolve(rootDir, sourcePath);
  for (const rawTarget of localLinkTargets(markdown)) {
    const target = rawTarget.trim();
    if (isNonFileUrl(target)) continue;
    const pathPart = target.split(/[?#]/, 1)[0];
    if (!pathPart) continue;

    let decoded;
    try {
      decoded = decodeURIComponent(pathPart);
    } catch {
      issues.push(`has a malformed local link: ${target}`);
      continue;
    }
    checked.push(target);
    const resolved = resolve(dirname(sourceFile), decoded);
    if (
      !fileExists(resolved) &&
      (resolved === backendRoot ||
        resolved.startsWith(`${backendRoot}${process.platform === 'win32' ? '\\' : '/'}`))
    ) {
      // The private backend is a validated gitlink. Unprivileged PR jobs do not
      // materialize it, so trusted backend workflows check its internal links.
      continue;
    }
    if (!fileExists(resolved)) issues.push(`has a broken local link: ${target}`);
  }
  return { checked, issues };
}
