# Frontend Safety Checks

## Scope

Liste arquivos, DOM IDs, seletores, `event handlers`, rotas e estados alterados. Não presuma que um ID ou selector não é consumido por outro script.

## Functional checks

1. Confirme que cada DOM ID e referência JavaScript ainda existe e tem o tipo esperado.
2. Exercite cada `event handler` alterado uma vez no fluxo real; confirme que não foi registrado duas vezes.
3. Preserve escaping de dados controlados pelo usuário e trate HTML dinâmico como risco de XSS; não use `innerHTML` para texto não confiável.
4. Abra a aplicação após a alteração e verifique console, carregamento e renderização para detectar `blank screen`.
5. Teste o fluxo afetado em desktop e mobile, incluindo largura reduzida quando a UI for responsiva.
6. Percorra navigation por links, botões, voltar/avançar quando aplicável e confirme destino, estado e retorno.

## Evidence

Registre comando ou ambiente, fluxo executado, dispositivo ou viewport, resultado e falhas encontradas. Relate verificações não executadas como pendências, nunca como aprovação.
