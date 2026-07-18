---
name: forja-task-router
description: Use when classifying FORJA tasks, requests, incidents, migrations, frontend changes, or documentation work before selecting FORJA skills.
---

# Route FORJA Tasks

## Purpose

Classifique a solicitação antes de planejar, alterar ou executar qualquer ação no FORJA.

## Trigger conditions

Use para trabalho FORJA que envolva documentação, frontend, autenticação, armazenamento, RLS, migration, incidente ou produção.

## Do not trigger when

Não use para outro projeto. Declare que nenhuma skill FORJA foi selecionada e mantenha o trabalho fora deste pacote.

## Required inputs

Confirme projeto, resumo da solicitação, escopo, ambiente, dados envolvidos e qualquer autoridade já concedida.

## Expected outputs

Produza exatamente este registro:

- Task summary:
- Risk level:
- Selected skills:
- Skills deliberately not selected:
- Required approvals:
- Prohibited actions:
- Validation plan:
- Stop conditions:

## Risk classification

Consulte [o contrato de roteamento](references/routing-contract.md). Identifique todos os gatilhos, atribua LOW, MODERATE, HIGH ou CRITICAL e aplique o maior risco: **the highest risk prevails**.

## Workflow

Confirme o escopo FORJA, classifique os sinais da solicitação, selecione todas as skills aplicáveis e aplique as restrições mais rigorosas ao registro.

## Required checks

Verifique projeto, nível de risco, nomes das skills, oito campos obrigatórios, aprovações, proibições e plano de validação. Não invente evidência.

## Stop conditions

Pare antes de ação destrutiva em produção, comando remoto de banco, deploy, dados reais, credenciais ou atividade fora da autoridade explícita. Para CRITICAL, aguarde autoridade de incidente.

## Failure recovery

Se faltar escopo, sinal de risco ou aprovação, não execute. Registre a lacuna no campo apropriado e solicite a informação ou autoridade necessária.

## Handoff or next skills

Encaminhe documentação para `forja-documentation`; frontend funcional para `forja-safe-frontend-change` e `forja-test-strategy`; RLS ou migration para `forja-supabase-migration`, `forja-auth-storage-safety` e `forja-test-strategy`; incidente crítico para `forja-incident-response`.

## Completion evidence

Conclua somente quando os oito campos estiverem completos, a seleção refletir os sinais da solicitação e as condições de parada estiverem explícitas.
