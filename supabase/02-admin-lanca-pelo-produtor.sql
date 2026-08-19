-- ============================================================
-- O administrador passa a poder LANCAR e CORRIGIR pelo produtor
-- Rodar em: Supabase > SQL Editor > New query > cola > Run
-- ============================================================
-- Antes: o administrador enxergava a producao dos produtores dele, mas
-- gravar era proibido. Toda tentativa voltava com
--   42501 - new row violates row-level security policy
-- porque a regra de escrita (with check) exigia que a linha fosse do
-- proprio usuario logado:
--
--   with check (produtor_id = auth.uid())
--
-- Agora a escrita aceita tambem o administrador dono daquele produtor,
-- usando a mesma funcao que ja valia para a leitura. O produtor continua
-- so alcancando as proprias linhas: eh_meu_produtor() responde pelo
-- admin_id, e produtor nao e admin de ninguem.
--
-- Seguro rodar mais de uma vez: cada politica e apagada e recriada.
-- ============================================================

-- producao do dia
drop policy if exists registros_tudo on public.registros;
create policy registros_tudo on public.registros for all
  using      (produtor_id = auth.uid() or public.eh_meu_produtor(produtor_id))
  with check (produtor_id = auth.uid() or public.eh_meu_produtor(produtor_id));

-- compras de racao
drop policy if exists gastos_tudo on public.gastos;
create policy gastos_tudo on public.gastos for all
  using      (produtor_id = auth.uid() or public.eh_meu_produtor(produtor_id))
  with check (produtor_id = auth.uid() or public.eh_meu_produtor(produtor_id));

-- preco do litro, meta e nome da propriedade
drop policy if exists ajustes_tudo on public.ajustes;
create policy ajustes_tudo on public.ajustes for all
  using      (produtor_id = auth.uid() or public.eh_meu_produtor(produtor_id))
  with check (produtor_id = auth.uid() or public.eh_meu_produtor(produtor_id));

-- ------------------------------------------------------------
-- Conferencia rapida depois de rodar (opcional):
--   select tablename, policyname, with_check
--     from pg_policies
--    where schemaname = 'public'
--      and tablename in ('registros','gastos','ajustes');
-- O with_check das tres deve citar eh_meu_produtor.
-- ------------------------------------------------------------
