#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const args = process.argv.slice(2);

function readArg(name, fallback = null) {
  const index = args.indexOf(name);
  if (index === -1) return fallback;
  return args[index + 1] || fallback;
}

const repoRoot = path.resolve(readArg("--root", process.cwd()));
const outputJson = args.includes("--json");

const ignoredDirs = new Set([
  ".dart_tool",
  ".git",
  ".gradle",
  ".idea",
  ".vscode",
  "build",
  "coverage",
  "dist",
  "node_modules",
  "Pods",
]);

const violations = [];
let checkedFiles = 0;
let directDebugPrintCount = 0;

// Current debt ceiling captured during the desloppify pass. Lower this number
// after each focused logging cleanup; never raise it without documenting why.
const directDebugPrintBudget = 814;

function toRepoPath(filePath) {
  return path.relative(repoRoot, filePath).split(path.sep).join("/");
}

function fileExists(relativePath) {
  return fs.existsSync(path.join(repoRoot, relativePath));
}

function lineFor(source, index) {
  return source.slice(0, index).split(/\r?\n/).length;
}

function addViolation(rule, filePath, message, index = 0) {
  violations.push({
    rule,
    file: toRepoPath(filePath),
    line: lineFor(readFile(filePath), index),
    message,
  });
}

function addAggregateViolation(rule, relativePath, message) {
  violations.push({
    rule,
    file: relativePath,
    line: 1,
    message,
  });
}

function readFile(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function walk(relativeDir, extensions) {
  const start = path.join(repoRoot, relativeDir);
  if (!fs.existsSync(start)) return [];

  const files = [];
  const stack = [start];

  while (stack.length > 0) {
    const current = stack.pop();
    const entries = fs.readdirSync(current, { withFileTypes: true });

    for (const entry of entries) {
      if (ignoredDirs.has(entry.name)) continue;
      const fullPath = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(fullPath);
        continue;
      }
      if (!entry.isFile()) continue;
      if (extensions && !extensions.has(path.extname(entry.name))) continue;
      files.push(fullPath);
    }
  }

  return files;
}

function scanRegex(files, rule, pattern, message) {
  for (const filePath of files) {
    checkedFiles += 1;
    const source = readFile(filePath);
    let match;
    pattern.lastIndex = 0;
    while ((match = pattern.exec(source)) !== null) {
      addViolation(rule, filePath, message, match.index);
    }
  }
}

function extractCall(source, callStart) {
  const open = source.indexOf("(", callStart);
  if (open === -1) return null;

  let depth = 0;
  let quote = null;
  let lineComment = false;
  let blockComment = false;
  let escaped = false;

  for (let i = open; i < source.length; i += 1) {
    const char = source[i];
    const next = source[i + 1];

    if (lineComment) {
      if (char === "\n") lineComment = false;
      continue;
    }

    if (blockComment) {
      if (char === "*" && next === "/") {
        blockComment = false;
        i += 1;
      }
      continue;
    }

    if (quote) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char === "\\") {
        escaped = true;
        continue;
      }
      if (char === quote) quote = null;
      continue;
    }

    if (char === "/" && next === "/") {
      lineComment = true;
      i += 1;
      continue;
    }

    if (char === "/" && next === "*") {
      blockComment = true;
      i += 1;
      continue;
    }

    if (char === "'" || char === '"' || char === "`") {
      quote = char;
      continue;
    }

    if (char === "(") depth += 1;
    if (char === ")") {
      depth -= 1;
      if (depth === 0) {
        return {
          text: source.slice(callStart, i + 1),
          start: callStart,
        };
      }
    }
  }

  return null;
}

function scanMulterMemoryLimits() {
  const files = walk("backend/src/routes", new Set([".js", ".cjs", ".mjs"]));
  for (const filePath of files) {
    checkedFiles += 1;
    const source = readFile(filePath);
    let index = 0;
    while ((index = source.indexOf("multer(", index)) !== -1) {
      const call = extractCall(source, index);
      if (!call) {
        index += "multer(".length;
        continue;
      }
      if (
        /multer\.memoryStorage\s*\(\s*\)/.test(call.text) &&
        !/\blimits\s*:/.test(call.text)
      ) {
        addViolation(
          "AK-GUARD-006",
          filePath,
          "multer.memoryStorage() uploads must declare explicit limits.",
          call.start,
        );
      }
      index = call.start + call.text.length;
    }
  }
}

function scanDirectDebugPrintBudget() {
  const files = walk("lib", new Set([".dart"]));
  const directDebugPrintPattern = /(?<![\w.])debugPrint\s*\(/g;

  for (const filePath of files) {
    checkedFiles += 1;
    const source = readFile(filePath);
    directDebugPrintPattern.lastIndex = 0;
    const matches = source.match(directDebugPrintPattern);
    directDebugPrintCount += matches ? matches.length : 0;
  }

  if (directDebugPrintCount > directDebugPrintBudget) {
    addAggregateViolation(
      "AK-GUARD-008",
      "lib",
      `Unqualified debugPrint calls increased to ${directDebugPrintCount}; keep at or below ${directDebugPrintBudget} and prefer AppConfig.debugPrint or kDebugMode-guarded helpers.`,
    );
  }
}

function runtimeConfigFiles() {
  const extensions = new Set([
    ".cjs",
    ".dart",
    ".env",
    ".js",
    ".json",
    ".mjs",
    ".sql",
    ".yaml",
    ".yml",
  ]);
  const files = new Set([
    ...walk("lib", extensions),
    ...walk("backend/src", extensions),
  ]);

  for (const relativePath of [
    "pubspec.yaml",
    "package.json",
    "version.json",
    "backend/package.json",
  ]) {
    if (fileExists(relativePath)) files.add(path.join(repoRoot, relativePath));
  }

  return [...files];
}

scanRegex(
  walk("lib", new Set([".dart"])),
  "AK-GUARD-001",
  /^\s*import\s+['"]dart:html['"]/gm,
  "Do not import dart:html; use package:web with conditional imports.",
);

scanRegex(
  [
    ...walk("lib/models", new Set([".dart"])),
    ...walk("lib/providers", new Set([".dart"])),
    ...walk("lib/screens", new Set([".dart"])),
    ...walk("lib/widgets", new Set([".dart"])),
  ],
  "AK-GUARD-002",
  /^\s*import\s+['"]package:http\/http\.dart['"]/gm,
  "Models, providers, screens, and widgets must use service boundaries instead of direct package:http imports.",
);

scanRegex(
  runtimeConfigFiles(),
  "AK-GUARD-003",
  /cloudflare-ipfs\.com/gi,
  "Do not reintroduce the retired cloudflare-ipfs.com gateway in runtime code or config.",
);

scanRegex(
  walk("lib", new Set([".dart"])),
  "AK-GUARD-004",
  /debugPrint\s*\(\s*['"`]DEBUG:/g,
  "Do not ship noisy debugPrint('DEBUG: ...') logs.",
);

scanRegex(
  [
    "lib/screens/map_screen.dart",
    "lib/screens/desktop/desktop_map_screen.dart",
  ]
    .filter(fileExists)
    .map((relativePath) => path.join(repoRoot, relativePath)),
  "AK-GUARD-005",
  /\b(?:addLayer|addSource|removeLayer|removeSource)\s*\(/g,
  "Map screens must not mutate MapLibre layers directly; use MapLayersManager.",
);

scanMulterMemoryLimits();

scanDirectDebugPrintBudget();

scanRegex(
  walk("lib/models", new Set([".dart"])),
  "AK-GUARD-007",
  /^\s*import\s+['"].*backend_api_service\.dart['"]/gm,
  "Domain models must not import BackendApiService; use config or media resolver helpers instead.",
);

const result = {
  ok: violations.length === 0,
  root: repoRoot,
  checkedFiles,
  directDebugPrintCount,
  directDebugPrintBudget,
  violations,
};

if (outputJson) {
  console.log(JSON.stringify(result, null, 2));
} else if (result.ok) {
  console.log(
    `Architecture guard passed (${checkedFiles} file checks; direct debugPrint budget ${directDebugPrintCount}/${directDebugPrintBudget}).`,
  );
} else {
  console.error(`Architecture guard failed with ${violations.length} violation(s):`);
  for (const violation of violations) {
    console.error(
      `- ${violation.rule} ${violation.file}:${violation.line} ${violation.message}`,
    );
  }
}

process.exitCode = result.ok ? 0 : 1;
