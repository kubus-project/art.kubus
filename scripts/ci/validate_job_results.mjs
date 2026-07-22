#!/usr/bin/env node
import { pathToFileURL } from 'node:url';

export function validateJobResults(needs, expectedJobs) {
  const failures = [];
  for (const job of expectedJobs) {
    if (!Object.hasOwn(needs, job)) {
      failures.push(`${job}: missing`);
      continue;
    }
    const result = needs[job]?.result;
    if (result !== 'success' && result !== 'skipped') failures.push(`${job}: ${result || 'missing result'}`);
  }
  if (failures.length) throw new Error(`Required job results were not acceptable: ${failures.join(', ')}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const needs = JSON.parse(process.env.NEEDS_JSON || '{}');
    const expected = (process.env.EXPECTED_JOBS || '').split(',').map((value) => value.trim()).filter(Boolean);
    validateJobResults(needs, expected);
    process.stdout.write(`Aggregate accepted ${expected.length} declared job results.\n`);
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}
