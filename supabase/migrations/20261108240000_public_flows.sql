-- Public flows used by the website. The policies validate shape but do not
-- grant public reads of participant records.
create policy "anyone can create enrollment" on public.enrollments
for insert to anon, authenticated
with check (
  char_length(trim(guest_name)) between 2 and 200
  and guest_email ~* '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$'
  and char_length(guest_cpf) = 11
  and char_length(trim(guest_phone)) between 8 and 40
  and char_length(trim(city)) between 2 and 120
  and state ~ '^[A-Za-z]{2}$'
);

-- Verification is intentionally exposed as a narrow function instead of a
-- table-wide public SELECT policy. It requires both the public code and the
-- participant's normalized full name.
create or replace function public.verify_certificate(p_code text, p_name text)
returns table (
  certificate_code text,
  verification_name text,
  activity_name text,
  workload_hours integer,
  period_start date,
  period_end date,
  issuer text,
  issued_at timestamptz,
  status text
)
language sql
security definer
set search_path = public
as $$
  select c.certificate_code, c.verification_name, c.activity_name,
         c.workload_hours, c.period_start, c.period_end, c.issuer,
         c.issued_at, c.status::text
    from public.certificates c
   where c.certificate_code = left(trim(p_code), 100)
     and lower(trim(c.verification_name)) = lower(trim(left(p_name, 200)))
     and c.status = 'valid'
   limit 1;
$$;

revoke all on function public.verify_certificate(text, text) from public;
grant execute on function public.verify_certificate(text, text) to anon, authenticated;

