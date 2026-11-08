import {NextResponse} from 'next/server'
import {createClient} from '@/lib/supabase/server'
export async function POST(request:Request,{params}:{params:Promise<{id:string}>}){const {id}=await params;const body=await request.json().catch(()=>({}));const email=String(body.email||'').trim();if(!email)return NextResponse.json({error:'E-mail é obrigatório.'},{status:400});const supabase=await createClient();const {data,error}=await supabase.rpc('cancel_enrollment',{p_enrollment_id:id,p_email:email});if(error)return NextResponse.json({error:'Não foi possível cancelar a inscrição.',detail:error.message},{status:400});return NextResponse.json({enrollment:Array.isArray(data)?data[0]:data})}

