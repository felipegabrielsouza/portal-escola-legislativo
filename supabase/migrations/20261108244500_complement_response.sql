create or replace function public.respond_to_certificate_complement(
  p_complement_id uuid,
  p_response text
)
returns table (id uuid, request_id uuid, status text)
language plpgsql security definer set search_path = public
as $$
declare v_user uuid := auth.uid(); v_request uuid;
begin
  if v_user is null then raise exception 'authentication_required'; end if;
  if length(trim(coalesce(p_response,''))) < 10 then raise exception 'response_too_short'; end if;
  select c.request_id into v_request
    from public.certificate_complementations c
    join public.certificate_correction_requests r on r.id=c.request_id
   where c.id=p_complement_id and r.participant_id=v_user and c.status='open';
  if v_request is null then raise exception 'complement_not_found'; end if;
  update public.certificate_complementations
     set response_text=trim(p_response), responded_at=now(), status='responded'
   where id=p_complement_id;
  update public.certificate_correction_requests
     set status='under_review', last_activity_at=now()
   where id=v_request;
  update public.correction_monitoring
     set pending_owner='administration', next_check_at=now()+interval '3 days'
   where request_id=v_request;
  insert into public.certificate_request_events(request_id,actor_id,event_type,details)
  values(v_request,v_user,'complement_responded',jsonb_build_object('complement_id',p_complement_id));
  return query select c.id,c.request_id,c.status from public.certificate_complementations c where c.id=p_complement_id;
end;
$$;
revoke all on function public.respond_to_certificate_complement(uuid,text) from public;
grant execute on function public.respond_to_certificate_complement(uuid,text) to authenticated;

