'use client'
import {useEffect} from 'react'
export default function ErrorPage({error,reset}:{error:Error&{digest?:string};reset:()=>void}){useEffect(()=>{console.error(error)},[error]);return <main className="wrap"><div className="card narrow"><div className="eyebrow">Erro inesperado</div><h1>Não foi possível concluir</h1><p>O incidente foi registrado. Tente novamente ou retorne ao início.</p><button className="button" onClick={()=>reset()}>Tentar novamente</button></div></main>}

