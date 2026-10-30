-- Seed data for local development / staging
insert into organizations (id, name, slug, country_code)
values ('11111111-1111-1111-1111-111111111111', 'Acme Concerts', 'acme-concerts', 'US');

insert into venues (id, organization_id, name, city, country_code)
values ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'The Grand Arena', 'Austin', 'US');

insert into events (id, organization_id, venue_id, slug, title, starts_at, status)
values (
  '33333333-3333-3333-3333-333333333333',
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  'summer-music-fest-2026',
  'Summer Music Fest 2026',
  now() + interval '45 days',
  'published'
);

insert into ticket_types (id, event_id, name, price_minor, currency, quantity_total)
values 
  ('44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', 'General Admission', 5000, 'USD', 100),
  ('55555555-5555-5555-5555-555555555555', '33333333-3333-3333-3333-333333333333', 'VIP Backstage', 15000, 'USD', 20);

insert into fee_rules (currency, pct_bps, flat_per_ticket_minor)
values ('USD', 500, 100);
