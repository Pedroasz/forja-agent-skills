---
name: forja-safe-frontend-change
description: Use when implementing or reviewing a functional FORJA HTML, CSS, JavaScript, button, form, UI, or navigation change that needs safe frontend checks.
---

# Change FORJA Frontend Safely

## Purpose

Planeje e valide mudanças funcionais de frontend sem quebrar a interface, a navegação ou a segurança do FORJA.

## Trigger conditions

Use para alteração funcional de HTML, CSS, JavaScript, botão, formulário, UI ou navegação do FORJA, inclusive quando afetar desktop ou mobile.

## Do not trigger when

Não use para documentação (`documentation-only`), README, ADR ou edição somente de texto sem comportamento de UI. Não use para outro projeto.

## Required inputs

Confirme o comportamento atual e desejado, arquivos e DOM IDs afetados, fluxos de navegação, dispositivos relevantes e autoridade de merge.

## Expected outputs

Registre escopo, risco, arquivos afetados, verificações executadas, resultados, pendências e o gate de aprovação.

## Risk classification

Classifique como **MODERATE** por padrão. Eleve o risco quando a mudança alcançar autenticação, dados, permissões ou produção; o maior risco aplicável prevalece.

## Workflow

Leia [frontend-safety-checks.md](references/frontend-safety-checks.md). Faça a menor alteração funcional, valide as referências afetadas e teste os fluxos alterados antes de propor merge.

## Required checks

Verifique DOM IDs e referências, `event handlers`, escaping/XSS, risco de `blank screen`, comportamento desktop/mobile e navegação. Teste somente os caminhos afetados e registre o resultado real.

## Stop conditions

Pare se faltar escopo, se um DOM ID ou handler necessário for desconhecido, se houver risco de XSS ou `blank screen`, ou se um fluxo de navegação falhar. Exija explicit approval before any functional SaaS merge.

## Failure recovery

Restaure a menor mudança local que isolou a falha, preserve evidências e corrija a causa antes de repetir as verificações. Não esconda erro de console, rota quebrada ou comportamento divergente.

## Handoff or next skills

Encaminhe para `forja-ux-accessibility` somente se houver requisito de UX, acessibilidade, teclado, foco ou contraste; para `forja-performance-audit` somente se houver hipótese de desempenho; e para `forja-test-strategy` somente se o risco exigir matriz de testes além das verificações locais.

## Completion evidence

Conclua somente com diff limitado ao escopo, verificações relevantes aprovadas em desktop/mobile e navegação, evidência de segurança registrada e a aprovação explícita antes do merge funcional do SaaS.
