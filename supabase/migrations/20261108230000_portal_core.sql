create extension if not exists pgcrypto;

do $$ begin create type public.user_role as enum ('admin_general','school_team','participant','visitor'); exception when duplicate_object then null; end $$;
do $$ begin create type public.activity_status as enum ('draft','published','archived'); exception when duplicate_object then null; end $$;
do $$ begin create type public.enrollment_status as enum ('confirmed','waitlist','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.certificate_status as enum ('valid','void','replaced'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '', email text, cpf text, phone text, city text, state text,
  institution text, job_title text, role public.user_role not null default 'participant',
  is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(), slug text not null unique, title text not null, description text not null,
  category text not null, image_path text, starts_at timestamptz not null, ends_at timestamptz not null,
  location text not null, modality text not null, duration_hours numeric(8,2) not null check (duration_hours > 0),
  speakers jsonb not null default '[]'::jsonb, content text, audience text, capacity integer not null check (capacity > 0),
  registration_opens_at timestamptz, registration_closes_at timestamptz, prerequisites text, materials jsonb not null default '[]'::jsonb,
  status public.activity_status not null default 'draft', cancellation_deadline_hours integer not null default 24,
  minimum_attendance_pct numeric(5,2) not null default 75 check (minimum_attendance_pct between 0 and 100),
  created_by uuid references auth.users(id), published_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (ends_at > starts_at), check (registration_closes_at is null or registration_opens_at is null or registration_closes_at >= registration_opens_at)
);
create table if not exists public.activity_sessions (
  id uuid primary key default gen_random_uuid(), activity_id uuid not null references public.activities(id) on delete cascade,
  starts_at timestamptz not null, ends_at timestamptz not null, hours numeric(8,2) not null check (hours > 0), content text,
  created_at timestamptz not null default now(), check (ends_at > starts_at)
);
create table if not exists public.enrollments (
  id uuid primary key default gen_random_uuid(), activity_id uuid not null references public.activities(id) on delete cascade,
  participant_id uuid references auth.users(id), guest_name text not null, guest_email text not null, guest_cpf text not null,
  guest_phone text not null, city text not null, state text not null, institution text, job_title text,
  status public.enrollment_status not null default 'confirmed', waitlist_position integer, created_at timestamptz not null default now(),
  cancelled_at timestamptz, cancellation_reason text
);
create unique index if not exists enrollments_activity_cpf_uq on public.enrollments(activity_id, guest_cpf) where status <> 'cancelled';
create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(), enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  session_id uuid not null references public.activity_sessions(id) on delete cascade, hours_present numeric(8,2) not null check (hours_present >= 0),
  source text not null check (source in ('manual','qr')), checked_in_at timestamptz not null default now(), created_by uuid references auth.users(id),
  unique(enrollment_id, session_id)
);
create table if not exists public.qr_checkins (
  id uuid primary key default gen_random_uuid(), session_id uuid not null references public.activity_sessions(id) on delete cascade,
  token_hash text not null unique, expires_at timestamptz not null, max_attempts integer not null default 5, attempts integer not null default 0,
  created_by uuid references auth.users(id), created_at timestamptz not null default now()
);

create table if not exists public.certificate_templates (
  id uuid primary key default gen_random_uuid(), name text not null, description text, active boolean not null default true,
  created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.certificate_template_versions (
  id uuid primary key default gen_random_uuid(), template_id uuid not null references public.certificate_templates(id) on delete cascade,
  version integer not null, canvas jsonb not null default '{}'::jsonb, asset_path text, created_by uuid references auth.users(id),
  created_at timestamptz not null default now(), unique(template_id, version)
);
create table if not exists public.certificates (
  id uuid primary key default gen_random_uuid(), enrollment_id uuid not null references public.enrollments(id),
  certificate_code text not null unique, verification_name text not null, activity_name text not null, workload_hours numeric(8,2) not null,
  period_start timestamptz, period_end timestamptz, issuer text not null, signatures jsonb not null default '[]'::jsonb,
  template_version_id uuid references public.certificate_template_versions(id), pdf_path text, status public.certificate_status not null default 'valid',
  replaces_certificate_id uuid references public.certificates(id), issued_at timestamptz not null default now(), voided_at timestamptz,
  void_reason text, created_by uuid references auth.users(id)
);

alter table public.certificate_correction_requests add column if not exists initiated_by text not null default 'participant';
alter table public.certificate_correction_requests add column if not exists final_decision_at timestamptz;
alter table public.certificate_correction_requests add column if not exists review_count integer not null default 0;
alter table public.certificate_correction_requests add column if not exists withdrawn_at timestamptz;
do $$ begin
  if not exists (select 1 from pg_constraint where conname='certificate_correction_requests_certificate_id_fkey') then
    alter table public.certificate_correction_requests add constraint certificate_correction_requests_certificate_id_fkey foreign key(certificate_id) references public.certificates(id);
  end if;
end $$;
create table if not exists public.certificate_reviews (
  id uuid primary key default gen_random_uuid(), request_id uuid not null references public.certificate_correction_requests(id) on delete cascade,
  reviewer_id uuid not null references auth.users(id), reason text not null, status text not null default 'submitted', decision text,
  created_at timestamptz not null default now(), decided_at timestamptz
);
create table if not exists public.certificate_request_events (
  id uuid primary key default gen_random_uuid(), request_id uuid not null references public.certificate_correction_requests(id) on delete cascade,
  actor_id uuid references auth.users(id), event_type text not null, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table if not exists public.news (
  id uuid primary key default gen_random_uuid(), slug text not null unique, title text not null, excerpt text, body text not null,
  cover_path text, status public.activity_status not null default 'draft', published_at timestamptz, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.pages (
  id uuid primary key default gen_random_uuid(), slug text not null unique, title text not null, body text not null, menu_label text,
  menu_order integer not null default 0, visible boolean not null default true, status public.activity_status not null default 'draft',
  created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.library_categories (id uuid primary key default gen_random_uuid(), name text not null unique, active boolean not null default true);
create table if not exists public.library_materials (
  id uuid primary key default gen_random_uuid(), title text not null, slug text not null unique, description text, author text, cover_path text,
  pdf_path text, status public.activity_status not null default 'draft', published_at timestamptz, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.library_material_categories (material_id uuid references public.library_materials(id) on delete cascade, category_id uuid references public.library_categories(id) on delete cascade, primary key(material_id, category_id));
create table if not exists public.institutional_documents (
  id uuid primary key default gen_random_uuid(), title text not null, document_type text not null, document_date date, document_number text,
  pdf_path text, status public.activity_status not null default 'draft', published_at timestamptz, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.galleries (
  id uuid primary key default gen_random_uuid(), activity_id uuid references public.activities(id) on delete set null, title text not null, description text,
  status public.activity_status not null default 'draft', created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.gallery_items (
  id uuid primary key default gen_random_uuid(), gallery_id uuid not null references public.galleries(id) on delete cascade, kind text not null check(kind in ('photo','video')),
  asset_path text, external_url text, caption text, item_order integer not null default 0
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(), recipient_id uuid references auth.users(id) on delete cascade, audience_role public.user_role,
  title text not null, body text not null, href text, read_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.notification_templates (
  id uuid primary key default gen_random_uuid(), key text not null unique, subject text not null, body text not null, active boolean not null default true,
  updated_by uuid references auth.users(id), updated_at timestamptz not null default now()
);
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(), actor_id uuid references auth.users(id), action text not null, module text not null,
  entity_type text, entity_id uuid, outcome text, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create table if not exists public.evaluation_forms (
  id uuid primary key default gen_random_uuid(), activity_id uuid not null references public.activities(id) on delete cascade, title text not null,
  anonymous boolean not null default true, opens_at timestamptz, closes_at timestamptz, active boolean not null default false, created_by uuid references auth.users(id)
);
create table if not exists public.evaluation_questions (
  id uuid primary key default gen_random_uuid(), form_id uuid not null references public.evaluation_forms(id) on delete cascade,
  prompt text not null, kind text not null check(kind in ('choice','scale','text')), required boolean not null default false, options jsonb not null default '[]'::jsonb, question_order integer not null default 0
);
create table if not exists public.evaluation_responses (
  id uuid primary key default gen_random_uuid(), form_id uuid not null references public.evaluation_forms(id) on delete cascade,
  enrollment_id uuid not null references public.enrollments(id) on delete cascade, respondent_hash text not null, created_at timestamptz not null default now(), unique(form_id, enrollment_id)
);
create table if not exists public.evaluation_answers (
  response_id uuid not null references public.evaluation_responses(id) on delete cascade, question_id uuid not null references public.evaluation_questions(id) on delete cascade,
  value jsonb not null, primary key(response_id, question_id)
);

create table if not exists public.privacy_requests (
  id uuid primary key default gen_random_uuid(), requester_id uuid references auth.users(id), email text not null, request_type text not null check(request_type in ('access','correction','deletion')),
  description text not null, status text not null default 'received', identity_verified_at timestamptz, legal_review text, resolved_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.support_incidents (
  id uuid primary key default gen_random_uuid(), severity text not null check(severity in ('critical','high','medium','low')), title text not null, description text not null,
  status text not null default 'open', owner_id uuid references auth.users(id), first_response_due_at timestamptz, resolved_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.maintenance_notices (
  id uuid primary key default gen_random_uuid(), title text not null, body text not null, starts_at timestamptz not null, ends_at timestamptz, emergency boolean not null default false, active boolean not null default true, created_by uuid references auth.users(id)
);
create table if not exists public.change_requests (
  id uuid primary key default gen_random_uuid(), title text not null, description text not null, priority text not null default 'medium', effort text, risk text,
  status text not null default 'proposed', requester_id uuid references auth.users(id), approver_id uuid references auth.users(id), decision_reason text, created_at timestamptz not null default now()
);
create table if not exists public.help_articles (
  id uuid primary key default gen_random_uuid(), slug text not null unique, title text not null, body text not null, audience public.user_role, status public.activity_status not null default 'draft', updated_by uuid references auth.users(id), updated_at timestamptz not null default now()
);
create table if not exists public.system_settings (
  key text primary key, value jsonb not null, category text not null, updated_by uuid references auth.users(id), updated_at timestamptz not null default now()
);
create table if not exists public.release_versions (
  id uuid primary key default gen_random_uuid(), version text not null unique, released_at timestamptz, change_summary text not null, status text not null default 'draft', created_by uuid references auth.users(id)
);
create table if not exists public.parliament_public_cache (
  id uuid primary key default gen_random_uuid(), entity_type text not null, external_id text not null, payload jsonb not null, synced_at timestamptz not null default now(), unique(entity_type, external_id)
);
create table if not exists public.contact_messages (
  id uuid primary key default gen_random_uuid(), name text not null, email text not null, subject text not null, message text not null,
  status text not null default 'received', created_at timestamptz not null default now()
);

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, full_name, email) values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), new.email) on conflict(id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.is_staff() returns boolean language sql stable as $$
  select coalesce((auth.jwt()->'app_metadata'->>'role') in ('admin_general','school_team'), false)
$$;
create or replace function public.is_admin() returns boolean language sql stable as $$
  select coalesce(auth.jwt()->'app_metadata'->>'role' = 'admin_general', false)
$$;

do $$ declare t text; begin
  foreach t in array array['profiles','activities','activity_sessions','enrollments','attendance','qr_checkins','certificate_templates','certificate_template_versions','certificates','certificate_reviews','certificate_request_events','news','pages','library_categories','library_materials','library_material_categories','institutional_documents','galleries','gallery_items','notifications','notification_templates','audit_logs','evaluation_forms','evaluation_questions','evaluation_responses','evaluation_answers','privacy_requests','support_incidents','maintenance_notices','change_requests','help_articles','system_settings','release_versions','parliament_public_cache','contact_messages'] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

create policy "published activities are public" on public.activities for select to anon, authenticated using (status='published');
create policy "published news are public" on public.news for select to anon, authenticated using (status='published');
create policy "visible pages are public" on public.pages for select to anon, authenticated using (status='published' and visible=true);
create policy "published materials are public" on public.library_materials for select to anon, authenticated using (status='published');
create policy "published documents are public" on public.institutional_documents for select to anon, authenticated using (status='published');
create policy "published galleries are public" on public.galleries for select to anon, authenticated using (status='published');
create policy "public gallery items are public" on public.gallery_items for select to anon, authenticated using (exists(select 1 from public.galleries g where g.id=gallery_id and g.status='published'));
create policy "public help is public" on public.help_articles for select to anon, authenticated using (status='published');
create policy "active maintenance is public" on public.maintenance_notices for select to anon, authenticated using (active=true);
create policy "public parliament cache is public" on public.parliament_public_cache for select to anon, authenticated using (true);
create policy "anyone can submit contact" on public.contact_messages for insert to anon, authenticated with check (char_length(name) between 2 and 120 and char_length(message) between 10 and 5000);
create policy "staff manage contact" on public.contact_messages for all to authenticated using (public.is_staff()) with check (public.is_staff());

create policy "users read own profile" on public.profiles for select to authenticated using ((select auth.uid())=id or public.is_staff());
create policy "users update own profile" on public.profiles for update to authenticated using ((select auth.uid())=id) with check ((select auth.uid())=id);
create policy "participants read own enrollments" on public.enrollments for select to authenticated using ((select auth.uid())=participant_id or public.is_staff());
create policy "participants read own attendance" on public.attendance for select to authenticated using (exists(select 1 from public.enrollments e where e.id=enrollment_id and (e.participant_id=(select auth.uid()) or public.is_staff())));
create policy "participants read own certificates" on public.certificates for select to authenticated using (exists(select 1 from public.enrollments e where e.id=enrollment_id and (e.participant_id=(select auth.uid()) or public.is_staff())));
create policy "participants read own notifications" on public.notifications for select to authenticated using (recipient_id=(select auth.uid()) or public.is_staff());
create policy "participants update own notifications" on public.notifications for update to authenticated using (recipient_id=(select auth.uid())) with check (recipient_id=(select auth.uid()));
create policy "participants read own privacy requests" on public.privacy_requests for select to authenticated using (requester_id=(select auth.uid()));
create policy "participants read own evaluations" on public.evaluation_responses for select to authenticated using (exists(select 1 from public.enrollments e where e.id=enrollment_id and e.participant_id=(select auth.uid())));
create policy "participants read own corrections" on public.certificate_correction_requests for select to authenticated using ((select auth.uid())=participant_id or public.is_staff());
create policy "participants create corrections" on public.certificate_correction_requests for insert to authenticated with check ((select auth.uid())=participant_id);
create policy "participants read correction children" on public.certificate_correction_items for select to authenticated using (exists(select 1 from public.certificate_correction_requests r where r.id=request_id and (r.participant_id=(select auth.uid()) or public.is_staff())));
create policy "participants read complements" on public.certificate_complementations for select to authenticated using (exists(select 1 from public.certificate_correction_requests r where r.id=request_id and (r.participant_id=(select auth.uid()) or public.is_staff())));
create policy "participants read reviews" on public.certificate_reviews for select to authenticated using (exists(select 1 from public.certificate_correction_requests r where r.id=request_id and (r.participant_id=(select auth.uid()) or public.is_staff())));
create policy "participants read correction events" on public.certificate_request_events for select to authenticated using (exists(select 1 from public.certificate_correction_requests r where r.id=request_id and (r.participant_id=(select auth.uid()) or public.is_staff())));

create policy "staff manage activities" on public.activities for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage activity sessions" on public.activity_sessions for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage enrollments" on public.enrollments for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage attendance" on public.attendance for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage certificates" on public.certificates for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage certificate workflows" on public.certificate_reviews for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage correction events" on public.certificate_request_events for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage content" on public.news for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage pages" on public.pages for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage library" on public.library_materials for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage documents" on public.institutional_documents for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage galleries" on public.galleries for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage gallery items" on public.gallery_items for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage notifications" on public.notifications for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage audits" on public.audit_logs for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage evaluations" on public.evaluation_forms for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage evaluation questions" on public.evaluation_questions for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage privacy" on public.privacy_requests for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage incidents" on public.support_incidents for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage maintenance" on public.maintenance_notices for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage change requests" on public.change_requests for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage help" on public.help_articles for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage settings" on public.system_settings for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage release versions" on public.release_versions for all to authenticated using (public.is_staff()) with check (public.is_staff());

create index if not exists activities_public_schedule_idx on public.activities(status, starts_at);
create index if not exists enrollments_activity_status_idx on public.enrollments(activity_id, status, created_at);
create index if not exists attendance_enrollment_idx on public.attendance(enrollment_id);
create index if not exists certificates_code_status_idx on public.certificates(certificate_code, status);
create index if not exists audit_logs_module_created_idx on public.audit_logs(module, created_at desc);
create index if not exists notifications_recipient_read_idx on public.notifications(recipient_id, read_at, created_at desc);

