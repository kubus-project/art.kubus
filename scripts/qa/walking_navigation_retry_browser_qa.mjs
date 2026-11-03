// Controlled network-failure browser test; requires the debug fixture web server.
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { chromium, firefox } from 'playwright';
const out=path.resolve(process.env.WALKING_QA_OUT || 'output/playwright/artifacts/walking-retry-fixture'); fs.mkdirSync(out,{recursive:true});
const dart=fs.readFileSync(new URL('../../lib/features/map/navigation/walking_navigation_debug_harness.dart', import.meta.url),'utf8');
const section=dart.split('static const List<LatLng> routePoints = <LatLng>[')[1].split('];')[0];
const points=[...section.matchAll(/LatLng\(([-\d.]+),\s*([-\d.]+)\)/g)].map(x=>[Number(x[1]),Number(x[2])]);
const elements=points.map(([lat,lon],i)=>({type:'node',id:i+1,lat,lon})); elements.push({type:'way',id:100,nodes:points.map((_,i)=>i+1),tags:{highway:'footway'}});
let active; const server=http.createServer(async(req,res)=>{res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS');res.setHeader('Access-Control-Allow-Headers','content-type'); if(req.method==='OPTIONS'){res.writeHead(204);res.end();return;} if(req.url!='/api/walking-graph'){res.writeHead(404);res.end();return;}for await(const c of req){} active.firstParty++;let status=active.firstParty===1?502:200; active.statuses.push(status);res.writeHead(status,{'content-type':'application/json'});res.end(JSON.stringify(status===200?{elements}:{error:'fixture'}));});
(async()=>{await new Promise(r=>server.listen(49487,'127.0.0.1',r)); let reports=[]; for(const [name,type] of Object.entries({chromium,firefox}).filter(([n])=>!process.env.WALKING_QA_BROWSER||n===process.env.WALKING_QA_BROWSER)){
active={firstParty:0,statuses:[],diagnostics:[],pageErrors:[],fallbacks:0};const browser=await type.launch({headless:true});const ctx=await browser.newContext({viewport:{width:1280,height:800}});await ctx.tracing.start({screenshots:true,snapshots:true});const page=await ctx.newPage();page.on('console',m=>{if(m.text().includes('WalkingNavigation:'))active.diagnostics.push(m.text());});page.on('pageerror',e=>active.pageErrors.push(String(e)));await page.route('**/api/interpreter',async route=>{active.fallbacks++;await route.fulfill({status:502,body:'fixture failure',headers:{'access-control-allow-origin':'*'}});});
try{await page.goto('http://127.0.0.1:49387/debug/walking-route?live=1',{waitUntil:'domcontentloaded',timeout:120000});let end=Date.now()+120000;while(Date.now()<end&&!active.diagnostics.some(x=>x.includes('route_request_failed')))await page.waitForTimeout(200);await page.screenshot({path:`${out}/${name}-failure.png`});console.log(name+' failure '+JSON.stringify(active));
// Explicit retry button location established from the captured failure panel.
await page.mouse.click(478,200); end=Date.now()+30000;while(Date.now()<end&&!active.diagnostics.some(x=>x.includes('route_visually_ready')))await page.waitForTimeout(200);await page.screenshot({path:`${out}/${name}-after-retry.png`});active.pass=active.firstParty===2&&active.statuses.join(',')==='502,200'&&active.fallbacks===2&&active.diagnostics.some(x=>x.includes('route_visually_ready'))&&active.pageErrors.length===0;
}catch(e){active.error=String(e);}await ctx.tracing.stop({path:`${out}/${name}-trace.zip`});reports.push({browser:name,...active});await browser.close();fs.writeFileSync(`${out}/results.json`,JSON.stringify(reports,null,2));}
server.close();console.log(JSON.stringify(reports,null,2));if(reports.some(x=>!x.pass))process.exitCode=1;
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
