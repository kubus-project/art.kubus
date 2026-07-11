import { rmSync } from 'node:fs';
import { dirname, isAbsolute, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const reportsDir = resolve(rootDir, 'android', 'build', 'reports');
const reportPath = resolve(reportsDir, 'problems', 'problems-report.html');
const reportRelativePath = relative(reportsDir, reportPath);

if (reportRelativePath.startsWith('..') || isAbsolute(reportRelativePath)) {
  throw new Error(`Refusing to remove generated report outside ${reportsDir}`);
}

rmSync(reportPath, { force: true });
console.log(`Cleared generated Gradle problems report: ${reportPath}`);
