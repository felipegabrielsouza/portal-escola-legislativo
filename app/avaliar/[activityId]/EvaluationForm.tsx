'use client'
import {useState} from 'react'
type Question={id:string;prompt:string;kind:'choice'|'scale'|'text';required:boolean;options:string[]}
export default function EvaluationForm({activityId,questions}:{activityId:string;questions:Question[]}){
  const [sent,setSent]=useState(false); const [error,setError]=useState('')
  async function submit(event:React.FormEvent<HTMLFormElement>){event.preventDefault();setError('');const form=new FormData(event.currentTarget);const answers:Record<string,unknown>={};for(const q of questions){const value=String(form.get(q.id)||'');if(value)answers[q.id]=value}const response=await fetch(`/api/evaluations/${activityId}`,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({cpf:form.get('cpf'),answers})});const body=await response.json();if(!response.ok){setError(body.error||'Não foi possível enviar.');return}setSent(true)}
  if(sent)return <div className="notice">Avaliação registrada. Obrigado pela participação.</div>
  return <form onSubmit={submit}><p>A avaliação é opcional e não interfere na emissão do certificado.</p><label>CPF usado na inscrição<input name="cpf" inputMode="numeric" required/></label>{questions.map(q=><fieldset key={q.id}><legend>{q.prompt}{q.required?' *':''}</legend>{q.kind==='text'?<textarea name={q.id} required={q.required} rows={4}/>:q.kind==='choice'?<select name={q.id} required={q.required}><option value="">Selecione</option>{(q.options||[]).map(o=><option key={o} value={o}>{o}</option>)}</select>:<div className="inline-options">{[1,2,3,4,5].map(n=><label key={n}><input type="radio" name={q.id} value={n} required={q.required&&n===1}/>{n}</label>)}</div>}</fieldset>)}{error&&<p className="error">{error}</p>}<button className="button">Enviar avaliação</button></form>
}

