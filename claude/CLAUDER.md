# clauder — wrapper de Claude Code com auto-retry de socket error

Wrapper bash que roda o Claude Code dentro de uma sessão `tmux` invisível, monitora o output da TUI, detecta o erro `API Error: The socket connection was closed unexpectedly` e digita `continue` automaticamente quando o claude fica travado.

## Por que existe

O Claude Code (binário Bun SEA) sofre de um bug conhecido em redes que fecham conexões TLS ociosas (ISP brasileiro residencial, redes corporativas com DPI, etc.). O issue [anthropics/claude-code#62034](https://github.com/anthropics/claude-code/issues/62034) documenta a causa raiz: a heurística interna `tengu_disable_keepalive_on_econnreset` testa `cause.code === ECONNRESET|EPIPE`, mas erros nativos do Bun não trazem `.code`, então a heurística nunca dispara e o pool de conexões reusa sockets meio-fechados.

Enquanto a Anthropic não corrige no upstream, `clauder` faz auto-retry pela TUI.

## Como funciona

```
┌────────────────────────────────────────────┐
│ Terminal do usuário                        │
│                                            │
│  attach ───────► tmux session ─► claude    │
│                       ▲                    │
│                       │                    │
│            monitor loop (poll 4s)          │
│             - capture-pane                 │
│             - detecta API Error            │
│             - confere se já tem continue   │
│             - confere se timer congelou    │
│             - send-keys "continue\n"       │
└────────────────────────────────────────────┘
```

### Heurísticas de quando disparar

O monitor só envia `continue` se **todos** os pontos abaixo forem verdade:

1. **Há erro pendente sem resposta** — varre o pane procurando o último `API Error` e verifica se NÃO existe uma linha `continue` depois dele. Cobre cenários:
   - `Error → continue → Error` → FIRE (último erro não respondido)
   - `Error` sozinho → FIRE
   - `Error → Error` → FIRE
   - `Error → continue` → SKIP (já respondido)
2. **Claude está travado, não processando** — captura o timer `(5m 57s)` no rodapé, espera 6s, captura de novo. Se o timer avançou ou apareceu, claude está vivo → skip. Se ficou congelado ou ausente nas 2 amostras → travado.
3. **Cooldown** — mínimo 120s entre disparos por sessão.
4. **Limite de tentativas** — 10 retries por sessão tmux.

### Capture inteligente do pane

O `tmux capture-pane` retorna o viewport inteiro (50 linhas), mas a maior parte costuma ser vazio depois do prompt. O capture do clauder identifica a última linha não-vazia e devolve as 20 linhas anteriores a ela. Isso garante que erros próximos ao prompt sempre entram no match, sem desperdiçar regex no rodapé vazio.

## Instalação

### Pré-requisitos

- `tmux` 3.2+ (testado em 3.6b)
- `claude` CLI no PATH (`~/.local/bin/claude` ou similar)
- `bash` 3.2+ (default macOS) ou `bash` 4+ (Linux)

### macOS

```bash
brew install tmux
ln -sf ~/projects/dotfiles/claude/clauder ~/.local/bin/clauder
ln -sf ~/projects/dotfiles/tmux/.tmux.conf ~/.tmux.conf
```

### WSL / Linux

O `wsl/install.sh` deste repo já instala `tmux` (lib `01-apt.sh`) e cria os symlinks (lib `13-configs.sh`). Pra rodar manualmente:

```bash
sudo apt-get install -y tmux
ln -sf ~/.dotfiles/claude/clauder ~/.local/bin/clauder
ln -sf ~/.dotfiles/tmux/.tmux.conf ~/.tmux.conf
```

## Uso

Substitui `claude` na linha de comando:

```bash
clauder                                          # equivalente a "claude"
clauder --dangerously-skip-permissions
clauder --dangerously-skip-permissions --resume
clauder -p "uma pergunta one-shot"
```

Tudo é repassado pro `claude` original. O monitor roda em paralelo no background.

### Atalhos do tmux

A config `tmux/.tmux.conf` mantém o tmux quase invisível pro usuário (sem prefix bindings exóticos). O importante é:

- **`shift+enter`** — funciona como newline no claude (via `extended-keys csi-u`)
- **Mouse** — ativado pra scroll/seleção (`mouse on`)
- **Scrollback** — 50000 linhas

Pra detach manual da sessão: `Ctrl+B` então `D` (deixa claude rodando em background, monitor continua vivo).

## Configuração

Constantes editáveis no topo do script `clauder`:

| Variável | Default | O que controla |
|----------|---------|----------------|
| `CLAUDE_BIN` | `$HOME/.local/bin/claude` | Caminho do binário do claude |
| `LOG_DIR` | `$HOME/.claude/retry-logs` | Onde os logs do monitor são gravados |
| `ERROR_PATTERN` | regex de 4 erros | Quais mensagens disparam o retry |
| `TIMER_REGEX` | `\(([0-9]+h )?([0-9]+m )?[0-9]+s\)` | Como achar o timer do claude |
| `STUCK_CHECK_DELAY` | `6` segundos | Quanto esperar entre as 2 amostras do timer |
| `POLL_INTERVAL` | `4` segundos | Frequência do loop principal |
| `COOLDOWN_AFTER_RETRY` | `120` segundos | Tempo mínimo entre 2 disparos |
| `MAX_AUTO_RETRIES` | `10` | Limite total por sessão |

Pra override por sessão: `CLAUDE_BIN=/outro/path clauder ...`

## Logs e debug

Cada sessão escreve em `~/.claude/retry-logs/session-YYYYMMDD-HHMMSS.log`:

```
[2026-05-25 14:32:11] starting session=clauder-12345-1779638883 with args: --resume
[2026-05-25 14:35:42] claude stuck (timer='(5m 57s)' = '(5m 57s)') with socket error — auto-retry 1/10
[2026-05-25 14:38:01] timer moved ((6m 12s) → (6m 15s)) — claude still processing, skipping
[2026-05-25 14:42:18] no pending error needing continue on 2nd sample, skipping
[2026-05-25 14:55:30] session ended
```

Pra acompanhar em tempo real:

```bash
tail -f ~/.claude/retry-logs/session-*.log
```

Pra ver as sessões tmux ativas:

```bash
tmux ls | grep clauder
```

Pra matar todas e relançar:

```bash
tmux ls | grep clauder | cut -d: -f1 | xargs -I {} tmux kill-session -t {}
clauder --dangerously-skip-permissions --resume
```

## Limitações conhecidas

- **Falso positivo possível** se a string "API Error: socket connection..." aparecer no meio de uma resposta do claude (ex: explicação técnica desse bug). Mitigação: cooldown de 120s + check de timer + check de "continue depois".
- **Não recupera mid-stream** — se o socket caiu no meio de uma resposta longa, a parte já streamada se perde. Claude precisa começar do início. Limitação fundamental da API SSE da Anthropic, não do wrapper.
- **Não funciona se `tmux` não estiver instalado** — nesse caso o wrapper degrada pra `exec claude "$@"` (sem monitor).
- **Só macOS e Linux** — não testado em WSL1 nem em Termux.

## Como atualizar o wrapper

```bash
cd ~/projects/dotfiles
git pull
# o symlink já aponta pro arquivo do repo, próxima invocação pega a versão nova
```

Sessões `clauder` já abertas continuam rodando a versão antiga em memória até serem fechadas.

## Referências

- Issue raiz no Claude Code: [anthropics/claude-code#62034](https://github.com/anthropics/claude-code/issues/62034)
- Issue canônico de ECONNRESET: [anthropics/claude-code#5674](https://github.com/anthropics/claude-code/issues/5674)
- Análise QUIC/HTTP3: [anthropics/claude-code#49761](https://github.com/anthropics/claude-code/issues/49761)
