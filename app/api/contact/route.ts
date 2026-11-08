import {NextResponse} from 'next/server'
import {createClient} from '@/lib/supabase/server'
export async function POST(request:Request){const body=await request.json();if(!body.name||!/^\S+@\S+\.\S+$/.test(String(body.email))||!body.message)return NextResponse.json({error:'Nome, e-mail e mensagem são obrigatórios.'},{status:400});const supabase=await createClient();const {error}=await supabase.from('contact_messages').insert({name:String(body.name).trim(),email:String(body.email).trim().toLowerCase(),subject:String(body.subject||'Contato pelo portal').trim(),message:String(body.message).trim()});return error?NextResponse.json({error:'Não foi possível enviar a mensagem.'},{status:500}):NextResponse.json({ok:true},{status:201})}

