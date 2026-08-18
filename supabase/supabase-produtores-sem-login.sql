-- ============================================================
-- Produtores SEM login proprio, guardados pelo administrador
-- Rodar em: Supabase > SQL Editor > New query > cola > Run
-- ============================================================
-- Aqui ficam os produtores que nao tem conta: quem manda para o
-- servidor e o aparelho do administrador. Assim o painel dele fica
-- igual em todos os aparelhos, sem obrigar ninguem a criar login.

create table if not exists public.produtores_livres (
  id            uuid primary key,
  admin_id      uuid not null references public.perfis(id) on delete cascade,
  nome          text not null,
  usuario       text,
  fazenda       text,
  dados         jsonb not null default '{}'::jsonb,
  recebido      date,
  atualizado_em timestamptz not null default now()
);

create index if not exists produtores_livres_admin on public.produtores_livres (admin_id);

alter table public.produtores_livres enable row level security;

-- so o dono da lista enxerga e mexe
drop policy if exists produtores_livres_tudo on public.produtores_livres;
create policy produtores_livres_tudo on public.produtores_livres for all
  using (admin_id = auth.uid())
  with check (admin_id = auth.uid());

drop trigger if exists hora_produtores_livres on public.produtores_livres;
create trigger hora_produtores_livres before insert or update on public.produtores_livres
  for each row execute function public.marcar_hora();
