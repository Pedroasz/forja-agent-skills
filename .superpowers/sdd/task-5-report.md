# Task 5 Report: forja-safe-frontend-change

## RED baseline

Os prompts de alteração de botão e de navegação mobile não forneciam, por si, um contrato que exigisse verificar DOM IDs, `event handlers`, escaping/XSS, `blank screen`, desktop/mobile, navegação e aprovação antes do merge funcional do SaaS. O prompt de documentação também precisava provar o anti-gatilho.

Foi criada primeiro a suíte determinística `SkillTriggers`, com os prompts reais em `tests/skill-trigger-cases.json` e as seleções esperadas em `tests/expected-skill-selection.json`. A execução RED falhou com `safe frontend change skill is missing`.

## GREEN evidence

`forja-safe-frontend-change` implementa o contrato de 12 seções, front matter somente com `name` e `description`, risco padrão MODERATE, anti-gatilho para `documentation-only`, checks de frontend e handoffs condicionais para UX, performance e estratégia de testes.

A suíte executa os prompts reais para mudança de botão, navegação mobile e edição somente de documentação. As duas mutações substituem a solicitação funcional por documentação; a suíte falha se a seleção não mudar, evitando evidência baseada apenas em IDs de fixture.

## Validation

- `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Run-Tests.ps1 -Suite SkillTriggers` — PASS.
- `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Run-Tests.ps1 -Suite Routing` — PASS, preservando os cinco casos canônicos.
- `powershell -NoProfile -ExecutionPolicy Bypass -File tests/Run-Tests.ps1 -Suite Manifests` — PASS.
- `quick_validate.py` foi invocado com o Python local e `PYTHONPATH=C:\Users\Pedro\.codex\skills\.system\skill-creator`, mas não pôde iniciar porque o Python bundled não contém o módulo `yaml` (`ModuleNotFoundError`). Nenhuma dependência foi instalada; a suíte local valida estrutura e requisitos semânticos da skill.
