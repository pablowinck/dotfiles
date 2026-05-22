Pipeline orquestrado de feature ponta-a-ponta com superpowers: refino → impl paralelo + reviewers → PRs → review final → QA → teste local → reportar PRs.

**ARG da invocação:** descrição livre da feature (ex: "rastrear parceiro_pagador_id em passagens").

## Pré-leitura obrigatória (sempre, no início)

Invoque `superpowers:using-superpowers` antes de qualquer ação. Esse fluxo depende ativamente de skills do superpowers:
- `brainstorming` (fase 1)
- `dispatching-parallel-agents` (fases 2 e 4)
- `using-git-worktrees` (sempre que impl mexer em código existente)
- `test-driven-development` (impl)
- `requesting-code-review` (review pós-impl)
- `verification-before-completion` (antes de claim "PR pronto")
- `finishing-a-development-branch` (fase 3)

Se você ignorar superpowers nesse fluxo, vai entregar resultado pior.

## Visão geral das fases

| # | Fase | Paralelo? | Falha → relançar |
|---|---|---|---|
| 1 | Refinar spec | não | sim |
| 2 | N implementadores + 1 reviewer cada | sim (entre features independentes) | sim |
| 3 | Commit + abrir PRs | sequencial por repo | sim |
| 4 | Review final cross-PR | não | sim |
| 5 | QA levanta cenários | sim, paralelo com fase 4 | sim |
| 6 | Teste local E2E | não (após 4+5) | sim |
| 7 | Reportar PRs ao usuário | sim (final) | n/a |

**Regra absoluta:** "se um agente falhar ou entregar resultado insatisfatório, relance-o." Use `SendMessage` pra retomar o mesmo agente quando socket cair; use `Agent` novo apenas se o anterior já tiver feito muito trabalho desperdiçado ou se o contexto dele estiver poluído. Auto mode permite seguir sem confirmar entre fases — só pause em decisões destrutivas (DELETE em prod, force-push, etc.).

## Fase 1 — Refinar spec

Invoque a skill `superpowers:brainstorming`. Pra inputs do agente:
- Contexto da feature pedida
- Restrições conhecidas (regras PE: distributed-locks-financial, processador-clean-arch, flyway-migrations, etc.)
- Decisões em aberto que precisem do CTO antes de prosseguir
- Banco/serviços envolvidos
- Output em `/Users/pablowinter/projects/movvia/docs/superpowers/specs/YYYY-MM-DD-<slug>-design.md`

Espere o agente perguntar dúvidas — não chute. Quando ele propor opções, transmita pro Pablo via `AskUserQuestion`. Status final do frontmatter: `approved`.

**Critério de saída fase 1:** spec aprovada com schema (se DDL), endpoints/contratos, lista de arquivos a criar, plano de implementação dividido em N tarefas paralelas.

## Fase 2 — Implementadores paralelos + reviewers

Pra cada conjunto de mudanças independentes (ex: migration + service + filter), lance **um agente implementador**. Faça em paralelo (single message, múltiplos `Agent` calls com `run_in_background: true`).

Brief de cada implementador deve conter:
- Path do worktree fresh (use `using-git-worktrees`)
- Branch nova a partir de `develop` (pe-configuracoes é a partir de `main`)
- Lista exata de arquivos a criar/modificar
- Decisões já fechadas (não delegar de novo)
- Convenção PE relevante (skim CLAUDE.md do repo)
- Comando exato pra rodar build + test
- **Não commitar ainda** — reviewer aprova primeiro

Quando cada implementador terminar, **lance imediatamente o reviewer correspondente** (1:1, paralelo entre si). Reviewer:
- Skim spec + diff completo
- Aderência ao contrato (DDL ↔ JPA entity, etc.)
- Cross-cutting: segurança (PII, headers sensíveis), performance, idempotência, race conditions
- **Roda testes** (`mvn test` / `npm test`) — não confia em "passei localmente"
- Output: `APPROVED` / `REQUEST_CHANGES` / `REJECTED` + lista de findings por severidade

**Loop:** se reviewer pede `REQUEST_CHANGES`, **relance o mesmo implementador via SendMessage** com as correções específicas. Reviewer re-revisa. Repete até `APPROVED`. **NÃO** ignore findings importantes.

**Critério de saída fase 2:** todos implementadores `APPROVED`, sem commit, código em worktree pronto.

## Fase 3 — Commit + abrir PRs

**Um único** agente DevOps que:
- Pra cada branch: commit message detalhado (HEREDOC, sem emoji, co-author Claude Opus 4.7), `git push -u`
- `gh pr create --base develop` (ou `main` pra pe-configuracoes/pe-argocd)
- Body do PR: Resumo + Test plan checkbox + link spec
- **NUNCA** `--delete-branch`, **NUNCA** `--no-verify`
- Reporta URLs + SHAs + CI status inicial

**Critério de saída fase 3:** N PRs abertos, URLs coletadas, CI rodando.

## Fase 4 — Review final cross-PR

Lance um agente reviewer sênior em **background** que faz revisão de pré-prod:
- Cross-PR consistency (schema ↔ entity batem? contratos?)
- CI status final dos PRs
- CodeRabbit findings (lista críticos)
- Riscos pra PRD (flags, ordem de merge, pós-merge actions)
- Output: APPROVED / REQUEST_CHANGES por PR + recomendação de ordem de merge

Se REQUEST_CHANGES: relance implementador pra correção, depois re-revisa. Não cancele apenas porque tem nit — só CRITICAL bloqueia merge.

## Fase 5 — QA cenários (paralelo com fase 4)

Lance em paralelo um agente QA pra produzir cenários de teste. Categorias mínimas:
- BACK: curl + verificação SQL (>= 15 cenários)
- Operacionais: queries analíticas / suporte / LGPD
- Borda: falha de async, DB down, request inválida, body grande

Output em `/Users/pablowinter/projects/movvia/.tmp/cenarios-<slug>-YYYY-MM-DD.md` com IDs (FEAT-001…), tipo (ATIVIDADE/REGRESSÃO), severidade (P0/P1/P2), critério de aceite SQL.

**Critério de saída fase 5:** roteiro markdown publicado, cenários cobrindo a spec inteira.

## Fase 6 — Teste local E2E

Lance um agente QA que executa **subset crítico** (P0 + P1 representativos) do roteiro contra a stack local. Pré-reqs:
- Stack rodando (`docker-compose -f pedagio-eletronico/pe-api-banking/docker-compose.e2e.yml ps`)
- Migration aplicada (`docker-compose run --rm flyway-migrate`)
- Containers buildados nos worktrees corretos
- Seed/fixture conforme a feature

Output em `/Users/pablowinter/projects/movvia/.tmp/resultado-e2e-<slug>-YYYY-MM-DD.md`:
- X/N PASS, Y FAIL
- Tabela por cenário
- Detalhes dos FAILs (SQL real, resposta, hipótese)

**Loop crítico:** se teste local achar bug P0/P1 que reviewer perdeu (especialmente bugs que H2/mocks escondem mas PG real expõe), **relance o implementador via SendMessage** com correção. Após fix, re-rode os cenários que falharam.

**Critério de saída fase 6:** 100% P0 PASS. P1 e P2 podem ter fails documentados se for tradeoff aceitável.

## Fase 7 — Reportar PRs

Texto curto ao usuário:
- Links de todos os PRs criados (markdown clicável)
- Status final de cada (mergeable? CI?)
- Decisões pendentes pro usuário (ordem de merge? pe-configuracoes?)
- Caminhos dos artifacts (spec, cenários, relatório E2E)

## Patterns de comportamento

- **Tasks**: crie 1 task por fase via `TaskCreate`. Marca `in_progress` ao começar, `completed` ao finalizar. Não enfileire 20 tasks de uma vez — granularidade por fase.
- **Falha de socket de agente**: use `SendMessage` ao mesmo agentId com instruções terse pra retomar. Se cair 3+ vezes seguidas com 0 trabalho útil, assuma manualmente (sem agente).
- **Decisões destrutivas em ambientes compartilhados**: `AskUserQuestion` antes (DELETE em HML/PRD, merge em main, force-push, drop schema).
- **Auto mode**: prossiga sem confirmação entre fases. Pause só pra (a) resolver ambiguidade na spec ou (b) decisão destrutiva.
- **Background agents**: prefira `run_in_background: true` quando lança 2+ agentes paralelos. Aguarde a notificação automática; não polling.
- **Verificação antes de claim**: nunca diga "PR aberto" sem `gh pr view`, nunca diga "deploy OK" sem `kubectl rollout status`.

## Exemplo de saída final esperada

```
Pipeline X concluído.

PRs:
- pe-migrations #N: <url>  (MERGEABLE, CI verde)
- gestao-webhooks-api #M: <url>  (MERGEABLE, CI verde)

Artifacts:
- spec: <path>
- cenários: <path>
- relatório E2E: <path>

Pendências:
- Mergear na ordem (1) #N (2) #M
- PR pe-configuracoes pra habilitar flag em HML
```
