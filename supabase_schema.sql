-- ============================================================
-- MenuScuola — Schema Supabase completo
-- Esegui questo nell'editor SQL del tuo progetto Supabase
-- ============================================================

-- ─── EXTENSIONS ──────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ─── LOOKUP TABLES ───────────────────────────────────────────────────────────

create table regions (
  id   uuid primary key default gen_random_uuid(),
  name text not null unique
);

create table provinces (
  id        uuid primary key default gen_random_uuid(),
  name      text not null,
  region_id uuid not null references regions(id) on delete cascade,
  unique(name, region_id)
);

create table municipalities (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  province_id uuid not null references provinces(id) on delete cascade,
  unique(name, province_id)
);

-- Indici per velocizzare le ricerche geografiche
create index on provinces(region_id);
create index on municipalities(province_id);

-- ─── USER PROFILES ────────────────────────────────────────────────────────────

create table user_profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  full_name  text,
  avatar_url text,
  role       text not null default 'user' check (role in ('user', 'school', 'admin')),
  created_at timestamptz not null default now()
);

-- RLS
alter table user_profiles enable row level security;

create policy "Utenti vedono il proprio profilo"
  on user_profiles for select
  using (auth.uid() = id);

create policy "Utenti modificano il proprio profilo"
  on user_profiles for update
  using (auth.uid() = id);

create policy "Inserimento profilo alla registrazione"
  on user_profiles for insert
  with check (auth.uid() = id);

-- ─── SCHOOLS ─────────────────────────────────────────────────────────────────

create table schools (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  name            text not null,
  school_type     text not null default 'primaria'
                  check (school_type in ('nido', 'materna', 'primaria', 'media')),
  municipality_id uuid not null references municipalities(id),
  address         text,
  phone           text,
  logo_url        text,
  is_approved     boolean not null default false,
  created_at      timestamptz not null default now()
);

create index on schools(municipality_id);
create index on schools(user_id);
create index on schools(is_approved);

-- Indice full-text per ricerca per nome
create index on schools using gin(to_tsvector('italian', name));

-- RLS
alter table schools enable row level security;

-- Tutti gli utenti autenticati vedono le scuole approvate
create policy "Scuole approvate visibili a tutti"
  on schools for select
  using (is_approved = true or auth.uid() = user_id);

-- Solo la scuola stessa può modificarsi
create policy "Scuola modifica se stessa"
  on schools for update
  using (auth.uid() = user_id);

-- Inserimento solo da utenti autenticati
create policy "Scuola si registra"
  on schools for insert
  with check (auth.uid() = user_id);

-- ─── MENUS ───────────────────────────────────────────────────────────────────

create table menus (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references schools(id) on delete cascade,
  title      text not null default 'Menu',
  start_date date not null,
  end_date   date not null,
  pdf_url    text,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);

create index on menus(school_id);
create index on menus(is_active);
create index on menus(start_date, end_date);

-- RLS
alter table menus enable row level security;

-- Tutti vedono i menu delle scuole approvate
create policy "Menu visibili se scuola approvata"
  on menus for select
  using (
    exists (
      select 1 from schools
      where schools.id = menus.school_id
      and (schools.is_approved = true or schools.user_id = auth.uid())
    )
  );

-- Solo la scuola proprietaria modifica i propri menu
create policy "Scuola gestisce i propri menu"
  on menus for all
  using (
    exists (
      select 1 from schools
      where schools.id = menus.school_id
      and schools.user_id = auth.uid()
    )
  );

-- ─── MENU DAYS ───────────────────────────────────────────────────────────────

create table menu_days (
  id       uuid primary key default gen_random_uuid(),
  menu_id  uuid not null references menus(id) on delete cascade,
  day_date date not null,
  unique(menu_id, day_date)
);

create index on menu_days(menu_id);
create index on menu_days(day_date);

-- RLS (eredita le policy dai menu tramite join)
alter table menu_days enable row level security;

create policy "Giorni visibili se menu visibile"
  on menu_days for select
  using (
    exists (
      select 1 from menus
      join schools on schools.id = menus.school_id
      where menus.id = menu_days.menu_id
      and (schools.is_approved = true or schools.user_id = auth.uid())
    )
  );

create policy "Scuola gestisce i propri giorni"
  on menu_days for all
  using (
    exists (
      select 1 from menus
      join schools on schools.id = menus.school_id
      where menus.id = menu_days.menu_id
      and schools.user_id = auth.uid()
    )
  );

-- ─── MENU COURSES ────────────────────────────────────────────────────────────

create table menu_courses (
  id           uuid primary key default gen_random_uuid(),
  menu_day_id  uuid not null references menu_days(id) on delete cascade,
  course_type  text not null default 'custom'
               check (course_type in ('primo', 'secondo', 'contorno', 'frutta', 'dessert', 'custom')),
  custom_label text,
  description  text not null,
  allergens    text[] not null default '{}',
  sort_order   integer not null default 0
);

create index on menu_courses(menu_day_id);

-- RLS
alter table menu_courses enable row level security;

create policy "Portate visibili se giorno visibile"
  on menu_courses for select
  using (
    exists (
      select 1 from menu_days
      join menus on menus.id = menu_days.menu_id
      join schools on schools.id = menus.school_id
      where menu_days.id = menu_courses.menu_day_id
      and (schools.is_approved = true or schools.user_id = auth.uid())
    )
  );

create policy "Scuola gestisce le proprie portate"
  on menu_courses for all
  using (
    exists (
      select 1 from menu_days
      join menus on menus.id = menu_days.menu_id
      join schools on schools.id = menus.school_id
      where menu_days.id = menu_courses.menu_day_id
      and schools.user_id = auth.uid()
    )
  );

-- ─── USER FAVORITES ───────────────────────────────────────────────────────────

create table user_favorites (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  school_id  uuid not null references schools(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(user_id, school_id)
);

create index on user_favorites(user_id);

-- RLS
alter table user_favorites enable row level security;

create policy "Utente vede i propri preferiti"
  on user_favorites for select
  using (auth.uid() = user_id);

create policy "Utente gestisce i propri preferiti"
  on user_favorites for all
  using (auth.uid() = user_id);

-- ─── STORAGE BUCKET ──────────────────────────────────────────────────────────
-- Crea il bucket 'school-logos' in Supabase Storage con accesso pubblico
-- e il bucket 'menu-pdfs' per i PDF dei menu.

-- Eseguire dalla dashboard Supabase > Storage > New Bucket:
-- 1. Nome: school-logos | Public: ON
-- 2. Nome: menu-pdfs    | Public: ON

-- ─── SEED DATA — Alcune regioni italiane di esempio ──────────────────────────

insert into regions (name) values
  ('Lombardia'),
  ('Piemonte'),
  ('Veneto'),
  ('Emilia-Romagna'),
  ('Toscana'),
  ('Lazio'),
  ('Campania'),
  ('Sicilia');

-- Esempio province Lombardia
with lombardia as (select id from regions where name = 'Lombardia')
insert into provinces (name, region_id) values
  ('Milano',   (select id from lombardia)),
  ('Bergamo',  (select id from lombardia)),
  ('Brescia',  (select id from lombardia)),
  ('Como',     (select id from lombardia)),
  ('Monza e Brianza', (select id from lombardia));

-- Esempio comuni Milano
with mi as (select id from provinces where name = 'Milano')
insert into municipalities (name, province_id) values
  ('Milano',           (select id from mi)),
  ('Sesto San Giovanni',(select id from mi)),
  ('Cinisello Balsamo',(select id from mi)),
  ('Monza',            (select id from mi)),
  ('Rho',              (select id from mi)),
  ('Cologno Monzese',  (select id from mi));

-- ─── FUNZIONE: auto-crea profilo utente dopo signup ──────────────────────────

create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into user_profiles (id, full_name, role, created_at)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    coalesce(new.raw_user_meta_data->>'role', 'user'),
    now()
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Trigger sul signup
create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();
