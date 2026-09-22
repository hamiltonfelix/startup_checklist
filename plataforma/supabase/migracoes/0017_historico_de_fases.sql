-- 0017 · Histórico de fases do negócio
-- Dono: orquestrador. Pedido da frente de operação.
--
-- Por que existe: o alarme de negócio parado nasceu com piso fixo de trinta
-- dias, porque não havia como saber quanto tempo uma fase costuma durar nesta
-- casa. Com esta tabela, o alarme passa a ser duas vezes a mediana histórica da
-- fase, que é a regra que a casa quer. Enquanto não houver histórico bastante,
-- o piso configurado continua valendo.

create table valor.historico_fases (
  id           uuid primary key default gen_random_uuid(),
  inquilino_id uuid not null references valor.inquilinos(id) on delete restrict,
  negocio_id   uuid not null references valor.negocios(id) on delete cascade,
  fase         smallint not null check (fase between 0 and 9),
  entrou_em    date not null,
  saiu_em      date,
  dias_na_fase integer generated always as (saiu_em - entrou_em) stored,
  criado_em    timestamptz not null default now(),
  criado_por   uuid
);

create index on valor.historico_fases (inquilino_id, fase) where saiu_em is not null;
create index on valor.historico_fases (negocio_id, entrou_em);
create unique index historico_fases_aberta_unica on valor.historico_fases (negocio_id)
  where saiu_em is null;

comment on table valor.historico_fases is
  'Uma linha por passagem de um negócio por uma fase. É daqui que sai a mediana de duração por fase.';
comment on column valor.historico_fases.dias_na_fase is
  'Calculado pelo banco. Nulo enquanto o negócio ainda estiver na fase.';

-- Registra a entrada na fase e fecha a anterior, sem que ninguém precise lembrar.
create or replace function valor.registrar_fase() returns trigger
language plpgsql security definer set search_path = valor, pg_catalog as $$
begin
  if tg_op = 'INSERT' then
    insert into valor.historico_fases (inquilino_id, negocio_id, fase, entrou_em, criado_por)
    values (new.inquilino_id, new.id, new.fase, coalesce(new.entrou_na_fase_em, current_date), valor.usuario_atual());
    return new;
  end if;

  if new.fase is distinct from old.fase then
    update valor.historico_fases
       set saiu_em = current_date
     where negocio_id = new.id and saiu_em is null;

    insert into valor.historico_fases (inquilino_id, negocio_id, fase, entrou_em, criado_por)
    values (new.inquilino_id, new.id, new.fase, current_date, valor.usuario_atual());

    new.entrou_na_fase_em := current_date;
  end if;
  return new;
end;
$$;

create trigger registra_fase_ao_nascer after insert on valor.negocios
  for each row execute function valor.registrar_fase();
create trigger registra_fase_ao_mudar before update of fase on valor.negocios
  for each row execute function valor.registrar_fase();

-- A mediana por fase. Devolve nulo quando não há amostra bastante, e aí quem
-- chama usa o piso configurado. Doze passagens é o mínimo para a mediana dizer
-- alguma coisa, e o número fica na configuração do inquilino.
create or replace function valor.mediana_dias_da_fase(p_inquilino uuid, p_fase smallint)
returns integer language sql stable as $$
  with amostra as (
    select dias_na_fase from valor.historico_fases
    where inquilino_id = p_inquilino and fase = p_fase and saiu_em is not null and dias_na_fase >= 0
  )
  select case
    when (select count(*) from amostra) >= coalesce(
           (select (valor->>'valor')::integer from valor.configuracoes
             where inquilino_id = p_inquilino and chave = 'alerta.amostra_minima_mediana'), 12)
    then (select percentile_cont(0.5) within group (order by dias_na_fase)::integer from amostra)
  end;
$$;

alter table valor.historico_fases enable row level security;

create policy historico_fases_le on valor.historico_fases for select
  using (inquilino_id = valor.inquilino_atual() and not valor.eh_parceiro());
create policy historico_fases_escreve on valor.historico_fases for all
  using (inquilino_id = valor.inquilino_atual() and not valor.eh_parceiro())
  with check (inquilino_id = valor.inquilino_atual() and not valor.eh_parceiro());

-- Pedido da frente de operação: a validade do Plano de Trabalho vivia dentro do
-- jsonb e o alerta precisava adivinhar. Agora é coluna.
alter table valor.artefatos add column if not exists valido_ate date;
comment on column valor.artefatos.valido_ate is
  'Até quando o artefato vale para o cliente. O alerta de Plano de Trabalho vencendo lê esta coluna.';
