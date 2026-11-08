import {NextResponse} from 'next/server'
import {createClient} from '@/lib/supabase/server'
export async function POST(request:Request){const body=await request.json();const code=String(body.code||'').trim();const name=String(body.name||'').trim();if(!code||!name)return NextResponse.json({error:'Código e nome completo são obrigatórios.'},{status:400});const supabase=await createClient();const {data,error}=await supabase.rpc('verify_certificate',{p_code:code,p_name:name});const certificate=Array.isArray(data)?data[0]:data;if(error||!certificate)return NextResponse.json({valid:false,error:'Certificado não localizado.'},{status:404});return NextResponse.json({valid:true,certificate})}

