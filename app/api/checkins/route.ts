import {NextResponse} from 'next/server'
import {createClient} from '@/lib/supabase/server'
export async function POST(request:Request){const body=await request.json();const token=String(body.token||'').trim();const cpf=String(body.cpf||'').trim();if(!token||!cpf)return NextResponse.json({error:'QR Code e CPF são obrigatórios.'},{status:400});const supabase=await createClient();const {data,error}=await supabase.rpc('record_qr_checkin',{p_token:token,p_cpf:cpf});if(error)return NextResponse.json({error:'Check-in recusado.',detail:error.message},{status:400});return NextResponse.json({attendance:Array.isArray(data)?data[0]:data},{status:201})}

