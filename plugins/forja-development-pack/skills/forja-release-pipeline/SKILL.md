---
name: forja-release-pipeline
description: Use when preparing, reviewing, approving, tagging, releasing, merging, deploying, rolling back, or reporting a FORJA Development Pack skills package release or a functional FORJA SaaS release.
---

# Gate FORJA Releases with Evidence

## Purpose

Classifique a release como **FORJA Development Pack skills package** ou **FORJA SaaS funcional** e aplique o gate mais restritivo antes de merge, tag, release ou deploy.

## Trigger conditions

Use para branch, PR, version, changelog, tag, GitHub Release, merge, deploy, rollback ou relato de release do pacote de skills ou do SaaS FORJA.

## Do not trigger when

Não use para uma edição local sem intenção de release, merge, tag ou deploy. Não use para outro projeto; não trate documentação do pacote como mudança funcional do SaaS.

## Required inputs

Confirme repositório, alvo (FORJA Development Pack skills package ou SaaS), tipo de mudança (`docs-only`, interna de skills ou funcional), branch/PR, branch protection, versão, changelog, checks, reviews, evidências, ambiente e autoridade explícita.

## Expected outputs

Registre classificação, risco, gates aprovados ou pendentes, evidência observada, proveniência de version/changelog/tag, autorização necessária, plano de rollback e condição de parada. Diferencie claramente elegibilidade de auto-merge de autorização para executar merge/deploy.

## Risk classification

Trate release `docs-only` ou interna do **skills package** como LOW somente se não alterar o SaaS. Trate qualquer release funcional do **SaaS** como **HIGH**; dados reais, produção ou ação irreversível elevam o gate. O maior risco prevalece.

## Workflow

Leia [release-gates.md](references/release-gates.md). Classifique primeiro o alvo e a natureza da mudança. Para o pacote, considere auto-merge apenas se todos os gates de branch, checks, reviews, evidence, version, changelog e tag forem confirmados. Para o SaaS funcional, registre a aprovação humana explícita antes de merge ou deploy, mesmo com todos os checks verdes.

## Required checks

Verifique branch protection e PR correto, checks/CI reais, reviews exigidas, diff e evidência de validação, versão consistente, entrada de changelog e proveniência da tag anotada. Faça **remote confirmation** de branch, checks, merge, tag, GitHub Release ou deploy antes de declarar qualquer um como concluído.

## Stop conditions

Pare se faltar branch protection, check/CI, review, evidence, version, changelog, tag ou confirmação remota aplicável. Nunca crie tag, release, merge, deploy ou alegação de sucesso sem a evidência real correspondente. Para SaaS funcional, pare antes de merge ou deploy até receber **explicit human approval**.

## Failure recovery

Se um gate falhar, não contorne proteção nem reescreva proveniência. Preserve logs e hashes, mantenha a branch/PR em estado não aprovado, corrija a causa e repita somente os checks necessários. Se merge ou deploy autorizado falhar, execute o rollback aprovado, confirme o estado remoto e registre o resultado real.

## Handoff or next skills

Encaminhe mudança funcional de UI para `forja-safe-frontend-change`, autenticação ou Storage para `forja-auth-storage-safety`, migration/RLS para `forja-supabase-migration`, estratégia de validação para `forja-test-strategy` e incidente/produção crítica para `forja-incident-response`.

## Completion evidence

Conclua somente com classificação do alvo, branch/PR e proteção confirmadas, checks/CI e reviews observados, evidence de validação, version/changelog/tag consistentes e confirmação remota quando houver ação remota. Para SaaS funcional, inclua a aprovação humana explícita antes de afirmar merge ou deploy.
