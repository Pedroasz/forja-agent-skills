---
name: forja-documentation
description: Use when creating or updating FORJA ADRs, changelogs, runbooks, release reports, documentation, or evidence records that must distinguish verified facts from plans.
---

# Documentar o FORJA com evidências

## Purpose

Produza documentação verificável do FORJA. O risco padrão é **LOW** para documentação isolada; preserve o maior risco e as skills aplicáveis quando o conteúdo também envolver código, dados, release ou produção.

## Trigger conditions

Use para ADR, README, changelog, runbook, relatório de release, registro de evidência ou documentação do FORJA. Inclua pedidos em que a confirmação local, GitHub, Drive ou produção precise ser relatada.

## Do not trigger when

Não use para outro projeto, edição acadêmica genérica ou texto sem escopo FORJA. IDs, hashes, URLs ou nomes de arquivos sozinhos não são lógica de roteamento; eles apenas qualificam a evidência depois que o escopo já foi confirmado.

## Required inputs

Receba escopo, artefato, estado e evidência disponível. Para cada afirmação, registre o **evidence source**, `command/check`, timestamp quando relevante, e os identificadores aplicáveis: commit/hash, URL, Drive ID, tamanho e modified metadata.

## Expected outputs

Separe estritamente `executed`, `observed`, `planned` e `not-run`. Declare a confirmação como `local artifact`, `GitHub`, `Drive` ou `production`; confirmação local não confirma GitHub, Drive nem produção. Conclusões sem suporte (`unsupported conclusions`) são proibidas.

## Risk classification

Documentação isolada é **LOW**. Não reduza MODERATE, HIGH ou CRITICAL porque uma parte é documentação: aplique **highest risk prevails** e mantenha a composição com test/release e as skills anteriores quando aplicáveis.

## Workflow

Leia [evidence-schema.md](references/evidence-schema.md). Primeiro classifique cada fato pelo estado; depois associe a fonte exata e a verificação. Para Drive, só registre upload, overwrite ou deletion quando houver evidência do conector, incluindo folder ID, file ID e post-upload reread de metadata ou conteúdo.

## Required checks

Valide que cada resultado executado ou observado possui fonte e comando/check; inclua timestamp quando o tempo altera o significado. Cite commit/hash para Git, URL para GitHub quando disponível, e Drive ID/size/modified metadata para Drive. Redija segredos: nunca inclua secret, credential, token, chave, PII ou dados pessoais desnecessários.

## Stop conditions

Pare a conclusão quando faltar fonte, comando/check, timestamp relevante, hash/URL/ID ou metadata aplicável. Não declare sucesso de upload, sincronização, overwrite, deletion, validação remota ou produção sem evidência observada. Não exponha segredos, credentials ou PII.

## Failure recovery

Troque a afirmação não comprovada por `planned` ou `not-run`, descreva a lacuna e a próxima verificação necessária. Preserve evidência já observada; não invente hash, URL, Drive ID, size, modified metadata ou confirmação de reread.

## Handoff or next skills

Encaminhe estratégia de validação para `forja-test-strategy`, gates e proveniência de release para `forja-release-pipeline`, alteração funcional de UI para `forja-safe-frontend-change`, e migration/RLS/Storage para as skills de segurança aplicáveis. Não remova a documentação da composição.

## Completion evidence

Entregue o artefato com os quatro estados, fonte exata e limites explícitos. Para cada confirmação, identifique se é local artifact, GitHub, Drive ou production. Um relatório do Drive só está completo após o post-upload reread confirmar folder ID, file ID, size e modified metadata; sem essa evidência, use `not-run` ou pendente.
