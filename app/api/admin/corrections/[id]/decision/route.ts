import {NextResponse} from 'next/server'
import {createClient} from '@/lib/supabase/server'

export async function POST(request:Request,{params}:{params:Promise<{id:string}>}){
  const {id}=await params; const body=await request.json();
  const items=Array.isArray(body.items)?body.items:[]; const reason=String(body.reason||'').trim();
  const supabase=await createClient(); const {data:claimsData}=await supabase.auth.getClaims();
  const claims=claimsData?.claims as Record<string,unknown>|undefined; const actorId=String(claims?.sub||'');
  const role=String(((claims?.app_metadata||{}) as Record<string,unknown>).role||'');
  if(!actorId||!['admin_general','staff','reviewer','operator'].includes(role))return NextResponse.json({error:'Acesso administrativo necessário.'},{status:403});
  if(reason.length<20)return NextResponse.json({error:'A fundamentação deve ter ao menos 20 caracteres.'},{status:400});
  const {data:current,error:loadError}=await supabase.from('certificate_correction_requests').select('id,status,review_count').eq('id',id).single();
  if(loadError||!current)return NextResponse.json({error:'Solicitação não encontrada.'},{status:404});
  if(['approved','rejected','closed','withdrawn'].includes(current.status))return NextResponse.json({error:'Solicitação já possui decisão final.'},{status:409});
  const valid=items.filter((x:{decision?:string})=>x.decision==='approved'||x.decision==='rejected');
  if(!valid.length)return NextResponse.json({error:'Informe ao menos uma decisão.'},{status:400});
  for(const item of valid){const {error}=await supabase.from('certificate_correction_items').update({decision:item.decision,decision_reason:String(item.reason||reason),decided_at:new Date().toISOString()}).eq('id',String(item.id)).eq('request_id',id);if(error)return NextResponse.json({error:error.message},{status:400})}
  const {data:all}=await supabase.from('certificate_correction_items').select('decision').eq('request_id',id); const decisions=(all||[]).map(x=>x.decision);
  const status=decisions.some(x=>x===null)?'partially_approved':decisions.every(x=>x==='approved')?'approved':decisions.every(x=>x==='rejected')?'rejected':'partially_approved';
  const finalDecision=['approved','rejected'].includes(status); const now=new Date().toISOString();
  const {error:updateError}=await supabase.from('certificate_correction_requests').update({status,review_count:(current.review_count||0)+1,final_decision_at:finalDecision?now:null,last_activity_at:now}).eq('id',id);
  if(updateError)return NextResponse.json({error:updateError.message},{status:400});
  await supabase.from('certificate_reviews').insert({request_id:id,reviewer_id:actorId,reason,status:'decided',decision:status,decided_at:now});
  if(status==='approved'){const {error:reissueError}=await supabase.rpc('complete_certificate_correction',{p_request_id:id});if(reissueError)return NextResponse.json({error:'Decisão registrada, mas a reemissão precisa de correção operacional.',detail:reissueError.message},{status:409});}
  await supabase.from('certificate_request_events').insert({request_id:id,actor_id:actorId,event_type:'decision_recorded',details:{status,items:valid.map((x:{id:string;decision:string})=>({id:x.id,decision:x.decision}))}});
  return NextResponse.json({status});
}

