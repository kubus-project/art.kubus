import test from 'node:test';
import assert from 'node:assert/strict';
import { artworkLocaleOwner } from './seo_locale_contract.mjs';
const en='https://app.kubus.site/en/artworks/id';
const sl='https://app.kubus.site/sl/umetnine/id';
const links=`<link href="${en}" hreflang="en" rel="alternate"><link rel="alternate" hreflang="sl" href="${sl}"><link rel="alternate" hreflang="x-default" href="${en}">`;
test('untranslated artwork consolidates at English owner',()=>{
  assert.deepEqual(artworkLocaleOwner('', '', en, sl),{canonical:en,translated:false,valid:true});
});
test('reciprocal translated artwork retains Slovenian owner',()=>{
  assert.deepEqual(artworkLocaleOwner(links,links,en,sl),{canonical:sl,translated:true,valid:true});
});
test('one-sided locale declaration is rejected',()=>{
  assert.equal(artworkLocaleOwner(links,'',en,sl).valid,false);
});
test('alternate for another artwork is rejected',()=>{
  assert.equal(artworkLocaleOwner(links.replace(sl,sl+'-other'),links,en,sl).valid,false);
});
test('translated artwork must retain English x-default',()=>{
  assert.equal(artworkLocaleOwner(links.replace('hreflang="x-default"','hreflang="other"'),links,en,sl).valid,false);
});
