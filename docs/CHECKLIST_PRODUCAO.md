# ✅ Checklist de Entrada em Produção — leads-cadastro

Use este checklist antes de colocar o workflow em produção.  
Marque cada item somente após confirmar manualmente.

---

## 1. Configuração do ambiente

- [ ] Planilha criada no Google Sheets com a aba nomeada exatamente como `leads`
- [ ] Linha 1 da planilha contém os cabeçalhos na ordem correta: `id | nome | email | telefone | empresa | origem | data_cadastro | status_cadastro | status_notificacao | tentativas_notificacao | ultima_tentativa | observacoes`
- [ ] ID da planilha copiado e configurado nos três nós Google Sheets do workflow principal
- [ ] Credencial `Google Sheets OAuth2 API` criada e testada no n8n
- [ ] Credencial `Gmail OAuth2 API` criada e testada no n8n
- [ ] Destinatário de notificações configurado no nó `Notificar Equipe`
- [ ] Destinatário de alertas configurado no nó `Alertar Responsavel` (workflow de erros)

---

## 2. Configurações de segurança e concorrência

- [ ] `Max Concurrent Executions` definido como `1` em `Settings → Workflow Settings`
- [ ] Workflow `leads-monitoramento-erros` criado e **ativado**
- [ ] Workflow `leads-monitoramento-erros` configurado em `Settings → Error Workflow` do workflow principal
- [ ] Nenhuma credencial, token ou ID de planilha real está em campos de texto do workflow
- [ ] Arquivo `.env` (se existir) está listado no `.gitignore` e **não foi commitado**

---

## 3. Workflow auxiliar de renotificação

- [ ] Workflow `leads-renotificacao` criado e **ativado**
- [ ] Schedule Trigger configurado (frequência recomendada: 15 minutos)
- [ ] Filtro da consulta ao Google Sheets está correto: `status_notificacao = falha`
- [ ] Workflow **não insere** novas linhas — apenas atualiza o status

---

## 4. Validação e duplicidade

- [ ] Teste com **e-mail ausente** → fluxo encerrado sem inserção ✓
- [ ] Teste com **e-mail inválido** (sem @) → fluxo encerrado sem inserção ✓
- [ ] Teste com **nome ausente** → fluxo encerrado sem inserção ✓
- [ ] Teste com **lead duplicado** (mesmo e-mail, segunda chamada) → sem nova linha ✓
- [ ] E-mails com maiúsculas e espaços normalizados antes de comparar ✓

---

## 5. Cadastro e notificação

- [ ] Teste com **lead válido e inédito** → linha inserida na planilha + e-mail enviado ✓
- [ ] `status_notificacao` inicia como `pendente` e é atualizado para `enviado` após o Gmail ✓
- [ ] Notificação **nunca** é enviada antes do cadastro ser confirmado ✓
- [ ] Campos opcionais ausentes não interrompem o fluxo ✓

---

## 6. Tratamento de falhas

- [ ] Falha simulada no Gmail → `status_notificacao = falha` registrado na planilha ✓
- [ ] Workflow de renotificação consegue reenviar o e-mail sem duplicar o cadastro ✓
- [ ] Error Trigger do workflow principal ativa o monitoramento e envia alerta ✓
- [ ] Retries configurados nos nós Google Sheets e Gmail (`Max Tries: 3`, `Wait: 5s`) ✓
- [ ] `Continue on Fail` ativado nos nós Lookup e Append do Google Sheets ✓

---

## 7. Segurança e privacidade

- [ ] Dados pessoais dos leads armazenados apenas na planilha — não nos logs de execução
- [ ] Acesso à planilha restrito às contas necessárias (revisar permissões de compartilhamento)
- [ ] URL do webhook não exposta publicamente sem proteção (considere adicionar autenticação por header)
- [ ] Política de retenção de dados definida (LGPD / GDPR se aplicável)

---

> **Regra:** Todos os itens devem estar marcados antes de direcionar tráfego real para o webhook de produção.
