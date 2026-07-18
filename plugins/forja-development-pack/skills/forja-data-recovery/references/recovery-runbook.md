# Runbook de recuperacao de dados FORJA

## Gate de planejamento

1. Validar environment, source, target e minimum scope.
2. Aplicar `copy-first`: registrar `immutable snapshot` e `backup reference` nao-placeholder antes de qualquer mutacao.
3. Fazer somente simulation `read-only` ou `dry-run`; planning-only nunca executa restore ou rollback.
4. Registrar row, object ou file count e checksum before/after para o mesmo conjunto.
5. Preparar `rollback-of-recovery` antes da autorizacao.
6. Exigir `specific authorization` estruturada: environment, action e scope exatos.
7. Executar somente quando o gate inteiro estiver verdadeiro; fazer `post-verify` e preservar evidencia.

## Limites de escopo

Cache: nomear key ou namespace; nunca permitir que um cache rollback autorize restore amplo de data. Banco: nomear row/chave/tenant; migration recovery exige composition com migration, incident ou authorization aplicaveis. Storage: nomear object/file e caminho. Source e target devem ser validados e distintos; nao inventar IDs.

## Bloqueios

Production exige todos os campos acima e specific authorization para a action exata. Pare por placeholder, source/target incerto, ausencia de copy-first, immutable snapshot ou backup reference, simulation nao aprovada, count/checksum ausente, escopo amplo, rollback-of-recovery ausente, post-verify ausente, ou intencao de delete/truncate/purge/destruir dados ou backups. Nenhum plano executa dados reais, production, remoto ou aplicacao.

## Evidencia final

Registre o que foi planned, simulated, authorized, executed e post-verify; inclua environment, source, target, minimum scope, snapshot/reference, count/checksum before/after e resultado do rollback-of-recovery. Redija secret, credential e PII.
