# Gates de release

## Classificação obrigatória

| Classe | Escopo | Risco | Merge automático |
|---|---|---|---|
| `PACKAGE_DOCS_ONLY` | FORJA Development Pack, alteração `docs-only` ou interna de skills, sem comportamento do SaaS | LOW | Elegível somente com todos os gates abaixo aprovados |
| `SAAS_FUNCTIONAL` | FORJA SaaS com mudança de comportamento, UI, autenticação, banco, integração ou deploy | HIGH ou maior | Nunca; requer explicit human approval antes de merge e deploy |

Não infira `PACKAGE_DOCS_ONLY` pela palavra “package” ou pelo ID da tarefa. Confirme o repositório do pacote, o diff sem arquivo funcional do SaaS e a natureza `docs-only`/interna. Não reduza `SAAS_FUNCTIONAL` a LOW porque os checks passaram; HIGH prevalece.

## Gates do pacote de skills

Um merge automático é apenas elegível, nunca presumido, quando todos estiverem observados:

1. A branch e o PR alvo obedecem à branch protection remota.
2. Os checks e a CI exigidos estão concluídos e aprovados para o commit candidato.
3. As reviews obrigatórias estão aprovadas e não há finding bloqueador aberto.
4. A evidence de validação corresponde ao diff e não contém alegação não observada.
5. `VERSION`, manifest e changelog têm a mesma versão estável.
6. A **annotated tag** é anotada, aponta ao commit aprovado e tem proveniência verificável.

Sem todos os seis gates, mantenha merge, tag e GitHub Release pendentes. Depois de uma ação remota autorizada, faça remote confirmation do branch, checks, merge, tag e release efetivamente existentes antes de relatá-los como sucesso.

## Gates do SaaS funcional

Além de branch protection, CI/checks, reviews, evidence, version e changelog, uma release `SAAS_FUNCTIONAL` exige aprovação humana explícita e específica para o merge e para o deploy. Uma aprovação de PR não autoriza automaticamente produção; uma execução local não confirma deploy remoto. A aprovação deve identificar o alvo e a ação autorizada.

Não execute merge ou deploy em testes, planos ou simulações. Não afirme que houve merge, deploy, tag, GitHub Release ou sucesso de CI sem resultado real e remote confirmation aplicável.

## Proveniência de versão e tag

Registre versão estável, commit candidato, branch/PR, URL ou identificador do check, reviews, hash do changelog e tag anotada. A tag deve ser criada somente após o commit aprovado e deve apontar para ele; nunca mova ou recrie tag para ocultar uma falha. A GitHub Release usa a tag e o changelog validados, não um texto estimado.

## Falha, rollback e interrupção

Pare diante de proteção ausente, check/CI inconclusivo, review pendente, evidência divergente, versão/changelog/tag inconsistentes, conflito remoto, autorização ausente, dados reais ou deploy irreversível. Preserve logs, hashes e o estado da branch.

Antes de uma ação funcional autorizada, defina rollback verificável: versão/commit anterior, responsável, condição de acionamento, efeito esperado e confirmação remota após reversão. Se a ação falhar, não force push nem reescreva histórico; aplique somente o rollback aprovado e registre o resultado observado.
