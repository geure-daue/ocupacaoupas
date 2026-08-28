# Monitoramento de Ocupação — UPAs BH (Sala Vermelha + Enfermarias)

Sistema baseado no PAP DAUE 018, estendido para também monitorar as
Enfermarias (Adulto e Pediátrica) das mesmas 9 unidades.

## O que tem aqui

- `schema.sql` — banco de dados (Supabase). Rode-o inteiro no SQL Editor
  sempre que ele mudar neste repositório — é seguro rodar em cima de um
  banco que já tem uma versão anterior (os `drop` no início recriam tudo
  do zero).
- `lancamento.html` — página de registro. Tem um seletor no topo para
  escolher **Sala Vermelha**, **Enfermaria Adulto** ou **Enfermaria
  Pediátrica** antes de preencher.
- `dashboard.html` — visão consolidada, com abas para os três tipos,
  alerta de pendências no topo, e destaque visual de unidades atrasadas.
- `relatorios.html` — página para extrair relatórios de ocupação por
  período (semanal / mensal / semestral / anual / customizado), com
  exportação em CSV. Acessível só por link direto — não aparece no
  dashboard.

## O que mudou desde a versão anterior

### 1. Sala Vermelha + Enfermaria Adulto + Enfermaria Pediátrica (três "tipos")

A lógica da Sala Vermelha **não foi alterada** — mesmos níveis (Verde/
Amarelo/Vermelho/Preto), mesma regra do "1 leito livre não pode ser
referência". As duas Enfermarias rodam em paralelo, cada uma com sua
própria capacidade de leitos; a Enfermaria Pediátrica usa o mesmo
cronograma da Enfermaria Adulto.

Cada unidade continua com **um único link** de lançamento
(`lancamento.html?u=barreiro`) — dentro da página, a pessoa escolhe qual
dos três tipos está preenchendo.

### 2. Cronograma de atraso por tipo

- **Sala Vermelha:** padrão a cada 2h (00, 02, 04… 22h), com 15 minutos de
  tolerância.
- **Enfermaria Adulto e Enfermaria Pediátrica:** cronograma próprio, só
  **9h e 20h**, com 45 minutos de tolerância (ajustável na função
  `fn_tolerancia` do `schema.sql`).

O dashboard mostra, para cada card, se o último lançamento está **"No
horário"** ou **"Atrasado"** — e quem atrasa fica com destaque visual
(contorno vermelho no card) e um selo "⏱ atrasado", além do nome e cargo
de quem fez o último lançamento.

### 3. Alerta de pendências

Um banner vermelho aparece no topo do dashboard sempre que houver
qualquer unidade (de qualquer um dos três tipos) com lançamento atrasado.

### 4. Lotação acima da capacidade

O campo de pacientes internados não tem limite máximo. Quando o número
ultrapassa os leitos cadastrados:
- A tela de lançamento mostra um alerta imediato.
- O card no dashboard ganha o selo "⚠ acima da capacidade".
- Vagas aparecem como número negativo, destacado em vermelho.
- Cada ocorrência fica registrada no histórico normalmente.

### 5. Relatórios (`relatorios.html`)

Escolha um período (semanal, mensal, semestral, anual ou customizado) e o
tipo (Sala Vermelha, Enfermaria Adulto, Enfermaria Pediátrica, ou todos).
O relatório mostra, por unidade: registros no período, ocupação média e
máxima, registros acima da capacidade, e máximo de pacientes já
registrado. Dá para baixar em CSV. O cálculo roda dentro do banco (função
`relatorio_ocupacao`), então funciona mesmo com um ano inteiro de
histórico.

### 6. Nome e cargo obrigatórios

A tela de lançamento exige nome e cargo de quem preenche — validado no
formulário e reforçado no banco (`NOT NULL`).

### 7. Visual

Borda colorida lateral dos cards mais grossa (10px). O nível **Preto**
(≥85%) usa preto de verdade (`#000000`) em vez do tom avermelhado escuro
usado antes.

### 8. Relatórios só por link direto

Não há mais atalho para `relatorios.html` a partir do dashboard —
compartilhe o link só com quem precisa extrair relatórios.

### 9. Enfermaria Pediátrica

Terceiro tipo de unidade, em paralelo à Sala Vermelha e à Enfermaria
Adulto. Mesmo link de lançamento de sempre — a pessoa escolhe entre os
três tipos dentro da página. Cronograma e tolerância iguais aos da
Enfermaria Adulto (9h e 20h, 45 min). Dashboard e relatórios ganharam uma
terceira aba/filtro.

## Passo a passo de instalação

### 1. Criar o projeto Supabase (só na primeira vez)

supabase.com → **New Project**. Guarde a senha do banco.

### 2. Rodar o schema

**SQL Editor** → cole o `schema.sql` inteiro → **Run**.

Isso cria as 9 UPAs e a capacidade de leitos dos três tipos (Sala
Vermelha com os valores já usados antes; Enfermaria Adulto e Pediátrica
com valores de exemplo — **ajuste em Table Editor → `capacidade_leitos`**
para os números reais de cada unidade; se alguma unidade não tiver
Enfermaria Pediátrica, apague a linha dela nessa tabela).

### 3. Pegar as chaves

**Project Settings → API** → copie a `Project URL` e a chave pública
(`anon` / `publishable`). Cole nos **três** arquivos HTML
(`lancamento.html`, `dashboard.html`, `relatorios.html`).

### 4. Hospedar no GitHub Pages

Suba os arquivos para o repositório institucional e ative o GitHub Pages.

### 5. Links de lançamento (um por UPA)

```
.../lancamento.html?u=barreiro
.../lancamento.html?u=centro_sul
.../lancamento.html?u=leste
.../lancamento.html?u=nordeste
.../lancamento.html?u=noroeste
.../lancamento.html?u=norte
.../lancamento.html?u=oeste
.../lancamento.html?u=pampulha
.../lancamento.html?u=venda_nova
```

Cada link atende Sala Vermelha, Enfermaria Adulto e Enfermaria
Pediátrica — a pessoa escolhe dentro da página.

### 6. Dashboard e relatórios

```
.../dashboard.html
.../relatorios.html
```

O link de relatórios não aparece no dashboard — compartilhe
`.../relatorios.html` só com quem precisa extrair relatórios.

## Sobre a heartbeat / pausa por inatividade

O workflow `.github/workflows/heartbeat.yml` (se presente no seu
repositório) faz uma leitura diária no Supabase para evitar a pausa por
inatividade do plano gratuito. Ao subir os arquivos deste pacote, mantenha
essa pasta e confira na aba **Actions** do GitHub se ele está ativo.

## Segurança

Mesmo modelo de sempre: quem tem o link de uma unidade pode lançar dados
para ela, sem autenticação adicional — reproduz o nível de confiança da
planilha original. Reforços possíveis (Supabase Auth por unidade, ou uma
Edge Function validando token) continuam sendo incrementos futuros.
