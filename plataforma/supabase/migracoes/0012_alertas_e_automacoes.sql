-- 0012 · Alertas e automações
-- Dono: engenheiro de operação. É o que faz a plataforma cobrar sozinha.
-- Todo prazo desta migração mora em valor.configuracoes e é trocado em tela.
-- Nada é apagado: alerta resolvido é carimbado, nunca removido.

-- --------------------------------------------------------------------- tipos

create type valor.canal_alerta as enum ('painel', 'email', 'whatsapp', 'push');
comment on type valor.canal_alerta is 'Por onde o alerta chega. Rótulos de tela: Painel, E-mail, WhatsApp, Notificação.';

create type valor.status_alerta as enum ('aberto', 'reconhecido', 'resolvido', 'silenciado');
comment on type valor.status_alerta is 'Rótulos de tela: Aberto, Reconhecido, Resolvido, Silenciado.';

create type valor.tipo_condicao_alerta as enum ('sql', 'jsonb');

create type valor.gatilho_automacao as enum ('agendado', 'evento', 'manual');

create type valor.resultado_execucao as enum ('sucesso', 'erro', 'ignorada');

-- --------------------------------------------------- leitura das invariantes

create or replace function valor.artefato_exigido_na_fase(p_fase smallint)
returns valor.tipo_artefato language sql immutable as $$
  select case p_fase
    when 1 then 'plano_conta'::valor.tipo_artefato
    when 2 then 'plano_negocio'::valor.tipo_artefato
    when 3 then 'plano_trabalho'::valor.tipo_artefato
    when 4 then 'contrato_valor'::valor.tipo_artefato
  end;
$$;
comment on function valor.artefato_exigido_na_fase(smallint) is
  'O artefato que comprova cada fase do método, conforme a seção 4 do contrato técnico.';

-- As quatro invariantes de higiene da seção 6 do contrato técnico, lidas linha a
-- linha. A janela de dias sem interação vem de valor.configuracoes.
create or replace function valor.negocios_fora_da_higiene(p_inquilino uuid default null)
returns table (
  inquilino_id          uuid,
  negocio_id            uuid,
  titulo                text,
  fase                  smallint,
  tem_proximo_passo     boolean,
  decisao_no_futuro     boolean,
  interacao_recente     boolean,
  tem_artefato_da_fase  boolean,
  invariantes_quebradas text[]
)
language sql stable as $$
  with leitura as (
    select
      n.inquilino_id,
      n.id as negocio_id,
      n.titulo,
      n.fase,
      (n.proximo_passo is not null
        and n.proximo_passo_data is not null
        and n.proximo_passo_data >= current_date) as tem_proximo_passo,
      (n.data_decisao_cliente is not null
        and n.data_decisao_cliente >= current_date) as decisao_no_futuro,
      (coalesce(n.ultima_interacao, n.criado_em::date)
        >= current_date
           - valor.configuracao_num(n.inquilino_id, 'higiene.dias_sem_interacao', 30)::integer) as interacao_recente,
      exists (
        select 1 from valor.artefatos a
         where a.negocio_id = n.id
           and a.tipo = valor.artefato_exigido_na_fase(n.fase)
           and a.arquivado_em is null
      ) as tem_artefato_da_fase
    from valor.negocios n
   where n.arquivado_em is null
     and n.desfecho is null
     and n.fase between 1 and 4
     and (p_inquilino is null or n.inquilino_id = p_inquilino)
  )
  select l.inquilino_id, l.negocio_id, l.titulo, l.fase,
         l.tem_proximo_passo, l.decisao_no_futuro, l.interacao_recente, l.tem_artefato_da_fase,
         array_remove(array[
           case when not l.tem_proximo_passo    then 'Próximo passo com data definida' end,
           case when not l.decisao_no_futuro    then 'Data da decisão do cliente no futuro' end,
           case when not l.interacao_recente    then 'Interação dentro da janela de higiene' end,
           case when not l.tem_artefato_da_fase then 'Artefato da fase atual registrado' end
         ], null)
    from leitura l
   where not (l.tem_proximo_passo and l.decisao_no_futuro
              and l.interacao_recente and l.tem_artefato_da_fase);
$$;
comment on function valor.negocios_fora_da_higiene(uuid) is
  'Lista os negócios ativos das fases 1 a 4 que quebram pelo menos uma das quatro invariantes de higiene.';

-- Limite de dias parado por fase. Enquanto não houver mediana histórica com
-- amostra suficiente, vale o piso configurado. Havendo, vale o fator vezes a
-- mediana. A mediana sai de valor.historico_fases, que outra migração entrega.
create or replace function valor.limite_dias_parado(p_inquilino uuid, p_fase smallint)
returns integer language plpgsql stable as $$
declare
  v_piso    integer := valor.configuracao_num(p_inquilino, 'alerta.negocio_parado_dias_piso', 30)::integer;
  v_fator   numeric := valor.configuracao_num(p_inquilino, 'alerta.negocio_parado_fator_mediana', 2);
  v_amostra integer := valor.configuracao_num(p_inquilino, 'alerta.negocio_parado_amostra_minima', 5)::integer;
  v_n       integer;
  v_mediana numeric;
begin
  if to_regclass('valor.historico_fases') is null then
    return v_piso;
  end if;
  execute
    'select count(*)::integer,
            percentile_cont(0.5) within group (order by (h.saiu_em - h.entrou_em))
       from valor.historico_fases h
      where h.inquilino_id = $1 and h.fase = $2 and h.saiu_em is not null'
    into v_n, v_mediana
    using p_inquilino, p_fase;
  if v_n is null or v_n < v_amostra or v_mediana is null then
    return v_piso;
  end if;
  return greatest(1, ceil(v_mediana * v_fator)::integer);
end;
$$;
comment on function valor.limite_dias_parado(uuid, smallint) is
  'Piso de 30 dias por padrão, substituído por duas vezes a mediana histórica da fase quando houver amostra.';

-- ------------------------------------------------------------ regras e alertas

create table valor.regras_alerta (
  id                  uuid primary key default gen_random_uuid(),
  inquilino_id        uuid not null references valor.inquilinos(id) on delete restrict,
  codigo              text not null,
  nome                text not null,
  descricao           text,
  entidade_alvo       text not null,
  tipo_condicao       valor.tipo_condicao_alerta not null default 'sql',
  condicao_sql        text,
  condicao_jsonb      jsonb,
  tabelas_requeridas  text[],
  criticidade         valor.criticidade not null default 'amarelo',
  canal               valor.canal_alerta not null default 'painel',
  destinatario_perfil valor.perfil_usuario,
  destinatario_papel  valor.papel_negocio,
  ativa               boolean not null default true,
  configuravel        boolean not null default true,
  ordem               integer not null default 100,
  criado_em           timestamptz not null default now(),
  criado_por          uuid,
  atualizado_em       timestamptz,
  atualizado_por      uuid,
  arquivado_em        timestamptz,
  unique (inquilino_id, codigo),
  constraint condicao_presente check (
    (tipo_condicao = 'sql'   and condicao_sql is not null and condicao_jsonb is null)
    or (tipo_condicao = 'jsonb' and condicao_jsonb is not null and condicao_sql is null)
  ),
  constraint condicao_sql_recebe_inquilino check (
    condicao_sql is null or condicao_sql like '%$1%'
  )
);
comment on table valor.regras_alerta is
  'O catálogo de regras que a casa decidiu. Cada linha é configurável em tela, inclusive a condição.';
comment on column valor.regras_alerta.condicao_sql is
  'Consulta que devolve inquilino_id, entidade_chave, mensagem, criticidade e detalhe. Recebe o inquilino em $1.';
comment on column valor.regras_alerta.condicao_jsonb is
  'Alternativa declarativa para quem monta regra na tela: tabela, chave, mensagem, criticidade e filtros.';
comment on column valor.regras_alerta.tabelas_requeridas is
  'Tabelas que a condição precisa. Faltando alguma, a regra é adiada e a rodada registra o motivo, sem erro.';
comment on column valor.regras_alerta.destinatario_perfil is
  'Perfil que recebe. Quando nulo, vale o papel no negócio. Quando os dois são nulos, o alerta fica no painel da casa.';

create table valor.alertas (
  id             uuid primary key default gen_random_uuid(),
  inquilino_id   uuid not null references valor.inquilinos(id) on delete restrict,
  regra_id       uuid not null references valor.regras_alerta(id) on delete restrict,
  entidade       text not null,
  entidade_chave uuid not null,
  criticidade    valor.criticidade not null default 'amarelo',
  mensagem       text not null,
  detalhe        jsonb not null default '{}',
  disparado_em   timestamptz not null default now(),
  status         valor.status_alerta not null default 'aberto',
  destinatario_id uuid references valor.usuarios(id),
  reconhecido_por uuid references valor.usuarios(id),
  reconhecido_em timestamptz,
  resolvido_por  uuid references valor.usuarios(id),
  resolvido_em   timestamptz,
  nota_resolucao text,
  silenciado_por uuid references valor.usuarios(id),
  silenciado_ate date,
  criado_em      timestamptz not null default now(),
  criado_por     uuid,
  atualizado_em  timestamptz,
  atualizado_por uuid,
  arquivado_em   timestamptz
);
comment on table valor.alertas is
  'A instância disparada de uma regra. Resolver é carimbar status e data, jamais remover a linha.';
comment on column valor.alertas.entidade_chave is
  'O identificador da linha que provocou o alerta, na tabela nomeada em entidade.';

-- É esta restrição que torna valor.avaliar_alertas idempotente: enquanto houver
-- alerta aberto da mesma regra para a mesma entidade, não nasce outro.
create unique index alertas_um_aberto_por_entidade
  on valor.alertas (inquilino_id, regra_id, entidade_chave)
  where status = 'aberto' and arquivado_em is null;

create index on valor.alertas (inquilino_id, status, criticidade) where arquivado_em is null;
create index on valor.alertas (inquilino_id, entidade, entidade_chave);
create index on valor.alertas (destinatario_id, status) where arquivado_em is null;

-- ------------------------------------------------------------- automações

create table valor.automacoes (
  id                 uuid primary key default gen_random_uuid(),
  inquilino_id       uuid not null references valor.inquilinos(id) on delete restrict,
  codigo             text not null,
  nome               text not null,
  descricao          text,
  gatilho            valor.gatilho_automacao not null default 'agendado',
  gatilho_detalhe    text,
  acao               text not null,
  parametros         jsonb not null default '{}',
  tabelas_requeridas text[],
  ativa              boolean not null default true,
  ultima_execucao_em timestamptz,
  ultimo_resultado   valor.resultado_execucao,
  criado_em          timestamptz not null default now(),
  criado_por         uuid,
  atualizado_em      timestamptz,
  atualizado_por     uuid,
  arquivado_em       timestamptz,
  unique (inquilino_id, codigo)
);
comment on table valor.automacoes is
  'O que o sistema faz sozinho. A ação é um nome conhecido, despachado por lista fechada, nunca um texto executado às cegas.';
comment on column valor.automacoes.gatilho_detalhe is
  'Para gatilho agendado, a expressão de agenda no formato do pg_cron. Para gatilho por evento, o nome do evento.';

create table valor.execucoes_automacao (
  id                 uuid primary key default gen_random_uuid(),
  inquilino_id       uuid not null references valor.inquilinos(id) on delete restrict,
  automacao_id       uuid not null references valor.automacoes(id) on delete restrict,
  iniciada_em        timestamptz not null default now(),
  terminada_em       timestamptz,
  duracao_ms         integer,
  resultado          valor.resultado_execucao not null default 'sucesso',
  registros_afetados integer not null default 0,
  mensagem           text,
  erro               text,
  criado_em          timestamptz not null default now()
);
comment on table valor.execucoes_automacao is
  'O log de cada rodada. Fica para sempre: é dele que sai a prova de que a cobrança automática rodou.';

create index on valor.execucoes_automacao (automacao_id, iniciada_em desc);
create index on valor.execucoes_automacao (inquilino_id, resultado, iniciada_em desc);

create trigger carimbo before update on valor.regras_alerta for each row execute function valor.carimbar();
create trigger carimbo before update on valor.alertas       for each row execute function valor.carimbar();
create trigger carimbo before update on valor.automacoes    for each row execute function valor.carimbar();

-- ------------------------------------------- condição declarativa em jsonb

-- Traduz a condição declarativa montada na tela para consulta. Todo nome de
-- coluna passa por quote_ident e todo valor por quote_literal, então a tela não
-- vira porta de entrada de injeção.
create or replace function valor.montar_sql_condicao(p_condicao jsonb)
returns text language plpgsql immutable as $funcao$
declare
  v_tabela      text;
  v_chave       text;
  v_mensagem    text;
  v_criticidade text;
  v_onde        text := '';
  v_pedaco      text;
  v_coluna      text;
  v_operador    text;
  f             jsonb;
begin
  if p_condicao is null or p_condicao ->> 'tabela' is null then
    raise exception 'Condição declarativa sem tabela alvo.';
  end if;

  v_tabela      := 'valor.' || quote_ident(p_condicao ->> 'tabela');
  v_chave       := quote_ident(coalesce(p_condicao ->> 'chave', 'id'));
  v_mensagem    := quote_literal(coalesce(p_condicao ->> 'mensagem', 'Condição de alerta atendida'));
  v_criticidade := quote_literal(coalesce(p_condicao ->> 'criticidade', 'amarelo'));

  for f in select * from jsonb_array_elements(coalesce(p_condicao -> 'filtros', '[]'::jsonb))
  loop
    v_coluna   := quote_ident(f ->> 'coluna');
    v_operador := f ->> 'operador';
    v_pedaco := case v_operador
      when 'nulo'       then v_coluna || ' is null'
      when 'nao_nulo'   then v_coluna || ' is not null'
      when 'verdadeiro' then v_coluna || ' is true'
      when 'falso'      then v_coluna || ' is not true'
      when 'igual'      then v_coluna || ' = ' || quote_literal(f ->> 'valor')
      when 'diferente'  then v_coluna || ' is distinct from ' || quote_literal(f ->> 'valor')
      when 'maior'      then v_coluna || ' > ' || quote_literal(f ->> 'valor')
      when 'menor'      then v_coluna || ' < ' || quote_literal(f ->> 'valor')
      when 'entre'      then v_coluna || ' between ' || quote_literal(f -> 'valor' ->> 0)
                             || ' and ' || quote_literal(f -> 'valor' ->> 1)
      when 'dias_atras' then v_coluna || ' <= current_date - ' || (f ->> 'valor')::integer
      else null
    end;
    if v_pedaco is null then
      raise exception 'Operador declarativo desconhecido na regra de alerta: %', coalesce(v_operador, 'nulo');
    end if;
    v_onde := v_onde || ' and ' || v_pedaco;
  end loop;

  return 'select f.inquilino_id, f.' || v_chave || ' as entidade_chave, '
      || v_mensagem || '::text as mensagem, '
      || v_criticidade || '::valor.criticidade as criticidade, '
      || quote_literal('{}') || '::jsonb as detalhe'
      || ' from ' || v_tabela || ' f'
      || ' where ($1::uuid is null or f.inquilino_id = $1::uuid)' || v_onde;
end;
$funcao$;
comment on function valor.montar_sql_condicao(jsonb) is
  'Traduz a condição declarativa da tela em consulta, com nome de coluna e valor sempre citados.';

-- -------------------------------------------------------- avaliar alertas

-- Varre as regras ativas e grava os alertas. Idempotente: rodar duas vezes no
-- mesmo dia não duplica alerta aberto da mesma entidade pela mesma regra, porque
-- o índice alertas_um_aberto_por_entidade converte a segunda tentativa em
-- atualização da criticidade e da mensagem. O alerta cuja condição deixou de
-- valer é carimbado como resolvido, nunca removido.
create or replace function valor.avaliar_alertas(p_inquilino uuid default null)
returns table (
  regra       text,
  criticidade valor.criticidade,
  novos       integer,
  ja_abertos  integer,
  resolvidos  integer,
  situacao    text
)
language plpgsql security definer set search_path = valor, pg_catalog, public as $funcao$
declare
  r        record;
  v_sql    text;
  v_base   text;
  v_falta  text;
  v_tabela text;
begin
  for r in
    select * from valor.regras_alerta
     where ativa and arquivado_em is null
       and (p_inquilino is null or inquilino_id = p_inquilino)
     order by ordem, codigo
  loop
    regra       := r.codigo;
    criticidade := r.criticidade;
    novos       := 0;
    ja_abertos  := 0;
    resolvidos  := 0;
    situacao    := 'avaliada';
    v_falta     := null;

    if r.tabelas_requeridas is not null then
      foreach v_tabela in array r.tabelas_requeridas loop
        if to_regclass(v_tabela) is null then
          v_falta := coalesce(v_falta || ', ', '') || v_tabela;
        end if;
      end loop;
    end if;

    if v_falta is not null then
      situacao := 'adiada, faltam as tabelas ' || v_falta;
      return next;
      continue;
    end if;

    begin
      v_sql := coalesce(r.condicao_sql, valor.montar_sql_condicao(r.condicao_jsonb));

      -- A deduplicação garante que a mesma entidade não seja tocada duas vezes
      -- na mesma instrução, e mantém a leitura mais grave quando houver empate.
      v_base := '(select distinct on (c0.inquilino_id, c0.entidade_chave) c0.*'
             || ' from (' || v_sql || ') c0'
             || ' order by c0.inquilino_id, c0.entidade_chave, c0.criticidade desc) c';

      execute format($modelo$
        with gravado as (
          insert into valor.alertas
            (inquilino_id, regra_id, entidade, entidade_chave, criticidade, mensagem, detalhe)
          select c.inquilino_id, %L::uuid, %L, c.entidade_chave,
                 coalesce(c.criticidade, %L::valor.criticidade),
                 c.mensagem,
                 coalesce(c.detalhe, '{}'::jsonb)
            from %s
          on conflict (inquilino_id, regra_id, entidade_chave)
             where status = 'aberto' and arquivado_em is null
          do update set criticidade = excluded.criticidade,
                        mensagem    = excluded.mensagem,
                        detalhe     = excluded.detalhe
          returning (xmax = 0) as inserido
        )
        select (count(*) filter (where inserido))::integer,
               (count(*) filter (where not inserido))::integer
          from gravado
      $modelo$, r.id, r.entidade_alvo, r.criticidade, v_base)
      using r.inquilino_id
      into novos, ja_abertos;

      execute format($modelo$
        update valor.alertas a
           set status = 'resolvido',
               resolvido_em = now(),
               nota_resolucao = coalesce(a.nota_resolucao, 'Condição da regra deixou de valer.')
         where a.regra_id = %L::uuid
           and a.status = 'aberto'
           and a.arquivado_em is null
           and not exists (
             select 1 from %s
              where c.inquilino_id = a.inquilino_id
                and c.entidade_chave = a.entidade_chave)
      $modelo$, r.id, v_base)
      using r.inquilino_id;
      get diagnostics resolvidos = row_count;

    exception when others then
      novos      := 0;
      ja_abertos := 0;
      resolvidos := 0;
      situacao   := 'erro na condição: ' || sqlerrm;
    end;

    return next;
  end loop;
end;
$funcao$;
comment on function valor.avaliar_alertas(uuid) is
  'Varre as regras ativas e grava os alertas. Idempotente por regra e por entidade. Nada é apagado.';

-- ------------------------------------------------- carimbos do ciclo do alerta

create or replace function valor.reconhecer_alerta(p_alerta uuid) returns void
language sql as $$
  update valor.alertas
     set status = 'reconhecido',
         reconhecido_por = valor.usuario_atual(),
         reconhecido_em = now()
   where id = p_alerta and status = 'aberto' and arquivado_em is null;
$$;

create or replace function valor.resolver_alerta(p_alerta uuid, p_nota text default null) returns void
language sql as $$
  update valor.alertas
     set status = 'resolvido',
         resolvido_por = valor.usuario_atual(),
         resolvido_em = now(),
         nota_resolucao = coalesce(p_nota, nota_resolucao)
   where id = p_alerta and status in ('aberto', 'reconhecido', 'silenciado') and arquivado_em is null;
$$;

create or replace function valor.silenciar_alerta(p_alerta uuid, p_ate date) returns void
language sql as $$
  update valor.alertas
     set status = 'silenciado',
         silenciado_por = valor.usuario_atual(),
         silenciado_ate = p_ate
   where id = p_alerta and status in ('aberto', 'reconhecido') and arquivado_em is null;
$$;

create or replace function valor.reabrir_alertas_silenciados(p_inquilino uuid default null)
returns integer language plpgsql as $$
declare v_afetados integer;
begin
  update valor.alertas
     set status = 'aberto', silenciado_ate = null, silenciado_por = null
   where status = 'silenciado'
     and silenciado_ate is not null
     and silenciado_ate < current_date
     and arquivado_em is null
     and (p_inquilino is null or inquilino_id = p_inquilino);
  get diagnostics v_afetados = row_count;
  return v_afetados;
end;
$$;

-- Cria o negócio de renovação na antecedência configurada. Depende de
-- valor.contratos, que nasce em outra migração. Enquanto a tabela não existir,
-- a função devolve zero e a rodada é registrada como ignorada.
create or replace function valor.criar_negocios_renovacao(p_inquilino uuid)
returns integer
language plpgsql security definer set search_path = valor, pg_catalog, public as $funcao$
declare
  v_dias     integer := valor.configuracao_num(p_inquilino, 'alerta.contrato_renovacao_dias', 90)::integer;
  v_criados  integer := 0;
begin
  if to_regclass('valor.contratos') is null then
    return 0;
  end if;
  execute $modelo$
    insert into valor.negocios
      (inquilino_id, conta_id, oferta_id, titulo, fase, origem, data_decisao_cliente, entrou_na_fase_em)
    select k.inquilino_id, k.conta_id, k.oferta_id,
           'Renovação do contrato da conta ' || ct.nome,
           7, 'base_instalada'::valor.origem_lead, k.fim, current_date
      from valor.contratos k
      join valor.contas ct on ct.id = k.conta_id
     where k.inquilino_id = $1
       and k.arquivado_em is null
       and k.fim is not null
       and k.fim between current_date and current_date + $2
       and not exists (
         select 1 from valor.negocios n
          where n.conta_id = k.conta_id
            and n.fase = 7
            and n.arquivado_em is null
            and n.desfecho is null)
  $modelo$ using p_inquilino, v_dias;
  get diagnostics v_criados = row_count;
  return v_criados;
end;
$funcao$;
comment on function valor.criar_negocios_renovacao(uuid) is
  'Abre o negócio de renovação na antecedência configurada, um por conta. Adiada enquanto valor.contratos não existir.';

-- ------------------------------------------------------ executar automações

create or replace function valor.executar_automacoes(p_inquilino uuid default null)
returns table (
  automacao text,
  resultado valor.resultado_execucao,
  afetados  integer,
  mensagem  text
)
language plpgsql security definer set search_path = valor, pg_catalog, public as $funcao$
declare
  a         record;
  v_inicio  timestamptz;
  v_falta   text;
  v_tabela  text;
  v_erro    text;
begin
  for a in
    select * from valor.automacoes
     where ativa and arquivado_em is null
       and (p_inquilino is null or inquilino_id = p_inquilino)
     order by codigo
  loop
    automacao := a.codigo;
    resultado := 'sucesso';
    afetados  := 0;
    mensagem  := null;
    v_erro    := null;
    v_falta   := null;
    v_inicio  := clock_timestamp();

    if a.tabelas_requeridas is not null then
      foreach v_tabela in array a.tabelas_requeridas loop
        if to_regclass(v_tabela) is null then
          v_falta := coalesce(v_falta || ', ', '') || v_tabela;
        end if;
      end loop;
    end if;

    if v_falta is not null then
      resultado := 'ignorada';
      mensagem  := 'adiada, faltam as tabelas ' || v_falta;
    else
      begin
        case a.acao
          when 'avaliar_alertas' then
            select coalesce(sum(v.novos), 0)::integer
              into afetados
              from valor.avaliar_alertas(a.inquilino_id) v;
            mensagem := 'alertas novos gravados';
          when 'reabrir_alertas_silenciados' then
            afetados := valor.reabrir_alertas_silenciados(a.inquilino_id);
            mensagem := 'alertas devolvidos ao estado aberto';
          when 'criar_negocios_renovacao' then
            afetados := valor.criar_negocios_renovacao(a.inquilino_id);
            mensagem := 'negócios de renovação abertos';
          else
            resultado := 'ignorada';
            mensagem  := 'ação desconhecida: ' || a.acao;
        end case;
      exception when others then
        resultado := 'erro';
        v_erro    := sqlerrm;
        mensagem  := 'falhou ao executar ' || a.acao;
      end;
    end if;

    insert into valor.execucoes_automacao
      (inquilino_id, automacao_id, iniciada_em, terminada_em, duracao_ms,
       resultado, registros_afetados, mensagem, erro)
    values
      (a.inquilino_id, a.id, v_inicio, clock_timestamp(),
       (extract(epoch from (clock_timestamp() - v_inicio)) * 1000)::integer,
       resultado, afetados, mensagem, v_erro);

    update valor.automacoes
       set ultima_execucao_em = clock_timestamp(), ultimo_resultado = resultado
     where id = a.id;

    return next;
  end loop;
end;
$funcao$;
comment on function valor.executar_automacoes(uuid) is
  'Roda as automações ativas e grava uma linha de log por rodada, com resultado e erro.';

-- ------------------------------------------------------------ agendamento

-- O agendamento de produção é do pg_cron do Supabase. A extensão não existe
-- neste contêiner, então a chamada fica comentada de propósito. Para ligar no
-- Supabase, rode o bloco abaixo uma vez, com o papel postgres, trocando as
-- expressões de agenda se a casa quiser outro horário.
--
--   create extension if not exists pg_cron;
--
--   select cron.schedule(
--     'valor_avaliar_alertas',
--     '0 6 * * *',
--     $agenda$ select valor.avaliar_alertas(); $agenda$);
--
--   select cron.schedule(
--     'valor_executar_automacoes',
--     '15 6 * * *',
--     $agenda$ select valor.executar_automacoes(); $agenda$);
--
-- Para desligar: select cron.unschedule('valor_avaliar_alertas');
-- A expressão de agenda de cada automação fica em valor.automacoes.gatilho_detalhe,
-- para a tela mostrar o que está agendado sem consultar o catálogo do pg_cron.

-- -------------------------------------------------- semente da configuração

create or replace function valor.semear_configuracoes_alerta(p_inquilino uuid)
returns void language plpgsql as $$
begin
  perform valor.gravar_configuracao(p_inquilino, 'alerta.lead_sem_dono_dias', to_jsonb(3),
    'Dias até alertar lead sem dono', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.negocio_parado_dias_piso', to_jsonb(30),
    'Piso de dias parado antes do alarme', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.negocio_parado_fator_mediana', to_jsonb(2),
    'Fator sobre a mediana histórica da fase', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.negocio_parado_amostra_minima', to_jsonb(5),
    'Amostra mínima para confiar na mediana da fase', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.plano_trabalho_aviso_amarelo_dias', to_jsonb(7),
    'Primeiro aviso de Plano de Trabalho vencendo, em dias', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.plano_trabalho_aviso_vermelho_dias', to_jsonb(1),
    'Último aviso de Plano de Trabalho vencendo, em dias', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.contrato_renovacao_dias', to_jsonb(90),
    'Antecedência para abrir o negócio de renovação, em dias', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.contrato_aviso_amarelo_dias', to_jsonb(60),
    'Primeiro aviso de contrato vencendo, em dias', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.contrato_aviso_vermelho_dias', to_jsonb(30),
    'Último aviso de contrato vencendo, em dias', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.ata_nao_enviada_horas', to_jsonb(24),
    'Horas até alertar ata não enviada', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'alerta.concentracao_limite', to_jsonb(0.5),
    'Limite de concentração dos dois maiores negócios no pipeline', 'alertas');
  perform valor.gravar_configuracao(p_inquilino, 'higiene.dias_sem_interacao', to_jsonb(30),
    'Dias sem interação que quebram a invariante de higiene', 'higiene');
end;
$$;

-- ------------------------------------------------------- semente das regras

create or replace function valor.semear_regras_alerta(p_inquilino uuid)
returns void language plpgsql as $funcao$
begin
  perform valor.semear_configuracoes_alerta(p_inquilino);

  insert into valor.regras_alerta
    (inquilino_id, codigo, nome, descricao, entidade_alvo, tipo_condicao, condicao_sql,
     tabelas_requeridas, criticidade, canal, destinatario_perfil, ordem)
  values
  (p_inquilino, 'lead_sem_dono',
   'Lead sem dono',
   'Lead parado sem Gerente de Contas além do prazo configurado.',
   'negocios', 'sql', $sql$
    select n.inquilino_id,
           n.id as entidade_chave,
           'Lead sem dono há ' || (current_date - n.criado_em::date) || ' dias: ' || n.titulo as mensagem,
           'amarelo'::valor.criticidade as criticidade,
           jsonb_build_object(
             'dias_sem_dono', (current_date - n.criado_em::date),
             'limite_dias', d.dias) as detalhe
      from valor.negocios n
      join valor.contas ct on ct.id = n.conta_id
      cross join lateral (
        select valor.configuracao_num(n.inquilino_id, 'alerta.lead_sem_dono_dias', 3)::integer as dias
      ) d
     where n.arquivado_em is null
       and n.desfecho is null
       and n.fase = 0
       and ct.gerente_contas_id is null
       and not exists (
         select 1 from valor.papeis_negocio p
          where p.negocio_id = n.id
            and p.ativo
            and p.arquivado_em is null
            and p.papel = 'gerente_contas')
       and n.criado_em::date <= current_date - d.dias
       and ($1::uuid is null or n.inquilino_id = $1::uuid)
   $sql$, null, 'amarelo', 'painel', 'lider', 10),

  (p_inquilino, 'negocio_parado',
   'Negócio parado',
   'Negócio sem interação acima do piso configurado, ou acima do fator sobre a mediana histórica da fase.',
   'negocios', 'sql', $sql$
    select n.inquilino_id,
           n.id as entidade_chave,
           'Negócio parado há ' || p.dias_parado || ' dias, acima do limite de '
             || p.limite || ' dias: ' || n.titulo as mensagem,
           'vermelho'::valor.criticidade as criticidade,
           jsonb_build_object(
             'dias_parado', p.dias_parado,
             'limite_dias', p.limite,
             'fase', n.fase,
             'ultima_interacao', n.ultima_interacao) as detalhe
      from valor.negocios n
      cross join lateral (
        select (current_date - coalesce(n.ultima_interacao, n.entrou_na_fase_em, n.criado_em::date)) as dias_parado,
               valor.limite_dias_parado(n.inquilino_id, n.fase) as limite
      ) p
     where n.arquivado_em is null
       and n.desfecho is null
       and n.fase between 1 and 7
       and p.dias_parado > p.limite
       and ($1::uuid is null or n.inquilino_id = $1::uuid)
   $sql$, null, 'vermelho', 'painel', 'lider', 20),

  (p_inquilino, 'plano_trabalho_vencendo',
   'Plano de Trabalho vencendo',
   'Plano de Trabalho validado com o cliente chegando ao fim da validade. Amarelo no primeiro aviso, vermelho no último.',
   'artefatos', 'sql', $sql$
    select n.inquilino_id,
           a.id as entidade_chave,
           'Plano de Trabalho do negócio ' || n.titulo || ' vence em ' || v.dias_restantes || ' dias' as mensagem,
           case when v.dias_restantes <= v.aviso_vermelho
                then 'vermelho'::valor.criticidade
                else 'amarelo'::valor.criticidade end as criticidade,
           jsonb_build_object(
             'negocio_id', n.id,
             'vence_em', v.vence_em,
             'dias_restantes', v.dias_restantes) as detalhe
      from valor.artefatos a
      join valor.negocios n on n.id = a.negocio_id
      cross join lateral (
        select coalesce((a.conteudo ->> 'valido_ate')::date, n.data_decisao_cliente) as vence_em,
               valor.configuracao_num(n.inquilino_id, 'alerta.plano_trabalho_aviso_amarelo_dias', 7)::integer as aviso_amarelo,
               valor.configuracao_num(n.inquilino_id, 'alerta.plano_trabalho_aviso_vermelho_dias', 1)::integer as aviso_vermelho
      ) x
      cross join lateral (
        select x.vence_em, x.aviso_amarelo, x.aviso_vermelho,
               (x.vence_em - current_date) as dias_restantes
      ) v
     where a.tipo = 'plano_trabalho'
       and a.status = 'validado_com_cliente'
       and a.arquivado_em is null
       and n.arquivado_em is null
       and n.desfecho is null
       and v.vence_em is not null
       and v.dias_restantes between 0 and v.aviso_amarelo
       and ($1::uuid is null or n.inquilino_id = $1::uuid)
   $sql$, null, 'amarelo', 'painel', 'gerente_contas', 30),

  (p_inquilino, 'contrato_vencendo',
   'Contrato vencendo',
   'Contrato chegando ao fim da vigência. Primeiro aviso em amarelo, último em vermelho. O negócio de renovação é aberto pela automação criar_negocios_renovacao.',
   'contratos', 'sql', $sql$
    select c.inquilino_id,
           c.id as entidade_chave,
           'Contrato da conta ' || ct.nome || ' vence em ' || (c.fim - current_date) || ' dias' as mensagem,
           case when (c.fim - current_date)
                     <= valor.configuracao_num(c.inquilino_id, 'alerta.contrato_aviso_vermelho_dias', 30)::integer
                then 'vermelho'::valor.criticidade
                else 'amarelo'::valor.criticidade end as criticidade,
           jsonb_build_object(
             'conta_id', c.conta_id,
             'fim', c.fim,
             'dias_restantes', (c.fim - current_date)) as detalhe
      from valor.contratos c
      join valor.contas ct on ct.id = c.conta_id
     where c.arquivado_em is null
       and c.fim is not null
       and (c.fim - current_date)
           between 0 and valor.configuracao_num(c.inquilino_id, 'alerta.contrato_aviso_amarelo_dias', 60)::integer
       and ($1::uuid is null or c.inquilino_id = $1::uuid)
   $sql$, array['valor.contratos'], 'amarelo', 'painel', 'lider', 40),

  (p_inquilino, 'ata_nao_enviada',
   'Ata não enviada',
   'Reunião de conselho realizada e ata ainda não enviada além do prazo configurado.',
   'reunioes_conselho', 'sql', $sql$
    select r.inquilino_id,
           r.id as entidade_chave,
           'Ata não enviada ' || round(extract(epoch from (now() - e.data::timestamptz)) / 3600)
             || ' horas depois da reunião' as mensagem,
           'amarelo'::valor.criticidade as criticidade,
           jsonb_build_object(
             'encontro_id', r.encontro_id,
             'ata_status', r.ata_status) as detalhe
      from valor.reunioes_conselho r
      join valor.encontros e on e.id = r.encontro_id
     where r.arquivado_em is null
       and r.ata_status is distinct from 'enviada'
       and e.data is not null
       and now() - e.data::timestamptz
           > make_interval(hours => valor.configuracao_num(r.inquilino_id, 'alerta.ata_nao_enviada_horas', 24)::integer)
       and ($1::uuid is null or r.inquilino_id = $1::uuid)
   $sql$, array['valor.reunioes_conselho', 'valor.encontros'], 'amarelo', 'painel', 'assessor', 50),

  (p_inquilino, 'higiene_quebrada',
   'Invariante de higiene quebrada',
   'Negócio ativo nas fases 1 a 4 que quebra pelo menos uma das quatro invariantes de higiene. Alarme imediato no painel.',
   'negocios', 'sql', $sql$
    select h.inquilino_id,
           h.negocio_id as entidade_chave,
           'Higiene quebrada em ' || h.titulo || ': '
             || array_to_string(h.invariantes_quebradas, ', ') as mensagem,
           'vermelho'::valor.criticidade as criticidade,
           jsonb_build_object(
             'fase', h.fase,
             'invariantes_quebradas', to_jsonb(h.invariantes_quebradas),
             'tem_proximo_passo', h.tem_proximo_passo,
             'decisao_no_futuro', h.decisao_no_futuro,
             'interacao_recente', h.interacao_recente,
             'tem_artefato_da_fase', h.tem_artefato_da_fase) as detalhe
      from valor.negocios_fora_da_higiene($1::uuid) h
   $sql$, null, 'vermelho', 'painel', 'lider', 60),

  (p_inquilino, 'concentracao_de_pipeline',
   'Concentração de pipeline',
   'Os dois maiores negócios passam da fração configurada do pipeline declarado.',
   'inquilinos', 'sql', $sql$
    with pipeline as (
      select n.inquilino_id, n.id, coalesce(n.valor_total, 0) as valor_total
        from valor.negocios n
       where n.arquivado_em is null
         and n.desfecho is null
         and n.fase between 1 and 4
         and ($1::uuid is null or n.inquilino_id = $1::uuid)
    ),
    posicionado as (
      select p.*, row_number() over (partition by p.inquilino_id order by p.valor_total desc) as posicao
        from pipeline p
    ),
    resumo as (
      select q.inquilino_id,
             sum(q.valor_total) as declarado,
             sum(q.valor_total) filter (where q.posicao <= 2) as dois_maiores,
             count(*) as quantos
        from posicionado q
       group by q.inquilino_id
    )
    select r.inquilino_id,
           r.inquilino_id as entidade_chave,
           'Concentração de ' || round(100 * r.dois_maiores / r.declarado)
             || ' por cento do pipeline declarado nos dois maiores negócios' as mensagem,
           'vermelho'::valor.criticidade as criticidade,
           jsonb_build_object(
             'pipeline_declarado', r.declarado,
             'dois_maiores', r.dois_maiores,
             'negocios_no_pipeline', r.quantos) as detalhe
      from resumo r
     where r.declarado > 0
       and r.quantos > 2
       and (r.dois_maiores / r.declarado)
           > valor.configuracao_num(r.inquilino_id, 'alerta.concentracao_limite', 0.5)
   $sql$, null, 'vermelho', 'painel', 'lider', 70)
  on conflict (inquilino_id, codigo) do nothing;

  insert into valor.automacoes
    (inquilino_id, codigo, nome, descricao, gatilho, gatilho_detalhe, acao, tabelas_requeridas)
  values
    (p_inquilino, 'avaliar_alertas', 'Avaliar alertas',
     'Varre as regras ativas todo dia de manhã e grava os alertas.',
     'agendado', '0 6 * * *', 'avaliar_alertas', null),
    (p_inquilino, 'reabrir_alertas_silenciados', 'Reabrir alertas silenciados',
     'Devolve ao estado aberto o alerta cujo silêncio venceu.',
     'agendado', '10 6 * * *', 'reabrir_alertas_silenciados', null),
    (p_inquilino, 'criar_negocios_renovacao', 'Abrir negócio de renovação',
     'Abre o negócio de renovação na antecedência configurada para cada contrato vencendo.',
     'agendado', '20 6 * * *', 'criar_negocios_renovacao', array['valor.contratos'])
  on conflict (inquilino_id, codigo) do nothing;
end;
$funcao$;
comment on function valor.semear_regras_alerta(uuid) is
  'Semeia as regras e automações que a casa já decidiu, junto com os prazos em valor.configuracoes. Idempotente.';

do $$
declare r record;
begin
  for r in select id from valor.inquilinos loop
    perform valor.semear_regras_alerta(r.id);
  end loop;
end;
$$;

-- ------------------------------------------------------------- segurança

alter table valor.regras_alerta        enable row level security;
alter table valor.alertas              enable row level security;
alter table valor.automacoes           enable row level security;
alter table valor.execucoes_automacao  enable row level security;

create policy regra_le on valor.regras_alerta for select
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());
create policy regra_escreve on valor.regras_alerta for all
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

-- O alerta é da casa. O parceiro não recebe cobrança interna.
create policy alerta_le on valor.alertas for select
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());
create policy alerta_carimba on valor.alertas for update
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro())
  with check (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());
create policy alerta_grava on valor.alertas for insert
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy automacao_le on valor.automacoes for select
  using (valor.do_inquilino(inquilino_id) and not valor.eh_parceiro());
create policy automacao_escreve on valor.automacoes for all
  using (valor.do_inquilino(inquilino_id) and valor.eh_admin())
  with check (valor.do_inquilino(inquilino_id) and valor.eh_admin());

create policy execucao_le on valor.execucoes_automacao for select
  using (valor.do_inquilino(inquilino_id) and (valor.eh_admin() or valor.ve_confidencial()));
