-- Operational state required by the activity, certificate and correction flows.
create table if not exists public.waitlist_promotions (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  previous_position integer not null,
  promoted_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.certificate_issuance_jobs (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  certificate_id uuid references public.certificates(id) on delete set null,
  template_version_id uuid references public.certificate_template_versions(id),
  status text not null default 'pending' check(status in ('pending','processing','completed','retryable','failed')),
  idempotency_key text not null unique,
  attempts integer not null default 0,
  error_message text,
  requested_by uuid references auth.users(id),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.institutional_calendars (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  version integer not null,
  timezone text not null default 'America/Sao_Paulo',
  counts_business_days boolean not null default false,
  active boolean not null default false,
  starts_on date,
  ends_on date,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique(name, version)
);
create table if not exists public.institutional_calendar_days (
  calendar_id uuid not null references public.institutional_calendars(id) on delete cascade,
  day date not null,
  kind text not null check(kind in ('holiday','working_day','suspension')),
  label text,
  primary key(calendar_id, day)
);

alter table public.certificate_correction_requests
  add column if not exists review_deadline_mode text not null default 'calendar_days' check(review_deadline_mode in ('calendar_days','business_days')),
  add column if not exists review_due_at timestamptz,
  add column if not exists calendar_version integer;
alter table public.certificate_complementations
  add column if not exists response_substantive_change boolean,
  add column if not exists reopened_at timestamptz,
  add column if not exists reopened_by uuid references auth.users(id);
alter table public.notifications
  add column if not exists channel text not null default 'in_app' check(channel in ('in_app','email')),
  add column if not exists delivery_status text not null default 'pending' check(delivery_status in ('pending','sent','retryable','failed')),
  add column if not exists attempts integer not null default 0,
  add column if not exists sent_at timestamptz,
  add column if not exists last_error text;

alter table public.waitlist_promotions enable row level security;
alter table public.certificate_issuance_jobs enable row level security;
alter table public.institutional_calendars enable row level security;
alter table public.institutional_calendar_days enable row level security;

create policy "staff manage waitlist promotions" on public.waitlist_promotions
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage issuance jobs" on public.certificate_issuance_jobs
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "participants read own issuance jobs" on public.certificate_issuance_jobs
for select to authenticated using (exists(select 1 from public.enrollments e where e.id=enrollment_id and e.participant_id=(select auth.uid())));
create policy "staff manage calendars" on public.institutional_calendars
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage calendar days" on public.institutional_calendar_days
for all to authenticated using (public.is_staff()) with check (public.is_staff());

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values
  ('portal-public','portal-public',true,10485760,array['image/jpeg','image/png','image/webp','video/mp4','application/pdf']),
  ('portal-private','portal-private',false,20971520,array['application/pdf','image/jpeg','image/png'])
on conflict (id) do update set file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

create policy "staff upload portal assets" on storage.objects
for insert to authenticated with check (bucket_id in ('portal-public','portal-private') and public.is_staff());
create policy "staff update portal assets" on storage.objects
for update to authenticated using (bucket_id in ('portal-public','portal-private') and public.is_staff()) with check (bucket_id in ('portal-public','portal-private') and public.is_staff());
create policy "staff delete portal assets" on storage.objects
for delete to authenticated using (bucket_id in ('portal-public','portal-private') and public.is_staff());
create policy "public assets are readable" on storage.objects
for select to anon, authenticated using (bucket_id='portal-public');
create policy "participants read own certificate assets" on storage.objects
for select to authenticated using (
  bucket_id='portal-private'
  and name ~ '^certificates/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\\.pdf$'
  and exists (
    select 1 from public.certificates c
    join public.enrollments e on e.id=c.enrollment_id
    where c.id=(split_part(name,'/',2)::text::uuid) and e.participant_id=(select auth.uid())
  )
);

create index if not exists waitlist_promotions_activity_idx on public.waitlist_promotions(activity_id, created_at desc);
create index if not exists issuance_jobs_status_idx on public.certificate_issuance_jobs(status, created_at);
create index if not exists notifications_delivery_idx on public.notifications(delivery_status, channel, created_at);

