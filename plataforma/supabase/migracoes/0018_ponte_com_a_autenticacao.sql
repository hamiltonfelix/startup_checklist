-- 0018 · Ponte com a autenticação do Supabase
-- Dono: orquestrador.
--
-- Por que este arquivo existe, e por que ele é indispensável:
--
-- Toda a segurança desta plataforma pergunta ao token quem é a pessoa, de que
-- inquilino ela é, que perfil ela tem, e, quando for parceiro, qual parceiro.
-- O token que o Supabase emite por padrão **não carrega nada disso**. Sem esta
-- ponte, `valor.perfil_atual()` devolve `nenhum` para todo mundo, toda política
-- nega tudo, e a plataforma sobe muda: ninguém enxerga nada e ninguém entende
-- por quê.
--
-- Duas peças resolvem isso:
--
-- 1. O gancho de emissão de token, que o Supabase chama a cada autenticação e a
--    cada renovação. Ele lê a linha da pessoa em `valor.usuarios` e escreve as
--    claims dentro do token.
-- 2. O vínculo entre `auth.users` e `valor.usuarios`, feito por endereço, no
--    momento em que a pessoa aceita o convite.
--
-- Tudo aqui é condicional: neste contêiner não existe o esquema `auth` nem o
-- papel `supabase_auth_admin`, e o arquivo precisa aplicar mesmo assim, para a
-- cadeia de migrações continuar rodando no teste local.

-- ------------------------------------------------ o gancho de emissão de token

create or replace function valor.gancho_token(evento jsonb)
returns jsonb language plpgsql stable security definer set search_path = valor, pg_catalog as $$
declare
  pessoa   record;
  claims   jsonb;
  parceiro uuid;
begin
  claims := coalesce(evento -> 'claims', '{}'::jsonb);

  select u.id, u.inquilino_id, u.perfil, u.ativo, u.nome
    into pessoa
    from valor.usuarios u
   where u.auth_id = (evento ->> 'user_id')::uuid
     and u.arquivado_em is null
   limit 1;

  if pessoa.id is null or not pessoa.ativo then
    -- Pessoa sem cadastro ativo recebe um token sem poder algum. A sessão
    -- autentica e não enxerga nada, que é o comportamento correto: recusar o
    -- acesso é papel da aplicação, e negar o dado é papel do banco.
    claims := claims
      || jsonb_build_object('perfil', 'nenhum')
      || jsonb_build_object('plataforma_de_valor', 'sem_cadastro_ativo');
    return jsonb_set(evento, '{claims}', claims);
  end if;

  select pu.parceiro_id into parceiro
    from valor.parceiros_usuarios pu
   where pu.usuario_id = pessoa.id
     and pu.arquivado_em is null
   limit 1;

  claims := claims
    || jsonb_build_object('usuario_id',   pessoa.id::text)
    || jsonb_build_object('inquilino_id', pessoa.inquilino_id::text)
    || jsonb_build_object('perfil',       pessoa.perfil::text)
    || jsonb_build_object('nome',         pessoa.nome);

  if parceiro is not null then
    claims := claims || jsonb_build_object('parceiro_id', parceiro::text);
  end if;

  return jsonb_set(evento, '{claims}', claims);
end;
$$;

comment on function valor.gancho_token(jsonb) is
  'Escreve inquilino, perfil, usuário e parceiro dentro do token. Ligar no painel do Supabase, em Autenticação, gancho de emissão de token de acesso.';

-- ------------------------------------------------ o vínculo com o convite

-- Quando a pessoa aceita o convite e nasce em auth.users, amarramos a linha dela
-- em valor.usuarios pelo endereço. Sem isto, o gancho não acha ninguém.
create or replace function valor.vincular_identidade(p_auth_id uuid, p_email text)
returns uuid language plpgsql security definer set search_path = valor, pg_catalog as $$
declare
  alvo uuid;
begin
  update valor.usuarios
     set auth_id = p_auth_id,
         ultimo_acesso = now()
   where lower(email) = lower(p_email)
     and auth_id is null
     and arquivado_em is null
   returning id into alvo;

  if alvo is not null then
    update valor.convites
       set aceito_em = now(), usuario_id = alvo
     where lower(email) = lower(p_email) and aceito_em is null;
  end if;

  return alvo;
end;
$$;

comment on function valor.vincular_identidade(uuid, text) is
  'Amarra a identidade recém criada na autenticação à pessoa já convidada. Casa pelo endereço, e só quando o vínculo ainda não existe.';

-- ------------------------------------------------ o que só existe no Supabase

do $$
begin
  -- O gancho roda com o papel da autenticação, que precisa alcançar o cadastro.
  if exists (select 1 from pg_roles where rolname = 'supabase_auth_admin') then
    execute 'grant usage on schema valor to supabase_auth_admin';
    execute 'grant execute on function valor.gancho_token(jsonb) to supabase_auth_admin';
    execute 'grant select on valor.usuarios, valor.parceiros_usuarios to supabase_auth_admin';

    -- O gancho é do serviço de autenticação, e de mais ninguém.
    execute 'revoke execute on function valor.gancho_token(jsonb) from authenticated, anon, public';
    execute 'revoke execute on function valor.vincular_identidade(uuid, text) from authenticated, anon, public';

    execute $pol$
      create policy usuario_le_pela_autenticacao on valor.usuarios for select
        to supabase_auth_admin using (true)
    $pol$;
    execute $pol$
      create policy parceiro_usuario_le_pela_autenticacao on valor.parceiros_usuarios for select
        to supabase_auth_admin using (true)
    $pol$;
  end if;

  -- Amarra a identidade no instante em que ela nasce.
  if exists (select 1 from pg_namespace where nspname = 'auth') then
    execute $fn$
      create or replace function valor.ao_nascer_identidade() returns trigger
      language plpgsql security definer set search_path = valor, pg_catalog as $b$
      begin
        perform valor.vincular_identidade(new.id, new.email);
        return new;
      end;
      $b$;
    $fn$;
    execute 'drop trigger if exists vincula_na_plataforma_de_valor on auth.users';
    execute 'create trigger vincula_na_plataforma_de_valor after insert on auth.users
             for each row execute function valor.ao_nascer_identidade()';
  end if;
end $$;
