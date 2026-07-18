---
name: forja-data-recovery
description: Use when a FORJA rollback, restore, recovery, or cache reversal can affect state or data and needs CRITICAL copy-first planning, simulation, authorization, and verification.
---

# Planejar recuperacao de dados do FORJA

## Purpose

Planeje recovery, restore ou rollback **CRITICAL** sem executar mudanca de estado. Preserve uma copia antes de qualquer mutacao e produza um gate verificavel para a menor recuperacao segura.

## Trigger conditions

Use para rollback de cache, restore de arquivo/objeto, recovery de dados, ou reversao de migration que possa afetar estado ou dados do FORJA. Uma pergunta hypothetical ou planning-only usa a skill somente para planejamento e nunca executa.

## Do not trigger when

Nao use para limpar cache comum, editar documentacao, ou reverter apenas codigo local sem dados ou estado. Nao use para outro projeto. Nao transforme um rollback de cache em restore amplo de dados sem evidencia de escopo.

## Required inputs

Exija os campos estruturados por linha `requested environment`, `requested action`, `requested scope`, `source`, `target` e `minimum scope`; normalize valores e rejeite placeholders. `source` e `target` devem ser distintos. Exija `copy-first`, `immutable snapshot`, `backup reference`, contagens de row, object ou file e checksum before/after, `read-only dry-run`, `rollback-of-recovery` e `post-verify`. Para producao, exija `authorization environment`, `authorization action` e `authorization scope` exatamente iguais aos campos requested; autorizacao por substring, escopo amplo ou IDs inventados nao vale.

## Expected outputs

Entregue `risk`, `copyPreserved`, `simulationPassed`, `minimumScope`, `countsChecksums`, `authorizationSpecific`, `executionAllowed` e `postVerify`. Registre fonte, alvo, copia imutavel, comparacoes before/after, lacunas e proximo gate; nao alegue execucao, restore ou verificacao nao observados.

## Risk classification

Classifique restore, rollback e recovery que possam afetar state/data como **CRITICAL**; o maior risco prevalece. Production, dados reais, migracao ou Storage continuam CRITICAL. `executionAllowed` so pode ser verdadeiro com todos os prerequisitos validados, authorization especifica e nenhuma intencao destrutiva ampla.

## Workflow

Leia [recovery-runbook.md](references/recovery-runbook.md). Siga: validar source/target -> `copy-first` -> registrar immutable snapshot e backup reference -> definir minimum scope -> executar somente read-only dry-run/simulation -> comparar count e checksum before/after previstos -> preparar rollback-of-recovery -> solicitar specific authorization -> post-verify. Em planning-only, pare apos o plano; nao toque em dados, producao, remoto ou aplicacao.

## Required checks

Confirme que source e target sao distintos e identificados, que a copia e imutavel e recuperavel, e que dry-run e read-only. `minimum scope` deve ser igual a `requested scope` ou comprovadamente menor; rejeite `all data`, database/table/tenant inteiro ou full, wildcard, e todos os records, rows, files, objects ou cache. Limite cache a key/namespace, banco a row/tenant e Storage a object/file explicitamente listados. Registre count e checksum before/after para cada row, object ou file afetado. Verifique que rollback-of-recovery restaura o estado anterior da propria recovery e que post-verify mede o mesmo escopo. Nao aceite autorizacao generica: os tres campos authorization devem corresponder exatamente aos campos requested.

## Stop conditions

Pare antes de restore, rollback, recovery, write, delete, truncate, purge, producao, remoto ou dados reais se faltar copia, snapshot/backup reference, source/target, simulation, minimum scope, count/checksum, rollback-of-recovery, post-verify ou specific authorization. Pare tambem diante de placeholder, escopo amplo, ID ausente/inventado, ou pedido de destruir backups/dados. Pergunta hypothetical e planning-only nunca permitem execucao.

## Failure recovery

Se dry-run, contagem, checksum ou post-verify divergir, nao repita a mutacao. Preserve a copia e os resultados, interrompa no menor escopo, execute somente o rollback-of-recovery ja aprovado quando autorizado e retorne ao planejamento. Nunca apague a backup reference para liberar espaco ou ocultar falha.

## Handoff or next skills

Encaminhe incidente confirmado para `forja-incident-response`; migration, schema ou RLS para `forja-supabase-migration`; identity, tenant, workspace ou Storage para `forja-auth-storage-safety`; e matriz de evidencia para `forja-test-strategy`. Mantenha a autorizacao e o escopo no handoff.

## Completion evidence

Conclua com todos os campos de resultado, environment/source/target, immutable snapshot, backup reference, dry-run, minimum scope, count/checksum before/after, rollback-of-recovery, specific authorization e post-verify observados ou marcados como pendentes. Planejamento nao e execucao; nao exponha secret, credential ou PII.
