# Monitoramento de Ocupação — UPAs BH (Sala Vermelha + Enfermarias)

Sistema baseado no PAP DAUE 018, estendido para também monitorar as
Enfermarias (Adulto e Pediátrica) das mesmas 9 unidades.

## O que tem aqui

- `schema.sql` — banco de dados (Supabase). Rode-o inteiro no SQL Editor
  sempre que ele mudar neste repositório — é seguro rodar em cima de um
  banco que já tem uma versão anterior.
- `lancamento.html` — página de registro. Tem um seletor no topo para
  escolher **Sala Vermelha**, **Enfermaria Adulto** ou **Enfermaria
  Pediátrica** antes de preencher.
- `dashboard.html` — visão consolidada, com abas para os três tipos,
  alerta de pendências no topo, e destaque visual de unidades atrasadas.
  **Não tem mais link para a tela de relatórios** — veja item 8 abaixo.
- `relatorios.html` — página separada (não linkada no dashboard) para
  extrair relatórios de ocupação por período (semanal / mensal / semestral
  / anual / customizado), com exportação em CSV.

## O que mudou desde a versão anterior

### 1. Sala Vermelha + Enfermaria Adulto + Enfermaria Pediátrica (mesma lógica, três "tipos")
A lógica da Sala Vermelha **não foi alterada** — mesmos níveis (Verde/
Amarelo/Vermelho/Preto), mesma regra do "1 leito livre não pode ser
referência". As duas Enfermarias rodam em paralelo, cada uma com sua
própria capacidade de leitos; a Enfermaria Pediátrica usa o mesmo
cronograma da Enfermaria Adulto.

Cada unidade continua com **um único link** de lançamento
(`lancamento.html?u=barreiro`) — dentro da página, a pessoa escolhe qual
dos três tipos está preenchendo.

### 2. Cronograma de atraso por tipo (corrigido — antes tudo usava a régua de 2h)
- **Sala Vermelha:** padrão a cada 2h (00, 02, 04… 22h), com 15 minutos de
  tolerância.
- **Enfermaria Adulto e Enfermaria Pediátrica:** cronograma próprio, só
  **9h e 20h**, com 45 minutos de tolerância (esse intervalo é ajustável
  na função `fn_tolerancia` do `schema.sql`, caso queira mais ou menos
  rigor).

Antes, o sistema usava a régua de 2 em 2 horas da Sala Vermelha para
decidir se **qualquer** unidade estava atrasada — inclusive as
Enfermarias, que preenchem só duas vezes por dia. Isso foi corrigido: a
função `fn_horario_esperado_anterior` do `schema.sql` agora calcula o
cronograma esperado separadamente por tipo.

O dashboard mostra, para cada card, se o último lançamento está **"No
horário"** ou **"Atrasado"** — e quem atrasa fica com destaque visual
(contorno vermelho no card) e um selo "⏱ atrasado". Isso deve ajudar nas
cobranças às unidades que atrasam com frequência, já que também aparece
o nome e cargo de quem fez o último lançamento.

### 3. Alerta de pendências
Um banner vermelho aparece no topo do dashboard sempre que houver
qualquer unidade (de qualquer um dos três tipos) com lançamento atrasado
— não precisa entrar na aba certa para perceber.

### 4. Lotação acima da capacidade
O campo de pacientes internados não tem mais limite máximo — dá para
lançar um número maior que os leitos cadastrados. Quando isso acontece:
- A tela de lançamento mostra um alerta imediato ("lotação acima da
  capacidade em X paciente(s)").
- O card no dashboard ganha o selo "⚠ acima da capacidade".
- Vagas aparecem como número negativo, destacado em vermelho.
- Cada ocorrência fica registrada no histórico normalmente — nada é
  bloqueado, só sinalizado.

### 5. Relatórios (`relatorios.html`)
Nova página, acessível pelo link "📊 Relatórios" no dashboard. Escolha um
período (semanal = últimos 7 dias, mensal = últimos 30, semestral = 6
meses, anual = 12 meses, ou datas customizadas) e o tipo (Sala Vermelha,
Enfermaria, ou os dois). O relatório mostra, por unidade:
- número de registros no período
- ocupação média e máxima (%)
- quantos registros ficaram acima da capacidade
- número máximo de pacientes já registrado

Dá para baixar tudo em CSV. Esse cálculo roda **dentro do banco**
(função `relatorio_ocupacao`), então funciona mesmo com um ano inteiro de
histórico sem sobrecarregar o navegador.

### 6. Nome e cargo obrigatórios
A tela de lançamento agora exige nome e cargo de quem está preenchendo —
o botão de enviar valida isso antes de gravar, e o banco também recusa
(colunas `NOT NULL`) caso algo tente pular essa validação.

### 7. Visual
A borda colorida lateral dos cards ficou mais grossa (de 5px para 10px),
como pedido. O nível **Preto** (≥85%) agora usa preto de verdade
(`#000000` na borda, texto quase preto) — antes a cor estava saindo num
tom de vermelho escuro (`#7a1f1a`) em vez de preto.

### 8. Relatórios só por link direto
O botão/link "📊 Relatórios" foi removido do dashboard. A página
`relatorios.html` continua funcionando normalmente, mas só quem receber o
link diretamente (ex: `.../relatorios.html`) consegue abri-la — não tem
mais nenhum atalho visível a partir do dashboard.

### 9. Enfermaria Pediátrica
Terceiro tipo de unidade, em paralelo à Sala Vermelha e à Enfermaria
Adulto (que já existiam). Mesmo link de lançamento de sempre
(`lancamento.html?u=<unidade>`) — a pessoa escolhe entre os três tipos
dentro da página. Cronograma e tolerância de atraso da Enfermaria
Pediátrica são iguais aos da Enfermaria Adulto (9h e 20h, 45 min de
tolerância — ver item 2). O dashboard e os relatórios ganharam uma
terceira aba/filtro para ela.

## Passo a passo de instalação

Se o projeto Supabase **já existe** (caso normal — só está aplicando os
ajustes mais recentes), pule direto para o passo 2: o `schema.sql` é
seguro de rodar de novo em cima do banco atual, ele não apaga dados.

### 1. Criar o projeto Supabase (só na primeira vez)

supabase.com → **New Project**. Guarde a senha do banco (não é usada no
dia a dia, só em emergências).

### 2. Rodar o schema

**SQL Editor** → cole o `schema.sql` inteiro → **Run**. Isso é
obrigatório sempre que `schema.sql` mudar neste repositório (é o caso
agora: cronograma de atraso por tipo corrigido + Enfermaria Pediátrica).

Isso cria as 9 UPAs, a capacidade de leitos de Sala Vermelha (valores já
usados antes), de Enfermaria Adulto e de Enfermaria Pediátrica
(**valores de exemplo — vá em Table Editor → `capacidade_leitos` e
ajuste para os números reais de cada unidade**; se alguma unidade não
tiver Enfermaria Pediátrica, apague a linha dela nessa tabela).

### 3. Pegar as chaves

**Project Settings → API** → copie a `Project URL` e a chave pública
(`anon` / `publishable`).

Cole essas duas informações nos **três** arquivos HTML
(`lancamento.html`, `dashboard.html`, `relatorios.html`), no topo do
`<script>`.

### 4. Hospedar no GitHub Pages

Suba os quatro arquivos (os três `.html` + este `README.md`, opcional)
para o repositório institucional e ative o GitHub Pages.


## Sobre a heartbeat / pausa por inatividade

Continua valendo a recomendação de configurar um "ping" automático
(GitHub Actions, 1x por dia) para o projeto Supabase não pausar por
inatividade — ainda mais importante agora que existe um segundo
cronograma (Enfermaria, só 2x/dia), que já é naturalmente mais espaçado.

## Segurança (sem mudanças em relação à versão anterior)

Continua o mesmo modelo: quem tem o link de uma unidade pode lançar dados
para ela, sem autenticação adicional — reproduz o nível de confiança da
planilha atual. Reforços possíveis (Supabase Auth por unidade, ou uma
Edge Function validando token) continuam sendo incrementos futuros, não
bloqueadores para uso.
