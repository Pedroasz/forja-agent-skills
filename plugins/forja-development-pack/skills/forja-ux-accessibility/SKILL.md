---
name: forja-ux-accessibility
description: Use when auditing or implementing scoped FORJA UX and accessibility fixes for mobile, forms, modals, keyboard navigation, focus, contrast, errors, semantics, reduced motion, or touch targets; not full redesign, documentation-only, or backend-only work.
---

# UX e acessibilidade do FORJA

## Purpose

Audite ou corrija uma interação existente do FORJA para que permaneça compreensível, utilizável em mobile e acessível sem ampliar o escopo funcional.

## Trigger conditions

Use para falhas ou mudanças pontuais de mobile, form, modal, keyboard, foco, contrast, erros, semântica ou accessibility em uma tela ou fluxo do FORJA.

## Do not trigger when

Não use para documentação-only, backend-only, API, migration ou tarefa sem interface observável. Não trate full redesign como auditoria: ele exige separate discovery e approval antes de qualquer proposta, pois não está no escopo deste skill. Não use para outro projeto.

## Required inputs

Obtenha o fluxo afetado, viewport/dispositivo, estados de erro e sucesso, elementos interativos, conteúdo dinâmico e critérios de aceitação. Para modal, identifique gatilho, foco inicial, limite do diálogo e destino do foco ao fechar.

## Expected outputs

Entregue escopo da interação, achados ou alteração mínima, checks executados, evidência observável, pendências e riscos. Diferencie resultado validado de verificação não executada.

## Risk classification

Classifique como **MODERATE**. Se a alteração também atingir autenticação, dados, permissões, migração ou produção, aplique o risco mais alto e seus gates.

## Workflow

Leia [accessibility-checks.md](references/accessibility-checks.md). Reproduza o fluxo, aplique a menor correção que preserve o comportamento, percorra os checks proporcionais ao risco e registre o resultado real.

## Required checks

Verifique keyboard, ordem e visibilidade de foco, modal quando aplicável, contrast, associação e anúncio de error, semantic HTML, labels, roles, mobile e movimentos/toque proporcionais ao fluxo.

## Stop conditions

Pare se não houver fluxo ou interface para observar, se o problema exigir full redesign, se faltar critério de aceitação, se uma mudança afetar fronteira de segurança ou se um check essencial falhar. Exija approval before any functional SaaS merge.

## Failure recovery

Reverta somente a menor alteração local que introduziu a regressão, preserve a evidência, isole a causa e repita os checks afetados. Não oculte falha de teclado, foco perdido, erro sem anúncio ou contraste insuficiente.

## Handoff or next skills

Encaminhe alteração funcional de HTML/CSS/JavaScript para `forja-safe-frontend-change`; requisitos de autenticação, sessão, Storage, RLS ou dados para `forja-auth-storage-safety` e `forja-supabase-migration`; matriz de cobertura para `forja-test-strategy`; e redesign para descoberta e approval separados.

## Completion evidence

Conclua com fluxo e viewport testados, método de navegação, resultado dos checks aplicáveis, pendências declaradas e diff limitado ao escopo. Para alteração funcional do SaaS, registre a aprovação explícita antes do merge.
