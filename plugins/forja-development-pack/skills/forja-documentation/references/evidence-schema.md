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
| Drive: novo arquivo | folder ID, file ID, size, modified metadata, evidence source, post-upload reread de metadata ou conteúdo; backup `NOT_APPLICABLE` com reason | upload sem a releitura. |
| Drive: update/overwrite | backup-before-update: pre-update metadata/conteúdo, backup file ID, backup name com timestamp, backup size, backup modified, backup confirmation, original file ID preservado, e post-upload reread | update/overwrite até o backup confirmado; never delete history. |
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

## Atualização de arquivo existente no Drive

Antes de update ou overwrite, leia o arquivo existente e seus metadados (`pre-update`). Preserve o conteúdo remoto como backup timestampado ou cópia suportada pelo conector. Registre `backup file ID`, `backup name`, `backup size`, `backup modified` e `backup confirmation` por releitura de metadata ou conteúdo. Somente depois atualize o arquivo, preservando o `original file ID` quando isso for seguro. Nunca delete history.

Para upload de um arquivo novo, use `backup: NOT_APPLICABLE` e declare a reason: não havia arquivo remoto existente para preservar.

## Redação segura

Não registre secret, credential, token, senha, chave privada ou PII. Redija valores sensíveis e prefira referências seguras. Não preencha campos desconhecidos com suposições; ausência de hash, URL, Drive ID ou evidência torna a conclusão incompleta.
