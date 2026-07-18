# Rubrica de revisão independente

## Perspectivas obrigatórias

| Perspectiva | Verificar |
|---|---|
| Architecture e manutenibilidade | Contrato, separação de responsabilidades, compatibilidade, erros e testes. |
| Security | Autorização, dados, segredos, supply chain, validação de entrada e superfície remota. |
| Usability e Accessibility | Fluxos compreensíveis, feedback, teclado, foco, semântica, contraste, precisão de gatilhos e contexto. |

Faça as três passagens de forma independente. Não use a conclusão de uma para presumir evidência nas outras.

## Escala de severidade

| Severidade | Regra |
|---|---|
| Critical | Risco imediato de segurança, perda de dados, ação irreversível ou quebra grave. Merge-blocking. |
| High | Violação importante de requisito, segurança, autorização ou comportamento essencial. Merge-blocking. |
| Medium | Defeito relevante, mas contido; corrigir se estiver no escopo. |
| Low | Melhoria limitada; pode permanecer somente com justificativa. |

Critical e High só deixam de bloquear depois de correção ou Accepted risk por uma explicit risk authority identificada, seguida de re-review da evidência pertinente. “Aprovar rápido”, checks verdes ou ausência de tempo não são aceite de risco.

## Registro por finding

Use um registro por finding:

| Campo | Conteúdo exigido |
|---|---|
| Severity | Critical, High, Medium ou Low. |
| Evidence | Trecho, comando, diff ou observação realmente verificada. |
| File / line | Referência precisa; se line references are not applicable, explique por quê. |
| Impact | Consequência concreta se não for corrigido. |
| Recommended fix | Próxima correção verificável, sem prometer execução. |
| Status | Open, Fixed pending re-review, Re-reviewed, Accepted risk ou Not applicable. |

Não invente evidence, linhas, resultados de testes ou aprovação. Um finding sem evidência deve ser uma limitação, não uma acusação.

## Sem achados e nova revisão

Use “No findings observed” somente depois das três perspectivas. Inclua artefatos lidos e limitações, por exemplo diff ausente, arquivo binário ou teste não executado. Após mudança, aceite de risco ou nova evidência, execute re-review das perspectivas afetadas e atualize o status; não reutilize o resultado antigo como carimbo de aprovação.
