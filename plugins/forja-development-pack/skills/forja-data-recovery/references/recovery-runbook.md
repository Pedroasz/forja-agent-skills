# Runbook de recuperacao de dados FORJA

## Gate de planejamento

1. Validar campos por linha: `requested environment`, `requested action`, `requested scope`, `source`, `target` e `minimum scope`; normalizar valores, rejeitar placeholders e exigir source diferente de target.
2. Aplicar `copy-first`: registrar `immutable snapshot` e `backup reference` nao-placeholder antes de qualquer mutacao.
3. Fazer somente simulation `read-only` ou `dry-run`; planning-only nunca executa restore ou rollback.
4. Registrar row, object ou file count e checksum before/after para o mesmo conjunto.
5. Preparar `rollback-of-recovery` antes da autorizacao.
6. Exigir `authorization environment` e `authorization action` estruturados e exatamente iguais aos campos requested, e `minimum scope == requested scope == authorization scope`; substring nao basta.
7. Executar somente quando o gate inteiro estiver verdadeiro; fazer `post-verify` e preservar evidencia.

## Limites de escopo

Cache: nomear key ou namespace; nunca permitir que um cache rollback autorize restore amplo de data. Banco: nomear row/chave/tenant; migration recovery exige composition com migration, incident ou authorization aplicaveis. Storage: nomear object/file e caminho. O gate automatizado aceita somente `minimum scope == requested scope == authorization scope`; nao infira hierarquia ou subconjunto por texto livre. Para uma recuperacao menor, crie novo `requested scope` e obtenha nova authorization exata. Rejeite all data, database/table/tenant inteiro ou full, wildcard, e todos os records/rows/files/objects/cache. Source e target devem ser validados e distintos; nao inventar IDs.

## Bloqueios

Production exige todos os campos acima e specific authorization para a action exata. Pare por placeholder, source/target incerto, ausencia de copy-first, immutable snapshot ou backup reference, simulation nao aprovada, count/checksum ausente, escopo amplo, rollback-of-recovery ausente, post-verify ausente, ou intencao de delete/truncate/purge/destruir dados ou backups. Nenhum plano executa dados reais, production, remoto ou aplicacao.

## Evidencia final

Registre o que foi planned, simulated, authorized, executed e post-verify; inclua environment, source, target, minimum scope, snapshot/reference, count/checksum before/after e resultado do rollback-of-recovery. Redija secret, credential e PII.
