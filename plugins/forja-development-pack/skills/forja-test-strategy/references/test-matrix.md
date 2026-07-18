# Matriz de testes mínima do FORJA

## Regra de seleção

Escolha a matriz `smallest-sufficient` que prova a alteração e suas fronteiras. O risco da rota é LOW, MODERATE, HIGH ou CRITICAL; highest risk prevails. Uma descrição ou README no mesmo pedido não reduz RLS, tenant, Storage ou migration para LOW.

| Risco e superfície | Matriz mínima | Evidência |
| --- | --- | --- |
| LOW: documentação, README, artefato de skill | static, content, manifest | sintaxe, links/campos e manifesto ou estrutura válida |
| MODERATE: frontend funcional | LOW aplicável + unit, integration, browser focado | comportamento, erro e fluxo afetados |
| MODERATE: UI responsiva ou rota | MODERATE + desktop, mobile, navigation conforme mudança | viewport e rota/retorno afetados |
| HIGH: auth, RLS, tenant, Storage, migration sem UI | static, SQL, integration, local migration, authenticated actor, RLS e tenant; Storage somente quando afetado | permissão permitida e negada, isolamento e migração local |
| HIGH: auth, RLS, tenant, Storage, migration com UI | HIGH sem UI + unit, browser, desktop, mobile e navigation conforme a superfície | fronteira de segurança e fluxo visual afetados |
| CRITICAL: produção ou ação irreversível | HIGH aplicável + parada e autoridade | plano, evidência preservada e autorização explícita antes da execução |

## Escopo por tipo

- `static`: parse, lint, sintaxe ou verificação estrutural do artefato.
- `content`: textos, campos obrigatórios, links e contrato sem comportamento de UI.
- `manifest`: schema, metadados e referências declaradas.
- `unit`: decisão, validação ou transformação isolada alterada.
- `integration`: integração local entre componentes ou serviço simulado autorizado.
- `browser`: apenas o fluxo UI modificado; acrescente desktop, mobile e navigation somente quando o pedido os afetar. Não use esses itens para RLS ou migration sem UI, viewport ou rota.
- `authenticated actor`: execute com identidade autenticada e sem ela quando a fronteira exigir.
- `RLS` e `tenant`: prove acesso permitido e negação cross-tenant/cross-workspace.
- `Storage`: prove bucket/objeto permitido e negação fora da fronteira.
- `local migration`: valide a migration incremental localmente, incluindo política e rollback planejado quando aplicável.

## Ambientes

`offline` é aplicável quando cache, PWA ou conectividade fazem parte do comportamento. `preview` é aplicável quando o fluxo precisa de ambiente de prévia autorizado. `production` não é uma etapa padrão: primeiro faça `non-mutating observation` para observar logs, métricas ou fluxo sem mudar estado; só faça `authorized execution` após autorização explícita para a mutação exata. Nunca apresente observação como execução.

## Forma do resultado

Use somente campos derivados do pedido, sem IDs:

```text
risk: HIGH
matrix: static | content | manifest | unit | integration | authenticated actor | RLS | tenant | Storage | local migration
productionGate: AUTHORIZED_EXECUTION_REQUIRED
```

Se não houver autorização ou o ambiente não for aplicável, registre `productionGate: NOT_APPLICABLE` ou uma pendência, sem executar.
