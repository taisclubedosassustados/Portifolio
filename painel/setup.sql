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
-- ABA "MINHA ROTINA" DO PAINEL
-- Tabelas de organização pessoal: registros semanais/diários de entregas
-- e tarefas manuais no calendário. Só quem está logado no painel usa isso.
-- =========================================================================

-- Cada "tick" marcado nos checklists (semanais ou diários) vira uma linha
-- aqui. O progresso é sempre calculado somando linhas, nunca guardado como
-- um número fixo, então nada fica dessincronizado.
create table if not exists rotina_registros (
  id uuid primary key default gen_random_uuid(),
  categoria text not null,   -- 'instagram', 'tiktok', 'youtube' ou 'diario'
  item text not null,        -- 'roteiro', 'gravacao', 'video', 'prospeccao', 'live', 'responder_mensagens', 'consumir_referencias'
  data date not null default current_date,
  created_at timestamptz not null default now()
);

-- Tarefas avulsas que você adiciona manualmente num dia específico do calendário.
create table if not exists rotina_tarefas (
  id uuid primary key default gen_random_uuid(),
  data date not null,
  titulo text not null,
  concluida boolean not null default false,
  created_at timestamptz not null default now()
);

alter table rotina_registros enable row level security;
alter table rotina_tarefas enable row level security;

create policy "leitura autenticada - rotina registros"
  on rotina_registros for select
  to authenticated
  using (true);

create policy "leitura autenticada - rotina tarefas"
  on rotina_tarefas for select
  to authenticated
  using (true);

-- Escrita também via funções "security definer" (mesmo padrão de cima),
-- só liberada para quem está autenticado (logado no painel).
create or replace function public.rotina_registrar_tick(
  p_categoria text,
  p_item text,
  p_data date default current_date
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  novo_id uuid;
begin
  insert into rotina_registros (categoria, item, data)
  values (p_categoria, p_item, p_data)
  returning id into novo_id;
  return novo_id;
end;
$$;

grant execute on function public.rotina_registrar_tick(text, text, date) to authenticated;

create or replace function public.rotina_remover_tick(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from rotina_registros where id = p_id;
end;
$$;

grant execute on function public.rotina_remover_tick(uuid) to authenticated;

create or replace function public.rotina_adicionar_tarefa(p_data date, p_titulo text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  novo_id uuid;
begin
  insert into rotina_tarefas (data, titulo)
  values (p_data, p_titulo)
  returning id into novo_id;
  return novo_id;
end;
$$;

grant execute on function public.rotina_adicionar_tarefa(date, text) to authenticated;

create or replace function public.rotina_marcar_tarefa(p_id uuid, p_concluida boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update rotina_tarefas set concluida = p_concluida where id = p_id;
end;
$$;

grant execute on function public.rotina_marcar_tarefa(uuid, boolean) to authenticated;

create or replace function public.rotina_remover_tarefa(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from rotina_tarefas where id = p_id;
end;
$$;

grant execute on function public.rotina_remover_tarefa(uuid) to authenticated;
-- =========================================================================
