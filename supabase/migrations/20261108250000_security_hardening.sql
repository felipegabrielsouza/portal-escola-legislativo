alter function public.is_staff() set search_path = public;
alter function public.is_admin() set search_path = public;

-- Explicitly scope workflow RPCs to signed-in participants. Public
-- certificate verification remains the only intentionally anonymous RPC.
revoke execute on function public.create_certificate_correction(uuid,text,jsonb) from anon, public;
grant execute on function public.create_certificate_correction(uuid,text,jsonb) to authenticated;
revoke execute on function public.withdraw_certificate_correction(uuid) from anon, public;
grant execute on function public.withdraw_certificate_correction(uuid) to authenticated;
revoke execute on function public.respond_to_certificate_complement(uuid,text) from anon, public;
grant execute on function public.respond_to_certificate_complement(uuid,text) to authenticated;
revoke execute on function public.handle_new_user() from anon, authenticated, public;

create policy "staff manage certificate templates" on public.certificate_templates
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage certificate template versions" on public.certificate_template_versions
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage library categories" on public.library_categories
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage material categories" on public.library_material_categories
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage evaluation answers" on public.evaluation_answers
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage notification templates" on public.notification_templates
for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy "staff manage qr checkins" on public.qr_checkins
for all to authenticated using (public.is_staff()) with check (public.is_staff());

