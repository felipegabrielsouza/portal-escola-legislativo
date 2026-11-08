create or replace function public.is_staff() returns boolean language sql stable set search_path=public as $$
  select coalesce((auth.jwt()->'app_metadata'->>'role') in ('admin_general','school_team','staff','reviewer','operator'), false)
$$;

create or replace function public.cancel_enrollment(p_enrollment_id uuid, p_email text)
returns table (id uuid, status public.enrollment_status)
language plpgsql security definer set search_path=public
as $$
declare v_enrollment public.enrollments%rowtype; v_activity public.activities%rowtype; v_uid uuid:=auth.uid();
begin
  select e.* into v_enrollment from public.enrollments e where e.id=p_enrollment_id;
  if not found then raise exception 'enrollment_not_found'; end if;
  if v_uid is not null and v_enrollment.participant_id is distinct from v_uid and lower(v_enrollment.guest_email)<>lower(trim(p_email)) then raise exception 'not_allowed'; end if;
  if v_uid is null and lower(v_enrollment.guest_email)<>lower(trim(p_email)) then raise exception 'not_allowed'; end if;
  select a.* into v_activity from public.activities a where a.id=v_enrollment.activity_id;
  if v_enrollment.status='cancelled' then return query select v_enrollment.id,v_enrollment.status; return; end if;
  if now() > coalesce(v_activity.starts_at - make_interval(hours => v_activity.cancellation_deadline_hours), v_activity.starts_at) then raise exception 'cancellation_deadline_passed'; end if;
  update public.enrollments set status='cancelled',cancelled_at=now(),cancellation_reason='participant_request' where id=v_enrollment.id returning enrollments.id,enrollments.status into id,status;
  insert into public.audit_logs(actor_id,action,module,entity_type,entity_id,outcome,details) values(v_uid,'cancel_enrollment','enrollments','enrollment',v_enrollment.id,'success',jsonb_build_object('email',lower(trim(p_email))));
  return next;
end;
$$;
revoke all on function public.cancel_enrollment(uuid,text) from public;
grant execute on function public.cancel_enrollment(uuid,text) to anon,authenticated;

create or replace function public.promote_next_waitlist(p_activity_id uuid)
returns table (id uuid, guest_name text, guest_email text, waitlist_position integer)
language plpgsql security invoker set search_path=public
as $$
declare v_enrollment public.enrollments%rowtype; v_uid uuid:=auth.uid();
begin
  if not public.is_staff() or v_uid is null then raise exception 'staff_required'; end if;
  select e.* into v_enrollment from public.enrollments e where e.activity_id=p_activity_id and e.status='waitlist' order by e.created_at asc for update skip locked limit 1;
  if not found then return; end if;
  update public.enrollments set status='confirmed',waitlist_position=null where enrollments.id=v_enrollment.id;
  insert into public.waitlist_promotions(activity_id,enrollment_id,previous_position,promoted_by) values(p_activity_id,v_enrollment.id,coalesce(v_enrollment.waitlist_position,0),v_uid);
  if v_enrollment.participant_id is not null then insert into public.notifications(recipient_id,title,body,href) values(v_enrollment.participant_id,'Vaga confirmada','Sua inscrição saiu da lista de espera.','/participante'); end if;
  insert into public.audit_logs(actor_id,action,module,entity_type,entity_id,outcome,details) values(v_uid,'promote_waitlist','enrollments','enrollment',v_enrollment.id,'success',jsonb_build_object('activity_id',p_activity_id));
  return query select e.id,e.guest_name,e.guest_email,e.waitlist_position from public.enrollments e where e.id=v_enrollment.id;
end;
$$;
revoke all on function public.promote_next_waitlist(uuid) from public;
grant execute on function public.promote_next_waitlist(uuid) to authenticated;

