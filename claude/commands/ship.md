Commit all staged/unstaged changes, push to develop, and monitor CI/CD until completion.

## Steps

### 1. Identify affected repos

Look at the modified files and determine which repo(s) have changes. Each project lives in its own subdirectory with its own `.git` (e.g., `pe-portais/`, `pe-bff-portal/`, `pe-api-core/`, etc.). **NEVER** run git from the `00-pedagio-eletronico/` root.

### 2. Commit and push each repo

For each repo with changes:
1. `cd` into the repo directory
2. `git status` and `git diff --stat` to review changes
3. `git log --oneline -3` to match commit message style
4. Stage the specific changed files (never `git add -A`)
5. Commit with a descriptive message following conventional commits (`fix:`, `feat:`, etc.)
6. `git push origin develop` (rebase if rejected: `git pull --rebase origin develop && git push origin develop`)

### 3. Monitor CI/CD

For **backend repos** (pe-api-core, pe-bff-portal, pe-api-banking, pe-gateway-api, pe-api-notification, tpa-*):
```bash
gh run list --repo freeflowsoftware/<repo> --branch develop --limit 3
gh run watch <run-id> --repo freeflowsoftware/<repo> --exit-status
```

For **frontend repos** (pe-portais — all apps deploy via Vercel):
```bash
# Each monorepo app has its own Vercel project:
# pe-portal, pe-portal-backoffice, pe-portal-concessionaria, pe-portal-cnl, pe-portal-camanducaia
vercel ls <project-name> --yes 2>&1 | head -10
```
Check that the latest deployment shows status `Ready`. If `Building`, wait and re-check.

For **mixed changes** (both backend and frontend), run both checks in parallel.

### 4. Report results

Summarize:
- Which repos were committed and pushed
- CI/CD status for each (pass/fail, duration)
- Vercel deployment status for frontend apps (Ready/Error/Building)
- Any issues found
