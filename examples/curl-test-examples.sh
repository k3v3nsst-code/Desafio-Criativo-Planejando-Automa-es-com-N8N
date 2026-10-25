#!/usr/bin/env bash
# =============================================================================
# Exemplos de teste via curl para o workflow de cadastro de leads (n8n)
#
# Substitua SEU_DOMINIO_N8N pelo endereço real do seu n8n.
# Em teste: use a URL com /webhook-test/ (somente com o editor aberto).
# Em produção: use a URL com /webhook/ (workflow ativo).
# =============================================================================

N8N_URL="https://SEU_DOMINIO_N8N"
WEBHOOK_PATH="leads"

# -----------------------------------------------------------------------------
# Cenário 1 — Lead válido e inédito
# Resultado esperado: linha inserida na planilha + e-mail enviado
# -----------------------------------------------------------------------------
echo "=== Cenário 1: Lead válido e inédito ==="
curl -s -X POST "${N8N_URL}/webhook-test/${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "Maria Silva",
    "email": "maria.silva@example.com",
    "telefone": "11999999999",
    "empresa": "Empresa Exemplo",
    "origem": "Formulario do site"
  }'
echo -e "\n"

# -----------------------------------------------------------------------------
# Cenário 2 — E-mail ausente
# Resultado esperado: rejeitado, nenhuma linha inserida
# -----------------------------------------------------------------------------
echo "=== Cenário 2: E-mail ausente ==="
curl -s -X POST "${N8N_URL}/webhook-test/${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "João Sem Email",
    "email": "",
    "telefone": "11777777777"
  }'
echo -e "\n"

# -----------------------------------------------------------------------------
# Cenário 3 — E-mail inválido (sem @)
# Resultado esperado: rejeitado pela regex
# -----------------------------------------------------------------------------
echo "=== Cenário 3: E-mail inválido ==="
curl -s -X POST "${N8N_URL}/webhook-test/${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "Pedro Invalido",
    "email": "nao-e-um-email",
    "telefone": "11666666666"
  }'
echo -e "\n"

# -----------------------------------------------------------------------------
# Cenário 4 — Nome ausente
# Resultado esperado: rejeitado
# -----------------------------------------------------------------------------
echo "=== Cenário 4: Nome ausente ==="
curl -s -X POST "${N8N_URL}/webhook-test/${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "",
    "email": "sem.nome@example.com"
  }'
echo -e "\n"

# -----------------------------------------------------------------------------
# Cenário 5 — Lead duplicado (enviar o mesmo do Cenário 1 novamente)
# Resultado esperado: sem nova linha, sem e-mail de novo lead
# -----------------------------------------------------------------------------
echo "=== Cenário 5: Lead duplicado ==="
curl -s -X POST "${N8N_URL}/webhook-test/${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "Maria Silva",
    "email": "maria.silva@example.com",
    "telefone": "11999999999",
    "empresa": "Empresa Exemplo",
    "origem": "Formulario do site"
  }'
echo -e "\n"

# -----------------------------------------------------------------------------
# Cenário 6 — Campos opcionais ausentes
# Resultado esperado: lead cadastrado com campos opcionais vazios
# -----------------------------------------------------------------------------
echo "=== Cenário 6: Apenas campos obrigatórios ==="
curl -s -X POST "${N8N_URL}/webhook-test/${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "Ana Souza",
    "email": "ana.souza@example.com"
  }'
echo -e "\n"

# -----------------------------------------------------------------------------
# Cenário 7 — E-mail com maiúsculas e espaços (deve ser normalizado)
# Resultado esperado: e-mail gravado como "carlos@example.com"
# -----------------------------------------------------------------------------
echo "=== Cenário 7: E-mail com maiúsculas e espaços ==="
curl -s -X POST "${N8N_URL}/webhook-test/${WEBHOOK_PATH}" \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "Carlos Lima",
    "email": "  CARLOS@EXAMPLE.COM  ",
    "telefone": "11555555555"
  }'
echo -e "\n"

echo "=== Testes concluídos. Verifique a planilha e a caixa de entrada do destinatário. ==="
