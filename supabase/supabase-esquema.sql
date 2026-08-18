-- ============================================================
-- Controle de producao de leite - estrutura do banco (Supabase)
-- Rodar uma vez em: Supabase > SQL Editor > New query > Run
-- ============================================================

-- ---------- tabelas ----------

-- uma linha por pessoa que entra no sistema
create table if not exists public.perfis (
  id         uuid primary key references auth.users(id) on delete cascade,
  nome       text not null,
  usuario    text not null unique,
  papel      text not null check (papel in ('admin', 'produtor')),
  admin_id   uuid references public.perfis(id) on delete set null,
  fazenda    text,
  criado_em  timestamptz not null default now()
);

-- producao do dia: uma linha por produtor por data
create table if not exists public.registros (
  produtor_id   uuid not null references public.perfis(id) on delete cascade,
  data          date not null,
  litros        numeric not null check (litros >= 0),
  vacas         integer check (vacas >= 0),
  obs           text,
  atualizado_em timestamptz not null default now(),
  primary key (produtor_id, data)
);

-- compras de racao
create table if not exists public.gastos (
  id            uuid primary key default gen_random_uuid(),
  produtor_id   uuid not null references public.perfis(id) on delete cascade,
  data          date not null,
  valor         numeric not null check (valor >= 0),
  kg            numeric check (kg >= 0),
  descricao     text,
  atualizado_em timestamptz not null default now()
);

-- nome da propriedade, preco do litro, meta e precos por quinzena
create table if not exists public.ajustes (
  produtor_id   uuid primary key references public.perfis(id) on delete cascade,
  fazenda       text,
  preco         numeric,
  meta          numeric,
  precos        jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now()
);

create index if not exists registros_produtor_data on public.registros (produtor_id, data desc);
create index if not exists gastos_produtor_data    on public.gastos    (produtor_id, data desc);
create index if not exists perfis_admin            on public.perfis    (admin_id);

-- ---------- quem pode ver o que ----------
-- Sem isto, a chave publica do site daria acesso a tudo.
-- Cada produtor so alcanca as proprias linhas; o administrador
-- alcanca as linhas dos produtores que sao dele.

alter table public.perfis    enable row level security;
alter table public.registros enable row level security;
alter table public.gastos    enable row level security;
alter table public.ajustes   enable row level security;

-- funcao auxiliar: este produtor e meu?
-- security definer evita que a propria politica de perfis se chame em loop
create or replace function public.eh_meu_produtor(p uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.perfis
    where id = p and admin_id = auth.uid()
  );
$$;

-- perfis
drop policy if exists perfis_ver on public.perfis;
create policy perfis_ver on public.perfis for select
  using (id = auth.uid() or admin_id = auth.uid());

drop policy if exists perfis_criar on public.perfis;
create policy perfis_criar on public.perfis for insert
  with check (id = auth.uid());

drop policy if exists perfis_mudar on public.perfis;
create policy perfis_mudar on public.perfis for update
  using (id = auth.uid() or admin_id = auth.uid())
  with check (id = auth.uid() or admin_id = auth.uid());

-- registros, gastos e ajustes seguem a mesma regra
drop policy if exists registros_tudo on public.registros;
create policy registros_tudo on public.registros for all
  using (produtor_id = auth.uid() or public.eh_meu_produtor(produtor_id))
  with check (produtor_id = auth.uid());

drop policy if exists gastos_tudo on public.gastos;
create policy gastos_tudo on public.gastos for all
  using (produtor_id = auth.uid() or public.eh_meu_produtor(produtor_id))
  with check (produtor_id = auth.uid());

drop policy if exists ajustes_tudo on public.ajustes;
create policy ajustes_tudo on public.ajustes for all
  using (produtor_id = auth.uid() or public.eh_meu_produtor(produtor_id))
  with check (produtor_id = auth.uid());

-- ---------- carimbo de hora ----------
-- usado para decidir quem venceu quando o mesmo dia for lancado
-- em dois aparelhos: vale o mais recente

create or replace function public.marcar_hora()
returns trigger language plpgsql as $$
begin
  new.atualizado_em = now();
  return new;
end;
$$;

drop trigger if exists hora_registros on public.registros;
create trigger hora_registros before insert or update on public.registros
  for each row execute function public.marcar_hora();

drop trigger if exists hora_gastos on public.gastos;
create trigger hora_gastos before insert or update on public.gastos
  for each row execute function public.marcar_hora();

drop trigger if exists hora_ajustes on public.ajustes;
create trigger hora_ajustes before insert or update on public.ajustes
  for each row execute function public.marcar_hora();
