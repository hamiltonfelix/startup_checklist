-- 0090 · Papéis de banco e permissões
-- Dono: orquestrador. Roda por último, depois que todas as tabelas existem.
--
-- Por que este arquivo existe: o dono de uma tabela no PostgreSQL ignora a
-- segurança de linha por padrão. Um teste feito com o dono aprova qualquer
-- política, inclusive uma política quebrada. Aqui nasce o papel sem privilégio
-- que o aplicativo usa de verdade, e é com ele que a segurança é provada.
--
-- No Supabase, o papel equivalente é `authenticated`. As concessões abaixo
-- usam `valor_aplicacao` no ambiente local e `authenticated` quando ele existir.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'valor_aplicacao') then
    create role valor_aplicacao nologin;
  end if;
end $$;

grant usage on schema valor to valor_aplicacao;
grant select, insert, update on all tables in schema valor to valor_aplicacao;
grant execute on all functions in schema valor to valor_aplicacao;
alter default privileges in schema valor
  grant select, insert, update on tables to valor_aplicacao;

-- Ninguém apaga linha. Arquivar é carimbar a data em arquivado_em.
revoke delete on all tables in schema valor from valor_aplicacao;

-- A trilha de auditoria não se reescreve.
revoke update on valor.auditoria from valor_aplicacao;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    execute 'grant usage on schema valor to authenticated';
    execute 'grant select, insert, update on all tables in schema valor to authenticated';
    execute 'grant execute on all functions in schema valor to authenticated';
    execute 'revoke delete on all tables in schema valor from authenticated';
  end if;
end $$;
