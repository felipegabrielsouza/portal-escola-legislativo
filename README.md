# Portal da Escola do Legislativo

Base inicial executável para Vercel/Next.js e Supabase/PostgreSQL. Inclui portal público, área administrativa demonstrativa e fluxo de solicitação de correção de certificados, com modelagem para complementações, reabertura/prorrogação auditada e monitoramento sem encerramento automático.

## Execução

1. Copie `.env.example` para `.env.local` e preencha `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`.
2. `npm install` e `npm run dev`.
3. Aplique a migração em `supabase/migrations` após o projeto Supabase ativo.

## Estado da entrega

Esta base não comprova a implementação integral de REQ-001–176: o texto completo desses requisitos e credenciais ativas não estavam disponíveis nesta conversa. Autenticação real, RBAC administrativo, storage, notificações, jobs agendados, certificados PDF e integração com dados institucionais ainda precisam ser configurados e testados em ambiente ativo.

