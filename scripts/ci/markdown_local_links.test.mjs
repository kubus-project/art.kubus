import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { validateLocalMarkdownLinks } from '../lib/markdown_local_links.mjs';

function withRoot(run) {
  const rootDir = mkdtempSync(join(tmpdir(), 'kubus-doc-links-'));
  try {
    mkdirSync(join(rootDir, 'docs'), { recursive: true });
    run(rootDir);
  } finally {
    rmSync(rootDir, { recursive: true, force: true });
  }
}

function validate(markdown, rootDir) {
  return validateLocalMarkdownLinks(markdown, {
    sourcePath: 'docs/guide.md',
    rootDir,
    backendRoot: join(rootDir, 'backend'),
  });
}

test('broken HTML href/src and reference definitions fail validation', () => {
  withRoot((rootDir) => {
    const result = validate(
      '<a href="missing-page.md">missing</a>\n' +
        '<img src=missing-image.png>\n' +
        '[details]: missing-reference.md\n' +
        '[details]\n',
      rootDir,
    );
    assert.equal(result.checked.length, 3);
    assert.equal(result.issues.length, 3);
    assert.match(result.issues.join('\n'), /missing-page\.md/);
    assert.match(result.issues.join('\n'), /missing-image\.png/);
    assert.match(result.issues.join('\n'), /missing-reference\.md/);
  });
});

test('valid Markdown, reference, and HTML links pass while external URLs are skipped', () => {
  withRoot((rootDir) => {
    writeFileSync(join(rootDir, 'docs', 'target.md'), '# target\n');
    writeFileSync(join(rootDir, 'docs', 'image.png'), 'fixture');
    const result = validate(
      '[inline](target.md#part)\n' +
        '[reference][target]\n' +
        '[target]: <target.md> "title"\n' +
        '<a href="target.md?mode=1">target</a>\n' +
        '<img src=./image.png>\n' +
        '[external](https://example.test/page)\n' +
        '<a href="mailto:team@example.test">mail</a>\n',
      rootDir,
    );
    assert.equal(result.checked.length, 4);
    assert.deepEqual(result.issues, []);
  });
});

test('links inside fenced examples and unresolved backend gitlink targets are skipped', () => {
  withRoot((rootDir) => {
    const result = validate(
      '```md\n[example](missing-in-example.md)\n' +
        '<img src="missing-in-example.png">\n```\n' +
        '<a href="../backend/README.md">backend</a>\n',
      rootDir,
    );
    assert.equal(result.checked.length, 1);
    assert.deepEqual(result.issues, []);
  });
});

test('long fences close only on an equal-or-longer run of the same marker', () => {
  withRoot((rootDir) => {
    const result = validate(
      '[before](missing-before.md)\n' +
        '````md\n' +
        '```\n' +
        '[short nested fence](missing-short-nested.md)\n' +
        '~~~~~\n' +
        '[mismatched marker](missing-mismatched-marker.md)\n' +
        '`````\n' +
        '[after backtick fence](missing-after-backtick.md)\n' +
        '~~~~~md\n' +
        '~~~~\n' +
        '[short tilde close](missing-short-tilde-close.md)\n' +
        '`````\n' +
        '[mismatched backtick marker](missing-mismatched-backtick.md)\n' +
        '~~~~~~\n' +
        '[after tilde fence](missing-after-tilde.md)\n',
      rootDir,
    );

    assert.deepEqual(result.checked, [
      'missing-before.md',
      'missing-after-backtick.md',
      'missing-after-tilde.md',
    ]);
    assert.equal(result.issues.length, 3);
  });
});
