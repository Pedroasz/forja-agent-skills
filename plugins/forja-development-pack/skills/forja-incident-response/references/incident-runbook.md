# Runbook de incidente FORJA

## Ordem operacional

Siga sempre `contain → preserve → classify → investigate → communicate → fix → verify → document`.

| Etapa | Registro mínimo | Limite |
| --- | --- | --- |
| contain | medida reversível, timestamp, owner | `executionAllowed` somente com evidência integral e autoridade estruturada; não mutate produção sem aprovação específica. |
| preserve | timestamp ISO-8601, hash ou snapshot não-placeholder, log reference não-placeholder, chain com trilha e owner identificado | não fazer log deletion, cleanup ou restart antes de preservar. |
| classify | estado: confirmed, hypothetical ou não incidente; impacto e risco | hypothetical é planejamento, não execução. |
| investigate | hipótese, fonte, intervalo temporal e lacunas | não alterar evidência para testar hipótese. |
| communicate | status verdadeiro, impacto conhecido/desconhecido, owner e cadence | sem blame, secret ou PII. |
| fix | proposta, aprovação explícita, reversibilidade e rollback | destructive fix ou production mutation exige incident authority. |
| verify | check observável, resultado, timestamp e limite | não concluir recuperação fora do escopo verificado. |
| document | fatos executed/observed/planned/not-run e handoff | preserve referências, não dados sensíveis. |

## Preservação e cadeia

Registre a origem de cada snapshot, hash e log reference, quem coletou, quando e qual owner mantém a chain. Rejeite `unknown`, `now`, `yes` e valores genéricos: `evidencePreserved` requer simultaneamente timestamp ISO-8601, hash ou snapshot válido, log reference válido, trilha chain/chain-of-custody e owner identificado. Copie ou referencie evidência sem editar a origem; não delete logs, não faça cleanup e não use restart para apagar sintomas. Se a autoridade faltar, mantenha somente observação não mutante e a contenção reversível já autorizada.

## Comunicação e recuperação

Defina cadence de status com a autoridade e diga apenas o que é observado: impacto, intervalo, mitigação, incerteza e próximo update. Aplique `no blame`. `executionAllowed` requer, além da evidência integral, explicit incident authority com nome, papel ou ID e vale somente para authorized reversible containment. Mesmo assim, cleanup, restart, destructive fix e production mutation continuam bloqueados até autorização específica separada. Ao propor fix, anexe plano de rollback e recovery, owner do handoff e critérios de verify. O encerramento requer status final verdadeiro, evidência de verify e pendências explicitamente documentadas.
