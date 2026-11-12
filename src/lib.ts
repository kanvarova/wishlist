import {createClient} from '@supabase/supabase-js';
import type {Product} from './types';
const url=import.meta.env?.VITE_SUPABASE_URL;
const key=import.meta.env?.VITE_SUPABASE_ANON_KEY;
export const db=url&&key&&!url.includes('YOUR_')?createClient(url,key):null;
export const money=(n:number)=>new Intl.NumberFormat('ru-KZ',{maximumFractionDigits:0}).format(n)+' ₸';
export function recommend(products:Product[],budget:number){
  const eligible=products.filter(p=>!p.archived&&p.published&&p.status==='available');
  const within=eligible.filter(p=>p.price<=budget).sort((a,b)=>b.price-a.price||a.position-b.position||a.id.localeCompare(b.id));
  if(within.length)return {products:within,nearby:false};
  const above=eligible.filter(p=>p.price>budget).sort((a,b)=>a.price-b.price||a.position-b.position||a.id.localeCompare(b.id));
  if(!above.length)return {products:[],nearby:false};
  let tolerance=Math.max(budget*.2,2000);
  while(above[0].price>budget+tolerance)tolerance*=2;
  return {products:above.filter(p=>p.price<=budget+tolerance).slice(0,6),nearby:true};
}
export function validUrl(value:string){try {return ['https:','http:'].includes(new URL(value).protocol)}catch{return false}}
export function safeFavorites():string[]{try{const v=JSON.parse(localStorage.getItem('wishlist-favorites')||'[]');return Array.isArray(v)?v.filter((x:unknown)=>typeof x==='string'):[]}catch{return []}}
export async function share(url:string,title:string){if(navigator.share){try{await navigator.share({url,title});return 'Отправлено ♡'}catch(e){if((e as Error).name==='AbortError')return '';}}await navigator.clipboard.writeText(url);return 'Ссылка скопирована ♡'}
export async function uploadPhoto(file:File){
  if(!db)throw Error('Сначала подключите базу данных.');
  if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>10*1024*1024)throw Error('Выберите JPG, PNG или WebP до 10 МБ.');
  const bitmap=await createImageBitmap(file);const scale=Math.min(1,1600/Math.max(bitmap.width,bitmap.height));
  const canvas=document.createElement('canvas');canvas.width=Math.round(bitmap.width*scale);canvas.height=Math.round(bitmap.height*scale);
  canvas.getContext('2d')!.drawImage(bitmap,0,0,canvas.width,canvas.height);bitmap.close();
  const blob=await new Promise<Blob>((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(Error('Не удалось обработать фото.')),'image/webp',.85));
  if(blob.size>5*1024*1024)throw Error('После сжатия фото больше 5 МБ. Выберите другое.');
  const path=crypto.randomUUID()+'.webp';const {error}=await db.storage.from('gift-images').upload(path,blob,{contentType:'image/webp',cacheControl:'31536000'});if(error)throw Error('Не удалось загрузить фото. Проверьте подключение и права доступа.');
  return db.storage.from('gift-images').getPublicUrl(path).data.publicUrl;
}
export function russianError(error:unknown){const message=error instanceof Error?error.message:(error as {message?:string})?.message||'';return /[А-Яа-яЁё]/.test(message)?message:'Не получилось выполнить действие. Проверьте подключение и попробуйте ещё раз.'}

