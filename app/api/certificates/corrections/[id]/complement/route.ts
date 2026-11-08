import {NextResponse} from 'next/server'
import {createClient} from '@/lib/supabase/server'
export async function POST(request:Request,{params}:{params:Promise<{id:string}>}){const {id}=await params;const body=await request.json();const supabase=await createClient();const {data:claimsData}=await supabase.auth.getClaims();if(!claimsData?.claims?.sub)return NextResponse.json({error:'Autenticação necessária.'},{status:401});const {data,error}=await supabase.rpc('respond_to_certificate_complement',{p_complement_id:id,p_response:String(body.response||'')});if(error)return NextResponse.json({error:'Não foi possível responder à complementação.',detail:error.message},{status:400});return NextResponse.json({complement:Array.isArray(data)?data[0]:data})}

