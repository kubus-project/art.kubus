import { spawnSync } from 'node:child_process';
import path from 'node:path';

// Run from the repository root after starting the debug fixture app with
// BACKEND_BASE_URL=http://127.0.0.1:49487. Set WALKING_QA_EXTERNAL_GRAPH=1
// and WALKING_QA_GRAPH_PORT to use a separately running real graph listener
// for the first test. Retry and cancellation always use controlled fixtures.
const root=path.resolve(process.env.WALKING_QA_OUT || 'output/playwright/artifacts/walking-browser-all');
const scripts=[['route','walking_navigation_browser_qa.mjs'],['retry','walking_navigation_retry_browser_qa.mjs'],['cancel','walking_navigation_cancel_browser_qa.mjs']];
let failed=false;
for (const [label, script] of scripts) {
  const result=spawnSync(process.execPath,[path.join('scripts','qa',script)],{stdio:'inherit',env:{...process.env,WALKING_QA_OUT:path.join(root,label)}});
  if (result.error || result.status !== 0) {failed=true; console.error(`${label} failed: ${result.error || result.status}`);}
}
if (failed) process.exitCode=1;
