const ID='2890e5ec-3fdd-474e-a0ee-b16e5097b669';
const strip=(h)=>h.replace(/<style[\s\S]*?<\/style>/g,'<style/>').replace(/"(generatedAt|expiresAt)":"[^"]*"/g,'"$1":"T"');
(async()=>{let bad=0;
for(const p of ['/en/artworks/'+ID,'/sl/umetnine/'+ID,'/en/artworks/00000000-0000-4000-8000-000000000000']){
  const [a,b]=await Promise.all([fetch('http://127.0.0.1:5110'+p),fetch('http://127.0.0.1:5112'+p)]);
  const [ta,tb]=[await a.text(),await b.text()];
  const same=strip(ta)===strip(tb);
  const grab=(t,re)=>(t.match(re)||[]).join('|');
  const ld=(t)=>grab(t,/<script type="application\/ld\+json">[\s\S]*?<\/script>/g);
  console.log(p.slice(0,18).padEnd(19),'status',a.status,b.status,'| non-CSS html identical:',same,'| JSON-LD identical:',ld(ta)===ld(tb),'| canonical:',grab(tb,/<link rel="canonical"[^>]*>/).slice(0,70),'| og:image identical:',grab(ta,/og:image" content="[^"]*"/)===grab(tb,/og:image" content="[^"]*"/));
  if(!same)bad++;
}
process.exit(bad?1:0);})();
