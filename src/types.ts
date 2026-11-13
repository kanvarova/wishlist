export type Category = {id:string;name:string;position:number;visible:boolean};
export type PurchaseLink = {id?:string;store:string;url:string};
export type Product = {id:string;name:string;price:number;category_id:string|null;description:string;image_url:string;published:boolean;archived:boolean;position:number;created_at:string;gift_type:'beautiful'|'practical'|'small'|'any';links:PurchaseLink[];status?:'available'|'reserved'|'purchased'};
export type Settings = {id:number;title:string;subtitle:string;accent:string;background:string;birthday:string|null;countdown_enabled:boolean;countdown_text:string;categories_visible:boolean;budget_min:number;budget_max:number};
export const defaults:Settings={id:1,title:'MY WISHLIST',subtitle:'',accent:'#4a1823',background:'#f7eee5',birthday:null,countdown_enabled:false,countdown_text:'До моего дня рождения осталось',categories_visible:true,budget_min:5000,budget_max:150000};
