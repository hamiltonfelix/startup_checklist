-- 0080 · Amarração entre domínios
-- Dono: orquestrador. Roda depois que todas as tabelas existem e antes das permissões.
--
-- Por que este arquivo existe: cinco construtores escreveram em paralelo, e um
-- não pode criar chave estrangeira para tabela que ainda não existia quando ele
-- escreveu. Cada um deixou a coluna solta e registrou o pedido. Aqui as pontas
-- se encontram, num lugar só, onde dá para ver o desenho inteiro.

-- ------------------------------------------------ governança aponta para o BRM
-- A pauta, a ata e a pendência pertencem a uma reunião de uma turma.
-- Todas continuam aceitando nulo, porque existe pendência que nasce fora de
-- reunião e ata de encontro que ainda não foi cadastrado.

alter table valor.pautas
  add constraint pautas_turma_fk     foreign key (turma_id)    references valor.turmas(id)    on delete restrict,
  add constraint pautas_encontro_fk  foreign key (encontro_id) references valor.encontros(id) on delete restrict;

alter table valor.atas
  add constraint atas_turma_fk       foreign key (turma_id)    references valor.turmas(id)    on delete restrict,
  add constraint atas_encontro_fk    foreign key (encontro_id) references valor.encontros(id) on delete restrict;

alter table valor.pendencias
  add constraint pendencias_turma_fk    foreign key (turma_id)    references valor.turmas(id)    on delete restrict,
  add constraint pendencias_encontro_fk foreign key (encontro_id) references valor.encontros(id) on delete restrict;

alter table valor.pesquisas
  add constraint pesquisas_turma_fk    foreign key (turma_id)    references valor.turmas(id)    on delete restrict,
  add constraint pesquisas_programa_fk foreign key (programa_id) references valor.programas(id) on delete restrict;

-- ------------------------------------------------ BRM aponta para o financeiro
-- Todas aceitam nulo de propósito: a turma pode rodar antes do contrato estar
-- assinado, e isso acontece na prática.

alter table valor.programas
  add constraint programas_contrato_fk foreign key (contrato_id) references valor.contratos(id) on delete restrict;
alter table valor.turmas
  add constraint turmas_contrato_fk foreign key (contrato_id) references valor.contratos(id) on delete restrict;
alter table valor.turmas_contas
  add constraint turmas_contas_contrato_fk foreign key (contrato_id) references valor.contratos(id) on delete restrict;
alter table valor.participantes
  add constraint participantes_contrato_fk foreign key (contrato_id) references valor.contratos(id) on delete restrict;
alter table valor.historico_valor
  add constraint historico_valor_contrato_fk foreign key (contrato_id) references valor.contratos(id) on delete restrict;

-- ------------------------------------------------ numeração por turma
-- Decisão de arquitetura número 3. No conselho compartilhado, uma turma reúne
-- empresários de contas diferentes e a reunião é uma só. Numerar por conta
-- produziria a mesma reunião com números distintos para cada participante.
-- Onde não há turma, a numeração por conta continua valendo.

drop index if exists valor.pautas_numero_unico;

create unique index pautas_numero_por_turma on valor.pautas (inquilino_id, turma_id, numero)
  where turma_id is not null and numero is not null and arquivado_em is null;
create unique index pautas_numero_por_conta on valor.pautas (inquilino_id, conta_id, numero)
  where turma_id is null and numero is not null and arquivado_em is null;

alter table valor.atas drop constraint if exists atas_inquilino_id_conta_id_numero_key;

create unique index atas_numero_por_turma on valor.atas (inquilino_id, turma_id, numero)
  where turma_id is not null and arquivado_em is null;
create unique index atas_numero_por_conta on valor.atas (inquilino_id, conta_id, numero)
  where turma_id is null and arquivado_em is null;

comment on index valor.atas_numero_por_turma is
  'A ata é numerada por turma. No conselho compartilhado a reunião é uma só para contas diferentes.';
