# Checks de UX e acessibilidade

## Navegação e foco

1. Percorra keyboard navigation em ordem de leitura: todo controle alcançável deve operar sem mouse e sem salto inesperado.
2. Confirme focus order coerente com a interface e visible focus em cada controle interativo.
3. Em modal, mova o foco para um elemento útil ao abrir, mantenha focus trap dentro do diálogo e faça focus return ao gatilho ao fechar, salvo destino mais adequado comunicado ao usuário.

## Conteúdo, erro e semântica

1. Confira contrast suficiente entre texto/ícone e fundo nos estados normal, hover, foco, desabilitado e erro quando existirem.
2. Garanta error association: associe cada error ao campo ou controle correspondente; forneça live feedback para mensagens novas que não recebam foco.
3. Prefira semantic HTML; confirme labels programáticos para campos e botões, e use roles apenas quando a semântica nativa não representar o componente.

## Mobile e proporcionalidade

1. Teste mobile no viewport afetado, incluindo conteúdo ampliado, quebra de linha, rolagem e controles alcançáveis.
2. Respeite reduced motion para animações não essenciais e não use movimento como único sinal de estado.
3. Avalie touch target proporcionalmente ao contexto: controles essenciais ou próximos não podem exigir toque de precisão; documente a limitação quando o layout impedir uma correção segura no escopo.

## Evidência

Registre fluxo, viewport ou dispositivo, método de entrada, estados cobertos, resultado e pendências. Não declare conformidade geral com um único fluxo ou sem inspeção observável.
