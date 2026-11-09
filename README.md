# Portal da Escola do Legislativo

Portal público e administrativo da Escola do Legislativo Dr. Thiago Ferraz de Siqueira, preparado para Next.js/Vercel e Supabase/PostgreSQL.

## Incluído

- Portal público responsivo: institucional, cursos, inscrições híbridas, notícias, biblioteca, documentos, galerias, contato, busca e páginas legais.
- Supabase Auth com acesso por código de e-mail, sessão SSR, RLS e separação de perfis por `app_metadata.role`.
- Modelo PostgreSQL para atividades, sessões, inscrições, espera, presença manual/QR, certificados, templates versionados, avaliações, conteúdo, notificações, auditoria, privacidade, suporte, manutenção e Parlamento Jovem público.
- Verificação pública de certificado por código e nome completo, sem leitura pública da tabela de certificados.
- Correções REQ-162–176: protocolo, itens com decisão individual, justificativa, histórico, complementações com prazo, retirada antes da decisão final, revisões administrativas e monitoramento sem encerramento automático.
- Operação fechada para atividades: rascunho/publicação, lista de espera com promoção autorizada, cancelamento dentro do prazo, encontros, presença manual ou QR temporário, cálculo ponderado, liberação idempotente de certificado e reemissão auditada.
- Avaliações por atividade: janela de abertura/fechamento, perguntas de escolha/escala/texto, CPF somente para comprovar inscrição, uma resposta por inscrição e conteúdo anônimo quando configurado.
- Migrações versionadas em `supabase/migrations`.

## Desenvolvimento

1. Copie `.env.example` para `.env.local` e preencha `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.
2. Execute `npm install` e `npm run dev`.
3. Execute `npm test` e `npm run build` antes de publicar.

## Verificação de implantação

- A publicação de produção é feita a partir da branch `main` no Vercel.
- O endpoint público `/api/activities` deve responder `200` antes do aceite.
- `/api/admin/activities` deve responder `403` sem sessão administrativa.
- A página `/admin` deve redirecionar usuários não autenticados para `/login`.
- Migrações aplicadas no Supabase devem aparecer na tabela de histórico antes de homologar os fluxos autenticados.

## Autorização administrativa

O painel `/admin` exige um usuário autenticado com `app_metadata.role` igual a `admin_general`, `school_team`, `staff`, `reviewer` ou `operator`. A administração de papéis deve ser feita por operador autorizado no Supabase Auth; não há usuário administrativo padrão criado pelo código.

## Escopo e pendências verificadas

O PDF fornecido contém requisitos REQ-001–109 e REQ-162–176. Ele declara REQ-110–161 como ausentes e orienta que não sejam inventados; esses requisitos continuam bloqueados até o fornecimento de seu conteúdo.

Integrações externas de e-mail transacional, Storage de arquivos/PDF, assinatura visual final, sincronização do Parlamento Jovem e rotina operacional de backup/retenção precisam de configuração institucional e teste com dados reais antes do aceite formal.

