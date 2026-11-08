import {NextResponse} from 'next/server'
import {getCurrentClaims,isStaffClaims} from '@/lib/auth'
export async function POST(request:Request){const body=await request.json();const {supabase,claims}=await getCurrentClaims();if(!claims?.sub||!isStaffClaims(claims))return NextResponse.json({error:'Acesso administrativo necessário.'},{status:403});const {data,error}=await supabase.rpc('release_certificate',{p_enrollment_id:String(body.enrollmentId),p_template_version_id:body.templateVersionId?String(body.templateVersionId):null});if(error)return NextResponse.json({error:'Certificado não liberado.',detail:error.message},{status:400});return NextResponse.json({certificate:Array.isArray(data)?data[0]:data},{status:201})}

