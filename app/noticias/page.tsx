import {Shell} from '@/app/components/Shell'
import {createClient} from '@/lib/supabase/server'
export default async function Noticias(){const supabase=await createClient();const {data}=await supabase.from('news').select('slug,title,excerpt,published_at').eq('status','published').order('published_at',{ascending:false});return <Shell title="Notícias"><h1>Notícias e destaques</h1><div className="grid">{(data??[]).map(n=><article className="card" key={n.slug}><div className="eyebrow">{n.published_at?new Date(n.published_at).toLocaleDateString('pt-BR'):''}</div><h2>{n.title}</h2><p>{n.excerpt}</p></article>)}{!data?.length&&<article className="card"><h2>Conteúdo em atualização</h2><p>As notícias publicadas pela equipe da Escola aparecerão aqui.</p></article>}</div></Shell>}

