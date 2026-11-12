-- No products are seeded. All privileged mutation paths use auth.uid().
create table public.admin_authorization(user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admin_authorization enable row level security;
create function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.admin_authorization where user_id=auth.uid());
$$;
create table public.categories(id uuid primary key default gen_random_uuid(),name text not null check(length(name) between 1 and 60),position integer not null default 0,visible boolean not null default true);
create table public.products(
 id uuid primary key default gen_random_uuid(), name text not null check(length(name) between 1 and 160),
 price numeric(12,0) not null check(price>0), category_id uuid references public.categories on delete set null,
 description text not null default '' check(length(description)<=3000), image_url text not null default '' check(image_url='' or image_url ~ '^https://'),
 published boolean not null default true, archived boolean not null default false, position integer not null default 0,
 gift_type text not null default 'any' check(gift_type in ('beautiful','practical','small','any')),created_at timestamptz not null default now()
);
create table public.product_purchase_links(id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products on delete cascade,store text not null check(length(store) between 1 and 80),url text not null check(length(url)<=2048 and url ~ '^https?://[^[:space:]]+'));
create index purchase_product on public.product_purchase_links(product_id);
create table public.website_settings(
 id integer primary key default 1 check(id=1), title text not null default 'MY WISHLIST ♡' check(length(title) between 1 and 100),
 subtitle text not null default 'Маленький гид по тому, что сделает меня счастливее.' check(length(subtitle)<=300),
 accent text not null default '#52613e' check(accent ~ '^#[0-9a-fA-F]{6}$'),background text not null default '#f8f6f1' check(background ~ '^#[0-9a-fA-F]{6}$'),
 birthday date, countdown_enabled boolean not null default false,countdown_text text not null default 'До моего дня рождения осталось' check(length(countdown_text)<=150),
 categories_visible boolean not null default true,budget_min integer not null default 5000 check(budget_min>=0),budget_max integer not null default 150000 check(budget_max>budget_min and budget_max<=999999999)
);
create table public.reservations(
 id uuid primary key default gen_random_uuid(),product_id uuid not null unique references public.products on delete cascade,
 nickname text not null check(length(nickname) between 1 and 80),token_hash text not null unique,client_hash text not null,
 status text not null default 'reserved' check(status in ('reserved','purchased')),created_at timestamptz not null default now()
);
create table public.reservation_throttle(id bigint generated always as identity primary key,client_hash text not null,created_at timestamptz not null default now());
create index throttle_time on public.reservation_throttle(created_at);
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_purchase_links enable row level security;
alter table public.website_settings enable row level security;
alter table public.reservations enable row level security;
alter table public.reservation_throttle enable row level security;
create policy categories_public on public.categories for select to anon,authenticated using(visible or public.is_admin());
create policy settings_public on public.website_settings for select to anon,authenticated using(true);
create policy products_public on public.products for select to anon,authenticated using((published and not archived) or public.is_admin());
create policy links_public on public.product_purchase_links for select to anon,authenticated using(exists(select 1 from public.products p where p.id=product_id and ((p.published and not p.archived) or public.is_admin())));
create policy categories_admin on public.categories for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy products_admin on public.products for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy links_admin on public.product_purchase_links for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy settings_admin on public.website_settings for all to authenticated using(public.is_admin()) with check(public.is_admin());
-- No reservation SELECT policy, including for administrators. Reveal is explicit.
grant select on public.categories,public.products,public.product_purchase_links,public.website_settings to anon,authenticated;
grant insert,update,delete on public.categories,public.products,public.product_purchase_links,public.website_settings to authenticated;
revoke all on public.reservations,public.admin_authorization,public.reservation_throttle from anon,authenticated;
create function public.public_catalog() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(p)||jsonb_build_object('status',coalesce(r.status,'available'),'links',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'store',l.store,'url',l.url)) from public.product_purchase_links l where l.product_id=p.id),'[]'::jsonb)) order by p.position,p.created_at desc),'[]'::jsonb)
 from public.products p left join public.reservations r on r.product_id=p.id where p.published and not p.archived;
$$;
create function public.reserve_gift(p_product uuid,p_nickname text,p_client text) returns text language plpgsql security definer set search_path='' as $$
declare v_token text; v_hash text;
begin
 if length(trim(p_nickname)) not between 1 and 80 or p_nickname is null then raise exception 'Введите имя или псевдоним (до 80 символов).'; end if;
 if p_client is null or length(p_client) not between 32 and 128 then raise exception 'Обновите страницу и попробуйте снова.'; end if;
 v_hash=encode(sha256(convert_to(p_client,'UTF8')),'hex');
 perform pg_advisory_xact_lock(20261112);
 delete from public.reservation_throttle where created_at<now()-interval '1 hour';
 if (select count(*) from public.reservation_throttle where created_at>now()-interval '10 minutes')>=30 or exists(select 1 from public.reservation_throttle where client_hash=v_hash and created_at>now()-interval '30 seconds') then raise exception 'Слишком много запросов. Попробуйте чуть позже.'; end if;
 perform 1 from public.products where id=p_product and published and not archived for update;
 if not found then raise exception 'Этот подарок больше недоступен.'; end if;
 if exists(select 1 from public.reservations where product_id=p_product) then raise exception 'Этот подарок уже кто-то выбрал ♡'; end if;
 v_token=replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-','');
 insert into public.reservations(product_id,nickname,token_hash,client_hash) values(p_product,trim(p_nickname),encode(sha256(convert_to(v_token,'UTF8')),'hex'),v_hash);
 insert into public.reservation_throttle(client_hash) values(v_hash);
 return v_token;
end;$$;
create function public.manage_reservation(p_token text,p_action text default 'view') returns jsonb language plpgsql security definer set search_path='' as $$
declare v_r public.reservations; v_name text;
begin
 if p_token is null or length(p_token)<>64 then raise exception 'Приватная ссылка недействительна.'; end if;
 select * into v_r from public.reservations where token_hash=encode(sha256(convert_to(p_token,'UTF8')),'hex') for update;
 if not found then raise exception 'Бронь не найдена. Возможно, она уже отменена.';end if;
 select name into v_name from public.products where id=v_r.product_id;
 if p_action='cancel' then
   if v_r.status='purchased' then raise exception 'Покупка уже подтверждена. Для изменения обратитесь к владельцу вишлиста.';end if;
   delete from public.reservations where id=v_r.id;
 elsif p_action='purchase' then update public.reservations set status='purchased' where id=v_r.id;v_r.status='purchased';
 elsif p_action<>'view' then raise exception 'Неизвестное действие.';end if;
 return jsonb_build_object('product_name',v_name,'status',case when p_action='cancel' then 'cancelled' else v_r.status end);
end;$$;
create function public.reveal_surprises(p_confirm boolean) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not public.is_admin() or p_confirm is distinct from true then raise exception 'Нужны права владельца и подтверждение раскрытия.';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('product_name',p.name,'nickname',r.nickname,'status',r.status,'created_at',r.created_at)) from public.reservations r join public.products p on p.id=r.product_id),'[]'::jsonb);
end;$$;
-- Atomic content edits; reservation state is never part of the admin response.
create function public.save_gift(p_product jsonb,p_links jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if not public.is_admin() then raise exception 'Доступ только для владельца.';end if;
 v_id=coalesce(nullif(p_product->>'id','')::uuid,gen_random_uuid());
 insert into public.products(id,name,price,category_id,description,image_url,published,archived,position,gift_type)
 values(v_id,p_product->>'name',(p_product->>'price')::numeric,nullif(p_product->>'category_id','')::uuid,coalesce(p_product->>'description',''),coalesce(p_product->>'image_url',''),coalesce((p_product->>'published')::boolean,true),coalesce((p_product->>'archived')::boolean,false),coalesce((p_product->>'position')::integer,0),coalesce(p_product->>'gift_type','any'))
 on conflict(id) do update set name=excluded.name,price=excluded.price,category_id=excluded.category_id,description=excluded.description,image_url=excluded.image_url,published=excluded.published,archived=excluded.archived,position=excluded.position,gift_type=excluded.gift_type;
 delete from public.product_purchase_links where product_id=v_id;
 insert into public.product_purchase_links(product_id,store,url) select v_id,x->>'store',x->>'url' from jsonb_array_elements(p_links) x;
 return v_id;
end;$$;
create function public.reorder_gifts(p_ids uuid[]) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_admin() then raise exception 'Доступ только для владельца.';end if;
 update public.products p set position=s.n from (select unnest(p_ids) as id,generate_subscripts(p_ids,1) as n)s where p.id=s.id;
end;$$;
-- Supabase may grant anon/authenticated EXECUTE through default privileges.
-- Revoke those direct grants too, without touching unrelated functions.
revoke execute on function public.is_admin(),public.public_catalog(),public.reserve_gift(uuid,text,text),public.manage_reservation(text,text),public.reveal_surprises(boolean),public.save_gift(jsonb,jsonb),public.reorder_gifts(uuid[]) from public,anon,authenticated;
grant execute on function public.is_admin(),public.public_catalog(),public.reserve_gift(uuid,text,text),public.manage_reservation(text,text) to anon,authenticated;
grant execute on function public.reveal_surprises(boolean),public.save_gift(jsonb,jsonb),public.reorder_gifts(uuid[]) to authenticated;
insert into public.website_settings(id) values(1);
insert into public.categories(name,position) values ('Красота',0),('Одежда',1),('Аксессуары',2),('Техника',3),('Для дома',4),('Впечатления',5),('Другое',6);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('gift-images','gift-images',true,5242880,array['image/jpeg','image/png','image/webp']);
create policy images_read on storage.objects for select to anon,authenticated using(bucket_id='gift-images');
create policy images_admin on storage.objects for all to authenticated using(bucket_id='gift-images' and public.is_admin()) with check(bucket_id='gift-images' and public.is_admin());
