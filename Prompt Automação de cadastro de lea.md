Prompt: Automação de cadastro de leads no n8n
Atue como um especialista em automação de processos, integrações de APIs e desenvolvimento de workflows no n8n.

Sua tarefa é planejar uma automação completa, confiável e organizada para registrar leads automaticamente, validar seus dados, evitar duplicidades e notificar a equipe comercial por e-mail.

1. Objetivo
Criar um workflow no n8n que receba os dados de novos leads, valide as informações, verifique se o lead já existe no banco de dados mantido no Google Sheets, registre os novos leads válidos e envie uma notificação à equipe comercial por meio do Gmail.

O público beneficiado é a equipe comercial, que utilizará as informações para acompanhar e contatar potenciais clientes.

2. Ferramentas envolvidas
Utilize as seguintes ferramentas:

n8n para orquestrar o processo.
Google Sheets para armazenar e consultar os leads.
Gmail para enviar as notificações.
Webhook ou formulário integrado como mecanismo de entrada dos dados.
Se houver mais de uma alternativa de implementação, apresente a mais simples e confiável e explique as diferenças relevantes.

3. Estrutura dos dados
Considere que cada lead poderá conter os seguintes campos:

nome;
email;
telefone;
empresa;
origem;
data de recebimento.
Os campos nome e email devem ser obrigatórios. Telefone, empresa e origem podem ser opcionais.

Sugira uma estrutura de colunas para a planilha do Google Sheets, incluindo uma coluna para a data de cadastro e outra para o status do registro.

4. Lógica do workflow
Desenvolva o fluxo na seguinte ordem:

Receber o lead: utilizar um nó Webhook ou outro gatilho apropriado para receber os dados.
Normalizar os dados: remover espaços desnecessários e normalizar o endereço de e-mail para letras minúsculas. Preservar os demais dados necessários.
Validar os campos: verificar se nome e e-mail estão preenchidos e se o e-mail apresenta um formato válido. Não considerar uma validação sintática como garantia de que o endereço realmente existe.
Decidir sobre a validade: utilizar um nó IF ou equivalente para separar os registros válidos dos inválidos. Registros inválidos não devem ser cadastrados nem gerar notificações de sucesso.
Verificar duplicidade: consultar o Google Sheets para verificar se já existe um registro com o mesmo e-mail normalizado.
Tratar duplicidades: se o lead já existir, encerrar o caminho de novo cadastro sem adicionar outra linha nem enviar uma notificação de novo lead.
Cadastrar o lead: se o registro for válido e inédito, adicionar uma nova linha ao Google Sheets.
Confirmar o cadastro: somente prosseguir para a notificação de sucesso após a operação de gravação ser concluída com sucesso.
Notificar a equipe: utilizar o Gmail para enviar uma mensagem com os dados relevantes do novo lead.
Registrar o resultado: manter informações sobre o sucesso, a duplicidade, a rejeição por validação ou a falha técnica, evitando armazenar dados sensíveis desnecessários.
5. Nós do n8n recomendados
Explique quais nós devem ser utilizados e como configurá-los.

Considere, conforme a versão do n8n e as operações disponíveis:

Webhook: receber os dados do lead.
Edit Fields (Set): organizar e normalizar os campos.
IF: validar os dados e direcionar os caminhos.
Google Sheets: consultar registros existentes e adicionar novas linhas.
Gmail: enviar a notificação.
NoOp ou um nó equivalente: encerrar caminhos de duplicidade ou rejeição, quando apropriado.
Error Trigger ou mecanismos de tratamento de erros: monitorar falhas de execução, conforme a estratégia escolhida.
Utilize nós Code somente se as expressões e os nós nativos não forem suficientes.

Não invente opções de configuração. Se uma operação depender da versão do n8n, explique como verificar a opção correspondente na interface.

6. Regras de negócio
A automação deve respeitar as seguintes regras:

Não cadastrar registros sem nome ou e-mail válido.
Normalizar os e-mails antes de compará-los.
Evitar duplicidades com base no e-mail normalizado.
Não notificar a equipe sobre registros rejeitados ou duplicados como se fossem novos leads.
Enviar a notificação somente depois do cadastro bem-sucedido.
Preservar os registros já cadastrados caso o envio do Gmail falhe.
Permitir a recuperação de notificações que falharem, sem inserir novamente o mesmo lead.
Tratar campos opcionais ausentes.
Não expor credenciais nos dados de execução ou nas mensagens de erro.
Considerar a possibilidade de duas execuções simultâneas tentarem cadastrar o mesmo e-mail.
Explique que uma consulta seguida de uma inserção pode não impedir todas as duplicidades quando há execuções simultâneas. Proponha uma estratégia apropriada para reduzir esse risco, como controle de concorrência ou armazenamento com restrição de unicidade, se necessário.

7. Tratamento de erros
Descreva como o workflow deverá reagir aos seguintes problemas:

Dados obrigatórios ausentes.
E-mail em formato inválido.
Lead já cadastrado.
Falha de autenticação ou indisponibilidade do Google Sheets.
Erro ao inserir uma nova linha.
Falha no envio pelo Gmail.
Limites de requisições ou indisponibilidade temporária de um serviço.
Diferencie erros de validação de erros técnicos. Explique quando utilizar novas tentativas, intervalos entre tentativas e um fluxo de tratamento de erros.

Se o cadastro for concluído, mas a notificação falhar, não refaça automaticamente a inserção do lead. Proponha um mecanismo de reprocessamento da notificação, como uma fila de pendências ou uma coluna de status, e explique suas limitações.

8. Modelo de notificação
Crie um exemplo de e-mail enviado à equipe comercial com:

Assunto: Novo lead cadastrado.
Nome do lead.
E-mail.
Telefone, quando disponível.
Empresa, quando disponível.
Origem e data de cadastro, quando disponíveis.
A mensagem deve ser objetiva, legível e adequada ao uso profissional.

9. Formato da resposta
Organize sua resposta nas seguintes seções:

Visão geral da solução.
Estrutura sugerida da planilha.
Diagrama textual do workflow.
Lista dos nós na ordem de execução.
Configuração de cada nó, incluindo os campos relevantes e as expressões necessárias.
Regras de validação e prevenção de duplicidades.
Tratamento de erros e estratégia de recuperação.
Modelo de e-mail de notificação.
Passo a passo para implementar e testar o workflow.
Checklist final de validação.
Inclua expressões de exemplo compatíveis com o n8n e, quando necessário, trechos de código prontos para uso. Explique onde cada expressão ou código deve ser inserido.

Não afirme que o workflow foi criado, executado ou testado. O objetivo é fornecer um plano de implementação detalhado que possa ser seguido no editor do n8n.

Ao final, apresente um checklist para verificar o cadastro válido, a rejeição de e-mails inválidos, a detecção de duplicidades, o envio de notificações e a recuperação de falhas.

Como utilizar o prompt
Copie o Passo 3 — Prompt final completo.

Cole o texto em uma IA capaz de gerar instruções técnicas ou workflows para o n8n.

Revise as configurações propostas e conecte suas credenciais do Google Sheets e do Gmail diretamente no n8n.

Teste o fluxo com leads válidos, e-mails inválidos, registros duplicados e falhas simuladas antes de colocá-lo em produção.

Observação importante: para uma automação real, é necessário definir o endereço da planilha, as colunas utilizadas, o destinatário das notificações e a origem dos leads. Esses detalhes podem ser adicionados depois, sem alterar a estrutura principal do prompt.

Você disse:
gere o prompt em md

O ChatGPT disse:
Segue o prompt completo em Markdown (.md), pronto para copiar e salvar como prompt_automacao_leads_n8n.md.

Escrita

Prompt: Automação de Cadastro de Leads no n8n
1. Papel da IA
Atue como um especialista em automação de processos, integrações de APIs e desenvolvimento de workflows no n8n.

Sua tarefa é planejar uma automação completa, confiável e organizada para registrar leads automaticamente, validar seus dados, evitar duplicidades e notificar a equipe comercial por e-mail.

Apresente instruções claras, configurações práticas e exemplos que possam ser implementados diretamente no editor do n8n.

2. Objetivo da automação
Criar um workflow no n8n que execute as seguintes tarefas:

Receber os dados de novos leads.
Validar as informações recebidas.
Verificar se o lead já está cadastrado.
Salvar os novos leads no Google Sheets.
Enviar uma notificação para a equipe comercial por meio do Gmail.
Registrar resultados e tratar erros sem gerar cadastros duplicados.
Público-alvo: equipe comercial.

Resultado esperado: automatizar o registro dos leads, reduzir tarefas manuais e agilizar o acompanhamento de potenciais clientes.

3. Ferramentas envolvidas
Utilize as seguintes ferramentas:

n8n: orquestração e execução do workflow.
Google Sheets: armazenamento e consulta dos leads.
Gmail: envio de notificações por e-mail.
Webhook ou formulário integrado: entrada dos dados dos novos leads.
Escolha a alternativa mais simples e confiável para receber os dados. Caso existam diferentes opções, explique as vantagens e limitações de cada uma.

4. Estrutura dos dados
Cada lead poderá conter os seguintes campos:

Campo	Obrigatório	Descrição
nome	Sim	Nome completo do lead
email	Sim	Endereço de e-mail
telefone	Não	Telefone de contato
empresa	Não	Empresa do lead
origem	Não	Origem do lead
data_cadastro	Sim	Data e hora do cadastro
status	Sim	Situação do processamento
Sugira uma estrutura de colunas no Google Sheets que permita armazenar essas informações e acompanhar o processamento das notificações.

Considere também campos adicionais, se necessários, para controlar tentativas de envio e notificações pendentes.

5. Fluxo da automação
Implemente a seguinte lógica:

Receber os dados do lead por meio de um Webhook ou formulário integrado.
Normalizar os dados recebidos, removendo espaços desnecessários.
Converter o e-mail para letras minúsculas antes de utilizá-lo como identificador.
Validar os campos obrigatórios e verificar o formato do endereço de e-mail.
Se os dados forem inválidos, interromper o cadastro e registrar o motivo da rejeição.
Se os dados forem válidos, consultar o Google Sheets para verificar se o e-mail já está cadastrado.
Se o lead já existir, impedir a criação de um novo registro e não enviar uma notificação de novo lead.
Se o lead for válido e inédito, adicionar uma nova linha ao Google Sheets.
Confirmar o sucesso da operação de cadastro.
Enviar uma notificação pelo Gmail para a equipe comercial.
Registrar o resultado final do processamento.
Tratar falhas técnicas e permitir a recuperação das operações que não foram concluídas.
6. Nós recomendados do n8n
Explique como configurar os seguintes nós, utilizando os nomes e as operações disponíveis na versão do n8n considerada:

6.1. Webhook
Receber os dados do lead.
Definir o método HTTP apropriado.
Explicar como testar o recebimento dos dados.
Demonstrar um exemplo de payload JSON.
6.2. Edit Fields (Set)
Organizar os campos recebidos.
Normalizar o e-mail.
Preparar a data de cadastro.
Definir valores padrão para campos opcionais, quando necessário.
6.3. IF
Verificar se o nome está preenchido.
Validar se o e-mail está presente e possui formato aceitável.
Separar os registros válidos dos inválidos.
Direcionar o fluxo conforme o resultado das verificações.
6.4. Google Sheets
Consultar a planilha para identificar registros existentes.
Comparar os e-mails normalizados.
Adicionar novos leads somente quando não houver duplicidade.
Atualizar o status do processamento, quando necessário.
Explique as operações, os parâmetros e os mapeamentos de campos que devem ser configurados.

6.5. Gmail
Configurar o destinatário da equipe comercial.
Definir o assunto e o corpo do e-mail.
Inserir dinamicamente os dados do lead.
Executar o envio somente após a confirmação do cadastro.
6.6. Tratamento de erros
Considere o uso de mecanismos de novas tentativas, nós de tratamento de erros e fluxos de recuperação.

Explique quando utilizar o Error Trigger e como configurar alertas para falhas que exigem intervenção.

Utilize nós Code somente quando os recursos nativos e as expressões do n8n não forem suficientes.

7. Regras de negócio
A automação deve respeitar rigorosamente as seguintes regras:

Não cadastrar leads sem nome ou e-mail válido.
Normalizar os e-mails antes de compará-los.
Evitar cadastros duplicados com base no e-mail normalizado.
Não enviar notificações de novos leads para registros inválidos ou duplicados.
Enviar a notificação somente depois que o cadastro for concluído com sucesso.
Não excluir nem duplicar o registro caso o Gmail falhe.
Permitir que notificações pendentes sejam reprocessadas sem inserir novamente o lead.
Aceitar campos opcionais ausentes sem interromper desnecessariamente o processamento.
Não expor senhas, tokens ou credenciais nos registros de execução.
Considerar execuções simultâneas que possam tentar cadastrar o mesmo e-mail.
Explique que consultar a planilha antes de inserir um registro não garante, por si só, a prevenção de duplicidades em execuções simultâneas.

Proponha uma estratégia adequada para reduzir esse risco, como limitar a concorrência do workflow ou utilizar um armazenamento com restrição de unicidade quando a consistência dos dados exigir maior garantia.

8. Tratamento de erros e recuperação
Explique como tratar cada uma das seguintes situações:

Nome ou e-mail ausente.
E-mail com formato inválido.
Lead já cadastrado.
Falha de autenticação do Google Sheets.
Indisponibilidade temporária do Google Sheets.
Erro ao inserir uma nova linha.
Falha no envio de e-mail pelo Gmail.
Limites de requisições das APIs.
Duas execuções tentando registrar o mesmo lead simultaneamente.
Defina estratégias para:

Separar erros de validação de erros técnicos.
Realizar novas tentativas em falhas temporárias.
Aplicar intervalos entre tentativas, quando apropriado.
Registrar o motivo das falhas.
Notificar o responsável quando houver erros que exijam intervenção.
Reprocessar notificações pendentes sem repetir o cadastro.
Regra crítica: se o cadastro for concluído, mas o envio do e-mail falhar, preserve o registro no Google Sheets e marque a notificação como pendente. O reprocessamento deve tentar enviar o e-mail sem inserir novamente o lead.

Explique como implementar esse mecanismo utilizando status e, se necessário, um workflow separado para processar notificações pendentes.

9. Modelo de notificação por e-mail
Crie um modelo profissional de e-mail com os seguintes requisitos:

Assunto: Novo lead cadastrado

Corpo da mensagem:

Olá, equipe comercial!

Um novo lead foi registrado automaticamente no sistema.

Nome: nome do lead
E-mail: e-mail do lead
Telefone: telefone, quando disponível
Empresa: empresa, quando disponível
Origem: origem, quando disponível
Data do cadastro: data e hora do registro
Acesse a planilha de leads para consultar as informações completas e realizar o acompanhamento comercial.

Atenciosamente,
Automação de Leads — n8n

Utilize expressões do n8n para preencher os campos dinamicamente. Explique como lidar com campos opcionais e evitar a inclusão de valores vazios ou indefinidos na mensagem.

10. Configuração das credenciais
Explique como configurar as credenciais do Google Sheets e do Gmail no n8n.

Inclua orientações sobre:

Autenticação e permissões necessárias.
Seleção da planilha e da aba.
Configuração do destinatário das notificações.
Proteção das credenciais.
Cuidados com dados pessoais dos leads.
Uso de variáveis e expressões sem expor informações sensíveis.
Não solicite que o usuário compartilhe senhas, tokens ou credenciais diretamente com a IA.

11. Exemplo de dados de entrada
Utilize o seguinte payload JSON como exemplo:

json
{
  "nome": "Maria Silva",
  "email": "maria.silva@example.com",
  "telefone": "11999999999",
  "empresa": "Empresa Exemplo",
  "origem": "Formulario do site"
}
Demonstre como os dados devem percorrer cada etapa do workflow até serem gravados na planilha e enviados por e-mail.

Utilize o domínio example.com apenas como exemplo fictício.

12. Cenários de teste
Crie uma tabela com os seguintes cenários:

Cenário	Resultado esperado
Lead válido e inédito	Registrar na planilha e enviar notificação
E-mail ausente	Rejeitar o cadastro
E-mail inválido	Rejeitar o cadastro
Nome ausente	Rejeitar o cadastro
E-mail já cadastrado	Não criar outra linha nem enviar notificação de novo lead
Falha no Google Sheets	Não enviar notificação de sucesso
Falha no Gmail após o cadastro	Preservar o registro e marcar a notificação como pendente
Nova tentativa de notificação	Enviar o e-mail sem duplicar o cadastro
Campos opcionais ausentes	Continuar o fluxo sem erros desnecessários
Execuções simultâneas	Aplicar a estratégia definida para reduzir duplicidades
Explique como executar cada teste e como verificar os resultados.

13. Formato obrigatório da resposta
Organize sua resposta final nas seguintes seções:

Visão geral da solução.
Estrutura da planilha do Google Sheets.
Diagrama textual do workflow.
Lista de nós na ordem de execução.
Configuração detalhada de cada nó.
Expressões prontas para copiar e colar.
Exemplo de payload e processamento dos dados.
Prevenção de duplicidades.
Tratamento de erros e recuperação.
Modelo de e-mail.
Passo a passo de implementação.
Plano de testes.
Checklist final para entrada em produção.
Sempre que apresentar uma expressão ou trecho de código, indique em qual campo ou nó ele deverá ser utilizado.

Utilize configurações compatíveis com o n8n e explique eventuais diferenças entre versões. Não invente parâmetros de nós ou opções de interface.

Se alguma informação estiver faltando, declare a suposição adotada e identifique o que deverá ser configurado pelo usuário.

Não afirme que o workflow foi criado, executado ou testado. Forneça um plano técnico detalhado para que o usuário possa implementá-lo e validá-lo.

14. Critérios de conclusão
Considere o planejamento concluído quando:

O fluxo estiver descrito de ponta a ponta.
Todos os nós estiverem identificados e suas funções explicadas.
As expressões necessárias estiverem documentadas.
A validação dos dados estiver definida.
A estratégia de prevenção de duplicidades estiver documentada.
As notificações forem enviadas somente após o cadastro bem-sucedido.
As falhas puderem ser identificadas e recuperadas.
Os cenários de teste estiverem definidos.
As instruções forem claras o suficiente para orientar a implementação no editor do n8n.