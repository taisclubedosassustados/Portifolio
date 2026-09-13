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
-- Escrita pública (o site do portfólio é 100% estático, sem servidor
-- próprio, então quem grava os eventos é o navegador de cada visitante,
-- usando a chave pública). Essas policies liberam APENAS a criação de
-- linhas novas (insert), nunca leitura, alteração ou exclusão para o
-- papel "anon": um visitante só consegue adicionar dados, nunca ver,
-- mudar ou apagar o que já está no banco.
-- -------------------------------------------------------------------------
create policy "escrita publica - eventos"
  on portfolio_events for insert
  to anon
  with check (event_type in ('page_view', 'button_click', 'video_view'));

create policy "escrita publica - leads"
  on portfolio_leads for insert
  to anon
  with check (source is null or source in ('contact', 'popup'));

-- Reforça a integridade dos dados também no nível da tabela (além da RLS).
-- Os blocos "do" abaixo evitam erro caso o script seja rodado mais de uma vez.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'chk_events_type') then
    alter table portfolio_events
      add constraint chk_events_type
      check (event_type in ('page_view', 'button_click', 'video_view'));
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'chk_leads_source') then
    alter table portfolio_leads
      add constraint chk_leads_source
      check (source is null or source in ('contact', 'popup'));
  end if;
end $$;

-- -------------------------------------------------------------------------
-- Funções de gravação (usadas pelo site em js/analytics.js via .rpc()).
-- O site chama estas funções em vez de gravar direto nas tabelas: elas
-- rodam com "security definer" (privilégio de quem criou a função), o
-- que evita depender da política de insert do papel "anon" na tabela.
-- -------------------------------------------------------------------------
create or replace function public.registrar_evento(
  p_event_type text,
  p_event_name text,
  p_session_id text,
  p_page_path text,
  p_metadata jsonb
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_event_type not in ('page_view', 'button_click', 'video_view') then
    raise exception 'tipo de evento invalido';
  end if;

  insert into portfolio_events (event_type, event_name, session_id, page_path, metadata)
  values (p_event_type, p_event_name, p_session_id, p_page_path, p_metadata);
end;
$$;

grant execute on function public.registrar_evento(text, text, text, text, jsonb) to anon, authenticated;

create or replace function public.registrar_lead(
  p_name text,
  p_email text,
  p_phone text,
  p_brand text,
  p_budget text,
  p_message text,
  p_source text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_source is not null and p_source not in ('contact', 'popup') then
    raise exception 'origem invalida';
  end if;

  insert into portfolio_leads (name, email, phone, brand, budget, message, source)
  values (p_name, p_email, p_phone, p_brand, p_budget, p_message, p_source);
end;
$$;

grant execute on function public.registrar_lead(text, text, text, text, text, text, text) to anon, authenticated;
-- =========================================================================
