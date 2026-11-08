import {NextResponse} from 'next/server'
import {getCurrentClaims,isStaffClaims} from '@/lib/auth'
export async function POST(_request:Request,{params}:{params:Promise<{id:string}>}){const {id}=await params;const {supabase,claims}=await getCurrentClaims();if(!claims?.sub||!isStaffClaims(claims))return NextResponse.json({error:'Acesso administrativo necessário.'},{status:403});const {data,error}=await supabase.rpc('promote_next_waitlist',{p_activity_id:id});if(error)return NextResponse.json({error:error.message},{status:400});return NextResponse.json({promotion:Array.isArray(data)?data[0]||null:data||null})}

