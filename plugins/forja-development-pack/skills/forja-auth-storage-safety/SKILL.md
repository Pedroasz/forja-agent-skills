---
name: forja-auth-storage-safety
description: Use when a FORJA request involves identity, authentication, login, session, permissions, Storage, workspace, tenant isolation, RLS, or access to user data.
---

# Preserve FORJA Auth and Storage Boundaries

## Purpose

Planeje alterações de identity, authentication e storage preservando o acesso do authenticated actor somente ao seu tenant e workspace.

## Trigger conditions

Use para login, sessão, identidade, permissões, Storage, RLS, workspace, tenant, política de acesso ou dados de perfil do FORJA.

## Do not trigger when

Não use para cópia ou texto estático de perfil sem alterar autenticação, sessão, permissões, workspace, tenant ou dados. Não use para outro projeto.

## Required inputs

Confirme actor autenticado, tenant e workspace de origem, recurso afetado, ambiente, dados envolvidos, mudança pretendida e autoridade explícita disponível.

## Expected outputs

Registre escopo, classificação, matriz de acesso por actor/tenant, limites de Storage, testes requeridos, aprovações, proibições e pendências.

## Risk classification

Classifique como **HIGH**. Aplique o maior risco quando houver dados reais, produção, credenciais ou ação irreversível.

## Workflow

Leia [auth-storage-boundaries.md](references/auth-storage-boundaries.md). Delimite primeiro actor, tenant, workspace e recurso; planeje a menor mudança local e mantenha perguntas hipotéticas em modo **planning-only**.

## Required checks

Teste um authenticated actor autorizado e um actor de outro tenant. Verifique tenant isolation, negação cross-workspace, sessão expirada/ausente e regras de Storage para leitura, escrita e caminho do objeto.

## Stop conditions

Pare antes de acessar cross-workspace, alterar dados reais (**real data**), usar credenciais reais, executar comando remoto ou aplicar RLS/migration. Exija **explicit approval** antes de execução de migration ou merge do SaaS; uma pergunta hipotética nunca autoriza execução.

## Failure recovery

Se qualquer teste revelar acesso fora do tenant ou workspace, interrompa a mudança, preserve evidências locais e reverta somente a alteração local que introduziu o desvio. Não masque falha com dados de teste compartilhados.

## Handoff or next skills

Encaminhe schema, RLS ou migration para `forja-supabase-migration`; encaminhe a matriz proporcional de validação para `forja-test-strategy`. Para incidente, dados reais ou produção, aplique o gate de maior risco antes de qualquer ação.

## Completion evidence

Conclua somente com evidência dos testes de authenticated actor, tenant isolation, negação cross-workspace e Storage, aprovação explícita quando aplicável, diff local limitado e nenhuma alteração de dados reais.
