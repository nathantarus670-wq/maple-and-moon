-- Run with: supabase test db
begin;
select plan(15);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'a@test.dev'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'b@test.dev');

insert into organizations (id, name, slug, country_code)
values ('cccccccc-0000-0000-0000-000000000001', 'Test Org', 'test-org', 'CA');

insert into events (id, organization_id, slug, title, starts_at, status)
values ('dddddddd-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001',
        'test-event', 'Test Event', now() + interval '30 days', 'published');

-- 3 tickets in total: small enough to test sell-out easily.
insert into ticket_types (id, event_id, name, price_minor, currency, quantity_total)
values ('eeeeeeee-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000001', 'GA', 4500, 'CAD', 3);

insert into fee_rules (currency, pct_bps, flat_per_ticket_minor) values ('CAD', 800, 150);

create temp table t (k text primary key, v uuid);

-- 1-2. Order is created; total is computed server-side: 9000 + (720 + 300) = 10020
select lives_ok(
  $$ insert into t select 'o1', (create_order('aaaaaaaa-0000-0000-0000-000000000001',
       '[{"ticket_type_id":"eeeeeeee-0000-0000-0000-000000000001","quantity":2}]'::jsonb, 'k1', 'h1') ->> 'order_id')::uuid $$,
  'order is created');
select is((select total_minor from orders where id = (select v from t where k = 'o1')), 10020::bigint,
  'total is computed from trusted rows');

-- 3. Replay with the same key and body does not create a second order
select lives_ok(
  $$ select create_order('aaaaaaaa-0000-0000-0000-000000000001',
       '[{"ticket_type_id":"eeeeeeee-0000-0000-0000-000000000001","quantity":2}]'::jsonb, 'k1', 'h1') $$,
  'replay returns the original result');
select is((select count(*)::int from orders where customer_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 1,
  'replay did not create a duplicate order');

-- 4. Same key, different body is rejected
select throws_ok(
  $$ select create_order('aaaaaaaa-0000-0000-0000-000000000001',
       '[{"ticket_type_id":"eeeeeeee-0000-0000-0000-000000000001","quantity":1}]'::jsonb, 'k1', 'DIFFERENT') $$,
  'P0001', 'IDEMPOTENCY_KEY_REUSED', 'key reuse with a different body is rejected');

-- 5-6. Buying more than remains is rejected and nothing extra is held
select throws_ok(
  $$ select create_order('bbbbbbbb-0000-0000-0000-000000000002',
       '[{"ticket_type_id":"eeeeeeee-0000-0000-0000-000000000001","quantity":2}]'::jsonb, 'k2', 'h2') $$,
  'P0001', 'SOLD_OUT', 'cannot oversell');
select is((select quantity_held from ticket_types where id = 'eeeeeeee-0000-0000-0000-000000000001'), 2,
  'only the valid hold is counted');

-- 7-9. Expiry releases inventory exactly once, even if run twice
update inventory_reservations set expires_at = now() - interval '1 minute';
update orders set reservation_expires_at = now() - interval '1 minute';
select expire_reservations();
select expire_reservations();
select is((select quantity_held from ticket_types where id = 'eeeeeeee-0000-0000-0000-000000000001'), 0,
  'inventory released exactly once');
select is((select status::text from orders where id = (select v from t where k = 'o1')), 'expired',
  'unpaid order is expired');

-- 10-12. Late payment while inventory is free: fulfilled, tickets issued once
select is((select fulfill_order((select v from t where k = 'o1')) ->> 'result'), 'fulfilled_late',
  'late payment with free inventory is fulfilled');
select is((select quantity_sold from ticket_types where id = 'eeeeeeee-0000-0000-0000-000000000001'), 2,
  'sold count updated');
select is((select fulfill_order((select v from t where k = 'o1')) ->> 'result'), 'already_fulfilled',
  'repeat fulfilment is a no-op');
select is((select count(*)::int from tickets), 2, 'tickets were issued exactly once');

-- 13-15. Late payment when the last ticket is gone: no tickets, flagged for review
insert into t select 'o2', (create_order('bbbbbbbb-0000-0000-0000-000000000002',
  '[{"ticket_type_id":"eeeeeeee-0000-0000-0000-000000000001","quantity":1}]'::jsonb, 'k3', 'h3') ->> 'order_id')::uuid;
update inventory_reservations set expires_at = now() - interval '1 minute' where order_id = (select v from t where k = 'o2');
update orders set reservation_expires_at = now() - interval '1 minute' where id = (select v from t where k = 'o2');
select expire_reservations();
select create_order('aaaaaaaa-0000-0000-0000-000000000001',
  '[{"ticket_type_id":"eeeeeeee-0000-0000-0000-000000000001","quantity":1}]'::jsonb, 'k4', 'h4');

select is((select fulfill_order((select v from t where k = 'o2')) ->> 'result'), 'needs_review',
  'late payment with no inventory goes to review');
select is((select status::text from orders where id = (select v from t where k = 'o2')), 'needs_review',
  'order is marked needs_review');
select is((select count(*)::int from tickets), 2, 'no tickets issued for the review case');

select * from finish();
rollback;
