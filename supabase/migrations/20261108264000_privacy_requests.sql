create or replace function public.submit_privacy_request(p_email text,p_request_type text,p_description text)
returns uuid
language plpgsql security definer set search_path=public
as $$
declare v_id uuid; v_uid uuid:=auth.uid(); v_email text:=lower(btrim(coalesce(p_email,'')));
begin
  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'invalid_email'; end if;
  if p_request_type not in ('access','correction','deletion') then raise exception 'invalid_request_type'; end if;
  if length(btrim(coalesce(p_description,'')))<10 or length(p_description)>5000 then raise exception 'invalid_description'; end if;
  insert into public.privacy_requests(requester_id,email,request_type,description) values(v_uid,v_email,p_request_type,btrim(p_description)) returning id into v_id;
  insert into public.audit_logs(actor_id,action,module,entity_type,entity_id,outcome,details) values(v_uid,'submit_privacy_request','privacy','privacy_request',v_id,'success',jsonb_build_object('request_type',p_request_type));
  return v_id;
end;
$$;
revoke all on function public.submit_privacy_request(text,text,text) from public;
grant execute on function public.submit_privacy_request(text,text,text) to anon,authenticated;

