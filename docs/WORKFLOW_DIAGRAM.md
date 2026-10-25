# 📐 Diagramas dos Workflows — leads-cadastro

## Workflow Principal: `leads-cadastro`

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                        WORKFLOW PRINCIPAL: leads-cadastro                       │
│                   Concorrência máxima: 1 execução simultânea                    │
└────────────────────────────────────────────────────────────────────────────────┘

[1] Webhook (POST /leads)
        │
        │  payload: { nome, email, telefone?, empresa?, origem? }
        ▼
[2] Edit Fields — Normalizar Dados
        │  nome.trim()
        │  email.trim().toLowerCase()
        │  telefone?.trim() || ""
        │  empresa?.trim() || ""
        │  origem?.trim() || ""
        │  data_cadastro = $now.toISO()
        ▼
[3] IF — Validar Dados
        │  Condição 1: nome não vazio (AND)
        │  Condição 2: email não vazio (AND)
        │  Condição 3: email matches regex ^[^\s@]+@[^\s@]+\.[^\s@]+$
        │
        ├─── FALSE ────────────────────────────────────────────────────────┐
        │                                                                   │
        │                                           [4a] Edit Fields — Marcar Invalido
        │                                                  status_cadastro = "invalido"
        │                                                  status_notificacao = "nao_aplicavel"
        │                                                  observacoes = motivo
        │                                                   │
        │                                           [4b] NoOp — Encerrar Invalido
        │                                                  (fim do caminho de rejeição)
        │
        └─── TRUE ─────────────────────────────────────────────────────────┐
                                                                            │
                                              [5] Google Sheets — Buscar Lead Existente
                                                     Lookup: coluna email = $json.email
                                                     Continue on Fail: true
                                                                            │
                                                   ┌──── encontrou? ────────┤
                                                   │                        │
                                                   ▼ SIM (length > 0)     ▼ NÃO (length = 0)
                                    [6a] Edit Fields — Marcar Duplicado  [7] Edit Fields — Preparar Linha
                                           status_cadastro = "duplicado"       id = timestamp
                                           status_notificacao = "nao_aplicavel" status_cadastro = "novo"
                                                   │                            status_notificacao = "pendente"
                                    [6b] NoOp — Encerrar Duplicado              tentativas_notificacao = 0
                                           (fim do caminho duplicado)           │
                                                                        [8] Google Sheets — Cadastrar Lead
                                                                               Append Row (todas as 12 colunas)
                                                                               Continue on Fail: true
                                                                               Retry on Fail: 3x / 5s
                                                                                        │
                                                                        [9] Gmail — Notificar Equipe
                                                                               Send Email HTML
                                                                               Continue on Fail: true
                                                                               Retry on Fail: 3x / 5s
                                                                                        │
                                                                        ┌─── enviado? ───┤
                                                                        │                │
                                                                        ▼ SIM           ▼ NÃO (saída de erro)
                                                             [10a] GSheets Update  [10b] GSheets Update
                                                              status_notificacao    status_notificacao
                                                              = "enviado"           = "falha"
                                                              ultima_tentativa      ultima_tentativa
                                                              = $now.toISO()        = $now.toISO()
                                                                                    observacoes = motivo
```

---

## Workflow Auxiliar: `leads-renotificacao`

```
┌────────────────────────────────────────────────────────────────┐
│              WORKFLOW AUXILIAR: leads-renotificacao             │
│              Executa a cada 15 minutos automaticamente          │
│     Propósito: reenviar e-mails com status_notificacao = falha  │
│     NUNCA insere novas linhas na planilha                        │
└────────────────────────────────────────────────────────────────┘

[1] Schedule Trigger (a cada 15 min)
        │
        ▼
[2] Google Sheets — Buscar Pendentes
        │  Get All Rows onde status_notificacao = "falha"
        │  (também pode incluir "pendente" se desejar)
        │
        ▼
[3] IF — Há linhas pendentes?
        │  Condição: $items().length > 0
        │
        ├─── FALSE ──────────────────────┐
        │                                ▼
        │                    [NoOp] Nada a Fazer (fim)
        │
        └─── TRUE ───────────────────────┐
                                         ▼
                            [4] Gmail — Reenviar Notificacao
                                    (para cada linha retornada)
                                    Continue on Fail: true
                                         │
                            [5] Google Sheets — Atualizar Status
                                    status_notificacao = "enviado"
                                    ultima_tentativa = $now.toISO()
```

---

## Workflow de Monitoramento: `leads-monitoramento-erros`

```
┌────────────────────────────────────────────────────────────────┐
│          WORKFLOW: leads-monitoramento-erros                     │
│          Acionado automaticamente por falhas técnicas            │
│          Configurar em: Settings → Error Workflow               │
└────────────────────────────────────────────────────────────────┘

[1] Error Trigger
        │  Recebe dados do erro automaticamente do workflow principal
        │  { workflow.name, execution.lastNodeExecuted,
        │    execution.error.message, execution.id }
        │
        ▼
[2] Gmail — Alertar Responsavel
        │  Destinatário: responsavel-tecnico@suaempresa.com
        │  Assunto: ⚠️ Erro no workflow de leads — [nome do workflow]
        │  Corpo HTML com: workflow, nó, mensagem de erro, data/hora
```

---

## Legenda

| Símbolo | Significado |
|---|---|
| `[N]` | Número do nó na sequência |
| `│` | Fluxo de dados |
| `▼` | Direção do fluxo |
| `├──` | Bifurcação (saída condicional) |
| `└──` | Último ramo de bifurcação |
| `→` | Transição direta |
| `TRUE / FALSE` | Saídas do nó IF |
| `SIM / NÃO` | Resultado lógico após verificação |
