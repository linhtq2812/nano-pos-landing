-- Demo data for landing screenshots: one merchant, one shop "Tạp hoá Hoa Mai",
-- ~40 grocery products, customers, suppliers and ~35 days of counter sales.
-- LOCAL Supabase only (tools/demo/seed.sh checks the URL). Called with -v email=...
--
-- Rows are written as the owner (role authenticated + JWT claims), the same path the
-- apps take, so RLS, cost stamping, stock movements and report rollups all fire.
\set ON_ERROR_STOP 1

select id as owner from auth.users where email = :'email' \gset

-- ---------------------------------------------------------------- tenancy (as postgres)
begin;
insert into public.merchants (id, name, owner_user_id, legal_name, contact_phone)
values ('d0000000-0000-4000-8000-000000000001', 'Hoa Mai', :'owner', 'Hộ kinh doanh Hoa Mai', '0901234567')
on conflict do nothing;
insert into public.shops (id, merchant_id, name, code, address_line, phone, is_default)
values ('d0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000001',
        'Tạp hoá Hoa Mai', 'HM01', '12 Lê Lợi, Phường Bến Thành', '0901234567', true)
on conflict do nothing;
insert into public.shop_members (user_id, shop_id, role, display_name)
values (:'owner', 'd0000000-0000-4000-8000-000000000002', 'owner', 'Chị Mai')
on conflict do nothing;
update platform.subscriptions set plan_code = 'pro', is_trial = false
 where merchant_id = 'd0000000-0000-4000-8000-000000000001';
insert into platform.shop_licenses (shop_id, merchant_id, valid_until)
values ('d0000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-000000000001', now() + interval '1 year')
on conflict (shop_id) do nothing;
commit;

-- ---------------------------------------------------------------- shop data (as the owner)
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', :'owner', 'role', 'authenticated', 'email', :'email')::text, true);
set local role authenticated;

do $seed$
declare
  v_shop  constant uuid := 'd0000000-0000-4000-8000-000000000002';
  v_owner constant uuid := (current_setting('request.jwt.claims')::json->>'sub')::uuid;
  v_now   constant bigint := (extract(epoch from now()) * 1000)::bigint;
  v_tz    constant text := 'Asia/Ho_Chi_Minh';
  r record;
  v_day int; v_n int; v_i int; v_lines int; v_l int;
  v_order uuid; v_ts bigint; v_total numeric; v_pick int; v_qty int;
  v_method text; v_cust uuid; v_status text; v_no bigint := 1000;
  v_variants uuid[]; v_prices numeric[]; v_names text[]; v_units text[];
  v_customers uuid[];
  v_seed float := 0.42;
begin
  perform setseed(v_seed);

  -- Categories
  insert into categories (id, shop_id, name, last_updated)
  select md5('cat-' || c)::uuid, v_shop, c, v_now
    from unnest(array['Đồ uống','Sữa','Mì & đồ khô','Gia vị','Bánh kẹo','Vệ sinh','Gia dụng']) c
  on conflict do nothing;

  -- Products: name, category, unit, price, cost, stock, low-stock threshold
  for r in
    select * from (values
      ('Nước suối Lavie 500ml','Đồ uống','Chai', 6000, 3800, 180, 24),
      ('Coca-Cola lon 320ml','Đồ uống','Lon', 10000, 7200, 140, 24),
      ('Pepsi lon 320ml','Đồ uống','Lon', 10000, 7100, 96, 24),
      ('Trà xanh Không Độ 455ml','Đồ uống','Chai', 10000, 7000, 72, 24),
      ('Nước tăng lực Sting','Đồ uống','Chai', 12000, 8300, 60, 24),
      ('Bia Tiger lon 330ml','Đồ uống','Lon', 19000, 15500, 120, 24),
      ('Cà phê G7 hộp 18 gói','Đồ uống','Hộp', 58000, 46000, 22, 6),
      ('Sữa tươi Vinamilk 180ml','Sữa','Hộp', 8000, 6100, 200, 48),
      ('Sữa đặc Ông Thọ','Sữa','Lon', 26000, 21000, 40, 10),
      ('Sữa chua Vinamilk lốc 4','Sữa','Lốc', 28000, 22500, 18, 8),
      ('Mì Hảo Hảo tôm chua cay','Mì & đồ khô','Gói', 5000, 3700, 300, 60),
      ('Mì Omachi sườn','Mì & đồ khô','Gói', 9000, 6800, 120, 30),
      ('Phở bò Vifon','Mì & đồ khô','Gói', 9000, 6500, 4, 20),
      ('Gạo ST25 túi 5kg','Mì & đồ khô','Túi', 185000, 152000, 25, 5),
      ('Trứng gà hộp 10','Mì & đồ khô','Hộp', 36000, 29000, 30, 10),
      ('Dầu ăn Neptune 1L','Gia vị','Chai', 62000, 51000, 28, 6),
      ('Nước mắm Nam Ngư 750ml','Gia vị','Chai', 42000, 33000, 34, 8),
      ('Nước tương Chinsu 500ml','Gia vị','Chai', 22000, 16500, 40, 8),
      ('Muối chấm Hảo Hảo','Gia vị','Gói', 15000, 10500, 36, 8),
      ('Hạt nêm Knorr 400g','Gia vị','Gói', 38000, 30500, 3, 8),
      ('Đường trắng Biên Hoà 1kg','Gia vị','Gói', 29000, 23500, 26, 6),
      ('Bánh Oreo 133g','Bánh kẹo','Gói', 21000, 15800, 45, 10),
      ('Snack Oishi tôm cay','Bánh kẹo','Gói', 6000, 4100, 150, 30),
      ('Bánh Chocopie hộp 12','Bánh kẹo','Hộp', 58000, 47000, 20, 5),
      ('Kẹo Alpenliebe gói','Bánh kẹo','Gói', 18000, 13000, 30, 6),
      ('Bột giặt Omo 800g','Vệ sinh','Túi', 49000, 39500, 30, 6),
      ('Nước rửa chén Sunlight 750g','Vệ sinh','Chai', 32000, 25000, 26, 6),
      ('Nước tẩy rửa Vim 880ml','Vệ sinh','Chai', 39000, 31000, 2, 6),
      ('Dầu gội Clear 340g','Vệ sinh','Chai', 98000, 79000, 14, 4),
      ('Kem đánh răng P/S 230g','Vệ sinh','Tuýp', 36000, 28000, 32, 8),
      ('Giấy vệ sinh Pulppy 10 cuộn','Vệ sinh','Bịch', 69000, 55000, 18, 5),
      ('Khăn giấy Let-green','Gia dụng','Gói', 12000, 8000, 60, 12),
      ('Pin AA Panasonic vỉ 2','Gia dụng','Vỉ', 16000, 11000, 40, 6),
      ('Bật lửa Thống Nhất','Gia dụng','Cái', 5000, 2800, 80, 12),
      ('Túi rác đen cuộn','Gia dụng','Cuộn', 15000, 10000, 35, 8),
      ('Bánh mì que Pháp gói','Bánh kẹo','Gói', 8000, 5000, 12, 4)
    ) t(name, cat, unit, price, cost, stock, low)
  loop
    insert into products (id, shop_id, name, category_id, last_updated)
    values (md5('p-' || r.name)::uuid, v_shop, r.name, md5('cat-' || r.cat)::uuid, v_now)
    on conflict do nothing;
    insert into product_variants (id, shop_id, product_id, sku, barcode, price, base_unit_name,
                                  stock_quantity, manage_stock, low_stock_threshold, last_updated)
    values (md5('v-' || r.name)::uuid, v_shop, md5('p-' || r.name)::uuid,
            'HM' || lpad((abs(hashtext(r.name)) % 100000)::text, 5, '0'),
            '893' || lpad((abs(hashtext('b' || r.name)) % 1000000000)::text, 10, '0'),
            r.price, r.unit, r.stock + 0, true, r.low, v_now)
    on conflict do nothing;
    insert into product_costs (variant_id, shop_id, cost_price, last_updated)
    values (md5('v-' || r.name)::uuid, v_shop, r.cost, v_now)
    on conflict do nothing;
  end loop;

  select array_agg(v.id order by v.price), array_agg(v.price order by v.price),
         array_agg(p.name order by v.price), array_agg(v.base_unit_name order by v.price)
    into v_variants, v_prices, v_names, v_units
    from product_variants v join products p on p.id = v.product_id
   where v.shop_id = v_shop;

  -- Receiving bank account for VietQR. Fictional number and holder, never a real one.
  insert into shop_bank_accounts (id, shop_id, bank_code, account_no, account_name, is_default, last_updated)
  values ('d0000000-0000-4000-8000-0000000000b1', v_shop, 'VCB', '1023456789', 'TAP HOA HOA MAI', true, v_now)
  on conflict do nothing;

  -- Customers (a few regulars buy on credit) and suppliers
  insert into customers (id, shop_id, name, phone, last_updated)
  select md5('c-' || n)::uuid, v_shop, n, ph, v_now
    from (values ('Cô Ba bán xôi','0903111222'), ('Anh Tư xe ôm','0918222333'), ('Chị Hạnh','0987333444'),
                 ('Quán cơm Bà Sáu','0909444555'), ('Anh Khoa','0938555666'), ('Chú Bảy','0913666777'),
                 ('Chị Thu','0977777888'), ('Bác Năm','0906888999')) t(n, ph)
  on conflict do nothing;
  select array_agg(id) into v_customers from customers where shop_id = v_shop and name in ('Cô Ba bán xôi','Quán cơm Bà Sáu','Anh Tư xe ôm');

  insert into suppliers (id, shop_id, name, phone, last_updated)
  select md5('s-' || n)::uuid, v_shop, n, ph, v_now
    from (values ('NPP Vinamilk Quận 1','02838111222'), ('Đại lý nước giải khát Minh Long','0908123123'),
                 ('Tổng kho tạp hoá An Khang','0912456456'), ('Công ty Unilever (NPP)','02839888777')) t(n, ph)
  on conflict do nothing;

  -- Cash book: opening balances 75 days ago and recurring expenses (fixed ids, safe to re-run).
  insert into cash_book_openings (shop_id, fund, opened_on, amount, updated_by)
  values (v_shop, 'cash', (now() at time zone v_tz)::date - 75, 5000000, v_owner),
         (v_shop, 'bank', (now() at time zone v_tz)::date - 75, 20000000, v_owner)
  on conflict do nothing;
  insert into cash_book_entries (id, shop_id, kind, fund, amount, category_id, is_accounted,
                                 counterparty, note, timestamp, created_by)
  select md5('cb-' || e.tag || '-' || m)::uuid, v_shop, 'out', e.fund, e.amount, e.cat::uuid, e.acc,
         e.who, e.note,
         (extract(epoch from ((date_trunc('month', (now() at time zone v_tz)) - make_interval(months => m))
            + make_interval(days => e.dom - 1, hours => 9)) at time zone v_tz) * 1000)::bigint,
         v_owner
    from generate_series(0, 2) m,
         (values ('rent', 'bank', 6000000, 'cb000000-0000-0000-0000-000000000004', true, 'Chủ nhà', 'Tiền thuê mặt bằng', 1),
                 ('power', 'cash', 1350000, 'cb000000-0000-0000-0000-000000000003', true, 'EVN', 'Tiền điện nước', 5),
                 ('salary', 'bank', 5500000, 'cb000000-0000-0000-0000-000000000002', true, 'Lan', 'Lương thu ngân', 10),
                 ('goods', 'cash', 4200000, 'cb000000-0000-0000-0000-000000000001', false, 'Tổng kho An Khang', 'Trả tiền nhập hàng', 3)
         ) e(tag, fund, amount, cat, acc, who, note, dom)
   where (date_trunc('month', (now() at time zone v_tz)) - make_interval(months => m)
          + make_interval(days => e.dom - 1)) <= (now() at time zone v_tz)
  on conflict do nothing;

  if exists (select 1 from sale_orders where shop_id = v_shop) then
    raise notice 'demo orders already present, skipping (DEMO_RESET=1 to regenerate)';
    return;
  end if;

  -- Counter sales: 75 days back to today, busier on weekends, open 6:30–21:30.
  for v_day in reverse 74..0 loop
    v_n := 38 + floor(random() * 22)::int
           + case when extract(isodow from (now() at time zone v_tz)::date - v_day) in (6, 7) then 14 else 0 end;
    if v_day = 0 then
      v_n := greatest(8, (v_n * least(1.0, (extract(hour from now() at time zone v_tz) - 6.5) / 15.0))::int);
    end if;
    for v_i in 1..v_n loop
      v_no := v_no + 1;
      v_order := md5('o-' || v_no)::uuid;
      v_ts := (extract(epoch from (((now() at time zone v_tz)::date - v_day)::timestamp
                 + interval '6 hours 30 minutes'
                 + (v_i::float / (v_n + 1)) * interval '15 hours'
                 + random() * interval '10 minutes') at time zone v_tz) * 1000)::bigint;
      if v_day = 0 and v_ts > v_now then v_ts := v_now - (v_n - v_i) * 60000; end if;
      v_method := case when random() < 0.60 then 'cash' when random() < 0.82 then 'bank_transfer' else 'debt' end;
      v_cust := case when v_method = 'debt' then v_customers[1 + floor(random() * array_length(v_customers, 1))::int] end;
      v_status := case when random() < 0.025 then 'cancelled' else 'completed' end;

      insert into sale_orders (id, shop_id, order_no, timestamp, total_amount, payment_method,
                               last_updated, status, created_by, created_by_name, device_tag,
                               customer_id, payment_recon_status, payment_recon_at, payment_recon_by)
      values (v_order, v_shop, v_no, v_ts, 0, v_method, v_ts, v_status, v_owner,
              case when v_i % 3 = 0 then 'Chị Mai' else 'Lan (thu ngân)' end, 'quay-1', v_cust,
              case when v_method = 'bank_transfer' then 'confirmed' else '' end,
              case when v_method = 'bank_transfer' then v_ts else 0 end,
              case when v_method = 'bank_transfer' then v_owner end);

      v_total := 0;
      v_lines := 1 + floor(random() * random() * 5)::int;
      for v_l in 1..v_lines loop
        -- Cheap items sell more often: square the random index toward the low end.
        v_pick := 1 + floor(power(random(), 1.6) * array_length(v_variants, 1))::int;
        v_qty := case when v_prices[v_pick] < 15000 then 1 + floor(random() * 4)::int else 1 end;
        insert into sale_order_items (id, order_id, shop_id, variant_id, product_name, unit_price,
                                      quantity, line_no, unit_name)
        values (md5('i-' || v_no || '-' || v_l)::uuid, v_order, v_shop, v_variants[v_pick],
                v_names[v_pick], v_prices[v_pick], v_qty, v_l, v_units[v_pick]);
        v_total := v_total + v_prices[v_pick] * v_qty;
      end loop;
      update sale_orders set total_amount = v_total where id = v_order;
    end loop;
  end loop;
end
$seed$;
commit;

select count(*) as orders, sum(total_amount) filter (where status = 'completed') as revenue
  from public.sale_orders where shop_id = 'd0000000-0000-4000-8000-000000000002';
