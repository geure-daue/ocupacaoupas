-- =========================================================================
-- Monitoramento da Ocupação das UPAs — Sala Vermelha + Enfermarias
-- Baseado no PAP DAUE 018 (v.00, 07/07/2026), com extensão para Enfermarias.
-- Execute este arquivo INTEIRO no SQL Editor do Supabase.
--
-- Este script é seguro de rodar tanto num projeto novo quanto num projeto
-- que já tinha a versão anterior (com Sala Vermelha apenas) — os comandos
-- abaixo removem as tabelas/objetos antigos antes de recriar tudo do zero.
-- ATENÇÃO: isso APAGA os dados que já estiverem nesse projeto. Se quiser
-- preservar histórico antigo, exporte antes (Table Editor → registros
-- antigos → Export).
-- =========================================================================

drop view if exists v_ocupacao_atual cascade;
drop function if exists relatorio_ocupacao(timestamptz, timestamptz) cascade;
drop function if exists fn_horario_esperado_anterior(text, timestamptz) cascade;
drop function if exists fn_tolerancia(text) cascade;
drop table if exists registros_ocupacao cascade;
drop table if exists capacidade_leitos cascade;
drop table if exists unidades cascade;

-- -------------------------------------------------------------------------
-- 1. TABELA: unidades
-- Cadastro fixo das 9 UPAs.
-- -------------------------------------------------------------------------
create table if not exists unidades (
  id     text primary key,        -- slug, ex: 'barreiro'
  nome   text not null,           -- ex: 'UPA BARREIRO'
  ordem  integer not null default 0,
  ativo  boolean not null default true
);

insert into unidades (id, nome, ordem) values
  ('barreiro',      'UPA BARREIRO',      1),
  ('centro_sul',    'UPA CENTRO-SUL',    2),
  ('leste',         'UPA LESTE',         3),
  ('nordeste',      'UPA NORDESTE',      4),
  ('noroeste',      'UPA NOROESTE',      5),
  ('norte',         'UPA NORTE',         6),
  ('oeste',         'UPA OESTE',         7),
  ('pampulha',      'UPA PAMPULHA',      8),
  ('venda_nova',    'UPA VENDA NOVA',    9)
on conflict (id) do nothing;

-- -------------------------------------------------------------------------
-- 2. TABELA: capacidade_leitos
-- Número de leitos por unidade E por tipo de monitoramento. Separar por
-- tipo permite que Sala Vermelha e Enfermaria tenham capacidades diferentes
-- na mesma unidade, e permite adicionar um terceiro tipo no futuro sem
-- mudar a estrutura.
-- -------------------------------------------------------------------------
create table if not exists capacidade_leitos (
  unidade_id     text not null references unidades(id),
  tipo           text not null check (tipo in ('sala_vermelha', 'enfermaria')),
  leitos_totais  integer not null check (leitos_totais > 0),
  primary key (unidade_id, tipo)
);

-- Sala Vermelha: mesmos valores já usados até aqui (ajuste se necessário).
insert into capacidade_leitos (unidade_id, tipo, leitos_totais) values
  ('barreiro',      'sala_vermelha', 6),
  ('centro_sul',    'sala_vermelha', 7),
  ('leste',         'sala_vermelha', 6),
  ('nordeste',      'sala_vermelha', 4),
  ('noroeste',      'sala_vermelha', 8),
  ('norte',         'sala_vermelha', 6),
  ('oeste',         'sala_vermelha', 3),
  ('pampulha',      'sala_vermelha', 4),
  ('venda_nova',    'sala_vermelha', 6)
on conflict (unidade_id, tipo) do nothing;

-- Enfermaria: valores de EXEMPLO — AJUSTE para os números reais de cada
-- unidade na tabela antes de usar em produção (Table Editor → capacidade_leitos).
insert into capacidade_leitos (unidade_id, tipo, leitos_totais) values
  ('barreiro',      'enfermaria', 20),
  ('centro_sul',    'enfermaria', 20),
  ('leste',         'enfermaria', 20),
  ('nordeste',      'enfermaria', 20),
  ('noroeste',      'enfermaria', 20),
  ('norte',         'enfermaria', 20),
  ('oeste',         'enfermaria', 20),
  ('pampulha',      'enfermaria', 20),
  ('venda_nova',    'enfermaria', 20)
on conflict (unidade_id, tipo) do nothing;

-- -------------------------------------------------------------------------
-- 3. TABELA: registros_ocupacao
-- Cada preenchimento gera uma LINHA NOVA (nunca update) — histórico e
-- auditoria de graça. Agora com `tipo`, nome e cargo obrigatórios, e SEM
-- limite superior de pacientes (permite registrar lotação acima da
-- capacidade — item 3 do pedido).
-- -------------------------------------------------------------------------
create table if not exists registros_ocupacao (
  id                     uuid primary key default gen_random_uuid(),
  unidade_id             text not null,
  tipo                   text not null check (tipo in ('sala_vermelha', 'enfermaria')),
  pacientes_internados   integer not null check (pacientes_internados >= 0),
  registrado_em          timestamptz not null default now(),
  registrado_por         text not null,   -- nome de quem preencheu — OBRIGATÓRIO
  registrado_cargo       text not null,   -- cargo de quem preencheu — OBRIGATÓRIO
  foreign key (unidade_id, tipo) references capacidade_leitos(unidade_id, tipo)
);

create index if not exists idx_registros_unidade_tipo_tempo
  on registros_ocupacao (unidade_id, tipo, registrado_em desc);

create index if not exists idx_registros_tempo
  on registros_ocupacao (registrado_em);

-- -------------------------------------------------------------------------
-- 4. FUNÇÕES: cronograma esperado por tipo
-- Sala Vermelha: checkpoint a cada 2h (00,02,04...22h) — como já era.
-- Enfermaria: checkpoint só às 9h e às 20h — item 7 do pedido.
-- Horários são calculados em America/Sao_Paulo para não depender do fuso
-- do servidor.
-- -------------------------------------------------------------------------
create or replace function fn_horario_esperado_anterior(p_tipo text, p_agora timestamptz)
returns timestamptz
language plpgsql
stable
as $$
declare
  local_ts timestamp;
  checkpoint_local timestamp;
begin
  local_ts := p_agora at time zone 'America/Sao_Paulo';

  if p_tipo = 'enfermaria' then
    if local_ts::time >= time '20:00' then
      checkpoint_local := date_trunc('day', local_ts) + interval '20 hours';
    elsif local_ts::time >= time '09:00' then
      checkpoint_local := date_trunc('day', local_ts) + interval '9 hours';
    else
      checkpoint_local := date_trunc('day', local_ts) - interval '1 day' + interval '20 hours';
    end if;
  else
    checkpoint_local := date_trunc('day', local_ts)
      + (floor(extract(hour from local_ts)::int / 2) * 2) * interval '1 hour';
  end if;

  return checkpoint_local at time zone 'America/Sao_Paulo';
end;
$$;

create or replace function fn_tolerancia(p_tipo text)
returns interval
language sql
immutable
as $$
  select case when p_tipo = 'enfermaria' then interval '45 minutes' else interval '15 minutes' end
$$;

-- -------------------------------------------------------------------------
-- 5. VIEW: v_ocupacao_atual
-- Uma linha por (unidade, tipo). Mantém toda a lógica original da Sala
-- Vermelha (classificação por nível, regra do "1 leito livre") e adiciona:
--   - acima_capacidade: pacientes > leitos cadastrados
--   - atrasado: calculado pelo cronograma esperado de CADA tipo (item 2/5/6)
-- -------------------------------------------------------------------------
create or replace view v_ocupacao_atual as
with ultimo as (
  select distinct on (unidade_id, tipo)
    unidade_id, tipo, pacientes_internados, registrado_em, registrado_por, registrado_cargo
  from registros_ocupacao
  order by unidade_id, tipo, registrado_em desc
)
select
  u.id                                                          as unidade_id,
  u.nome,
  u.ordem,
  c.tipo,
  c.leitos_totais,
  coalesce(r.pacientes_internados, 0)                           as pacientes_internados,
  c.leitos_totais - coalesce(r.pacientes_internados, 0)         as vagas,
  coalesce(r.pacientes_internados, 0) > c.leitos_totais         as acima_capacidade,
  round(100.0 * coalesce(r.pacientes_internados, 0) / c.leitos_totais)::int as percentual_ocupacao,
  case
    when r.pacientes_internados is null then 'sem_registro'
    when round(100.0 * r.pacientes_internados / c.leitos_totais) <= 50 then 'verde'
    when round(100.0 * r.pacientes_internados / c.leitos_totais) <= 69 then 'amarelo'
    when round(100.0 * r.pacientes_internados / c.leitos_totais) <= 84 then 'vermelho'
    else 'preto'
  end                                                            as nivel,
  (c.leitos_totais - coalesce(r.pacientes_internados, 0)) > 1    as pode_ser_referencia,
  r.registrado_em,
  r.registrado_por,
  r.registrado_cargo,
  fn_horario_esperado_anterior(c.tipo, now())                    as horario_esperado_anterior,
  case
    when r.registrado_em is null then true
    when r.registrado_em < fn_horario_esperado_anterior(c.tipo, now())
         and now() > fn_horario_esperado_anterior(c.tipo, now()) + fn_tolerancia(c.tipo)
      then true
    else false
  end                                                            as atrasado,
  extract(epoch from (now() - r.registrado_em)) / 60             as minutos_desde_registro
from unidades u
join capacidade_leitos c on c.unidade_id = u.id
left join ultimo r on r.unidade_id = u.id and r.tipo = c.tipo
where u.ativo = true
order by u.ordem, c.tipo;

-- -------------------------------------------------------------------------
-- 6. FUNÇÃO: relatorio_ocupacao
-- Agregação server-side por período (evita baixar milhares de linhas no
-- navegador). Usada pela tela de relatórios (semanal/mensal/semestral/anual
-- ou período customizado) — item 3 do pedido.
-- -------------------------------------------------------------------------
create or replace function relatorio_ocupacao(p_inicio timestamptz, p_fim timestamptz)
returns table (
  unidade_id                text,
  nome                      text,
  tipo                      text,
  leitos_totais             integer,
  total_registros           bigint,
  media_percentual          numeric,
  max_percentual            numeric,
  registros_acima_capacidade bigint,
  max_pacientes             integer,
  registros_atrasados_estimado bigint
)
language sql
stable
as $$
  select
    u.id,
    u.nome,
    r.tipo,
    c.leitos_totais,
    count(*)                                                            as total_registros,
    round(avg(100.0 * r.pacientes_internados / c.leitos_totais), 1)      as media_percentual,
    round(max(100.0 * r.pacientes_internados / c.leitos_totais), 1)      as max_percentual,
    count(*) filter (where r.pacientes_internados > c.leitos_totais)     as registros_acima_capacidade,
    max(r.pacientes_internados)                                         as max_pacientes,
    0::bigint                                                            as registros_atrasados_estimado
  from registros_ocupacao r
  join unidades u on u.id = r.unidade_id
  join capacidade_leitos c on c.unidade_id = r.unidade_id and c.tipo = r.tipo
  where r.registrado_em >= p_inicio and r.registrado_em < p_fim
  group by u.id, u.nome, r.tipo, c.leitos_totais
  order by u.nome, r.tipo;
$$;

grant execute on function relatorio_ocupacao(timestamptz, timestamptz) to anon, authenticated;

-- -------------------------------------------------------------------------
-- 7. RLS (Row Level Security)
-- Mesmo modelo de antes: leitura pública para quem visualiza, inserção
-- pública (controlada pelo link de cada unidade), nunca update/delete.
-- -------------------------------------------------------------------------
alter table unidades enable row level security;
alter table capacidade_leitos enable row level security;
alter table registros_ocupacao enable row level security;

drop policy if exists "unidades: leitura publica" on unidades;
create policy "unidades: leitura publica" on unidades for select using (true);

drop policy if exists "capacidade: leitura publica" on capacidade_leitos;
create policy "capacidade: leitura publica" on capacidade_leitos for select using (true);

drop policy if exists "registros: leitura publica" on registros_ocupacao;
create policy "registros: leitura publica" on registros_ocupacao for select using (true);

drop policy if exists "registros: insercao publica" on registros_ocupacao;
create policy "registros: insercao publica" on registros_ocupacao for insert with check (true);

-- Nunca criar policies de update/delete: histórico é imutável.

-- -------------------------------------------------------------------------
-- 8. REALTIME
-- -------------------------------------------------------------------------
alter publication supabase_realtime add table registros_ocupacao;

-- =========================================================================
-- NOTAS:
-- 1) Ajuste os valores de `leitos_totais` da Enfermaria (todos vieram como
--    20 de exemplo) em capacidade_leitos antes de usar em produção.
-- 2) A tolerância de atraso é de 15 min para Sala Vermelha e 45 min para
--    Enfermaria (ajustável em fn_tolerancia, já que o ciclo dela é mais
--    espaçado — 9h e 20h).
-- 3) A mesma observação de segurança do schema anterior continua válida:
--    quem tem o link de lançamento de uma unidade pode registrar dados
--    para ela, sem autenticação adicional.
-- =========================================================================
