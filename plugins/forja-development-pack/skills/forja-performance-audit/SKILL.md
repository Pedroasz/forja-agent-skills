---
name: forja-performance-audit
description: Use when a FORJA task asks to investigate or improve slowness, HTML or download size, repeated requests, latency, rendering, Storage, or database performance and needs measured evidence before a change.
---

# Auditar desempenho do FORJA

## Purpose

Meça desempenho antes de otimizar. Produza evidência reproduzível para uma hipótese limitada, sem atribuir ganho sem dados reais.

## Trigger conditions

Use para lentidão observável, HTML ou `download size`, requests repetidos, latência de rede, custo de renderização ou paint. Inclua Storage ou database apenas quando estiverem no escopo comprovado.

## Do not trigger when

Não use para documentação, README, análise de `performance review` sem alteração ou medição, nem para outro projeto. Não presuma uma causa para pedido vago como “make faster”: primeiro refine métrica e escopo.

## Required inputs

Defina hipótese (`hypothesis`), métrica (`metric`), workload, environment e tool. Registre URL/fluxo ou artefato, dispositivo/viewport quando aplicável, condições de rede/cache, número de repetições e limite de sucesso ou regressão (`regression`).

## Expected outputs

Entregue plano de medição, baseline reproduzível, menor experimento no escopo, tabela antes/depois sob as mesmas condições (`same conditions`), effect size, variance, regressões e decisão. Declare dados ausentes como pendência, nunca como ganho.

## Risk classification

Classifique como **MODERATE** por padrão. Eleve o risco para autenticação, dados, permissões, Storage compartilhado, database real ou produção; o maior risco aplicável prevalece.

## Workflow

Leia [performance-measurements.md](references/performance-measurements.md). Formule hipótese testável e execute o baseline antes de mudar código. Aplique um único experimento mínimo e reversível; repita a mesma medição com workload, environment e tool comparáveis. Calcule effect size, verifique variance e regressão, e só então decida manter ou reverter.

## Required checks

Meça HTML e `download size` quando o payload for hipótese; conte requests repetidos e registre latência quando a rede for hipótese; registre custo de render/browser quando a UI for hipótese. Meça chamadas de Storage ou database somente se estiverem no escopo. Não declare melhoria de performance sem dados reais (`actual data`) antes/depois.

## Stop conditions

Pare antes da alteração se faltar hipótese, métrica, workload, environment, tool ou baseline reproduzível. Pare e refine o pedido vago antes de inventar métrica ou alvo. Pare se as condições não forem comparáveis, a variance impedir conclusão, houver regressão relevante ou o experimento tocar dados reais/produção sem a autorização aplicável.

## Failure recovery

Reverta a menor alteração experimental ao baseline conhecido quando surgir regressão ou resultado inconclusivo. Preserve medições, comandos e condições; corrija o plano em vez de selecionar dados favoráveis ou alegar ganho.

## Handoff or next skills

Encaminhe mudança funcional de HTML, CSS ou JavaScript para `forja-safe-frontend-change`; requisitos de UX para `forja-ux-accessibility`; autenticação, Storage ou isolamento para `forja-auth-storage-safety`; e migrations ou database schema para `forja-supabase-migration`.

## Completion evidence

Conclua somente com hipótese, baseline reproduzível, alteração mínima ou decisão de não alterar, medições antes/depois nas mesmas condições, effect size, variance, regressões e decisão de manter ou rollback. Sem dados reais, reporte apenas plano ou resultado inconclusivo.
