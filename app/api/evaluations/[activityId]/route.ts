import {NextResponse} from 'next/server'
import {createClient} from '@/lib/supabase/server'

export async function GET(_request:Request,{params}:{params:Promise<{activityId:string}>}){
  const {activityId}=await params; const supabase=await createClient()
  const {data:form,error}=await supabase.from('evaluation_forms').select('id,activity_id,title,anonymous,opens_at,closes_at').eq('activity_id',activityId).eq('active',true).order('created_at',{ascending:false}).limit(1).maybeSingle()
  if(error||!form)return NextResponse.json({error:'Avaliação não disponível.'},{status:404})
  const {data:questions}=await supabase.from('evaluation_questions').select('id,prompt,kind,required,options,question_order').eq('form_id',form.id).order('question_order')
  return NextResponse.json({form,questions:questions??[]})
}

export async function POST(request:Request,{params}:{params:Promise<{activityId:string}>}){
  const {activityId}=await params; const body=await request.json(); const cpf=String(body.cpf||'').trim(); const answers=body.answers
  if(!cpf||!answers)return NextResponse.json({error:'CPF e respostas são obrigatórios.'},{status:400})
  const supabase=await createClient(); const {data,error}=await supabase.rpc('submit_evaluation',{p_activity_id:activityId,p_cpf:cpf,p_answers:answers})
  if(error){const status=/already_submitted/.test(error.message)?409:/closed|required_question|invalid_choice|invalid_scale|answer_too_long/.test(error.message)?400:403;return NextResponse.json({error:'Não foi possível registrar a avaliação.',detail:error.message},{status})}
  return NextResponse.json({id:data},{status:201})
}

