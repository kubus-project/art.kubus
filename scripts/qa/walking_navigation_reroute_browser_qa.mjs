import { chromium, firefox } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';

// Debug-only: fixed live-position stream follows the route then leaves it.
// Start the harness with BACKEND_BASE_URL=http://127.0.0.1:49487 and a
// separately provisioned graph listener on WALKING_QA_GRAPH_PORT.
// The Flutter debug web server boots only the FIRST browser connection after it
// starts: restart it before every browser run (WALKING_QA_BROWSER=chromium|firefox).
const out=path.resolve(process.env.WALKING_QA_OUT || 'output/playwright/artifacts/walking-reroute');
const port=process.env.WALKING_QA_GRAPH_PORT || '49488';
await fs.mkdir(out,{recursive:true});
const results=[];
const only=process.env.WALKING_QA_BROWSER;
for (const [name,type] of Object.entries({chromium,firefox}).filter(([n])=>!only||n===only)) {
  const result={browser:name,diagnostics:[],pageErrors:[],graphStatuses:[],pass:false};
  const browser=await type.launch({headless:true});
  const context=await browser.newContext({viewport:{width:1280,height:800}});
  await context.tracing.start({screenshots:true,snapshots:true});
  const page=await context.newPage();
  page.on('console',msg=>{if(msg.text().includes('WalkingNavigation:'))result.diagnostics.push(msg.text());});
  page.on('pageerror',error=>result.pageErrors.push(String(error)));
  page.on('response',response=>{if(response.url().includes('/api/walking-graph') && response.request().method()==='POST')result.graphStatuses.push(response.status());});
  await page.route('**/api/walking-graph',route=>route.continue({url:`http://127.0.0.1:${port}/api/walking-graph`}));
  try {
    await page.goto('http://127.0.0.1:49387/debug/walking-route?live=1&simulateWalk=1',{waitUntil:'domcontentloaded',timeout:120000});
    const deadline=Date.now()+110000;
    while(Date.now()<deadline && (result.diagnostics.filter(x=>x.includes('route_created')).length<2 || !result.diagnostics.some(x=>x.includes('reroute_triggered')))) await page.waitForTimeout(250);
    await page.screenshot({path:path.join(out,`${name}-rerouted.png`)});
    result.pass=result.graphStatuses.includes(200) && result.diagnostics.some(x=>x.includes('reroute_triggered')) && result.diagnostics.filter(x=>x.includes('route_created')).length>=2 && result.diagnostics.filter(x=>x.includes('route_source_write_succeeded')).length>=2 && result.pageErrors.length===0;
  } catch(error) { result.error=String(error); }
  await context.tracing.stop({path:path.join(out,`${name}-trace.zip`)});
  await browser.close(); results.push(result);
  await fs.writeFile(path.join(out,'results.json'),JSON.stringify(results,null,2));
  console.log(JSON.stringify(result));
}
if(results.some(x=>!x.pass))process.exitCode=1;
