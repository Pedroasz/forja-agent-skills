# Runbook de Migration Supabase

## Descoberta local

Antes de criar arquivos, registre `supabase --version` e consulte `supabase migration new --help`, `supabase db push --help` e `supabase db reset --help`. Não invente timestamp ou filename: gere a migration com `supabase migration new <nome-curto>` e use o arquivo criado pela CLI.

## Sequência local

1. Liste `supabase/migrations` e `supabase migration list`; identifique baseline e migrations aplicadas. Para novo índice, registre também o nome técnico `index` no plano.
2. Escreva somente a nova migration incremental; não edite baseline, histórico ou uma migration aplicada.
3. Consulte a ajuda antes de `supabase db push --dry-run`; execute-o somente se não puder alcançar projeto vinculado ou banco real. Caso contrário, registre a checagem como pendente de aprovação, sem executar.
4. Recrie o ambiente sintético com `supabase db reset`, depois confirme o histórico com `supabase migration list`.
5. Execute `supabase test db` quando houver testes de banco configurados.
6. Execute os advisors disponíveis após conferir a ajuda/version da CLI e registre o que foi executado ou indisponível.

## RLS e permissões

Para cada tabela afetada, documente actor, `TO` role, tenant/workspace e predicado de ownership. Policy de `UPDATE` precisa de `USING` para linha existente e `WITH CHECK` para o novo valor; cubra actor correto, outro tenant, sessão ausente e tentativa de mudar `tenant_id`. Adicione ou avalie índice para as colunas filtradas pela policy.

RLS decide linhas; privilégios decidem se o papel pode acessar a tabela. Verifique a exposição pela Data API e concessões explícitas, por exemplo `GRANT` somente ao papel indispensável, antes de considerar uma tabela utilizável. Não presuma que tabela pública nova é exposta ou que RLS concede acesso.

## Matriz mínima

| Caso | Resultado local exigido |
|---|---|
| actor do tenant correto | somente operações permitidas |
| actor de outro tenant | negar SELECT, INSERT, UPDATE e DELETE pertinentes |
| actor sem sessão | negar conforme papel e policy |
| UPDATE tentando trocar tenant | negar por `WITH CHECK` |
| consulta/policy filtrada | avaliar índice das colunas de tenant/ownership |

## Rollback e aprovação

Defina rollback forward-only em nova migration: remover policy/índice/coluna apenas quando a reversão for segura e preservar dados quando não for. Anexe impacto, pré-condições, resultado de dry-run/reset/testes/advisors, histórico e plano de recuperação ao pedido de aprovação explícita.

Sem aprovação, não execute `supabase db push`, reset de projeto vinculado, apply migration, comando remoto ou ação em banco real. Questões hipotéticas permanecem planning-only: plano e checks são permitidos, execução não.

## Fontes oficiais

Consulte a documentação de [database migrations](https://supabase.com/docs/guides/local-development/database-migrations) e de [CLI workflows](https://supabase.com/docs/guides/local-development/cli-workflows), confirmando comandos e flags pela ajuda da versão local.
