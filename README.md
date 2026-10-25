# 🤖 Automação de Cadastro de Leads — n8n

> Workflow completo para registrar leads automaticamente, validar dados, evitar duplicidades e notificar a equipe comercial por e-mail — usando **n8n + Google Sheets + Gmail**.

[![n8n](https://img.shields.io/badge/n8n-EA4B71?style=for-the-badge&logo=n8n&logoColor=white)](https://n8n.io/)
[![Google Sheets](https://img.shields.io/badge/Google%20Sheets-34A853?style=for-the-badge&logo=googlesheets&logoColor=white)](https://sheets.google.com)
[![Gmail](https://img.shields.io/badge/Gmail-D14836?style=for-the-badge&logo=gmail&logoColor=white)](https://gmail.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

---

## 📋 Sobre o projeto

Este repositório contém o **plano técnico completo** e os **artefatos de implementação** para uma automação de cadastro de leads no n8n, incluindo:

- 📐 Diagrama do workflow com todos os caminhos de execução
- ⚙️ Configuração detalhada de cada nó
- 🧮 Expressões prontas para copiar e colar
- 🛡️ Regras de validação e prevenção de duplicidades
- 🔁 Estratégia de recuperação de notificações com falha
- ✅ Checklist de entrada em produção com 22 itens

> **Importante:** Este repositório fornece um plano de implementação. O workflow deve ser criado e validado pelo usuário diretamente no editor do n8n.

---

## 🏗️ Arquitetura

```
Webhook POST /leads
        │
        ▼
Normalizar dados (email → minúsculas, trim)
        │
        ▼
Validar campos obrigatórios + regex de e-mail
        │
   ┌────┴────┐
   │         │
Inválido   Válido
   │         │
Encerrar  Buscar no Google Sheets
             │
        ┌────┴────┐
        │         │
   Duplicado    Novo
        │         │
   Encerrar   Cadastrar (Append Row)
                  │
              Notificar (Gmail)
                  │
             Atualizar status
```

---

## 📁 Estrutura do repositório

```
n8n-leads-automation/
├── README.md                          # Este arquivo
├── LICENSE                            # Licença MIT
├── .gitignore                         # Arquivos ignorados
│
├── docs/
│   ├── PLANO_COMPLETO.md              # Plano técnico detalhado (13 seções)
│   ├── WORKFLOW_DIAGRAM.md            # Diagrama textual ampliado
│   └── CHECKLIST_PRODUCAO.md         # Checklist de 22 itens para produção
│
├── workflows/
│   ├── leads-cadastro.json            # Workflow principal (template n8n)
│   ├── leads-renotificacao.json       # Workflow auxiliar de reenvio
│   └── leads-monitoramento-erros.json # Workflow de alertas de erro
│
├── sheets/
│   └── modelo-planilha.csv            # Estrutura de colunas para o Google Sheets
│
└── examples/
    ├── payload-valido.json            # Exemplo de lead válido
    ├── payload-email-invalido.json    # Exemplo de e-mail inválido
    ├── payload-campos-opcionais.json  # Exemplo sem campos opcionais
    └── curl-test-examples.sh          # Comandos curl para testes
```

---

## ⚡ Início rápido

### Pré-requisitos

- [n8n](https://n8n.io/) instalado (self-hosted ou cloud)
- Conta Google com acesso ao Google Sheets e Gmail
- Credenciais OAuth2 configuradas no n8n

### Passo a passo resumido

1. **Planilha** — Crie uma aba `leads` com os cabeçalhos do arquivo [`sheets/modelo-planilha.csv`](sheets/modelo-planilha.csv)
2. **Credenciais** — Configure `Google Sheets OAuth2 API` e `Gmail OAuth2 API` no n8n
3. **Workflows** — Importe os três arquivos `.json` da pasta [`workflows/`](workflows/)
4. **Concorrência** — Em `Settings → Workflow Settings`, defina `Max Concurrent Executions: 1`
5. **Erro** — Em `Settings → Error Workflow`, selecione `leads-monitoramento-erros`
6. **Teste** — Use os exemplos em [`examples/`](examples/) para validar todos os cenários

> Consulte o **[Plano Técnico Completo](docs/PLANO_COMPLETO.md)** para instruções detalhadas de cada etapa.

---

## 📊 Estrutura da planilha

| Coluna | Nome | Tipo | Obrigatório |
|---|---|---|---|
| A | `id` | Texto | Sim |
| B | `nome` | Texto | Sim |
| C | `email` | Texto | Sim |
| D | `telefone` | Texto | Não |
| E | `empresa` | Texto | Não |
| F | `origem` | Texto | Não |
| G | `data_cadastro` | ISO 8601 | Sim |
| H | `status_cadastro` | Enum | Sim |
| I | `status_notificacao` | Enum | Sim |
| J | `tentativas_notificacao` | Número | Sim |
| K | `ultima_tentativa` | ISO 8601 | Não |
| L | `observacoes` | Texto | Não |

---

## 🔧 Nós utilizados

| Nó | Tipo | Função |
|---|---|---|
| Receber Lead | Webhook | Entrada de dados via HTTP POST |
| Normalizar Dados | Edit Fields (Set) | Trim + lowercase no e-mail |
| Validar Dados | IF | Obrigatoriedade + regex de e-mail |
| Buscar Lead Existente | Google Sheets (Lookup) | Verificar duplicidade pelo e-mail |
| Preparar Linha | Edit Fields (Set) | Montar todos os campos para inserção |
| Cadastrar Lead | Google Sheets (Append Row) | Inserir nova linha |
| Notificar Equipe | Gmail (Send Email) | E-mail HTML para a equipe comercial |
| Atualizar Status | Google Sheets (Update Row) | Marcar `enviado` ou `falha` |
| Error Trigger | Error Trigger | Capturar falhas técnicas |

---

## 🛡️ Regras de negócio

- ❌ Não cadastra leads sem `nome` ou `email` válido
- 🔡 Normaliza e-mails (minúsculas, sem espaços) antes de comparar
- 🚫 Bloqueia duplicidades pelo e-mail normalizado
- 📧 Envia notificação **somente após** cadastro bem-sucedido
- 💾 Preserva o registro se o Gmail falhar (`status_notificacao = falha`)
- 🔁 Reprocessa notificações pendentes sem re-inserir o lead
- ⚙️ Limita concorrência a 1 execução para reduzir race conditions

---

## 📬 Modelo de e-mail

```
Assunto: Novo lead cadastrado: [Nome do Lead]

Olá, equipe comercial!

Um novo lead foi registrado automaticamente no sistema.

Nome:           Maria Silva
E-mail:         maria.silva@example.com
Telefone:       11999999999
Empresa:        Empresa Exemplo
Origem:         Formulário do site
Data cadastro:  2026-10-25T16:20:21Z

Acesse a planilha de leads para consultar as informações completas.

Automação de Leads — n8n
```

---

## 🧪 Cenários de teste

| Cenário | Resultado esperado |
|---|---|
| Lead válido e inédito | Linha inserida + e-mail enviado |
| E-mail ausente | Rejeitado, sem inserção |
| E-mail inválido | Rejeitado, sem inserção |
| Nome ausente | Rejeitado, sem inserção |
| Lead duplicado | Sem nova linha, sem novo e-mail |
| Falha no Google Sheets | Sem notificação de sucesso |
| Falha no Gmail após cadastro | Registro preservado, `status = falha` |
| Renotificação | E-mail enviado, sem duplicar cadastro |
| Campos opcionais ausentes | Fluxo continua normalmente |
| Execuções simultâneas | Estratégia de concorrência aplicada |

---

## 📚 Documentação completa

| Arquivo | Conteúdo |
|---|---|
| [`docs/PLANO_COMPLETO.md`](docs/PLANO_COMPLETO.md) | Plano técnico completo com 13 seções |
| [`docs/WORKFLOW_DIAGRAM.md`](docs/WORKFLOW_DIAGRAM.md) | Diagramas dos 3 workflows |
| [`docs/CHECKLIST_PRODUCAO.md`](docs/CHECKLIST_PRODUCAO.md) | 22 itens de validação antes de ir ao ar |

---

## ⚠️ Limitações conhecidas

- O Google Sheets **não possui restrição de unicidade nativa**. Limitar a concorrência para 1 execução reduz (mas não elimina completamente) o risco de duplicidades em cenários de carga muito alta.
- Para volumes elevados ou exigências críticas de consistência, considere substituir o Google Sheets por um banco relacional (PostgreSQL, Supabase).

---

## 📄 Licença

Distribuído sob a licença **MIT**. Veja [`LICENSE`](LICENSE) para mais informações.
