import {NextResponse} from 'next/server'
import {createClient} from '@/lib/supabase/server'
export async function POST(_request:Request,{params}:{params:Promise<{id:string}>}){const {id}=await params;const supabase=await createClient();const {data:claimsData}=await supabase.auth.getClaims();if(!claimsData?.claims?.sub)return NextResponse.json({error:'Autenticação necessária.'},{status:401});const {data,error}=await supabase.rpc('withdraw_certificate_correction',{p_request_id:id});if(error)return NextResponse.json({error:'Retirada não permitida.',detail:error.message},{status:400});return NextResponse.json({request:Array.isArray(data)?data[0]:data})}

