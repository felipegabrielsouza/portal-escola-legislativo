import {NextResponse} from 'next/server'
import {getCurrentClaims,isStaffClaims} from '@/lib/auth'
export async function POST(request:Request){const body=await request.json();const {supabase,claims}=await getCurrentClaims();if(!claims?.sub||!isStaffClaims(claims))return NextResponse.json({error:'Acesso administrativo necessário.'},{status:403});const {data,error}=await supabase.rpc('record_manual_attendance',{p_enrollment_id:String(body.enrollmentId),p_session_id:String(body.sessionId),p_hours_present:Number(body.hoursPresent)});if(error)return NextResponse.json({error:error.message},{status:400});return NextResponse.json({attendance:Array.isArray(data)?data[0]:data})}

