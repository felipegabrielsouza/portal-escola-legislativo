do $$ begin
  alter type public.correction_status add value if not exists 'withdrawn';
exception when duplicate_object then null;
end $$;

alter table public.certificate_complementations
  add column if not exists response_text text;

create sequence if not exists public.certificate_correction_protocol_seq;

create policy "staff manage correction requests" on public.certificate_correction_requests
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage correction items" on public.certificate_correction_items
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage complementations" on public.certificate_complementations
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage deadline changes" on public.certificate_deadline_changes
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage correction monitoring" on public.correction_monitoring
for all to authenticated using (public.is_staff()) with check (public.is_staff());

create or replace function public.create_certificate_correction(
  p_certificate_id uuid,
  p_justification text,
  p_items jsonb
)
returns table (id uuid, protocol text, status public.correction_status)
language plpgsql security definer set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_request_id uuid;
  v_protocol text;
  v_item jsonb;
  v_field text;
  v_value text;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  if length(trim(coalesce(p_justification, ''))) < 20 then raise exception 'justification_too_short'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'items_required'; end if;
  if not exists (
    select 1 from public.certificates c
    join public.enrollments e on e.id = c.enrollment_id
    where c.id = p_certificate_id and e.participant_id = v_user and c.status = 'valid'
  ) then raise exception 'certificate_not_owned'; end if;

  v_protocol := 'CR-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.certificate_correction_protocol_seq')::text, 6, '0');
  insert into public.certificate_correction_requests
    (protocol, participant_id, certificate_id, initiated_by, justification, status)
  values
    (v_protocol, v_user, p_certificate_id, 'participant', trim(p_justification), 'submitted')
  returning certificate_correction_requests.id into v_request_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_field := trim(coalesce(v_item->>'field_name', ''));
    v_value := trim(coalesce(v_item->>'requested_value', ''));
    if v_field = '' or v_value = '' or length(v_field) > 120 or length(v_value) > 1000 then
      raise exception 'invalid_item';
    end if;
    insert into public.certificate_correction_items(request_id, field_name, requested_value)
    values (v_request_id, v_field, v_value);
  end loop;

  insert into public.certificate_request_events(request_id, actor_id, event_type, details)
  values (v_request_id, v_user, 'submitted', jsonb_build_object('item_count', jsonb_array_length(p_items)));
  insert into public.correction_monitoring(request_id, pending_owner, next_check_at)
  values (v_request_id, 'administration', now() + interval '3 days');
  return query select r.id, r.protocol, r.status from public.certificate_correction_requests r where r.id = v_request_id;
end;
$$;

revoke all on function public.create_certificate_correction(uuid, text, jsonb) from public;
grant execute on function public.create_certificate_correction(uuid, text, jsonb) to authenticated;

create or replace function public.withdraw_certificate_correction(p_request_id uuid)
returns table (id uuid, protocol text, status public.correction_status)
language plpgsql security definer set search_path = public
as $$
declare v_user uuid := auth.uid();
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  update public.certificate_correction_requests r
     set status = 'withdrawn', withdrawn_at = now(), last_activity_at = now()
   where r.id = p_request_id and r.participant_id = v_user
     and r.status in ('submitted','under_review','awaiting_participant','partially_approved');
  if not found then raise exception 'withdrawal_not_allowed'; end if;
  insert into public.certificate_request_events(request_id, actor_id, event_type)
  values (p_request_id, v_user, 'withdrawn');
  return query select r.id, r.protocol, r.status from public.certificate_correction_requests r where r.id = p_request_id;
end;
$$;

revoke all on function public.withdraw_certificate_correction(uuid) from public;
grant execute on function public.withdraw_certificate_correction(uuid) to authenticated;

