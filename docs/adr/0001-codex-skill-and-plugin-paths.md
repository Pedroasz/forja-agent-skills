# ADR 0001 — Caminhos atuais de skills e plugin no Codex

**Status:** aceito

**Data:** 2026-07-18

## Contexto

O computador de casa possui skills existentes sob `%USERPROFILE%\.codex\skills`, mas o manual oficial atual do Codex informa que skills pessoais autoradas são descobertas em `%USERPROFILE%\.agents\skills`. O marketplace pessoal atual fica em `%USERPROFILE%\.agents\plugins\marketplace.json`, e caminhos locais de plugins devem ser relativos à raiz do marketplace e permanecer dentro dela.

A V4.2S precisa funcionar em computadores Windows diferentes, preservar conteúdo já instalado e não registrar caminhos pessoais absolutos.

## Decisão

1. Criar as 12 junctions de skills em `%USERPROFILE%\.agents\skills`.
2. Criar uma junction de plugin em `%USERPROFILE%\.agents\plugins\forja-development-pack`.
3. Registrar no marketplace `source.path` como `./plugins/forja-development-pack`.
4. Manter `%USERPROFILE%\.codex\skills` intocado; nenhuma migração automática será feita.
5. Usar `CODEX_HOME` somente para estado próprio do Codex e diagnóstico, não como raiz presumida das skills pessoais.
6. Informar que reinício do Codex ou nova sessão pode ser necessário após instalação.

## Consequências

- O caminho segue a documentação oficial atual e é independente do nome do usuário.
- Conteúdo legado permanece preservado.
- Há 12 junctions de descoberta e uma junction adicional de infraestrutura do plugin.
- O desinstalador deve distinguir os dois tipos e remover apenas links registrados no estado.
- Uma futura mudança oficial de caminho exigirá nova ADR e migração explícita, nunca silenciosa.

## Evidência normativa

- Manual oficial do Codex, **Build skills**, seção **Where to save skills**, obtido em 2026-07-18.
- Manual oficial do Codex, **Build plugins**, seções **Build your own curated plugin list**, **Marketplace metadata** e **Plugin structure**, obtido em 2026-07-18.
- Repositório oficial `openai/plugins`, `README.md`, `.agents/plugins/marketplace.json` e manifest `build-web-apps`, consultados em 2026-07-18.
