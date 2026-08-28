# Monitoramento de Ocupação — UPAs BH (Sala Vermelha + Enfermarias)

Sistema baseado no PAP DAUE 018, estendido para também monitorar as
Enfermarias das mesmas 9 unidades.

## O que tem aqui

- `schema.sql` — banco de dados (Supabase). 
- `lancamento.html` — página de registro.
- `dashboard.html` — visão consolidada.
- `relatorios.html` — página para extrair relatórios de ocupação por
  período (semanal / mensal / semestral / anual / customizado), com
  exportação em CSV.


## Passo a passo de instalação

### 1. Criar o projeto Supabase (conta institucional)

supabase.com → **New Project**. Guarde a senha do banco (não é usada no
dia a dia, só em emergências).

### 2. Rodar o schema

**SQL Editor** → cole o `schema.sql` inteiro → **Run**.

Isso cria as 9 UPAs, a capacidade de leitos de Sala Vermelha (valores já
usados antes) e de Enfermaria (**valores de exemplo, 20 para todas — vá
em Table Editor → `capacidade_leitos` e ajuste para os números reais**).

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

**Já incluído neste pacote:** `.github/workflows/heartbeat.yml` — um workflow
do GitHub Actions que faz uma leitura simples na tabela `unidades` todo dia
às 09:00 UTC (06:00 em Brasília), só para o Supabase nunca contar 7 dias
de silêncio e pausar o projeto.

**Para ativar:**
1. Ao subir os arquivos deste pacote para o repositório, mantenha a pasta
   `.github/workflows/` — o GitHub detecta o arquivo `.yml` automaticamente,
   não precisa configurar nada a mais.
2. Vá na aba **Actions** do repositório → deve aparecer "Heartbeat Supabase"
   na lista de workflows.
3. Clique nele → **Run workflow** → **Run workflow** (botão verde) para
   testar manualmente agora, sem esperar o horário agendado.
4. Confira se o resultado ficou verde (✓). Se ficar vermelho (✗), abra o
   log — geralmente indica chave do Supabase incorreta ou expirada.

**Atenção:** as chaves do Supabase usadas no `heartbeat.yml` são as mesmas
que estão nos arquivos HTML (chave pública, sem risco de expor). **Quando
você recriar o projeto na conta institucional, lembre de atualizar a URL e
a chave também neste arquivo** (`.github/workflows/heartbeat.yml`).


## Segurança (sem mudanças em relação à versão anterior)

Continua o mesmo modelo: quem tem o link de uma unidade pode lançar dados
para ela, sem autenticação adicional — reproduz o nível de confiança da
planilha atual. Reforços possíveis (Supabase Auth por unidade, ou uma
Edge Function validando token) continuam sendo incrementos futuros, não
bloqueadores para uso.
