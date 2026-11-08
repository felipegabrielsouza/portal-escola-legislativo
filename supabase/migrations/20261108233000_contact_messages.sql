create table if not exists public.contact_messages (
  id uuid primary key default gen_random_uuid(), name text not null, email text not null, subject text not null, message text not null,
  status text not null default 'received', created_at timestamptz not null default now()
);
alter table public.contact_messages enable row level security;
create policy "anyone can submit contact" on public.contact_messages for insert to anon, authenticated with check (char_length(name) between 2 and 120 and char_length(message) between 10 and 5000);
create policy "staff manage contact" on public.contact_messages for all to authenticated using (public.is_staff()) with check (public.is_staff());

