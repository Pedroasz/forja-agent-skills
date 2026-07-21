---
name: forja-incident-response
description: Use when a confirmed FORJA incident, outage, data loss, or production error needs CRITICAL containment, evidence preservation, investigation, and incident authority before action.
---

# Responder a incidentes do FORJA

## Purpose

Conduza resposta **CRITICAL** a incidente confirmado preservando fatos verificáveis antes de qualquer correção. Priorize pessoas, integridade dos dados e uma linha de evidência confiável; não busque culpados.

## Trigger conditions

Use para um confirmed incident, outage, data loss ou production error do FORJA, sobretudo quando envolver produção, dados reais ou risco de ação irreversível. Um cenário hypothetical de sync/produção também pode selecionar esta skill somente para planejamento, sem declarar ou executar um incidente.

## Do not trigger when

Não use para bug local comum, teste isolado ou alteração de desenvolvimento sem evidência de incidente, impacto em produção, outage ou perda de dados. Não eleve um caso apenas porque usa palavras como sync, log ou erro; classifique pelos fatos observados.

## Required inputs

Receba escopo e impacto observados, ambiente, início conhecido ou desconhecido, timestamp ISO-8601 válido, hash ou snapshot não-placeholder, log reference não-placeholder, cadeia de custódia (chain) com trilha de responsáveis e owner identificado. Receba também explicit incident authority estruturada (nome, papel ou ID), limites de atuação, contatos de status e evidência de rollback/recovery disponível. Rejeite `unknown`, `now`, `yes` e valores genéricos; redija secret, credential e PII.

## Expected outputs

Entregue `incidentState`, `risk`, `sequence`, `executionAllowed` e `evidencePreserved`, distinguindo confirmado, hypothetical e não incidente. `evidencePreserved` só é verdadeiro com todos os pré-requisitos validados independentemente. Para caso confirmado, `risk` é CRITICAL e a sequence é exatamente `contain → preserve → classify → investigate → communicate → fix → verify → document`; informe fatos, lacunas, owner e próximo ponto de decisão, sem inventar IDs ou certeza.

## Risk classification

Incidente confirmado, outage, data loss ou production error é **CRITICAL**; o maior risco prevalece. `executionAllowed` só pode ser verdadeiro para `authorized reversible containment`, com evidência integral preservada e explicit incident authority estruturada. Cleanup, restart, destructive fix, production mutation e qualquer ação destrutiva sobre production data ou logs — delete, drop, truncate, purge, wipe, erase, remove/removal — permanecem proibidos por este gate, mesmo quando ele estiver verdadeiro; exigem autorização específica separada e plano de reversão. Não execute rollback ou recovery sem explicit incident authority, plano de reversão e escopo aprovado.

## Workflow

Leia [incident-runbook.md](references/incident-runbook.md) e siga, nesta ordem: **contain → preserve → classify → investigate → communicate → fix → verify → document**. Contain: reduza exposição somente com medida reversível autorizada. Preserve: registre timestamp, hash/snapshot, log reference, chain e owner antes de mudar estado. Classify: confirme ou mantenha hypothetical. Investigate: formule hipóteses a partir das evidências. Communicate: publique status verdadeiro e cadence acordada. Fix: proponha correção e rollback/recovery para autoridade. Verify: confirme a recuperação dentro do escopo observado. Document: registre executado, observado, planejado e não executado.

## Required checks

Antes de qualquer correção, confirme timestamp ISO-8601, hash ou snapshot não-placeholder, log reference não-placeholder, chain com trilha e owner identificado. Faça no log deletion, cleanup, restart, destructive fix, delete, drop, truncate, purge, wipe, erase, removal de production data/logs ou production mutation antes da preservação e da explicit incident authority. Verifique a intenção da ação, não menções negativas como `do not delete` em um plano de evidências. Verifique que a contenção é reversível, que `executionAllowed` depende de todos esses checks e de autoridade estruturada, que o status não promete além da evidência, e que toda correção aprovada possui rollback/recovery handoff e critério de verify.

## Stop conditions

Pare e escale quando faltar evidência preservada, owner, autoridade, escopo, plano de rollback/recovery ou critério de sucesso. Pare antes de apagar logs, cleanup, restart, ação destrutiva, produção ou mutação remota. Caso hypothetical não permite alegar incidente confirmado nem executar contenção, investigação em sistemas reais ou fix.

## Failure recovery

Se uma ação falhar ou a evidência estiver incompleta, preserve o estado e o registro disponível, marque a lacuna e retorne à etapa preserve/classify; não limpe logs nem reinicie para “tentar de novo”. Reavalie a contenção reversível com a autoridade, prepare rollback/recovery e mantenha a cadeia de handoff até haver verify observável.

## Handoff or next skills

Encaminhe plano de validação para `forja-test-strategy`; migration, RLS ou schema para `forja-supabase-migration`; autenticação, tenant ou Storage para `forja-auth-storage-safety`; e recuperação controlada para `forja-data-recovery`. Preserve a coordenação da autoridade de incidente e do owner durante todo o handoff.

## Completion evidence

Conclua apenas com incidentState, risco CRITICAL quando aplicável, sequence concluída ou interrompida, evidências preservadas e referências seguras a timestamp, hash/snapshot, log reference, chain e owner. Registre status/cadence, impacto confirmado, comunicação enviada, fix/rollback/recovery aprovado, verify observado e pendências. Aplique `no blame`; não inclua secret ou PII.
