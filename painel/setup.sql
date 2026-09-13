-- =========================================================================
-- SETUP DO BANCO PARA O PAINEL ADMINISTRATIVO DO PORTFÓLIO
-- Rode este script uma única vez no SQL Editor do seu projeto Supabase
-- (Supabase > SQL Editor > New query > cole tudo > Run).
-- =========================================================================

-- Garante a extensão usada para gerar IDs (já vem ativa por padrão no Supabase).
create extension if not exists pgcrypto;

-- -------------------------------------------------------------------------
-- Tabela de eventos do site: visitas, cliques em botões e vídeos assistidos.
-- -------------------------------------------------------------------------
create table if not exists portfolio_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,        -- 'page_view', 'button_click' ou 'video_view'
  event_name text,                 -- nome do botão, id do vídeo, etc.
  session_id text,                 -- identifica um visitante durante a visita
  page_path text,                  -- caminho da página onde o evento ocorreu
  metadata jsonb,                  -- dados extras (title, brand, category...)
  created_at timestamptz not null default now()
);

-- -------------------------------------------------------------------------
-- Tabela de mensagens de contato: formulário do site e pop-up.
-- -------------------------------------------------------------------------
create table if not exists portfolio_leads (
  id uuid primary key default gen_random_uuid(),
  name text,
  email text,
  phone text,
  brand text,
  budget text,
  message text,
  source text,                     -- 'contact' ou 'popup'
  created_at timestamptz not null default now()
);

-- -------------------------------------------------------------------------
-- Row Level Security: por padrão, ninguém lê ou escreve nas tabelas.
-- As policies abaixo liberam apenas o necessário.
-- -------------------------------------------------------------------------
alter table portfolio_events enable row level security;
alter table portfolio_leads enable row level security;

-- Permite que qualquer usuário LOGADO no painel (authenticated) leia os dados.
create policy "leitura autenticada - eventos"
  on portfolio_events for select
  to authenticated
  using (true);

create policy "leitura autenticada - leads"
  on portfolio_leads for select
  to authenticated
  using (true);

-- -------------------------------------------------------------------------
-- IMPORTANTE
-- Este script não cria nenhuma policy de INSERT para o papel "anon"
-- (visitante público do site). De propósito: gravar eventos e mensagens
-- direto do navegador do visitante, usando a chave "anon", permitiria que
-- qualquer pessoa mandasse dados falsos pelo console do navegador.
--
-- A gravação em portfolio_events e portfolio_leads deve ser feita por um
-- servidor (uma função/rota que você controla) usando a chave de serviço
-- (service_role) do Supabase, nunca pela chave anon exposta no site.
-- =========================================================================
