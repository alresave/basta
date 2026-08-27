create extension if not exists pgcrypto;

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z2-9]{6}$'),
  host_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'lobby' check (status in ('lobby', 'playing', 'finished')),
  game_state jsonb not null default '{}'::jsonb,
  registry jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.room_players (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  nickname text not null default 'Jugador',
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (room_id, user_id)
);

create table if not exists public.room_events (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.rooms enable row level security;
alter table public.room_players enable row level security;
alter table public.room_events enable row level security;

create policy "members can read rooms" on public.rooms for select to authenticated
  using (exists (select 1 from public.room_players p where p.room_id = id and p.user_id = auth.uid()));
create policy "members can read players" on public.room_players for select to authenticated
  using (exists (select 1 from public.room_players self where self.room_id = room_id and self.user_id = auth.uid()));
create policy "members can read events" on public.room_events for select to authenticated
  using (exists (select 1 from public.room_players p where p.room_id = room_id and p.user_id = auth.uid()));

create or replace function public.create_basta_room(room_code text)
returns public.rooms language plpgsql security definer set search_path = public as $$
declare created_room public.rooms;
begin
  insert into public.rooms (code, host_id) values (room_code, auth.uid()) returning * into created_room;
  insert into public.room_players (room_id, user_id) values (created_room.id, auth.uid());
  return created_room;
end;
$$;

create or replace function public.join_basta_room(room_code text)
returns public.rooms language plpgsql security definer set search_path = public as $$
declare joined_room public.rooms;
begin
  select * into joined_room from public.rooms where code = room_code and status <> 'finished';
  if joined_room.id is null then raise exception 'Sala no encontrada o finalizada'; end if;
  insert into public.room_players (room_id, user_id) values (joined_room.id, auth.uid()) on conflict do nothing;
  return joined_room;
end;
$$;

revoke all on function public.create_basta_room(text) from public;
revoke all on function public.join_basta_room(text) from public;
grant execute on function public.create_basta_room(text), public.join_basta_room(text) to authenticated;

alter publication supabase_realtime add table public.rooms, public.room_players, public.room_events;
