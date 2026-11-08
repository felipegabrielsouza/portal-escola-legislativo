import {NextResponse} from 'next/server'
import {getCurrentClaims,isStaffClaims} from '@/lib/auth'
export async function POST(request:Request,{params}:{params:Promise<{id:string}>}){const {id}=await params;const body=await request.json().catch(()=>({}));const {supabase,claims}=await getCurrentClaims();if(!claims?.sub||!isStaffClaims(claims))return NextResponse.json({error:'Acesso administrativo necessário.'},{status:403});const {data,error}=await supabase.rpc('create_qr_checkin',{p_session_id:id,p_valid_seconds:Number(body.validSeconds||300)});if(error)return NextResponse.json({error:error.message},{status:400});return NextResponse.json({checkin:Array.isArray(data)?data[0]:data})}

