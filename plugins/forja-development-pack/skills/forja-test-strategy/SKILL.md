---
name: forja-test-strategy
description: Use when a FORJA task explicitly asks for a test strategy, test matrix, testing plan, or evidence-based validation scope for documentation, frontend behavior, authentication, RLS, Storage, migrations, or release environments.
---

# Definir estratégia de testes do FORJA

## Purpose

Defina a menor matriz suficiente, baseada em evidências e no risco já roteado. Testar mais não substitui testar o comportamento e a fronteira que podem falhar.

## Trigger conditions

Use quando o pedido FORJA solicitar explicitamente `test strategy`, `test matrix`, `estratégia de testes`, `matriz de testes`, `plano de testes` ou `escopo de validação`. Cubra documentação, frontend, autenticação, RLS, tenant, Storage e migration apenas conforme os sinais reais do pedido.

## Do not trigger when

Não use para outro projeto, execução de uma suíte já definida sem pedido de estratégia, nem para inflar uma edição somente de documentação. Uma pergunta hipotética produz somente plano; não autoriza testes remotos ou em produção.

## Required inputs

Receba o resumo da alteração, risco roteado, comportamento afetado, artefatos e ambiente disponíveis, atores e limites de tenant quando houver dados, e a autorização de cada ambiente. Declare lacunas de evidência em vez de inventar cobertura.

## Expected outputs

Entregue `risk`, `matrix` e `productionGate`, sem IDs. Para cada item, indique alvo, método, evidência esperada e se é planejado ou executado. A matriz deve ser `smallest-sufficient`: pequena, suficiente e rastreável ao risco e ao comportamento.

## Risk classification

Siga o risco da tarefa roteada: **LOW**, **MODERATE**, **HIGH** ou **CRITICAL**. **Highest risk prevails**: texto de documentação nunca reduz um sinal HIGH ou CRITICAL. LOW usa apenas a fundação relevante; MODERATE a mantém e acrescenta validação funcional; HIGH mantém LOW/MODERATE relevantes e acrescenta fronteiras de segurança; CRITICAL preserva tudo que for aplicável e para antes de ação irreversível.

## Workflow

Leia [test-matrix.md](references/test-matrix.md). Comece pela mudança observável e selecione somente os níveis necessários. Para documentação, valide static, content e manifest. Para frontend funcional, mantenha esses itens e acrescente unit, integration e browser focado em desktop, mobile e navigation conforme aplicável. Para HIGH, acrescente authenticated actor, RLS, tenant, Storage e local migration conforme a superfície afetada.

## Required checks

Use static/content/manifest para artefatos documentais; não exija browser para texto sem comportamento. Em RLS ou migration sem superfície de UI, use static, SQL, integration, local migration, authenticated actor, RLS e tenant, sem browser, desktop, mobile ou navigation. Acrescente unit e browser focado, desktop, mobile e navigation somente quando a UI, viewport ou rota mudarem. Teste offline, preview e production somente se aplicáveis e autorizados: `non-mutating observation` coleta evidência sem mudar estado; `authorized execution` exige autorização explícita antes de qualquer mutação.

## Stop conditions

Pare se o risco roteado, comportamento, ator, tenant, ambiente ou autorização necessária estiver ausente. Pare antes de produção, dados reais, RLS remoto, Storage compartilhado ou migration remota sem autorização explícita. Em CRITICAL, pare para a autoridade apropriada antes de qualquer execução irreversível.

## Failure recovery

Quando uma verificação falhar, preserve a evidência, reduza ao menor caso reproduzível e corrija a matriz ou a alteração. Não remova testes HIGH para obter verde, não substitua negação de acesso por teste feliz e não declare execução quando houve apenas observação.

## Handoff or next skills

Encaminhe alteração de UI para `forja-safe-frontend-change` e `forja-ux-accessibility`; autenticação, tenant ou Storage para `forja-auth-storage-safety`; schema, RLS ou migration para `forja-supabase-migration`; e aprovação de release para `forja-release-pipeline`.

## Completion evidence

Conclua com `risk`, `matrix`, `productionGate`, escopo justificado, resultados ou pendências e evidência observável por verificação. Distinga sempre planejado, observado sem mutação e executado com autorização.
