import {NextResponse} from 'next/server'
import {createClient} from '@/lib/supabase/server'

export async function GET(){
  const supabase=await createClient();
  const {data:claimsData}=await supabase.auth.getClaims();
  const user=claimsData?.claims;
  if(!user?.sub)return NextResponse.json({error:'Autenticação necessária.'},{status:401});
  const {data,error}=await supabase.from('certificate_correction_requests').select('id,protocol,status,justification,response_due_at,last_activity_at,created_at,certificate_id,certificate_correction_items(id,field_name,requested_value,decision,decision_reason,decided_at),certificate_complementations(id,description,justification,response_due_at,status,response_text)').eq('participant_id',user.sub).order('created_at',{ascending:false});
  if(error)return NextResponse.json({error:error.message},{status:400});
  return NextResponse.json({requests:data||[]});
}

export async function POST(request:Request){
  const body=await request.json();
  const certificateId=String(body.certificateId||'');
  const justification=String(body.justification||'');
  const items=Array.isArray(body.items)?body.items:[];
  const supabase=await createClient();
  const {data:claimsData}=await supabase.auth.getClaims();
  if(!claimsData?.claims?.sub)return NextResponse.json({error:'Faça login para solicitar correção.'},{status:401});
  const {data,error}=await supabase.rpc('create_certificate_correction',{p_certificate_id:certificateId,p_justification:justification,p_items:items});
  if(error)return NextResponse.json({error:'Não foi possível registrar a solicitação.',detail:error.message},{status:400});
  return NextResponse.json({request:Array.isArray(data)?data[0]:data},{status:201});
}

