---
name: forja-independent-review
description: Use when independently reviewing a FORJA pull request, diff, proposed merge, code change, or documentation change that needs evidence-based architecture, security, and usability assessment.
---

## Purpose

Produza uma revisão independente e verificável, sem aprovar, fazer merge ou substituir a autoridade de risco humana.

## Trigger conditions

Use para revisar PR, pull request, diff ou mudança FORJA antes de merge, inclusive código, documentação e pedidos para “approve quickly”.

## Do not trigger when

Não use para implementar uma mudança sem pedido de revisão, editar texto sem diff, ou revisar outro projeto. Não transforme uma revisão em aprovação, merge ou ação remota.

## Required inputs

Obtenha escopo, diff ou árvore observável, commits/base quando existirem, requisitos e evidência de validação. Registre lacunas; não invente evidence, arquivo, linha, teste ou aprovação. **Do not invent evidence.**

## Expected outputs

Entregue três perspectivas independentes: architecture/manutenibilidade, security/supply chain/segredos e usability/accessibility/precisão de gatilhos. Para cada finding, registre severity, evidence, file e line quando aplicável, impact, recommended fix e status. Se não houver finding, declare “No findings observed” e os limites da revisão; quando line references are not applicable, escreva esse motivo em vez de fabricar uma linha.

## Risk classification

Classifique cada finding como Critical, High, Medium ou Low conforme [review-rubric.md](references/review-rubric.md). Critical e High são merge-blocking até serem corrigidos ou aceitos por explicit risk authority identificada; após correção ou aceite, marque como re-reviewed antes de remover o bloqueio. Medium dentro do escopo deve ser corrigido; Low exige justificativa para permanecer.

## Workflow

Leia [review-rubric.md](references/review-rubric.md). Analise as três perspectivas separadamente a partir do artefato bruto, depois consolide sem duplicar achados. Verifique a evidência antes de registrar cada finding. Pressa, pedido de “approve quickly” ou ausência de achados não permitem rubber stamp: mantenha os gates e declare somente o que foi observado.

## Required checks

Confirme que architecture, security e usability/accessibility receberam passagens independentes; que todo finding contém os seis campos; que severidade segue a rubrica; e que Critical/High permanecem bloqueadores. Verifique o diff real, escopo e limitações. Não aprove PR, não faça merge e não alegue revisão ou evidência não observada.

## Stop conditions

Pare e marque a revisão como inconclusiva se não houver diff/artefato, se faltarem requisitos materiais, se a evidência não puder ser conferida, ou se Critical/High estiver aberto sem explicit risk authority. Não aceite risco implícito nem aprovação verbal genérica.

## Failure recovery

Se encontrar evidência incompleta, substitua conclusões por lacunas verificáveis e solicite o artefato necessário. Após uma correção ou aceite de risco, repita somente as perspectivas afetadas, atualize status para re-reviewed e preserve a evidência anterior.

## Handoff or next skills

Encaminhe defeitos de UI para `forja-ux-accessibility` e `forja-safe-frontend-change`; segurança de autenticação, Storage ou RLS para `forja-auth-storage-safety` e `forja-supabase-migration`; cobertura para `forja-test-strategy`; release para `forja-release-pipeline`.

## Completion evidence

Conclua com três resultados independentes, findings completos ou “No findings observed” com limitações, severidades/gates atuais e status re-reviewed quando aplicável. A conclusão é uma recomendação baseada em evidence, nunca aprovação automática.
