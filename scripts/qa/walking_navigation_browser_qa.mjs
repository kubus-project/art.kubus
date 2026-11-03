import { chromium, firefox } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';

// Debug-only full Flutter/MapLibre pipeline. Graph responses are controlled
// fixtures; this is not evidence for the production graph-delivery service.
// Start the debug web server on port 49387 with
// --dart-define=BACKEND_BASE_URL=http://127.0.0.1:49487, then run
// npm ci --prefix scripts/qa and node scripts/qa/walking_navigation_browser_qa.mjs.
const base = process.env.WALKING_QA_URL || 'http://127.0.0.1:49387';
const out = path.resolve(process.env.WALKING_QA_OUT || 'output/playwright/artifacts/walking-browser-fixture');
await fs.mkdir(out, { recursive: true });
// Reuse the previously recorded Ljubljana pedestrian geometry rather than
// inventing a route. It is served as a controlled graph fixture, not live OSM.
const harness = await fs.readFile(new URL('../../lib/features/map/navigation/walking_navigation_debug_harness.dart', import.meta.url), 'utf8');
const routeSection = harness.split('static const List<LatLng> routePoints = <LatLng>[')[1]?.split('];')[0];
if (!routeSection) throw new Error('Walking harness route fixture not found');
const points = [...routeSection.matchAll(/LatLng\(([-\d.]+),\s*([-\d.]+)\)/g)].map(m => [Number(m[1]), Number(m[2])]);
if (points.length < 10) throw new Error('Walking harness fixture is incomplete');
const elements = points.map(([lat, lon], i) => ({type: 'node', id: i + 1, lat, lon}));
elements.push({type: 'way', id: 100, nodes: points.map((_, i) => i + 1), tags: {highway:'footway', name:'Synthetic fixture walk'}});
// An actual localhost HTTP server returns a bounded, recorded graph fixture.
// It validates the request shape and records no coordinate values.
let activeResult;
const fixtureServer = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'content-type');
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
  if (req.method !== 'POST' || req.url !== '/api/walking-graph') {res.writeHead(404); return res.end();}
  let raw=''; for await (const chunk of req) raw += chunk;
  let body; try {body=JSON.parse(raw);} catch (_) {body=null;}
  const valid = body && Object.keys(body).sort().join(',') === 'east,north,south,west' && Object.values(body).every(Number.isFinite);
  activeResult.graphRequests.push({method:req.method,path:req.url,validSchema:Boolean(valid),status:valid ? 200 : 400});
  res.writeHead(valid ? 200 : 400, {'content-type':'application/json'});
  res.end(JSON.stringify(valid ? {elements} : {error:'invalid fixture request'}));
});
await new Promise((resolve, reject) => fixtureServer.listen(49487, '127.0.0.1', resolve).on('error', reject));
const report = [];
for (const [name, browserType] of Object.entries({chromium, firefox})) {
  const result = {browser:name, fixture:true, graphRequests:[], diagnostics:[], pageErrors:[], status:'FAIL'};
  activeResult = result;
  let browser;
  try {
    browser = await browserType.launch({headless:true, ...(name === 'chromium' ? {args:['--use-angle=swiftshader','--enable-webgl']} : {})});
    const context = await browser.newContext({viewport:{width:1280,height:800}});
    await context.tracing.start({screenshots:true,snapshots:true,sources:true});
    const page = await context.newPage();
    page.on('console', msg => {const text=msg.text(); if (text.includes('WalkingNavigation:')) result.diagnostics.push(text);});
    page.on('pageerror', err => result.pageErrors.push(String(err)));
    await page.goto(base + '/debug/walking-route?live=1', {waitUntil:'domcontentloaded',timeout:120000});
    const deadline=Date.now()+120000;
    while (Date.now()<deadline && !result.diagnostics.some(x=>x.includes('route_visually_ready'))) await page.waitForTimeout(500);
    await page.screenshot({path:path.join(out,`${name}-walking.png`)});
    // The screenshot records the pre-end geometry. Click the visible End
    // control at this fixed desktop viewport, then require the real session
    // end event; the follow-up screenshot permits visual cleanup inspection.
    await page.mouse.click(580, 224);
    const endDeadline=Date.now()+10000;
    while (Date.now()<endDeadline && !result.diagnostics.some(x=>x.includes('navigation_ended'))) await page.waitForTimeout(250);
    await page.screenshot({path:path.join(out,`${name}-ended.png`)});
    const checks = {
      firstPartyPost:result.graphRequests[0]?.method === 'POST' && result.graphRequests[0]?.status === 200,
      requestSchema:result.graphRequests[0]?.validSchema === true,
      routeCreated:result.diagnostics.some(x=>x.includes('route_created')),
      sourceWritten:result.diagnostics.some(x=>x.includes('route_source_write_succeeded')),
      layersVisible:result.diagnostics.some(x=>x.includes('route_visibility_succeeded')),
      cameraFitted:result.diagnostics.some(x=>x.includes('route_camera_fitted')),
      visuallyReady:result.diagnostics.some(x=>x.includes('route_visually_ready')),
      ended:result.diagnostics.some(x=>x.includes('navigation_ended')),
      noUncaughtPageErrors:result.pageErrors.length === 0,
    };
    result.checks=checks;
    result.status=Object.values(checks).every(Boolean)?'PASS':'FAIL';
    await context.tracing.stop({path:path.join(out,`${name}-trace.zip`)});
    await context.close();
  } catch(e) {result.error=String(e?.stack || e);}
  finally {await browser?.close();}
  report.push(result);
  await fs.writeFile(path.join(out,`${name}-result.json`),JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
}
await new Promise(resolve => fixtureServer.close(resolve));
if (report.some(x=>x.status!=='PASS')) process.exitCode=1;
