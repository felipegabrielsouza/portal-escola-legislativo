create or replace function public.create_qr_checkin(p_session_id uuid, p_valid_seconds integer default 300)
returns table (token text, expires_at timestamptz)
language plpgsql security invoker set search_path=public
as $$
declare v_token text:=encode(gen_random_bytes(24),'hex'); v_expires timestamptz:=now()+make_interval(secs=>least(greatest(p_valid_seconds,30),3600)); v_uid uuid:=auth.uid();
begin
  if not public.is_staff() or v_uid is null then raise exception 'staff_required'; end if;
  if not exists(select 1 from public.activity_sessions where id=p_session_id) then raise exception 'session_not_found'; end if;
  insert into public.qr_checkins(session_id,token_hash,expires_at,created_by) values(p_session_id,encode(digest(v_token,'sha256'),'hex'),v_expires,v_uid);
  return query select v_token,v_expires;
end;
$$;
revoke all on function public.create_qr_checkin(uuid,integer) from public;
grant execute on function public.create_qr_checkin(uuid,integer) to authenticated;

create or replace function public.record_qr_checkin(p_token text,p_cpf text)
returns table (attendance_id uuid, enrollment_id uuid, session_id uuid, hours_present numeric)
language plpgsql security definer set search_path=public
as $$
declare v_q public.qr_checkins%rowtype; v_session public.activity_sessions%rowtype; v_enrollment public.enrollments%rowtype; v_attendance public.attendance%rowtype; v_cpf text:=regexp_replace(coalesce(p_cpf,''),'\\D','','g');
begin
  select q.* into v_q from public.qr_checkins q where q.token_hash=encode(digest(trim(p_token),'sha256'),'hex') for update;
  if not found or now()>=v_q.expires_at or v_q.attempts>=v_q.max_attempts then raise exception 'qr_invalid_or_expired'; end if;
  update public.qr_checkins set attempts=attempts+1 where id=v_q.id;
  select s.* into v_session from public.activity_sessions s where s.id=v_q.session_id;
  select e.* into v_enrollment from public.enrollments e where e.activity_id=v_session.activity_id and e.guest_cpf=v_cpf and e.status='confirmed' order by e.created_at limit 1;
  if not found then raise exception 'enrollment_not_found'; end if;
  insert into public.attendance(enrollment_id,session_id,hours_present,source) values(v_enrollment.id,v_session.id,v_session.hours,'qr') on conflict(enrollment_id,session_id) do nothing returning attendance.* into v_attendance;
  if v_attendance.id is null then raise exception 'already_checked_in'; end if;
  return query select v_attendance.id,v_attendance.enrollment_id,v_attendance.session_id,v_attendance.hours_present;
end;
$$;
revoke all on function public.record_qr_checkin(text,text) from public;
grant execute on function public.record_qr_checkin(text,text) to anon,authenticated;

create or replace function public.record_manual_attendance(p_enrollment_id uuid,p_session_id uuid,p_hours_present numeric)
returns table (id uuid,enrollment_id uuid,session_id uuid,hours_present numeric)
language plpgsql security invoker set search_path=public
as $$
declare v_uid uuid:=auth.uid(); v_hours numeric;
begin
  if not public.is_staff() or v_uid is null then raise exception 'staff_required'; end if;
  select hours into v_hours from public.activity_sessions where id=p_session_id;
  if v_hours is null then raise exception 'session_not_found'; end if;
  if p_hours_present<0 or p_hours_present>v_hours then raise exception 'hours_out_of_range'; end if;
  insert into public.attendance(enrollment_id,session_id,hours_present,source,created_by) values(p_enrollment_id,p_session_id,p_hours_present,'manual',v_uid)
  on conflict(enrollment_id,session_id) do update set hours_present=excluded.hours_present,source='manual',created_by=excluded.created_by,checked_in_at=now()
  returning attendance.id,attendance.enrollment_id,attendance.session_id,attendance.hours_present;
end;
$$;
revoke all on function public.record_manual_attendance(uuid,uuid,numeric) from public;
grant execute on function public.record_manual_attendance(uuid,uuid,numeric) to authenticated;

create or replace function public.release_certificate(p_enrollment_id uuid,p_template_version_id uuid default null)
returns table (id uuid,certificate_code text,attendance_pct numeric,status public.certificate_status)
language plpgsql security invoker set search_path=public
as $$
declare v_uid uuid:=auth.uid(); v_enrollment public.enrollments%rowtype; v_activity public.activities%rowtype; v_pct numeric; v_code text; v_cert public.certificates%rowtype; v_job_key text;
begin
  if not public.is_staff() or v_uid is null then raise exception 'staff_required'; end if;
  select e.* into v_enrollment from public.enrollments e where e.id=p_enrollment_id and e.status='confirmed';
  if not found then raise exception 'confirmed_enrollment_required'; end if;
  select a.* into v_activity from public.activities a where a.id=v_enrollment.activity_id;
  select case when coalesce(sum(s.hours),0)=0 then 0 else round(coalesce(sum(at.hours_present),0)/sum(s.hours)*100,2) end into v_pct
    from public.activity_sessions s left join public.attendance at on at.session_id=s.id and at.enrollment_id=p_enrollment_id where s.activity_id=v_activity.id;
  if v_pct < v_activity.minimum_attendance_pct then raise exception 'attendance_below_minimum'; end if;
  select c.* into v_cert from public.certificates c where c.enrollment_id=p_enrollment_id and c.status='valid' order by c.issued_at desc limit 1;
  if found then return query select v_cert.id,v_cert.certificate_code,v_pct,v_cert.status; return; end if;
  v_code:='EL-'||to_char(now(),'YYYY')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,16));
  v_job_key:=p_enrollment_id::text||':'||coalesce(p_template_version_id::text,'default');
  insert into public.certificate_issuance_jobs(enrollment_id,template_version_id,status,idempotency_key,requested_by) values(p_enrollment_id,p_template_version_id,'processing',v_job_key,v_uid) on conflict(idempotency_key) do update set updated_at=now();
  insert into public.certificates(enrollment_id,certificate_code,verification_name,activity_name,workload_hours,period_start,period_end,issuer,template_version_id,created_by)
    values(p_enrollment_id,v_code,v_enrollment.guest_name,v_activity.title,v_activity.duration_hours,v_activity.starts_at,v_activity.ends_at,'Escola do Legislativo Dr. Thiago Ferraz de Siqueira',p_template_version_id,v_uid)
    returning certificates.* into v_cert;
  update public.certificate_issuance_jobs set certificate_id=v_cert.id,status='completed',completed_at=now(),updated_at=now() where idempotency_key=v_job_key;
  insert into public.audit_logs(actor_id,action,module,entity_type,entity_id,outcome,details) values(v_uid,'release_certificate','certificates','certificate',v_cert.id,'success',jsonb_build_object('attendance_pct',v_pct,'template_version_id',p_template_version_id));
  return query select v_cert.id,v_cert.certificate_code,v_pct,v_cert.status;
end;
$$;
revoke all on function public.release_certificate(uuid,uuid) from public;
grant execute on function public.release_certificate(uuid,uuid) to authenticated;

create or replace function public.complete_certificate_correction(p_request_id uuid)
returns table (old_certificate_id uuid,new_certificate_id uuid,new_code text)
language plpgsql security invoker set search_path=public
as $$
declare v_uid uuid:=auth.uid(); v_request public.certificate_correction_requests%rowtype; v_old public.certificates%rowtype; v_new public.certificates%rowtype; v_name text; v_activity text; v_hours numeric; v_issuer text; v_period_start timestamptz; v_period_end timestamptz; v_code text;
begin
  if not public.is_staff() or v_uid is null then raise exception 'staff_required'; end if;
  select r.* into v_request from public.certificate_correction_requests r where r.id=p_request_id and r.status='approved';
  if not found then raise exception 'approved_request_required'; end if;
  select c.* into v_old from public.certificates c where c.id=v_request.certificate_id and c.status='valid' for update;
  if not found then raise exception 'valid_certificate_not_found'; end if;
  v_name:=v_old.verification_name; v_activity:=v_old.activity_name; v_hours:=v_old.workload_hours; v_issuer:=v_old.issuer; v_period_start:=v_old.period_start; v_period_end:=v_old.period_end;
  select coalesce(max(case when lower(field_name) in ('nome','nome completo','verification_name','full_name') then requested_value end),v_name),coalesce(max(case when lower(field_name) in ('atividade','activity_name') then requested_value end),v_activity) into v_name,v_activity from public.certificate_correction_items where request_id=p_request_id and decision='approved';
  v_code:='EL-'||to_char(now(),'YYYY')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,16));
  update public.certificates set status='replaced',voided_at=now(),void_reason='Substituído após correção aprovada' where id=v_old.id;
  insert into public.certificates(enrollment_id,certificate_code,verification_name,activity_name,workload_hours,period_start,period_end,issuer,signatures,template_version_id,replaces_certificate_id,created_by)
    values(v_old.enrollment_id,v_code,v_name,v_activity,v_hours,v_period_start,v_period_end,v_issuer,v_old.signatures,v_old.template_version_id,v_old.id,v_uid) returning certificates.* into v_new;
  update public.certificate_correction_requests set status='closed',final_decision_at=coalesce(final_decision_at,now()),last_activity_at=now() where id=p_request_id;
  insert into public.certificate_request_events(request_id,actor_id,event_type,details) values(p_request_id,v_uid,'certificate_reissued',jsonb_build_object('old_certificate_id',v_old.id,'new_certificate_id',v_new.id,'new_code',v_new.certificate_code));
  insert into public.audit_logs(actor_id,action,module,entity_type,entity_id,outcome,details) values(v_uid,'reissue_certificate','certificates','certificate',v_new.id,'success',jsonb_build_object('replaces_certificate_id',v_old.id,'request_id',p_request_id));
  return query select v_old.id,v_new.id,v_new.certificate_code;
end;
$$;
revoke all on function public.complete_certificate_correction(uuid) from public;
grant execute on function public.complete_certificate_correction(uuid) to authenticated;

