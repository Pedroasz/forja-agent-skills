# Performance Measurements

## Plano mínimo

Antes de editar, registre uma hipótese (`hypothesis`) falsificável, metric, workload, environment e tool. Exemplo: “o HTML inicial excede o orçamento de `download size` no fluxo de login, medido pelo navegador em cache frio”. Não transforme suspeita em causa confirmada.

## Baseline reproduzível

Execute o baseline antes da alteração e registre versão/commit, URL ou fluxo, navegador/dispositivo/viewport, condições de network e cache, data, tool, amostras e unidades. Repita o workload suficiente para observar variance; uma execução isolada não sustenta conclusão.

## Escopo de medição

| Hipótese | Métrica mínima | Limite de escopo |
| --- | --- | --- |
| HTML pesado | bytes de HTML e `download size` | documento/resposta afetada |
| Requests repetidos | contagem de requests e latência (`latency`) | fluxo e chamadas observadas |
| UI lenta | tempo/custo de render e browser paint | viewport e interação afetados |
| Storage ou database lento | contagem e latência das chamadas | somente quando Storage ou database estiver no escopo |

Não atribua uma lentidão de render a Storage/database sem evidência. Não meça chamadas fora do escopo para criar uma justificativa de mudança ampla.

## Experimento comparável

Faça a menor alteração reversível que testa a hipótese. Compare antes/depois com o mesmo workload, environment, tool, navegador, viewport, condições de network/cache e método de coleta (`same conditions`). Registre amostras, mediana ou outra estatística escolhida antes, effect size, variance e qualquer regression funcional ou de métrica.

## Decisão e rollback

Mantenha a alteração apenas se os dados reais forem comparáveis e sustentarem o efeito. Sem baseline, com variance inconclusiva ou com regression relevante, não alegue ganho: pare, refine a medição ou faça rollback da menor alteração. Preserve o baseline e os resultados para reprodução.
