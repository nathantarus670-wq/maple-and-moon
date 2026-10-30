-- Ticketing core (Phase 1, first vertical slice)
-- Covers: events, ticket types, atomic inventory holds, orders, idempotency,
-- reservation expiry, payment fulfilment (incl. late payments), ticket issuance, RLS.
-- All writes go through the SECURITY DEFINER functions below, called with the
-- service role from server code only. Clients get read-only access via RLS.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- enums
create type event_status       as enum ('draft', 'published', 'cancelled', 'completed');
create type order_status       as enum ('pending_payment', 'paid', 'fulfilled', 'cancelled', 'expired', 'needs_review');
create type reservation_status as enum ('active', 'consumed', 'expired');
create type ticket_status      as enum ('valid', 'checked_in', 'void');

-- ---------------------------------------------------------------- identity
create table organizations (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  slug         text not null unique,
  country_code char(2) not null,
  created_at   timestamptz not null default now()
);

create table organization_members (
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  role            text not null check (role in ('owner', 'manager', 'staff')),
  primary key (organization_id, user_id)
);

-- ---------------------------------------------------------------- events
create table venues (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  address      text,
  country_code char(2) not null,
  timezone     text not null,
  latitude     numeric(9, 6),
  longitude    numeric(9, 6)
);

create table events (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id),
  venue_id        uuid references venues(id),
  slug            text not null unique,
  title           text not null,
  description     text,
  starts_at       timestamptz not null,
  ends_at         timestamptz,
  status          event_status not null default 'draft',
  created_at      timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);
create index events_status_starts_idx on events (status, starts_at);
create index events_org_idx on events (organization_id);

create table ticket_types (
  id                 uuid primary key default gen_random_uuid(),
  event_id           uuid not null references events(id) on delete cascade,
  name               text not null,
  price_minor        bigint not null check (price_minor >= 0),
  currency           char(3) not null,
  quantity_total     int not null check (quantity_total >= 0),
  quantity_held      int not null default 0,   -- active, unexpired reservations
  quantity_sold      int not null default 0,   -- paid and fulfilled
  quantity_available int generated always as (quantity_total - quantity_held - quantity_sold) stored,
  max_per_order      int not null default 8 check (max_per_order between 1 and 20),
  sales_start_at     timestamptz,
  sales_end_at       timestamptz,
  active             boolean not null default true,
  -- The last line of defence against overselling, whatever the application does.
  constraint inventory_not_oversold check (
    quantity_held >= 0 and quantity_sold >= 0 and quantity_held + quantity_sold <= quantity_total
  )
);
create index ticket_types_event_idx on ticket_types (event_id);

-- Platform fee, resolved server-side. Latest rule per currency wins.
create table fee_rules (
  id                   uuid primary key default gen_random_uuid(),
  currency             char(3) not null,
  pct_bps              int not null default 0 check (pct_bps >= 0),            -- 800 = 8.00%
  flat_per_ticket_minor int not null default 0 check (flat_per_ticket_minor >= 0),
  effective_from       timestamptz not null default now()
);
create index fee_rules_lookup_idx on fee_rules (currency, effective_from desc);

-- ---------------------------------------------------------------- orders
create function gen_order_number() returns text
language sql volatile as $$ select 'ORD-' || upper(encode(gen_random_bytes(5), 'hex')) $$;

create table orders (
  id                     uuid primary key default gen_random_uuid(),
  order_number           text not null unique default gen_order_number(),
  customer_id            uuid not null references auth.users(id),
  currency               char(3) not null,
  subtotal_minor         bigint not null default 0 check (subtotal_minor >= 0),
  fee_minor              bigint not null default 0 check (fee_minor >= 0),
  tax_minor              bigint not null default 0 check (tax_minor >= 0),
  total_minor            bigint not null default 0 check (total_minor >= 0),
  status                 order_status not null default 'pending_payment',
  reservation_expires_at timestamptz not null,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index orders_customer_idx on orders (customer_id, created_at desc);
create index orders_pending_expiry_idx on orders (reservation_expires_at) where status = 'pending_payment';

create table order_items (
  id                   uuid primary key default gen_random_uuid(),
  order_id             uuid not null references orders(id) on delete cascade,
  ticket_type_id       uuid not null references ticket_types(id),
  description_snapshot text not null,
  quantity             int not null check (quantity > 0),
  unit_price_minor     bigint not null check (unit_price_minor >= 0),
  total_minor          bigint not null check (total_minor >= 0)
);
create index order_items_order_idx on order_items (order_id);

create table inventory_reservations (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references orders(id) on delete cascade,
  ticket_type_id uuid not null references ticket_types(id),
  quantity       int not null check (quantity > 0),
  expires_at     timestamptz not null,
  status         reservation_status not null default 'active'
);
create index reservations_active_expiry_idx on inventory_reservations (expires_at) where status = 'active';
create index reservations_order_idx on inventory_reservations (order_id);

-- Tickets. QR payload = ticket_code + HMAC signature computed in app code with a
-- server secret (nothing sensitive is stored in the QR, and no raw token is stored here).
create table tickets (
  id            uuid primary key default gen_random_uuid(),
  order_item_id uuid not null references order_items(id) on delete cascade,
  seq           int not null,
  ticket_code   text not null unique default ('NN-' || upper(encode(gen_random_bytes(6), 'hex'))),
  status        ticket_status not null default 'valid',
  issued_at     timestamptz not null default now(),
  unique (order_item_id, seq)           -- makes issuance idempotent
);

create table idempotency_keys (
  user_id      uuid not null references auth.users(id) on delete cascade,
  operation    text not null,
  key          text not null,
  request_hash text not null,
  response     jsonb,
  created_at   timestamptz not null default now(),
  primary key (user_id, operation, key)
);

-- Used by the payment webhook handler to deduplicate provider callbacks.
create table webhook_events (
  id                uuid primary key default gen_random_uuid(),
  provider          text not null,
  external_event_id text not null,
  payload_hash      text not null,
  received_at       timestamptz not null default now(),
  processed_at      timestamptz,
  processing_status text not null default 'received',
  unique (provider, external_event_id)
);

-- ---------------------------------------------------------------- create_order
-- Validates, holds inventory atomically, prices from trusted rows, and is idempotent.
-- Errors are raised as stable message codes the API layer maps to HTTP statuses.
create function create_order(
  p_customer_id     uuid,
  p_items           jsonb,           -- [{"ticket_type_id": "...", "quantity": 2}]
  p_idempotency_key text,
  p_request_hash    text,
  p_hold_minutes    int default 10
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_idem     idempotency_keys%rowtype;
  v_item     record;
  v_tt       ticket_types%rowtype;
  v_event    events%rowtype;
  v_rule     fee_rules%rowtype;
  v_order    orders%rowtype;
  v_currency char(3);
  v_subtotal bigint := 0;
  v_count    int := 0;
  v_fee      bigint := 0;
  v_expires  timestamptz;
  v_result   jsonb;
begin
  -- 1. Idempotency. Concurrent requests with the same key serialise on this row.
  insert into idempotency_keys (user_id, operation, key, request_hash)
  values (p_customer_id, 'create_order', p_idempotency_key, p_request_hash)
  on conflict do nothing;

  select * into v_idem from idempotency_keys
   where user_id = p_customer_id and operation = 'create_order' and key = p_idempotency_key
   for update;

  if v_idem.request_hash <> p_request_hash then raise exception 'IDEMPOTENCY_KEY_REUSED'; end if;
  if v_idem.response is not null then return v_idem.response; end if;

  -- 2. Basic shape checks.
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 10 then
    raise exception 'INVALID_ITEMS';
  end if;

  select currency into v_currency from ticket_types
   where id = (p_items -> 0 ->> 'ticket_type_id')::uuid;
  if v_currency is null then raise exception 'TICKET_NOT_AVAILABLE'; end if;

  v_expires := clock_timestamp() + make_interval(mins => p_hold_minutes);

  insert into orders (customer_id, currency, reservation_expires_at)
  values (p_customer_id, v_currency, v_expires)
  returning * into v_order;

  -- 3. Lock and hold each ticket type. Sorted by id so concurrent orders
  --    always lock in the same order (no deadlocks).
  for v_item in
    select (e ->> 'ticket_type_id')::uuid as id, sum((e ->> 'quantity')::int)::int as qty
      from jsonb_array_elements(p_items) e
     group by 1 order by 1
  loop
    select * into v_tt from ticket_types where id = v_item.id for update;
    if not found then raise exception 'TICKET_NOT_AVAILABLE'; end if;

    select * into v_event from events where id = v_tt.event_id;

    if not v_tt.active
       or v_event.status <> 'published'
       or coalesce(v_event.ends_at, v_event.starts_at + interval '1 day') < now()
       or (v_tt.sales_start_at is not null and v_tt.sales_start_at > now())
       or (v_tt.sales_end_at   is not null and v_tt.sales_end_at  <= now())
    then raise exception 'TICKET_NOT_AVAILABLE'; end if;

    if v_tt.currency <> v_currency then raise exception 'MIXED_CURRENCY'; end if;
    if v_item.qty < 1 or v_item.qty > v_tt.max_per_order then raise exception 'QUANTITY_LIMIT'; end if;
    if v_tt.quantity_total - v_tt.quantity_held - v_tt.quantity_sold < v_item.qty then
      raise exception 'SOLD_OUT';
    end if;

    update ticket_types set quantity_held = quantity_held + v_item.qty where id = v_tt.id;

    insert into order_items (order_id, ticket_type_id, description_snapshot, quantity, unit_price_minor, total_minor)
    values (v_order.id, v_tt.id, v_event.title || ' – ' || v_tt.name, v_item.qty,
            v_tt.price_minor, v_tt.price_minor * v_item.qty);

    insert into inventory_reservations (order_id, ticket_type_id, quantity, expires_at)
    values (v_order.id, v_tt.id, v_item.qty, v_expires);

    v_subtotal := v_subtotal + v_tt.price_minor * v_item.qty;
    v_count    := v_count + v_item.qty;
  end loop;

  -- 4. Fee from the latest rule. Tax is a placeholder (0): compute it in the app
  --    (e.g. Stripe Tax) and extend this function before taking real payments.
  select * into v_rule from fee_rules
   where currency = v_currency and effective_from <= now()
   order by effective_from desc limit 1;
  if found then
    v_fee := round(v_subtotal * v_rule.pct_bps / 10000.0)::bigint
           + v_rule.flat_per_ticket_minor::bigint * v_count;
  end if;

  update orders
     set subtotal_minor = v_subtotal, fee_minor = v_fee, total_minor = v_subtotal + v_fee
   where id = v_order.id
   returning * into v_order;

  v_result := jsonb_build_object(
    'order_id', v_order.id, 'order_number', v_order.order_number,
    'status', v_order.status, 'currency', v_order.currency,
    'subtotal_minor', v_order.subtotal_minor, 'fee_minor', v_order.fee_minor,
    'tax_minor', v_order.tax_minor, 'total_minor', v_order.total_minor,
    'reservation_expires_at', v_order.reservation_expires_at
  );

  update idempotency_keys set response = v_result
   where user_id = p_customer_id and operation = 'create_order' and key = p_idempotency_key;

  return v_result;
end $$;

-- ---------------------------------------------------------------- expire_reservations
-- Run every minute (pg_cron or a scheduled job). Each reservation flips from
-- 'active' to 'expired' exactly once, so inventory is released exactly once.
create function expire_reservations() returns void
language plpgsql security definer set search_path = public as $$
begin
  with expired as (
    update inventory_reservations
       set status = 'expired'
     where status = 'active' and expires_at <= now()
    returning ticket_type_id, quantity
  ), agg as (
    select ticket_type_id, sum(quantity)::int as q from expired group by 1
  )
  update ticket_types t
     set quantity_held = t.quantity_held - agg.q
    from agg
   where t.id = agg.ticket_type_id;

  update orders
     set status = 'expired', updated_at = now()
   where status = 'pending_payment' and reservation_expires_at <= now();
end $$;

-- select cron.schedule('expire-reservations', '* * * * *', 'select expire_reservations()');

-- ---------------------------------------------------------------- fulfill_order
-- Call ONLY after the webhook handler has authenticated the callback, deduplicated
-- it, and verified amount, currency and provider reference against the order.
-- Safe to call repeatedly. Handles the late-payment case explicitly:
--   * hold still active   -> consume it and issue tickets
--   * hold already gone   -> re-acquire inventory if any remains, else 'needs_review'
--                            (do NOT issue tickets; finance reviews or refunds)
create function fulfill_order(p_order_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_order orders%rowtype;
  v_r     record;
  v_tt    ticket_types%rowtype;
  v_late  boolean;
  v_short boolean := false;
begin
  select * into v_order from orders where id = p_order_id for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;

  if v_order.status in ('paid', 'fulfilled') then
    return jsonb_build_object('result', 'already_fulfilled');
  end if;
  if v_order.status = 'needs_review' then
    return jsonb_build_object('result', 'needs_review');
  end if;

  v_late := v_order.status <> 'pending_payment'
         or not exists (select 1 from inventory_reservations
                         where order_id = p_order_id and status = 'active');

  if not v_late then
    for v_r in
      select ticket_type_id, quantity from inventory_reservations
       where order_id = p_order_id and status = 'active'
       order by ticket_type_id for update
    loop
      update ticket_types
         set quantity_held = quantity_held - v_r.quantity,
             quantity_sold = quantity_sold + v_r.quantity
       where id = v_r.ticket_type_id;
    end loop;
    update inventory_reservations set status = 'consumed'
     where order_id = p_order_id and status = 'active';
  else
    -- Check first (locking rows in a fixed order), apply only if everything fits.
    for v_r in
      select ticket_type_id, sum(quantity)::int as q from order_items
       where order_id = p_order_id group by 1 order by 1
    loop
      select * into v_tt from ticket_types where id = v_r.ticket_type_id for update;
      if v_tt.quantity_total - v_tt.quantity_held - v_tt.quantity_sold < v_r.q then
        v_short := true;
      end if;
    end loop;

    if v_short then
      update orders set status = 'needs_review', updated_at = now() where id = p_order_id;
      return jsonb_build_object('result', 'needs_review');
    end if;

    update ticket_types t
       set quantity_sold = t.quantity_sold + x.q
      from (select ticket_type_id, sum(quantity)::int as q
              from order_items where order_id = p_order_id group by 1) x
     where t.id = x.ticket_type_id;
  end if;

  insert into tickets (order_item_id, seq)
  select oi.id, g
    from order_items oi
   cross join lateral generate_series(1, oi.quantity) g
   where oi.order_id = p_order_id
  on conflict (order_item_id, seq) do nothing;

  update orders set status = 'fulfilled', updated_at = now() where id = p_order_id;

  return jsonb_build_object('result', case when v_late then 'fulfilled_late' else 'fulfilled' end);
end $$;

-- ---------------------------------------------------------------- privileges
revoke execute on function create_order(uuid, jsonb, text, text, int), expire_reservations(), fulfill_order(uuid)
  from public, anon, authenticated;
grant  execute on function create_order(uuid, jsonb, text, text, int), expire_reservations(), fulfill_order(uuid)
  to service_role;

-- ---------------------------------------------------------------- RLS
alter table organizations          enable row level security;
alter table organization_members   enable row level security;
alter table venues                 enable row level security;
alter table events                 enable row level security;
alter table ticket_types           enable row level security;
alter table fee_rules              enable row level security;
alter table orders                 enable row level security;
alter table order_items            enable row level security;
alter table inventory_reservations enable row level security;
alter table tickets                enable row level security;
alter table idempotency_keys       enable row level security;
alter table webhook_events         enable row level security;

-- Grants are explicit: RLS does not replace them.
revoke all on all tables in schema public from anon, authenticated;

grant select on venues, events to anon, authenticated;
-- Public sees availability but not the internal held/sold counters.
grant select (id, event_id, name, price_minor, currency, quantity_available,
              max_per_order, sales_start_at, sales_end_at, active)
  on ticket_types to anon, authenticated;
grant select on organizations, organization_members, orders, order_items, tickets to authenticated;

create policy venues_public_read on venues for select to anon, authenticated using (true);

create policy events_public_read on events for select to anon, authenticated
  using (status = 'published');
create policy events_org_read on events for select to authenticated
  using (exists (select 1 from organization_members m
                  where m.organization_id = events.organization_id and m.user_id = (select auth.uid())));

create policy ticket_types_public_read on ticket_types for select to anon, authenticated
  using (active and exists (select 1 from events e where e.id = ticket_types.event_id and e.status = 'published'));

create policy org_members_read_own on organization_members for select to authenticated
  using (user_id = (select auth.uid()));
create policy organizations_member_read on organizations for select to authenticated
  using (exists (select 1 from organization_members m
                  where m.organization_id = organizations.id and m.user_id = (select auth.uid())));

create policy orders_own_read on orders for select to authenticated
  using (customer_id = (select auth.uid()));
create policy order_items_own_read on order_items for select to authenticated
  using (exists (select 1 from orders o where o.id = order_items.order_id and o.customer_id = (select auth.uid())));
create policy tickets_own_read on tickets for select to authenticated
  using (exists (select 1 from order_items oi join orders o on o.id = oi.order_id
                  where oi.id = tickets.order_item_id and o.customer_id = (select auth.uid())));

-- No insert/update/delete policies on purpose: all writes go through the service role.
