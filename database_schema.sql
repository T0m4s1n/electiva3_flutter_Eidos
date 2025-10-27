-- Extensiones útiles (opcional)
create extension if not exists "uuid-ossp";

-- ============ TABLAS ============

create table public.conversations (
  id uuid primary key,
  user_id uuid references auth.users(id) on delete cascade,
  title text,
  model text,
  summary text,
  is_archived boolean default false,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.messages (
  id uuid primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  role text not null check (role in ('user','assistant','system','tool')),
  content jsonb not null,                      -- JSON estructurado
  created_at timestamptz not null,             -- tiempo cliente
  seq int not null,                            -- ordinal local para ordenar
  parent_id uuid null,                         -- para hilos/ediciones
  status text not null default 'ok' check (status in ('ok','pending','error')),
  is_deleted boolean not null default false
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============ ÍNDICES ============
create index if not exists idx_conversations_user_updated
  on public.conversations(user_id, updated_at desc);

create index if not exists idx_messages_conv_created
  on public.messages(conversation_id, created_at, seq);

create index if not exists idx_profiles_email
  on public.profiles(email);

-- ============ TRIGGERS ============
create or replace function public.tg_touch_conversation()
returns trigger language plpgsql as $$
begin
  update public.conversations
    set updated_at = now(),
        last_message_at = greatest(coalesce(new.created_at, now()), coalesce(last_message_at, '-infinity'))
  where id = new.conversation_id;
  return new;
end $$;

drop trigger if exists tg_touch_conversation on public.messages;
create trigger tg_touch_conversation
after insert on public.messages
for each row execute function public.tg_touch_conversation();

-- ============ RLS ============
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.profiles enable row level security;

-- Conversations: solo dueño
drop policy if exists "convs_select_own" on public.conversations;
create policy "convs_select_own"
on public.conversations for select
using (auth.uid() = user_id);

drop policy if exists "convs_insert_own" on public.conversations;
create policy "convs_insert_own"
on public.conversations for insert
with check (auth.uid() = user_id);

drop policy if exists "convs_update_own" on public.conversations;
create policy "convs_update_own"
on public.conversations for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "convs_delete_own" on public.conversations;
create policy "convs_delete_own"
on public.conversations for delete
using (auth.uid() = user_id);

-- Messages: solo de conversaciones del dueño
drop policy if exists "msgs_select_own_convs" on public.messages;
create policy "msgs_select_own_convs"
on public.messages for select
using (exists (
  select 1 from public.conversations c
  where c.id = messages.conversation_id and c.user_id = auth.uid()
));

drop policy if exists "msgs_insert_own_convs" on public.messages;
create policy "msgs_insert_own_convs"
on public.messages for insert
with check (exists (
  select 1 from public.conversations c
  where c.id = messages.conversation_id and c.user_id = auth.uid()
));

drop policy if exists "msgs_update_own_convs" on public.messages;
create policy "msgs_update_own_convs"
on public.messages for update
using (exists (
  select 1 from public.conversations c
  where c.id = messages.conversation_id and c.user_id = auth.uid()
))
with check (exists (
  select 1 from public.conversations c
  where c.id = messages.conversation_id and c.user_id = auth.uid()
));

drop policy if exists "msgs_delete_own_convs" on public.messages;
create policy "msgs_delete_own_convs"
on public.messages for delete
using (exists (
  select 1 from public.conversations c
  where c.id = messages.conversation_id and c.user_id = auth.uid()
));

-- Profiles: solo propio perfil
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles for select
using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles for insert
with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
on public.profiles for delete
using (auth.uid() = id);