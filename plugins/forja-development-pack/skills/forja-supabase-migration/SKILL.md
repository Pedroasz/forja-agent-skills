---
name: forja-supabase-migration
description: Use when a FORJA request changes a Supabase schema, database table, index, migration, RLS policy, permission, or generated database type.
---

# Plan Safe FORJA Supabase Migrations

## Purpose

Planeje migrations incrementais do FORJA sem alterar baseline ou migrations aplicadas, preservando schema, RLS, permissões e isolamento por tenant.

## Trigger conditions

Use para tabela, coluna, índice, constraint, schema, migration, RLS, policy, GRANT ou tipos derivados do banco do FORJA.

## Do not trigger when

Não use para texto, frontend ou documentação sem mudança de banco. Para outro projeto, não selecione esta skill.

## Required inputs

Confirme ambiente local, migration baseline e histórico, mudança mínima, tabela/colunas, actor, tenant, papéis, impacto em Data API e autoridade concedida.

## Expected outputs

Registre risco HIGH, migration incremental proposta, checks locais, matriz actor/tenant, plano de rollback, pendências e gate de aprovação explícita.

## Risk classification

Classifique como **HIGH**; o maior risco prevalece. Planeje e valide somente localmente com dados sintéticos. Dados reais, produção, credenciais ou ação irreversível elevam o gate.

## Workflow

Leia [migration-runbook.md](references/migration-runbook.md). Descubra versão e ajuda da CLI antes de propor comandos; crie uma **new incremental migration** com `supabase migration new` e nome gerado pela CLI. Preserve o baseline e nunca edite uma **applied migration**. Pergunta hipotética é **planning-only**: responda com plano, sem autorizar execução.

## Required checks

Faça `supabase db reset`, `supabase migration list` e, quando disponível, `supabase test db` no ambiente local. Consulte a ajuda para avaliar `supabase db push --dry-run`; só o execute se a própria CLI confirmar que não alcança projeto vinculado ou banco real, caso contrário registre-o como pendente de aprovação. Valide actor autorizado e actor de outro tenant. Para RLS, limite a policy `TO` ao papel necessário, use predicados de ownership/tenant, inclua `UPDATE USING` e `WITH CHECK`, e indexe colunas usadas pela policy. Verifique exposição pela Data API e GRANT explícito quando necessário; RLS não substitui GRANT.

## Stop conditions

Pare antes de editar migration aplicada, baseline ou histórico; usar dados reais; ou executar `db push`, reset vinculado, apply migration, comando remoto (**remote**) ou banco real. Não presuma que `supabase db push --dry-run` é local: pare se ele puder atingir projeto vinculado; ele nunca substitui aprovação. Exija **explicit approval** antes de qualquer execução remota, aplicação ou merge do SaaS.

## Failure recovery

Se reset, policy, isolamento, advisor ou histórico falhar, não masque o resultado. Preserve evidência local, corrija em nova migration incremental ou descarte somente mudança local não aplicada; não reescreva histórico. Atualize o rollback forward-only antes de solicitar aprovação.

## Handoff or next skills

Encaminhe limites de identidade e tenant para `forja-auth-storage-safety`; estratégia de testes para `forja-test-strategy`; incidente, dados reais ou produção para o gate de risco superior.

## Completion evidence

Conclua com diff local da nova migration, versão/ajuda da CLI, dry-run, reset, migration list, testes actor/tenant, advisors, checagem Data API/GRANT, rollback e aprovação explícita pendente ou registrada. Nunca alegue execução remota sem evidência autorizada.
