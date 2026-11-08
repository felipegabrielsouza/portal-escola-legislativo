import {notFound} from 'next/navigation'
import {Shell} from '@/app/components/Shell'
import {createClient} from '@/lib/supabase/server'
export default async function CursoDetalhe({params}:{params:Promise<{id:string}>}){const {id}=await params;const supabase=await createClient();const {data}=await supabase.from('activities').select('*').eq('id',id).eq('status','published').single();if(!data)notFound();return <Shell title="Detalhes da atividade"><div className="card"><h1>{data.title}</h1><p>{data.description}</p><dl className="details"><dt>Quando</dt><dd>{new Date(data.starts_at).toLocaleString('pt-BR')} até {new Date(data.ends_at).toLocaleString('pt-BR')}</dd><dt>Onde</dt><dd>{data.location}</dd><dt>Modalidade</dt><dd>{data.modality}</dd><dt>Vagas</dt><dd>{data.capacity}</dd><dt>Pré-requisitos</dt><dd>{data.prerequisites||'Não informado'}</dd></dl><a className="button" href={`/cursos/${data.id}/inscricao`}>Inscrever-se</a></div></Shell>}

