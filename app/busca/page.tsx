import {Shell} from '@/app/components/Shell'
export default function Busca(){return <Shell title="Busca integrada"><h1>Buscar no portal</h1><form action="/busca" className="search"><input name="q" placeholder="Notícias, atividades, biblioteca, documentos..."/><button className="button">Buscar</button></form><p>Os resultados publicados serão agrupados por conteúdo.</p></Shell>}

