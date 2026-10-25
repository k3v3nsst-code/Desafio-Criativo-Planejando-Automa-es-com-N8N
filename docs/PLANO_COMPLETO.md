# Automação de Cadastro de Leads no n8n
> **Plano técnico de implementação** — Este documento não representa um workflow criado, executado ou testado. Ele fornece instruções detalhadas para que o usuário possa implementá-lo e validá-lo no editor do n8n.

---

## Sumário

1. [Visão Geral da Solução](#1-visão-geral-da-solução)
2. [Estrutura da Planilha no Google Sheets](#2-estrutura-da-planilha-no-google-sheets)
3. [Diagrama Textual do Workflow](#3-diagrama-textual-do-workflow)
4. [Lista de Nós na Ordem de Execução](#4-lista-de-nós-na-ordem-de-execução)
5. [Configuração Detalhada de Cada Nó](#5-configuração-detalhada-de-cada-nó)
6. [Expressões Prontas para Copiar e Colar](#6-expressões-prontas-para-copiar-e-colar)
7. [Exemplo de Payload e Processamento dos Dados](#7-exemplo-de-payload-e-processamento-dos-dados)
8. [Prevenção de Duplicidades](#8-prevenção-de-duplicidades)
9. [Tratamento de Erros e Estratégia de Recuperação](#9-tratamento-de-erros-e-estratégia-de-recuperação)
10. [Modelo de E-mail de Notificação](#10-modelo-de-e-mail-de-notificação)
11. [Passo a Passo de Implementação](#11-passo-a-passo-de-implementação)
12. [Plano de Testes](#12-plano-de-testes)
13. [Checklist Final para Entrada em Produção](#13-checklist-final-para-entrada-em-produção)

---

## 1. Visão Geral da Solução

### Arquitetura

O workflow principal é acionado por um **Webhook HTTP**. Ele recebe os dados brutos do lead, os normaliza, valida, verifica duplicidades no Google Sheets e, caso o lead seja novo e válido, registra e notifica a equipe comercial pelo Gmail.

Um segundo workflow auxiliar (opcional, mas recomendado) verifica periodicamente leads com notificação pendente e tenta reenviar o e-mail sem repetir o cadastro.

### Fluxo Resumido

```
Webhook → Normalizar → Validar → [Inválido? → Encerrar]
                                 [Válido?   → Verificar duplicidade]
                                             [Duplicado? → Encerrar]
                                             [Novo?      → Cadastrar → Notificar → Registrar sucesso]
```

### Decisões de Design

| Decisão | Escolha adotada | Justificativa |
|---|---|---|
| Entrada de dados | Webhook HTTP | Simples, compatível com qualquer formulário ou sistema externo |
| Armazenamento | Google Sheets | Baixo custo, acesso fácil pela equipe comercial |
| Notificação | Gmail | Integração nativa no n8n, sem configuração de servidor SMTP |
| Controle de duplicidade | Consulta + estratégia de concorrência | Descrito em detalhes na Seção 8 |
| Reenvio de notificação | Coluna de status + workflow auxiliar | Evita re-inserção acidental do lead |

> **Suposição adotada:** O n8n está hospedado com acesso público à internet (necessário para receber webhooks). Caso esteja em rede local, utilize ngrok ou um túnel equivalente durante os testes.

---

## 2. Estrutura da Planilha no Google Sheets

### Nome sugerido da aba: `leads`

| Coluna | Nome da coluna | Tipo | Obrigatório | Descrição |
|---|---|---|---|---|
| A | `id` | Texto | Sim | Identificador único gerado pelo n8n (UUID ou timestamp) |
| B | `nome` | Texto | Sim | Nome completo do lead |
| C | `email` | Texto | Sim | E-mail normalizado (minúsculas, sem espaços) |
| D | `telefone` | Texto | Não | Telefone de contato (pode estar vazio) |
| E | `empresa` | Texto | Não | Empresa do lead |
| F | `origem` | Texto | Não | Canal de origem (ex.: Formulário do site) |
| G | `data_cadastro` | Texto (ISO 8601) | Sim | Data e hora do cadastro no formato `YYYY-MM-DDTHH:mm:ssZ` |
| H | `status_cadastro` | Texto | Sim | `novo`, `duplicado`, `invalido` |
| I | `status_notificacao` | Texto | Sim | `pendente`, `enviado`, `falha` |
| J | `tentativas_notificacao` | Número | Sim | Contador de tentativas de envio (começa em `0`) |
| K | `ultima_tentativa` | Texto (ISO 8601) | Não | Data/hora da última tentativa de envio |
| L | `observacoes` | Texto | Não | Detalhes de erros ou informações adicionais |

### Cabeçalho da linha 1 (exatamente como deve aparecer na planilha)

```
id | nome | email | telefone | empresa | origem | data_cadastro | status_cadastro | status_notificacao | tentativas_notificacao | ultima_tentativa | observacoes
```

> **Importante:** O n8n usa os nomes das colunas da primeira linha para mapear os campos. Mantenha os nomes exatamente como definidos acima, sem espaços extras ou acentos, para evitar problemas de mapeamento.

---

## 3. Diagrama Textual do Workflow

### Workflow Principal: `leads-cadastro`

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        WORKFLOW PRINCIPAL: leads-cadastro                    │
└─────────────────────────────────────────────────────────────────────────────┘

[1] Webhook (POST /leads)
        │
        ▼
[2] Edit Fields — Normalizar dados
        │  (email.toLowerCase().trim(), nome.trim(), etc.)
        │
        ▼
[3] IF — Validar campos obrigatórios e formato do e-mail
        │
        ├── FALSE ──────────────────────────────────────────────────┐
        │                                                            ▼
        │                                            [4a] Edit Fields — Marcar como inválido
        │                                                            │
        │                                            [4b] NoOp — Encerrar (rejeição)
        │
        └── TRUE ───────────────────────────────────────────────────┐
                                                                    ▼
                                        [5] Google Sheets — Lookup (buscar por email)
                                                                    │
                                        ┌───── encontrou? ──────────┤
                                        │                           │
                                        ▼ SIM                      ▼ NÃO
                    [6a] Edit Fields — Marcar duplicado    [7] Edit Fields — Preparar linha
                                        │                           │
                    [6b] NoOp — Encerrar (duplicado)               ▼
                                                    [8] Google Sheets — Append Row
                                                                    │
                                                          ┌─── sucesso? ───┐
                                                          │                │
                                                          ▼ SIM           ▼ NÃO
                                              [9] Gmail — Enviar          [Erro técnico]
                                                     notificação          → Error Trigger
                                                          │
                                              ┌─── enviado? ───┐
                                              │                │
                                              ▼ SIM           ▼ NÃO
                                 [10a] Google Sheets      [10b] Google Sheets
                                  Update status=enviado    Update status=falha
```

### Workflow Auxiliar: `leads-renotificacao` (opcional)

```
[1] Schedule Trigger (a cada 15 min)
        │
        ▼
[2] Google Sheets — Buscar linhas com status_notificacao = "pendente"
        │
        ▼
[3] IF — Há linhas pendentes?
        │
        ├── FALSE → NoOp (nada a fazer)
        │
        └── TRUE
                │
                ▼
        [4] Gmail — Enviar notificação (dados da linha)
                │
                ▼
        [5] Google Sheets — Atualizar status_notificacao = "enviado"
```

---

## 4. Lista de Nós na Ordem de Execução

| # | Nó | Tipo | Função |
|---|---|---|---|
| 1 | `Receber Lead` | Webhook | Ponto de entrada dos dados |
| 2 | `Normalizar Dados` | Edit Fields (Set) | Limpar e padronizar os campos |
| 3 | `Validar Dados` | IF | Verificar obrigatoriedade e formato do e-mail |
| 4a | `Marcar Inválido` | Edit Fields (Set) | Preparar metadados de rejeição |
| 4b | `Encerrar Inválido` | NoOp | Terminar o caminho de rejeição |
| 5 | `Buscar Lead Existente` | Google Sheets (Lookup) | Consultar se o e-mail já está cadastrado |
| 6a | `Marcar Duplicado` | Edit Fields (Set) | Preparar metadados de duplicidade |
| 6b | `Encerrar Duplicado` | NoOp | Terminar o caminho de duplicidade |
| 7 | `Preparar Linha` | Edit Fields (Set) | Montar todos os campos para inserção |
| 8 | `Cadastrar Lead` | Google Sheets (Append Row) | Inserir nova linha na planilha |
| 9 | `Notificar Equipe` | Gmail (Send Email) | Enviar e-mail de novo lead |
| 10a | `Atualizar Status Enviado` | Google Sheets (Update Row) | Marcar notificação como enviada |
| 10b | `Atualizar Status Falha` | Google Sheets (Update Row) | Marcar notificação como falha |
| E | `Error Trigger` | Error Trigger | Capturar erros técnicos não tratados |

---

## 5. Configuração Detalhada de Cada Nó

---

### Nó 1 — `Receber Lead` (Webhook)

**Tipo:** `Webhook`

| Campo | Valor |
|---|---|
| HTTP Method | `POST` |
| Path | `leads` *(ou outro caminho desejado)* |
| Response Mode | `Immediately` (responde imediatamente ao chamador) |
| Response Code | `200` |
| Response Body | `{ "status": "recebido" }` |

**Como testar:**
Após ativar o nó em modo de teste, o n8n fornece uma URL temporária no formato:
```
https://SEU_DOMINIO_N8N/webhook-test/leads
```
Use o Postman, Insomnia ou `curl` para enviar um payload de teste:

```bash
curl -X POST https://SEU_DOMINIO_N8N/webhook-test/leads \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "Maria Silva",
    "email": "maria.silva@example.com",
    "telefone": "11999999999",
    "empresa": "Empresa Exemplo",
    "origem": "Formulario do site"
  }'
```

> **Nota:** Em produção, utilize a URL sem `-test`. O webhook de teste só funciona enquanto o editor está aberto e aguardando dados.

---

### Nó 2 — `Normalizar Dados` (Edit Fields / Set)

**Tipo:** `Edit Fields (Set)`  
**Modo:** `Keep Only Set` *(mantém somente os campos definidos aqui)*

| Nome do campo | Expressão n8n |
|---|---|
| `nome` | `{{ $json.nome?.toString().trim() \|\| "" }}` |
| `email` | `{{ $json.email?.toString().trim().toLowerCase() \|\| "" }}` |
| `telefone` | `{{ $json.telefone?.toString().trim() \|\| "" }}` |
| `empresa` | `{{ $json.empresa?.toString().trim() \|\| "" }}` |
| `origem` | `{{ $json.origem?.toString().trim() \|\| "" }}` |
| `data_cadastro` | `{{ $now.toISO() }}` |

> **Onde inserir:** Cada expressão vai no campo "Value" do item correspondente no nó `Edit Fields`. O operador `?.` torna o acesso seguro quando o campo não existe no payload.

---

### Nó 3 — `Validar Dados` (IF)

**Tipo:** `IF`  
**Combinar condições com:** `AND` (todas devem ser verdadeiras para o lead ser válido)

| # | Campo | Operação | Valor |
|---|---|---|---|
| 1 | `{{ $json.nome }}` | is not empty | — |
| 2 | `{{ $json.email }}` | is not empty | — |
| 3 | `{{ $json.email }}` | matches regex | `^[^\s@]+@[^\s@]+\.[^\s@]+$` |

**Saída TRUE:** lead com dados válidos → continua para verificação de duplicidade.  
**Saída FALSE:** lead inválido → vai para os nós `4a` e `4b`.

> **Sobre a regex:** O padrão `^[^\s@]+@[^\s@]+\.[^\s@]+$` valida a estrutura sintática básica de um e-mail (presença de `@` e domínio com ponto). Ele **não verifica** se o endereço realmente existe. Isso é suficiente para a maioria dos casos de uso.

> **Como inserir a regex no n8n:** No nó IF, selecione o tipo de condição `String` → operação `Regex`. Cole a expressão no campo "Value 1" e a regex no campo "Value 2".

---

### Nó 4a — `Marcar Inválido` (Edit Fields / Set)

**Tipo:** `Edit Fields (Set)`  
**Modo:** `Merge with existing data`

| Campo | Valor |
|---|---|
| `status_cadastro` | `invalido` |
| `status_notificacao` | `nao_aplicavel` |
| `observacoes` | `{{ $json.nome ? "E-mail inválido ou ausente" : "Nome ausente" }}` |

---

### Nó 4b — `Encerrar Inválido` (NoOp)

**Tipo:** `No Operation, do nothing`  

Apenas encerra o caminho de rejeição. Não realiza nenhuma ação. Pode ser conectado a um nó de log externo se necessário.

---

### Nó 5 — `Buscar Lead Existente` (Google Sheets — Lookup)

**Tipo:** `Google Sheets`  
**Operação:** `Lookup` (ou `Get Many Rows` com filtro, dependendo da versão do n8n)

| Campo | Valor |
|---|---|
| Credential | *(selecionar credencial OAuth2 configurada)* |
| Spreadsheet | *(ID ou URL da planilha)* |
| Sheet | `leads` |
| Lookup Column | `email` |
| Lookup Value | `{{ $json.email }}` |

> **Verificação de versão:** Em versões mais recentes do n8n (≥ 1.x), a operação pode se chamar `Search Rows` com um filtro de coluna. Em versões anteriores, é `Lookup`. Verifique na aba "Operations" do nó Google Sheets no seu ambiente.

**Lógica após o Lookup:**  
- Se retornar **ao menos uma linha** → lead duplicado → vai para `6a`/`6b`
- Se retornar **lista vazia** → lead novo → vai para `7`

Para separar esses caminhos, adicione um nó **IF** após o Lookup:

```
Condição: {{ $json.length > 0 }} equals true
```

Ou, se o nó retornar itens diretamente, use:
```
{{ $items().length > 0 }}
```

> **Atenção:** O comportamento do nó Lookup quando não há resultado varia entre versões. Em algumas versões, ele lança um erro quando não encontra nada. Configure o campo `Continue On Fail` como `true` e verifique se o output é vazio no IF seguinte.

---

### Nó 6a — `Marcar Duplicado` (Edit Fields / Set)

| Campo | Valor |
|---|---|
| `status_cadastro` | `duplicado` |
| `status_notificacao` | `nao_aplicavel` |
| `observacoes` | `Lead já cadastrado com este e-mail` |

---

### Nó 6b — `Encerrar Duplicado` (NoOp)

Encerra o caminho de duplicidade sem ação adicional.

---

### Nó 7 — `Preparar Linha` (Edit Fields / Set)

**Tipo:** `Edit Fields (Set)`  
**Modo:** `Keep Only Set`

| Campo | Expressão |
|---|---|
| `id` | `{{ $now.toMillis().toString() }}` |
| `nome` | `{{ $json.nome }}` |
| `email` | `{{ $json.email }}` |
| `telefone` | `{{ $json.telefone \|\| "" }}` |
| `empresa` | `{{ $json.empresa \|\| "" }}` |
| `origem` | `{{ $json.origem \|\| "" }}` |
| `data_cadastro` | `{{ $json.data_cadastro }}` |
| `status_cadastro` | `novo` |
| `status_notificacao` | `pendente` |
| `tentativas_notificacao` | `0` |
| `ultima_tentativa` | `` |
| `observacoes` | `` |

> **Sobre o `id`:** Usar o timestamp em milissegundos como ID é simples e funciona na maioria dos casos. Para maior robustez, utilize um nó `Code` com `crypto.randomUUID()` (disponível no n8n ≥ 0.177).

---

### Nó 8 — `Cadastrar Lead` (Google Sheets — Append Row)

**Tipo:** `Google Sheets`  
**Operação:** `Append or Update Row` (ou `Append Row` em versões anteriores)

| Campo | Valor |
|---|---|
| Credential | *(mesma credencial do nó 5)* |
| Spreadsheet | *(mesma planilha)* |
| Sheet | `leads` |
| Columns | Mapear cada coluna para o campo correspondente de `$json` |

**Mapeamento de colunas:**

| Coluna da planilha | Expressão |
|---|---|
| `id` | `{{ $json.id }}` |
| `nome` | `{{ $json.nome }}` |
| `email` | `{{ $json.email }}` |
| `telefone` | `{{ $json.telefone }}` |
| `empresa` | `{{ $json.empresa }}` |
| `origem` | `{{ $json.origem }}` |
| `data_cadastro` | `{{ $json.data_cadastro }}` |
| `status_cadastro` | `{{ $json.status_cadastro }}` |
| `status_notificacao` | `{{ $json.status_notificacao }}` |
| `tentativas_notificacao` | `{{ $json.tentativas_notificacao }}` |
| `ultima_tentativa` | `{{ $json.ultima_tentativa }}` |
| `observacoes` | `{{ $json.observacoes }}` |

> **Habilite `Continue on Fail`** para que um erro de inserção não interrompa o tratamento de erros do workflow.

---

### Nó 9 — `Notificar Equipe` (Gmail — Send Email)

**Tipo:** `Gmail`  
**Operação:** `Send Email`

| Campo | Valor |
|---|---|
| Credential | *(credencial OAuth2 do Gmail configurada)* |
| To | `equipe-comercial@suaempresa.com` |
| Subject | `Novo lead cadastrado: {{ $json.nome }}` |
| Email Type | `HTML` |
| Message | *(ver modelo completo na Seção 10)* |

> **Atenção:** O destinatário deve ser configurado pelo usuário diretamente no n8n. Não codifique endereços de e-mail reais neste documento.

---

### Nó 10a — `Atualizar Status Enviado` (Google Sheets — Update Row)

**Tipo:** `Google Sheets`  
**Operação:** `Update Row`

| Campo | Valor |
|---|---|
| Lookup Column | `email` |
| Lookup Value | `{{ $json.email }}` |
| `status_notificacao` | `enviado` |
| `ultima_tentativa` | `{{ $now.toISO() }}` |

---

### Nó 10b — `Atualizar Status Falha` (Google Sheets — Update Row)

Conectado à saída de erro do nó Gmail.

| Campo | Valor |
|---|---|
| Lookup Column | `email` |
| Lookup Value | `{{ $json.email }}` |
| `status_notificacao` | `falha` |
| `ultima_tentativa` | `{{ $now.toISO() }}` |
| `observacoes` | `Falha no envio do e-mail` |

---

### Nó Error Trigger — Monitoramento Global

**Tipo:** `Error Trigger`

Configure um workflow separado chamado `leads-monitoramento-erros` com um nó `Error Trigger` como gatilho. Esse workflow receberá automaticamente erros de execução do workflow principal.

Dentro dele, adicione um nó Gmail (ou Slack, se disponível) para notificar o responsável técnico:

```
Assunto: ⚠️ Erro no workflow de leads
Corpo: Workflow: {{ $json.workflow.name }}
       Nó com falha: {{ $json.execution.lastNodeExecuted }}
       Erro: {{ $json.execution.error.message }}
       Data: {{ $now.toISO() }}
```

> **Para ativar:** No workflow principal, vá em `Settings → Error Workflow` e selecione o workflow `leads-monitoramento-erros`.

---

## 6. Expressões Prontas para Copiar e Colar

### Normalização de e-mail
```javascript
{{ $json.email?.toString().trim().toLowerCase() || "" }}
```
*Onde usar:* Nó `Normalizar Dados`, campo `email`.

### Normalização de nome
```javascript
{{ $json.nome?.toString().trim() || "" }}
```
*Onde usar:* Nó `Normalizar Dados`, campo `nome`.

### Data de cadastro (ISO 8601)
```javascript
{{ $now.toISO() }}
```
*Onde usar:* Nó `Normalizar Dados`, campo `data_cadastro`.

### Validação de e-mail com regex (no nó IF)
```
^[^\s@]+@[^\s@]+\.[^\s@]+$
```
*Onde usar:* Nó `Validar Dados`, operação `Regex Match`, campo `email`.

### Campo opcional com fallback
```javascript
{{ $json.telefone || "Não informado" }}
```
*Onde usar:* Nó `Notificar Equipe`, corpo do e-mail, campos opcionais.

### ID único baseado em timestamp
```javascript
{{ $now.toMillis().toString() }}
```
*Onde usar:* Nó `Preparar Linha`, campo `id`.

### ID UUID (via nó Code, se necessário)
```javascript
// Nó Code - Language: JavaScript
const { randomUUID } = require('crypto');
return [{ json: { ...items[0].json, id: randomUUID() } }];
```
*Onde usar:* Nó `Code` entre `Preparar Linha` e `Cadastrar Lead`, somente se UUID for necessário.

### Verificar se o Lookup retornou resultados
```javascript
{{ $items("Buscar Lead Existente").length > 0 }}
```
*Onde usar:* Nó IF após o Lookup do Google Sheets, campo "Value 1" com tipo `Expression`.

### Corpo do e-mail HTML com campos condicionais
```html
<h2>Novo lead cadastrado</h2>
<p>Olá, equipe comercial!</p>
<p>Um novo lead foi registrado automaticamente no sistema.</p>
<table border="0" cellpadding="6">
  <tr><td><strong>Nome:</strong></td><td>{{ $json.nome }}</td></tr>
  <tr><td><strong>E-mail:</strong></td><td>{{ $json.email }}</td></tr>
  {{ $json.telefone ? `<tr><td><strong>Telefone:</strong></td><td>${$json.telefone}</td></tr>` : "" }}
  {{ $json.empresa ? `<tr><td><strong>Empresa:</strong></td><td>${$json.empresa}</td></tr>` : "" }}
  {{ $json.origem ? `<tr><td><strong>Origem:</strong></td><td>${$json.origem}</td></tr>` : "" }}
  <tr><td><strong>Data do cadastro:</strong></td><td>{{ $json.data_cadastro }}</td></tr>
</table>
<p>Acesse a planilha de leads para mais detalhes.</p>
<p><em>Automação de Leads — n8n</em></p>
```
*Onde usar:* Nó `Notificar Equipe`, campo `Message` com tipo `HTML`.

> **Nota:** A interpolação de template literals (`` ` ` ``) dentro de expressões n8n pode ter suporte variado dependendo da versão. Se apresentar erro, substitua pelo nó `Edit Fields` para montar o corpo do e-mail em etapas.

---

## 7. Exemplo de Payload e Processamento dos Dados

### Payload de entrada (enviado ao webhook)

```json
{
  "nome": "  Maria Silva  ",
  "email": "  MARIA.SILVA@example.com  ",
  "telefone": "11999999999",
  "empresa": "Empresa Exemplo",
  "origem": "Formulario do site"
}
```

### Dados após normalização (saída do nó 2)

```json
{
  "nome": "Maria Silva",
  "email": "maria.silva@example.com",
  "telefone": "11999999999",
  "empresa": "Empresa Exemplo",
  "origem": "Formulario do site",
  "data_cadastro": "2026-10-25T16:20:21.000Z"
}
```

### Dados após o nó `Preparar Linha` (saída do nó 7)

```json
{
  "id": "1761404421000",
  "nome": "Maria Silva",
  "email": "maria.silva@example.com",
  "telefone": "11999999999",
  "empresa": "Empresa Exemplo",
  "origem": "Formulario do site",
  "data_cadastro": "2026-10-25T16:20:21.000Z",
  "status_cadastro": "novo",
  "status_notificacao": "pendente",
  "tentativas_notificacao": 0,
  "ultima_tentativa": "",
  "observacoes": ""
}
```

### Linha gravada na planilha Google Sheets

| id | nome | email | telefone | empresa | origem | data_cadastro | status_cadastro | status_notificacao | tentativas | ultima_tentativa | observacoes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1761404421000 | Maria Silva | maria.silva@example.com | 11999999999 | Empresa Exemplo | Formulario do site | 2026-10-25T16:20:21Z | novo | pendente → enviado | 1 | 2026-10-25T16:20:23Z | |

---

## 8. Prevenção de Duplicidades

### Como funciona a verificação atual

O nó `Buscar Lead Existente` consulta a coluna `email` da planilha e retorna linhas que correspondam ao valor normalizado. Caso encontre pelo menos uma linha, o workflow encerra sem cadastrar novamente.

### Limitação: Race Condition (execuções simultâneas)

> **Problema:** Se dois webhooks forem recebidos ao mesmo tempo com o mesmo e-mail, ambos podem executar a consulta antes que qualquer um grave a linha. Nesse caso, ambos encontrarão a planilha sem o registro e ambos tentarão inserir, gerando duplicidade.

O Google Sheets **não oferece restrição de unicidade nativa** por coluna.

### Estratégias para mitigar o problema

#### Estratégia 1 — Limitar a concorrência do workflow (recomendada para n8n)

No n8n, vá em **Settings → Workflow Settings → Concurrency** e configure:

```
Max Concurrent Executions: 1
```

Isso força as execuções a serem enfileiradas, eliminando o risco de race condition. **Desvantagem:** pode aumentar a latência quando há alto volume de leads simultâneos.

#### Estratégia 2 — Usar banco de dados com restrição de unicidade

Substitua o Google Sheets por um banco relacional (PostgreSQL, MySQL) ou por serviços como o **Supabase** (gratuito), que permitem definir a coluna `email` como `UNIQUE`. Tentativas de inserção duplicada retornarão erro, que pode ser capturado e tratado.

**Quando usar:** quando o volume de leads for alto e a estratégia de concorrência única gerar gargalo.

#### Estratégia 3 — Combinação (Recomendada para produção)

1. Limitar concorrência para `1` ou `2` execuções.
2. Após a inserção, buscar novamente o e-mail e verificar se há mais de uma linha.
3. Se houver duplicidade pós-inserção, excluir a linha mais recente.

> **Declare ao usuário:** Nenhuma das estratégias baseadas em Google Sheets garante 100% de atomicidade. Para sistemas com volume muito alto ou exigências críticas de consistência, utilize um banco de dados relacional.

---

## 9. Tratamento de Erros e Estratégia de Recuperação

### Tabela de situações e respostas

| Situação | Tipo de erro | Resposta do workflow |
|---|---|---|
| Nome ausente | Validação | Nó IF → caminho FALSE → `Marcar Inválido` → `Encerrar` |
| E-mail ausente | Validação | Nó IF → caminho FALSE → `Marcar Inválido` → `Encerrar` |
| E-mail mal formatado | Validação | Nó IF → caminho FALSE → `Marcar Inválido` → `Encerrar` |
| Lead duplicado | Regra de negócio | Nó IF → duplicado → `Marcar Duplicado` → `Encerrar` |
| Falha de autenticação Google Sheets | Técnico | Error Trigger → notifica responsável |
| Indisponibilidade do Google Sheets | Técnico | Retry automático (configurar no nó) + Error Trigger |
| Erro ao inserir linha | Técnico | Continue on Fail + Error Trigger |
| Falha no envio do Gmail | Técnico | Nó 10b marca `status_notificacao = falha` |
| Limite de API (rate limit) | Técnico | Retry com backoff exponencial (ver abaixo) |
| Execuções simultâneas | Concorrência | Limitar concorrência para 1 (ver Seção 8) |

### Retries (novas tentativas)

No n8n, configure retries diretamente em cada nó sensível:

1. Clique no nó → `Settings` (ícone de engrenagem)
2. Ative **Retry on Fail**
3. Configure:
   - `Max Tries`: `3`
   - `Wait Between Tries`: `5000` ms (5 segundos)

> **Use retry em:** nós Google Sheets (inserção e leitura), nó Gmail.  
> **Não use retry em:** nós de validação e nós NoOp.

### Separação entre erros de validação e erros técnicos

- **Erros de validação** → tratados pelo nó IF. Nunca geram retry. Não acionam o Error Trigger.
- **Erros técnicos** → podem gerar retry. Acionam o Error Trigger se esgotarem as tentativas.

### Recuperação de notificações pendentes

**Problema:** O lead foi gravado na planilha (coluna `status_notificacao = pendente` ou `= falha`), mas o e-mail não foi enviado.

**Solução:** Workflow auxiliar `leads-renotificacao`:

1. **Trigger:** Schedule Trigger → a cada 15 minutos (ou conforme conveniência)
2. **Buscar:** Google Sheets → `Get Many Rows` com filtro `status_notificacao = pendente OR falha`
3. **Para cada linha:** Enviar e-mail + atualizar `status_notificacao = enviado`

> **Importante:** Este workflow **não insere** novas linhas. Ele apenas lê dados existentes e tenta reenviar a notificação. Isso garante que o lead não será duplicado mesmo que o reprocessamento seja executado múltiplas vezes.

**Limitação:** Se a planilha estiver com muitas linhas com status pendente, o workflow auxiliar pode demorar. Monitore o volume e ajuste o intervalo de execução conforme necessário.

### Não expor credenciais

- Nunca coloque tokens, senhas ou IDs de planilha diretamente em campos de texto do workflow.
- Use o sistema de **Credentials** do n8n para armazenar e referenciar credenciais.
- Em mensagens de erro, referencie apenas o tipo de falha, não os valores dos campos sensíveis.

---

## 10. Modelo de E-mail de Notificação

### Assunto

```
Novo lead cadastrado: {{ $json.nome }}
```

### Corpo (HTML)

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; color: #333; font-size: 14px; }
    h2 { color: #1a73e8; }
    table { border-collapse: collapse; margin-top: 12px; }
    td { padding: 6px 12px; border-bottom: 1px solid #eee; }
    td:first-child { font-weight: bold; color: #555; width: 140px; }
    .footer { margin-top: 20px; color: #888; font-size: 12px; border-top: 1px solid #eee; padding-top: 10px; }
  </style>
</head>
<body>
  <h2>📋 Novo lead cadastrado</h2>
  <p>Olá, equipe comercial!</p>
  <p>Um novo lead foi registrado automaticamente no sistema e está pronto para acompanhamento.</p>

  <table>
    <tr><td>Nome:</td><td>{{ $json.nome }}</td></tr>
    <tr><td>E-mail:</td><td>{{ $json.email }}</td></tr>
    <tr><td>Telefone:</td><td>{{ $json.telefone || "Não informado" }}</td></tr>
    <tr><td>Empresa:</td><td>{{ $json.empresa || "Não informada" }}</td></tr>
    <tr><td>Origem:</td><td>{{ $json.origem || "Não informada" }}</td></tr>
    <tr><td>Data do cadastro:</td><td>{{ $json.data_cadastro }}</td></tr>
  </table>

  <p style="margin-top: 16px;">
    Acesse a planilha de leads para consultar as informações completas e iniciar o acompanhamento comercial.
  </p>

  <div class="footer">
    Atenciosamente,<br>
    <strong>Automação de Leads — n8n</strong><br>
    Esta é uma mensagem automática. Não responda a este e-mail.
  </div>
</body>
</html>
```

> **Como inserir:** Cole o HTML acima no campo `Message` do nó Gmail. Certifique-se de que o campo `Email Type` está definido como `HTML`.

> **Campos opcionais:** Os campos `telefone`, `empresa` e `origem` usam o operador `||` com um valor padrão de texto. Isso evita que apareça `undefined` ou vazio na mensagem.

---

## 11. Passo a Passo de Implementação

### Etapa 1 — Preparar o Google Sheets

1. Crie uma nova planilha no Google Sheets.
2. Renomeie a primeira aba para `leads`.
3. Na linha 1, insira os seguintes cabeçalhos nas colunas A a L:
   ```
   id | nome | email | telefone | empresa | origem | data_cadastro | status_cadastro | status_notificacao | tentativas_notificacao | ultima_tentativa | observacoes
   ```
4. Anote o **ID da planilha** (parte da URL: `https://docs.google.com/spreadsheets/d/[ID_AQUI]/edit`).

---

### Etapa 2 — Configurar as credenciais no n8n

#### Google Sheets (OAuth2)
1. No n8n, vá em `Settings → Credentials → New`.
2. Selecione `Google Sheets OAuth2 API`.
3. Siga o fluxo de autenticação OAuth2 com sua conta Google.
4. Conceda permissão de leitura e escrita em planilhas.

#### Gmail (OAuth2)
1. Crie uma nova credencial `Gmail OAuth2 API`.
2. Autentique com a conta Google que enviará os e-mails.
3. Conceda permissão de envio de e-mails (`gmail.send`).

> **Importante:** Use contas Google separadas ou uma conta de serviço dedicada para automações em produção.

---

### Etapa 3 — Criar o workflow principal no n8n

1. Abra o editor do n8n e clique em `+ New Workflow`.
2. Nomeie como `leads-cadastro`.
3. Adicione e configure os nós na ordem da Seção 4.
4. Conecte os nós conforme o diagrama da Seção 3.
5. Configure as credenciais em cada nó que as exige.
6. Em `Settings → Workflow Settings → Concurrency`, defina `Max Concurrent Executions: 1`.
7. Em `Settings → Error Workflow`, selecione o workflow `leads-monitoramento-erros` (criar na Etapa 6).

---

### Etapa 4 — Testar o workflow

Execute os testes na seguinte ordem (ver Seção 12 para detalhes):

1. **Lead válido e inédito** — Verificar se a linha aparece na planilha e se o e-mail foi enviado.
2. **E-mail ausente** — Verificar se o caminho de rejeição é seguido.
3. **E-mail inválido** — Verificar se a regex bloqueia corretamente.
4. **Nome ausente** — Verificar rejeição.
5. **Lead duplicado** — Enviar o mesmo payload duas vezes e verificar que somente uma linha é inserida.
6. **Campos opcionais ausentes** — Enviar sem `telefone`, `empresa` e `origem`.
7. **Falha simulada no Gmail** — Configurar temporariamente uma credencial inválida no nó Gmail e verificar se `status_notificacao` é marcado como `falha`.

---

### Etapa 5 — Criar o workflow auxiliar de renotificação

1. Crie um novo workflow chamado `leads-renotificacao`.
2. Adicione um nó `Schedule Trigger` → frequência: a cada 15 minutos.
3. Adicione um nó `Google Sheets → Get Many Rows` com filtro `status_notificacao = falha`.
4. Adicione um nó `IF` para verificar se há linhas retornadas.
5. Para cada linha, conecte um nó `Gmail → Send Email` com o mesmo modelo da Seção 10.
6. Após o envio, atualize a linha com `status_notificacao = enviado`.

---

### Etapa 6 — Criar o workflow de monitoramento de erros

1. Crie um workflow chamado `leads-monitoramento-erros`.
2. Adicione um nó `Error Trigger` como gatilho.
3. Adicione um nó `Gmail → Send Email` para notificar o responsável técnico.
4. Ative o workflow.
5. Volte ao workflow `leads-cadastro` e configure-o em `Settings → Error Workflow`.

---

### Etapa 7 — Colocar em produção

1. Ative os três workflows (principal, renotificação e monitoramento).
2. Copie a URL de produção do webhook (sem `-test`).
3. Configure essa URL no formulário ou sistema de origem dos leads.
4. Monitore as primeiras execuções diretamente no painel do n8n (`Executions`).

---

## 12. Plano de Testes

| # | Cenário | Payload de teste | Resultado esperado | Como verificar |
|---|---|---|---|---|
| 1 | Lead válido e inédito | Todos os campos preenchidos, e-mail novo | Linha inserida na planilha; e-mail enviado; `status_notificacao = enviado` | Abrir a planilha e verificar a linha; checar caixa de entrada do destinatário |
| 2 | E-mail ausente | `{ "nome": "João", "email": "" }` | Nó IF → FALSE; nenhuma linha inserida; nenhum e-mail enviado | Verificar execução no painel; planilha sem nova linha |
| 3 | E-mail inválido | `{ "nome": "João", "email": "nao-e-um-email" }` | Mesmo resultado do cenário 2 | Idem |
| 4 | Nome ausente | `{ "nome": "", "email": "teste@example.com" }` | Nó IF → FALSE; rejeição | Idem |
| 5 | Lead duplicado | Mesmo payload do cenário 1, reenviado | Nó IF após Lookup → TRUE; nenhuma nova linha; nenhum e-mail de novo lead | Verificar que a planilha continua com apenas uma linha para aquele e-mail |
| 6 | Campos opcionais ausentes | `{ "nome": "Ana", "email": "ana@example.com" }` | Lead cadastrado; e-mail enviado com "Não informado" nos campos opcionais | Abrir e-mail recebido e conferir os campos |
| 7 | Falha no Gmail após cadastro | Credencial Gmail temporariamente inválida | Lead inserido na planilha; `status_notificacao = falha` | Verificar coluna da planilha |
| 8 | Reprocessamento de notificação pendente | Corrigir credencial Gmail; aguardar Schedule Trigger | E-mail enviado; `status_notificacao = enviado`; nenhuma linha duplicada | Verificar e-mail recebido e conferir que há apenas uma linha |
| 9 | E-mail com espaços e maiúsculas | `{ "email": "  JOAO@EXAMPLE.COM  " }` | E-mail normalizado para `joao@example.com` antes da comparação e do cadastro | Verificar coluna `email` na planilha |
| 10 | Execuções simultâneas | Enviar o mesmo payload duas vezes em rápida sucessão | Com concorrência = 1, apenas uma linha inserida | Verificar planilha; executar com ferramenta de teste de carga se necessário |

---

## 13. Checklist Final para Entrada em Produção

### Configuração do ambiente

- [ ] Planilha criada com os cabeçalhos corretos na linha 1
- [ ] ID da planilha anotado e configurado nos nós do Google Sheets
- [ ] Credencial OAuth2 do Google Sheets configurada e testada no n8n
- [ ] Credencial OAuth2 do Gmail configurada e testada no n8n
- [ ] Destinatário das notificações definido no nó Gmail
- [ ] Concorrência máxima do workflow principal definida como `1`
- [ ] Workflow de monitoramento de erros criado e ativado
- [ ] Workflow de renotificação criado e ativado

### Validação e duplicidade

- [ ] Teste com e-mail ausente → rejeitado sem inserção
- [ ] Teste com e-mail inválido → rejeitado sem inserção
- [ ] Teste com nome ausente → rejeitado sem inserção
- [ ] Teste com lead duplicado → segunda execução não insere nova linha
- [ ] E-mails com maiúsculas e espaços normalizados antes da comparação

### Cadastro e notificação

- [ ] Lead válido e inédito → linha inserida com todos os campos
- [ ] `status_notificacao` marcado como `pendente` antes do envio e como `enviado` após o sucesso
- [ ] Notificação enviada somente após confirmação do cadastro
- [ ] Campos opcionais ausentes não interrompem o fluxo

### Tratamento de erros

- [ ] Falha no Gmail → `status_notificacao = falha` registrado na planilha
- [ ] Workflow de renotificação envia o e-mail sem inserir nova linha
- [ ] Error Trigger notifica o responsável técnico em caso de falha técnica
- [ ] Retries configurados nos nós Google Sheets e Gmail
- [ ] Nenhuma credencial exposta nos campos de texto ou nas mensagens de erro

### Segurança e conformidade

- [ ] Dados pessoais armazenados apenas na planilha, não nos logs de execução
- [ ] Acesso à planilha restrito às contas necessárias
- [ ] URL do webhook protegida (considere adicionar autenticação por header)
- [ ] Plano de exclusão de dados definido, conforme as políticas de privacidade aplicáveis

---

> **Nota final:** Este documento é um plano de implementação. Todos os IDs de planilha, endereços de e-mail, nomes de credenciais e URLs de webhook devem ser configurados pelo usuário diretamente no editor do n8n. Nenhum workflow foi criado, executado ou testado automaticamente.
