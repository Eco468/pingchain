-- Trailhead MVP schema
-- Run this in Supabase SQL Editor (Project → SQL Editor → New query → paste → Run)

create extension if not exists "pgcrypto";

-- A user account. telegram_chat_id is null until the user links Telegram.
create table if not exists public.users (
  id                   uuid primary key default gen_random_uuid(),
  telegram_chat_id     bigint unique,
  telegram_username    text,
  created_at           timestamptz not null default now()
);

-- Wallets a user wants to monitor. address is checksum-lowered.
create table if not exists public.wallets (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users(id) on delete cascade,
  address     text not null check (address = lower(address)),
  created_at  timestamptz not null default now(),
  unique (user_id, address)
);

create index if not exists wallets_address_idx on public.wallets (address);

-- One row per alert the user has enabled on a wallet.
-- rule_type: 'incoming_usdc' | 'new_approval' | 'outgoing_above'
-- threshold_usdc: only meaningful for 'outgoing_above' (USDC units, e.g. 100.5)
create table if not exists public.alert_rules (
  id              uuid primary key default gen_random_uuid(),
  wallet_id       uuid not null references public.wallets(id) on delete cascade,
  rule_type       text not null check (rule_type in ('incoming_usdc','new_approval','outgoing_above')),
  threshold_usdc  numeric(20, 6),
  enabled         boolean not null default true,
  created_at      timestamptz not null default now(),
  unique (wallet_id, rule_type)
);

create index if not exists alert_rules_enabled_idx on public.alert_rules (enabled) where enabled;

-- One-time codes for linking Telegram. Issued by the app, redeemed by /start <code> in the bot.
create table if not exists public.telegram_link_codes (
  code        text primary key,
  user_id     uuid not null references public.users(id) on delete cascade,
  expires_at  timestamptz not null,
  used_at     timestamptz
);

create index if not exists telegram_link_codes_user_idx on public.telegram_link_codes (user_id);

-- Indexer cursor: last block scanned, one row per stream (native_transfers, erc20_approvals).
create table if not exists public.indexer_state (
  stream      text primary key,
  last_block  bigint not null,
  updated_at  timestamptz not null default now()
);

-- Idempotency for fired alerts. (tx_hash, log_index, rule_type) is the natural key.
-- log_index is -1 for native USDC transfers (no log), positive for ERC-20 events.
create table if not exists public.processed_events (
  tx_hash     text not null,
  log_index   integer not null,
  rule_type   text not null,
  wallet_id   uuid not null references public.wallets(id) on delete cascade,
  fired_at    timestamptz not null default now(),
  primary key (tx_hash, log_index, rule_type, wallet_id)
);

-- Row-level security: deny anon access by default. Server uses service_role (bypasses RLS).
alter table public.users               enable row level security;
alter table public.wallets             enable row level security;
alter table public.alert_rules         enable row level security;
alter table public.telegram_link_codes enable row level security;
alter table public.indexer_state       enable row level security;
alter table public.processed_events    enable row level security;
