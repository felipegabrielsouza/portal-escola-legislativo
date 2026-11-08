'use client'
import {useState} from 'react'
import {createClient} from '@/lib/supabase/client'
export default function Login(){const [message,setMessage]=useState('');async function submit(e:React.FormEvent<HTMLFormElement>){e.preventDefault();const email=String(new FormData(e.currentTarget).get('email'));const supabase=createClient();const {error}=await supabase.auth.signInWithOtp({email,options:{emailRedirectTo:window.location.origin+'/participante'}});setMessage(error?.message||'Confira seu e-mail para continuar.')};return <main className="wrap"><div className="card narrow"><div className="eyebrow">Área segura</div><h1>Entrar no portal</h1><p>Use seu e-mail para receber um código temporário. Não coletamos data de nascimento.</p><form onSubmit={submit}><label>E-mail<input name="email" type="email" required/></label><button className="button">Enviar código</button></form>{message&&<p className="notice">{message}</p>}</div></main>}

