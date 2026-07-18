# Esquema de evidência documental

## Estados obrigatórios

| Estado | Significado | Regra de redação |
| --- | --- | --- |
| `executed` | Uma ação foi realizada. | Informe evidence source, command/check e timestamp quando relevante. |
| `observed` | Um estado foi lido sem mutação. | Informe fonte exata e o que foi observado. |
| `planned` | Ação futura proposta. | Não a descreva como executada ou confirmada. |
| `not-run` | Ação não realizada ou sem evidência suficiente. | Informe a lacuna e a próxima verificação. |

## Campos por confirmação

| Escopo | Campos mínimos | Não permite concluir |
| --- | --- | --- |
| local artifact | caminho/artefato, evidence source, command ou check, timestamp quando relevante, commit/hash quando aplicável | GitHub, Drive ou production. |
| GitHub | URL, evidence source, command/check, commit/hash quando aplicável e timestamp quando relevante | deploy ou produção. |
| Drive | folder ID, file ID, size, modified metadata, evidence source, post-upload reread de metadata ou conteúdo | upload, overwrite ou deletion sem a releitura. |
| production | ambiente, URL quando aplicável, evidence source, check observado, timestamp e autoridade aplicável | mutação, deploy ou saúde total fora do check executado. |

## Forma mínima de registro

```text
estado: observed
escopo: Drive
evidence source: Drive connector
command/check: reread metadata
timestamp: 2026-07-18T12:01:00Z
folder ID: ...
file ID: ...
size: ...
modified metadata: ...
limite: confirmação restrita ao conteúdo/metadata relido
```

## Redação segura

Não registre secret, credential, token, senha, chave privada ou PII. Redija valores sensíveis e prefira referências seguras. Não preencha campos desconhecidos com suposições; ausência de hash, URL, Drive ID ou evidência torna a conclusão incompleta.
