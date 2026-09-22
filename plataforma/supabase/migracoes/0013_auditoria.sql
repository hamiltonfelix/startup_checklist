-- 0013 · Trilha de auditoria
-- Dono: engenheiro de operação. Um gatilho genérico, pendurável em qualquer
-- tabela sem ser reescrito. Guarda só a coluna que mudou, e nunca o conteúdo de
-- coluna confidencial. Ninguém atualiza nem arquiva linha desta trilha.

create type valor.operacao_auditada as enum ('insercao', 'atualizacao', 'arquivamento');
comment on type valor.operacao_auditada is
  'Rótulos de tela: Inserção, Atualização, Arquivamento. Não existe remoção, porque nada é apagado.';

create table valor.auditoria (
  id           uuid primary key default gen_random_uuid(),
  inquilino_id uuid references valor.inquilinos(id) on delete restrict,
  esquema      text not null default 'valor',
  tabela       text not null,
  chave        uuid not null,
  operacao     valor.operacao_auditada not null,
  mudancas     jsonb not null default '{}',
  usuario_id   uuid,
  perfil       text,
  momento      timestamptz not null default clock_timestamp(),
  origem       text
);
comment on table valor.auditoria is
  'A trilha imutável. É a única tabela fora do padrão da seção 7 do contrato técnico, e de propósito: trilha imutável não tem atualizado_em nem arquivado_em, porque ninguém atualiza nem arquiva linha de auditoria.';
comment on column valor.auditoria.mudancas is
  'Só as colunas que mudaram, cada uma com antes e depois. Coluna confidencial entra com marca de omissão no lugar do valor.';
comment on column valor.auditoria.usuario_id is
  'Sem chave estrangeira de propósito: a trilha precisa sobreviver a qualquer estado do cadastro de usuários e nunca pode recusar uma gravação.';
comment on column valor.auditoria.momento is
  'O instante real da mudança, pelo relógio, e não o início da transação. É o que mantém a ordem certa quando várias mudanças cabem na mesma transação.';
comment on column valor.auditoria.origem is
  'De onde veio a chamada: o parâmetro de sessão app.origem, ou o nome da aplicação conectada.';

create index on valor.auditoria (inquilino_id, tabela, chave, momento desc);
create index on valor.auditoria (inquilino_id, momento desc);
create index on valor.auditoria (usuario_id, momento desc);

-- ------------------------------------------------ leitura do próprio catálogo

-- A coluna da chave primária, para o gatilho servir qualquer tabela sem saber
-- o nome dela de antemão.
create or replace function valor.coluna_chave(p_relacao oid)
returns text language sql stable as $$
  select a.attname::text
    from pg_index i
    join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any (i.indkey)
   where i.indrelid = p_relacao
     and i.indisprimary
     and i.indnatts = 1
   limit 1;
$$;
comment on function valor.coluna_chave(oid) is
  'Devolve a coluna da chave primária simples da tabela. Nulo quando a chave é composta.';

-- As colunas confidenciais saem do próprio banco: são as que têm
-- comment on column começando pela palavra CONFIDENCIAL, como manda a seção 7
-- do contrato técnico. Marcar a coluna já basta para ela nunca vazar na trilha.
create or replace function valor.colunas_confidenciais(p_relacao oid)
returns text[] language sql stable as $$
  select coalesce(array_agg(a.attname::text order by a.attname), array[]::text[])
    from pg_attribute a
   where a.attrelid = p_relacao
     and a.attnum > 0
     and not a.attisdropped
     and upper(btrim(coalesce(col_description(a.attrelid, a.attnum), ''))) like 'CONFIDENCIAL%';
$$;
comment on function valor.colunas_confidenciais(oid) is
  'Lista as colunas cuja descrição começa com a palavra CONFIDENCIAL. É a fonte da máscara da trilha.';

-- ------------------------------------------------------------ o gatilho único

create or replace function valor.auditar() returns trigger
language plpgsql security definer set search_path = valor, pg_catalog, public as $funcao$
declare
  -- Carimbo de atualização não entra no diff: a própria linha da trilha já
  -- guarda o momento e o usuário, então repetir viraria ruído.
  c_ignoradas     constant text[] := array['atualizado_em', 'atualizado_por'];
  c_omitido       constant jsonb  := to_jsonb('[omitido]'::text);
  v_confidenciais text[];
  v_chave_coluna  text;
  v_antes         jsonb;
  v_depois        jsonb;
  v_mudancas      jsonb := '{}'::jsonb;
  v_operacao      valor.operacao_auditada;
  v_coluna        text;
  v_valor_depois  jsonb;
  v_valor_antes   jsonb;
begin
  if tg_op = 'DELETE' then
    raise exception
      'Nesta plataforma nada é apagado. Preencha arquivado_em em vez de remover a linha de %.%.',
      tg_table_schema, tg_table_name
      using errcode = 'restrict_violation';
  end if;

  v_chave_coluna  := valor.coluna_chave(tg_relid);
  v_confidenciais := valor.colunas_confidenciais(tg_relid);

  if tg_op = 'INSERT' then
    v_operacao := 'insercao';
    v_antes    := '{}'::jsonb;
    v_depois   := to_jsonb(new);
  else
    v_antes  := to_jsonb(old);
    v_depois := to_jsonb(new);
    if (v_antes ->> 'arquivado_em') is null and (v_depois ->> 'arquivado_em') is not null then
      v_operacao := 'arquivamento';
    else
      v_operacao := 'atualizacao';
    end if;
  end if;

  for v_coluna, v_valor_depois in select e.key, e.value from jsonb_each(v_depois) e
  loop
    if v_coluna = any (c_ignoradas) then
      continue;
    end if;

    v_valor_antes := v_antes -> v_coluna;

    if tg_op = 'INSERT' then
      if v_valor_depois is null or jsonb_typeof(v_valor_depois) = 'null' then
        continue;
      end if;
    elsif v_valor_antes is not distinct from v_valor_depois then
      continue;
    end if;

    if v_coluna = any (v_confidenciais) then
      v_mudancas := v_mudancas || jsonb_build_object(
        v_coluna, jsonb_build_object('antes', c_omitido, 'depois', c_omitido, 'confidencial', true));
    else
      v_mudancas := v_mudancas || jsonb_build_object(
        v_coluna, jsonb_build_object('antes', v_valor_antes, 'depois', v_valor_depois));
    end if;
  end loop;

  if tg_op = 'UPDATE' and v_mudancas = '{}'::jsonb then
    return null;
  end if;

  insert into valor.auditoria
    (inquilino_id, esquema, tabela, chave, operacao, mudancas, usuario_id, perfil, origem)
  values (
    nullif(v_depois ->> 'inquilino_id', '')::uuid,
    tg_table_schema,
    tg_table_name,
    (v_depois ->> v_chave_coluna)::uuid,
    v_operacao,
    v_mudancas,
    valor.usuario_atual(),
    valor.perfil_atual(),
    coalesce(valor.claim('origem'), nullif(current_setting('application_name', true), ''), 'desconhecida')
  );

  return null;
end;
$funcao$;
comment on function valor.auditar() is
  'Gatilho genérico de auditoria. Serve qualquer tabela de chave uuid simples, sem uma linha de código por tabela.';

-- ----------------------------------------------------- a trilha é imutável

create or replace function valor.auditoria_imutavel() returns trigger
language plpgsql as $$
begin
  raise exception
    'A trilha de auditoria é imutável. Ninguém atualiza, arquiva nem remove linha de valor.auditoria.'
    using errcode = 'restrict_violation';
  return null;
end;
$$;

create trigger auditoria_sem_alteracao
  before update or delete on valor.auditoria
  for each row execute function valor.auditoria_imutavel();

create trigger auditoria_sem_esvaziar
  before truncate on valor.auditoria
  for each statement execute function valor.auditoria_imutavel();

-- ------------------------------------------------- pendurar em uma tabela

create or replace function valor.pendurar_auditoria(p_esquema text, p_tabela text)
returns void language plpgsql as $funcao$
declare
  v_relacao oid;
  v_chave   text;
  v_tipo    text;
begin
  v_relacao := to_regclass(quote_ident(p_esquema) || '.' || quote_ident(p_tabela));
  if v_relacao is null then
    raise exception 'A tabela %.% não existe, então a auditoria não pode ser pendurada nela.',
      p_esquema, p_tabela;
  end if;

  v_chave := valor.coluna_chave(v_relacao);
  if v_chave is null then
    raise exception 'A tabela %.% não tem chave primária de coluna única, e a trilha precisa de uma.',
      p_esquema, p_tabela;
  end if;

  select format_type(a.atttypid, null) into v_tipo
    from pg_attribute a
   where a.attrelid = v_relacao and a.attname = v_chave;
  if v_tipo <> 'uuid' then
    raise exception 'A chave primária de %.% é do tipo %, e a trilha guarda chave uuid.',
      p_esquema, p_tabela, v_tipo;
  end if;

  execute format('drop trigger if exists auditoria_registro on %I.%I', p_esquema, p_tabela);
  execute format(
    'create trigger auditoria_registro after insert or update on %I.%I
       for each row execute function valor.auditar()', p_esquema, p_tabela);

  execute format('drop trigger if exists auditoria_sem_apagar on %I.%I', p_esquema, p_tabela);
  execute format(
    'create trigger auditoria_sem_apagar before delete on %I.%I
       for each row execute function valor.auditar()', p_esquema, p_tabela);
end;
$funcao$;
comment on function valor.pendurar_auditoria(text, text) is
  'Pendura a trilha numa tabela: um gatilho que registra inserção e atualização, e outro que barra a remoção.';

set client_min_messages = warning;
do $$
begin
  perform valor.pendurar_auditoria('valor', 'negocios');
  perform valor.pendurar_auditoria('valor', 'artefatos');
  perform valor.pendurar_auditoria('valor', 'contas');
  perform valor.pendurar_auditoria('valor', 'usuarios');
end;
$$;
reset client_min_messages;

-- ------------------------------------------------------------- segurança

alter table valor.auditoria enable row level security;

-- Quem lê a trilha inteira do inquilino é o administrador. O restante do time
-- da casa enxerga apenas a própria pegada, e nada mais. Gente de fora não
-- alcança a trilha de jeito nenhum, nem o parceiro nem o participante, porque a
-- pegada revela o que a casa fez com o dado do cliente.
-- Não existe política de escrita: a única porta de entrada é o gatilho
-- valor.auditar, que roda como dono da tabela. E os gatilhos de imutabilidade
-- barram atualização, remoção e esvaziamento até para quem é dono.
create policy auditoria_le_admin on valor.auditoria for select
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy auditoria_le_propria_pegada on valor.auditoria for select
  using (valor.do_inquilino(inquilino_id)
         and valor.time_da_casa()
         and usuario_id is not null
         and usuario_id = valor.usuario_atual());
