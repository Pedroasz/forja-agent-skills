# Auth and Storage Boundaries

## Limites de acesso

Defina o actor autenticado, tenant, workspace e recurso antes de alterar código, política ou configuração. Um actor só pode operar recursos do seu tenant e workspace autorizados. Trate qualquer acesso cross-workspace como falha, inclusive quando o identificador do recurso foi obtido por URL, cache ou payload do cliente.

## Matriz mínima de testes

| Cenário | Resultado exigido |
|---|---|
| authenticated actor no tenant correto | leitura/escrita somente quando a permissão declarada permitir |
| actor autenticado de outro tenant | tenant isolation: negar leitura, escrita, listagem e alteração |
| actor sem sessão ou sessão expirada | negar acesso e solicitar autenticação conforme o fluxo |
| recurso de outro workspace | negar cross-workspace sem revelar existência ou metadados |
| Storage object | validar bucket, caminho associado ao tenant/workspace e autorização de leitura/escrita |

## Dados e aprovação

Use fixtures locais e dados sintéticos. Não altere dados reais (**real data**), não use credenciais reais e não execute comandos remotos. Pare e solicite explicit approval antes de executar migration, política RLS, operação de Storage remota ou merge funcional do SaaS. Perguntas hipotéticas permanecem planning-only: podem receber plano e testes, nunca execução.

## Evidência

Registre actor, tenant, workspace, recurso, ambiente, resultado esperado, resultado observado e qualquer teste não executado. Uma ausência de evidência não é aprovação.
