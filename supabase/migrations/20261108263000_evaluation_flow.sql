create or replace function public.submit_evaluation(p_activity_id uuid, p_cpf text, p_answers jsonb)
returns uuid
language plpgsql security definer set search_path=public
as $$
declare
  v_form public.evaluation_forms%rowtype;
  v_enrollment public.enrollments%rowtype;
  v_response_id uuid;
  v_cpf text:=regexp_replace(coalesce(p_cpf,''),'\D','','g');
  v_question public.evaluation_questions%rowtype;
  v_value jsonb;
begin
  if jsonb_typeof(coalesce(p_answers,'{}'::jsonb)) <> 'object' then raise exception 'answers_object_required'; end if;
  select f.* into v_form from public.evaluation_forms f where f.activity_id=p_activity_id and f.active=true and (f.opens_at is null or f.opens_at<=now()) and (f.closes_at is null or f.closes_at>=now()) order by f.created_at desc limit 1;
  if not found then raise exception 'evaluation_closed'; end if;
  select e.* into v_enrollment from public.enrollments e where e.activity_id=p_activity_id and e.guest_cpf=v_cpf and e.status='confirmed' order by e.created_at desc limit 1;
  if not found then raise exception 'enrollment_not_found'; end if;
  if exists(select 1 from public.evaluation_responses r where r.form_id=v_form.id and r.enrollment_id=v_enrollment.id) then raise exception 'evaluation_already_submitted'; end if;
  for v_question in select * from public.evaluation_questions where form_id=v_form.id order by question_order loop
    v_value:=p_answers->v_question.id::text;
    if v_question.required and (v_value is null or v_value='null'::jsonb or (jsonb_typeof(v_value)='string' and btrim(v_value #>> '{}')='')) then raise exception 'required_question_missing'; end if;
    if v_value is not null and v_value <> 'null'::jsonb then
      if v_question.kind='text' and length(v_value #>> '{}')>5000 then raise exception 'answer_too_long'; end if;
      if v_question.kind='choice' and not exists(select 1 from jsonb_array_elements_text(v_question.options) o where o=v_value #>> '{}') then raise exception 'invalid_choice'; end if;
      if v_question.kind='scale' and ((v_value #>> '{}') !~ '^[1-5]$') then raise exception 'invalid_scale'; end if;
    end if;
  end loop;
  insert into public.evaluation_responses(form_id,enrollment_id,respondent_hash) values(v_form.id,v_enrollment.id,encode(digest(v_form.id::text||':'||v_enrollment.id::text,'sha256'),'hex')) returning id into v_response_id;
  insert into public.evaluation_answers(response_id,question_id,value) select v_response_id,q.id,p_answers->q.id::text from public.evaluation_questions q where q.form_id=v_form.id and p_answers ? q.id::text;
  insert into public.audit_logs(action,module,entity_type,entity_id,outcome,details) values('submit_evaluation','evaluations','evaluation_response',v_response_id,'success',jsonb_build_object('activity_id',p_activity_id,'anonymous',v_form.anonymous));
  return v_response_id;
end;
$$;
revoke all on function public.submit_evaluation(uuid,text,jsonb) from public;
grant execute on function public.submit_evaluation(uuid,text,jsonb) to anon,authenticated;

create policy "active evaluation forms are public" on public.evaluation_forms for select to anon,authenticated using (active=true and (opens_at is null or opens_at<=now()) and (closes_at is null or closes_at>=now()));
create policy "active evaluation questions are public" on public.evaluation_questions for select to anon,authenticated using (exists(select 1 from public.evaluation_forms f where f.id=form_id and f.active=true and (f.opens_at is null or f.opens_at<=now()) and (f.closes_at is null or f.closes_at>=now())));

