async page => {
 // Run with playwright-cli after opening the disposable Head of Flowers fixture.
 const origin=new URL(page.url()).origin;
 const profile='8c03b35a-a4d6-4c08-95fc-503c879fbc45'; const out=[];
 for (const width of [390,1440]) for(const lang of ['en','sl']) {
  await page.setViewportSize({width,height:900});
  const rail=page.getByRole('button',{name:lang==='sl'?'Skr\u010di navigacijo':'Collapse navigation'});
  const artworkSegment=lang==='sl'?'umetnine':'artworks';
  await page.goto(`${origin}/${lang}/${artworkSegment}/53b99c8b-8503-545c-8a13-55f60cfb8342`);
  await page.getByRole('button',{name:/turrdl/}).first().waitFor({timeout:30000});
  if(await rail.count()!==0) throw Error(`${width} ${lang}: cold canonical entry unexpectedly has a rail`);
  const coldShell=await page.evaluate(()=>history.state?.state?.desktopShell===true);
  if(coldShell) throw Error(`${width} ${lang}: cold entry incorrectly serialized a rail`);
  await page.reload();
  await page.getByRole('button',{name:/turrdl/}).first().waitFor({timeout:30000});
  if(await rail.count()!==0) throw Error(`${width} ${lang}: cold entry reload gained a rail`);
  await page.goto(`${origin}/c/9102a51b-5d66-546d-8f6b-738394a6ccf1?lang=${lang}`);
  await page.getByRole('button',{name:/turrdl/}).first().click({timeout:30000});
  await page.waitForURL(u=>u.pathname.includes(profile),{timeout:30000});
  const title='Lala';
  await page.getByRole('button',{name:new RegExp(title+'.*mural','i')}).first().click({timeout:30000});
  await page.waitForURL(u=>u.pathname.includes('/artworks/')||u.pathname.includes('/umetnine/'),{timeout:30000});
  await page.getByRole('button',{name:/turrdl/}).first().waitFor({timeout:30000});
  if(width===1440) await rail.waitFor({state:'visible',timeout:30000});
  const original=page.url(),railBefore=await rail.count();
  await page.getByRole('button',{name:/turrdl/}).first().click();
  await page.waitForURL(u=>u.pathname.includes(profile),{timeout:30000});
  await page.goBack();await page.waitForURL(original,{timeout:30000});
  await page.getByRole('button',{name:/turrdl/}).first().waitFor({timeout:30000});
  if(width===1440) await rail.waitFor({state:'visible',timeout:30000});
  const railAfter=await rail.count();
  if(railBefore!==railAfter || (width===1440&&railAfter!==1)) throw Error(`${width} ${lang}: shell changed ${railBefore} -> ${railAfter}`);
  await page.goForward();
  await page.waitForURL(u=>u.pathname.includes(profile),{timeout:30000});
  await page.getByRole('button',{name:/Lala.*mural/i}).first().waitFor({timeout:30000});
  await page.goBack();
  await page.waitForURL(original,{timeout:30000});
  await page.getByRole('button',{name:/turrdl/}).first().waitFor({timeout:30000});
  if(width===1440) await rail.waitFor({state:'visible',timeout:30000});
  if(await rail.count()!==railBefore) throw Error(`${width} ${lang}: shell changed after Forward and Back`);
  await page.reload();await page.getByRole('button',{name:/turrdl/}).first().waitFor({timeout:30000});
  if(width===1440) await rail.waitFor({state:'visible',timeout:30000});
  const railReload=await rail.count();
  if(railBefore!==railReload) throw Error(`${width} ${lang}: reload shell changed ${railBefore} -> ${railReload}`);
  out.push(`${width} ${lang}: collection -> profile -> ${title} -> profile -> browser Back -> Forward -> Back -> reload passed`);
 }
 return out;
}


