import assert from 'node:assert/strict';
const origin=process.env.WISHLIST_URL||'https://wishlist-kanvarova.vercel.app';
const api=process.env.VITE_SUPABASE_URL,key=process.env.VITE_SUPABASE_ANON_KEY;
const checked=[];
async function get(url,options={}){const response=await fetch(url,{...options,signal:AbortSignal.timeout(20000)});assert.equal(response.status,200,`${new URL(url).pathname}: HTTP ${response.status}`);return response}
async function run(){
 const home=await get(origin+'/');const html=await home.text();assert.match(html,/<html lang="ru"/);assert.match(html,/<div id="root"/);assert.match(home.headers.get('content-security-policy')||'',/script-src/);checked.push('homepage + CSP');
 for(const route of ['/admin','/reservation']){assert.match(await(await get(origin+route)).text(),/<div id="root"/)}checked.push('SPA routes');
 const js=[...html.matchAll(/<script[^>]*src="([^"]+)"/g)].map(m=>m[1]);assert.ok(js.length,'JS entry missing');for(const path of js){const response=await get(new URL(path,origin));assert.match(response.headers.get('content-type')||'',/javascript/)}checked.push('JS assets');
 for(const path of ['/karina.webp','/og.png','/favicon.svg']){const response=await get(origin+path);assert.match(response.headers.get('content-type')||'',/image\//)}checked.push('images');
 assert.ok(api&&key,'Public Supabase environment missing; database was NOT checked. Use node --env-file-if-exists=.env.local scripts/healthcheck.mjs');
 const headers={apikey:key,'Content-Type':'application/json'};
 const settings=await(await get(api+'/rest/v1/website_settings?select=title,subtitle,accent,background&id=eq.1',{headers})).json();assert.equal(settings.length,1);assert.ok(settings[0].title);checked.push('public settings');
 const catalog=await(await get(api+'/rest/v1/rpc/public_catalog',{method:'POST',headers,body:'{}'})).json();assert.ok(Array.isArray(catalog));for(const gift of catalog){assert.equal(typeof gift.name,'string');assert.ok(Number.isFinite(gift.price)&&gift.price>0);assert.ok(Array.isArray(gift.links));assert.ok(!('nickname' in gift)&&!('token' in gift),'Private booking data exposed')};checked.push(`catalog (${catalog.length} gifts)`);
 const auth=await(await get(api+'/auth/v1/settings',{headers})).json();assert.equal(auth.disable_signup,true,'Public registration must stay disabled');checked.push('signup disabled');
 console.log(JSON.stringify({ok:true,at:new Date().toISOString(),checks:checked},null,2));
}
run().catch(error=>{console.error(JSON.stringify({ok:false,at:new Date().toISOString(),completed:checked,error:error.message},null,2));process.exitCode=1});
