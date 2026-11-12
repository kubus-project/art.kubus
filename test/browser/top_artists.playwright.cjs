async page => {
  const out = [];
  for (const lang of ['en','sl']) {
    await page.setViewportSize({width:1440,height:900});
    await page.goto(`http://127.0.0.1:58092/${lang}/${lang==='sl'?'zemljevid':'map'}`);
    await page.getByRole('button',{name:lang==='sl'?'Domov':'Home',exact:true}).click({timeout:30000});
    const title=page.getByRole('group',{name:lang==='sl'?'Izpostavljeni umetniki':'Top Artists'});
    await page.waitForTimeout(1500);
    await page.mouse.move(1300,650);
    await page.mouse.wheel(0,800);
    await title.waitFor({timeout:30000});
    const row=page.getByRole('button',{name:'Damjan Stevovic @damjan_stevovic'});
    await row.waitFor({timeout:30000});
    const box=await row.boundingBox();
    if(!box || box.y<0 || box.y+box.height>900) throw Error(`${lang}: artist row is outside viewport`);
    await page.mouse.click(box.x+box.width/2,box.y+box.height/2);
    await page.waitForURL(/\/profiles\/8c03b35a-a4d6-4c08-95fc-503c879fbc45|\/profili\/8c03b35a-a4d6-4c08-95fc-503c879fbc45/,{timeout:30000});
    out.push(`${lang}: real artist display name, handle and profile navigation passed`);
  }
  return out;
}
