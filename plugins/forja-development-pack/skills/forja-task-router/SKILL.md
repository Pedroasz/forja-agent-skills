---
name: forja-task-router
description: Use when classifying FORJA tasks, requests, incidents, migrations, frontend changes, or documentation work before selecting FORJA skills.
---

# Route FORJA Tasks

## Purpose

Classifique a solicitação antes de planejar, alterar ou executar qualquer ação no FORJA.

## Trigger conditions

Use para trabalho FORJA que envolva documentação, frontend, UX/acessibilidade, performance, autenticação, armazenamento, RLS, migration, testes, review, release, recovery, incidente ou produção.

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

**Composition rule:** The highest risk determines the risk level and gates but NEVER replaces lower-risk applicable skills.

## Workflow

Confirme o escopo FORJA, classifique todos os sinais, aplique cada overlay focado do contrato, componha todas as skills aplicáveis e somente então use o maior risco para aprovações, proibições e parada. Não deixe um incidente CRITICAL apagar recovery, testes ou documentação; não deixe uma migration HIGH apagar frontend ou UX.

## Required checks

Verifique projeto, todos os sinais focados, nível de risco, nomes das skills selecionadas e deliberadamente omitidas, oito campos obrigatórios, aprovações, proibições e plano de validação. Não invente evidência.

## Stop conditions

Pare antes de ação destrutiva em produção, comando remoto de banco, deploy, dados reais, credenciais ou atividade fora da autoridade explícita. Para CRITICAL, aguarde autoridade de incidente.

## Failure recovery

Se faltar escopo, sinal de risco ou aprovação, não execute. Registre a lacuna no campo apropriado e solicite a informação ou autoridade necessária.

## Handoff or next skills

Componha os handoffs: frontend funcional para `forja-safe-frontend-change`; keyboard, focus, contrast, modal ou accessibility também para `forja-ux-accessibility`; performance para `forja-performance-audit`; explicit test strategy para `forja-test-strategy`; documentation, evidence ou report para `forja-documentation`; review para `forja-independent-review`; release para `forja-release-pipeline`; restore, rollback, recovery ou copy-first para `forja-data-recovery`; confirmed outage, incident ou data loss para `forja-incident-response`; schema, RLS ou migration para `forja-supabase-migration`, `forja-auth-storage-safety` e `forja-test-strategy`.

## Completion evidence

Conclua somente quando os oito campos estiverem completos, a seleção refletir os sinais da solicitação e as condições de parada estiverem explícitas.
