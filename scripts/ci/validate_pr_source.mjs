#!/usr/bin/env node
import { pathToFileURL } from 'node:url';

export function validatePrSource({ eventName, baseRef, headRef, headRepository, repository }) {
  if (eventName === 'workflow_dispatch') return { tier: 'manual' };
  if (eventName !== 'pull_request') throw new Error(`Unsupported event: ${eventName}`);
  if (baseRef === 'dev') {
    if (headRef === 'dev' || headRef === 'master') {
      throw new Error(`Protected branch ${headRef} cannot be an ordinary PR source.`);
    }
    return { tier: 'integration' };
  }
  if (baseRef === 'master') {
    if (headRepository !== repository) {
      throw new Error('Release and hotfix PRs must originate in the protected repository.');
    }
    if (headRef === 'dev') return { tier: 'release' };
    if (/^hotfix\/[A-Za-z0-9][A-Za-z0-9._/-]*$/.test(headRef) && !headRef.includes('..')) {
      return { tier: 'hotfix' };
    }
    throw new Error(`PRs into master may originate only from dev or hotfix/*, not ${headRef}.`);
  }
  throw new Error(`Pull requests into ${baseRef} are outside the governed workflow.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const result = validatePrSource({
      eventName: process.env.EVENT_NAME,
      baseRef: process.env.BASE_REF,
      headRef: process.env.HEAD_REF,
      headRepository: process.env.HEAD_REPOSITORY,
      repository: process.env.REPOSITORY,
    });
    process.stdout.write(`PR source policy passed (${result.tier}).\n`);
  } catch (error) {
    console.error(error.message);
    process.exit(1);
  }
}
