# Agent Commit Policy

This file is the authoritative policy for **agent or automation-authored commits and pull requests**
in this repository.

For repository architecture and AGENTS routing, see root `AGENTS.md`.
For contributor setup — git identity configuration, GitHub App installation, hook installation —
see `README.md`.

---

## Git identity

Commits authored by an agent must use the repo-local agent identity:

- **Name**: `settlespace-agent`
- **Email**: `settlespace-agent@local`

Set with:

```powershell
./scripts/setup/set-agent-git-identity.ps1
```

Clear with:

```powershell
./scripts/setup/set-agent-git-identity.ps1 -ClearLocalIdentity
```

Human-authored commits must not use this identity.

---

## Branch naming

Follow the [Conventional Branch](https://conventional-branch.github.io/) format:

```
<type>/<description>
```

- `<type>` must be one of: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
  `build`, `ci`, `chore`, `ops`
- `<description>` is kebab-case, concise, present-tense
- Examples: `feat/debt-settlement-algorithm`, `fix/duplicate-transaction-save`,
  `docs/update-agents-transactions`

One branch per logical deliverable. Do not bundle unrelated changes on one branch.

**No direct push to `main`.** All changes go through a pull request. The `pre-push` hook
enforces this locally; GitHub branch protection is the authoritative remote barrier.

---

## Commit message format

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<optional scope>): <description>

<optional body>

Agent: GitHub Copilot
```

Rules:
- Summary line: `type(scope): description` — imperative mood, no trailing period
- Supported types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`,
  `ci`, `chore`, `ops`
- Each non-empty body or trailer line must be **≤ 100 characters**
- The `Agent: GitHub Copilot` trailer is required on all agent-authored commits
- `Reviewed-by:` is optional unless `settlespace.requireReviewedBy=true`
- Human-authored commits must not include an `Agent:` trailer

---

## Pull request workflow

PRs must be opened using the `salakist-agent` GitHub App identity, not the contributor's
personal GitHub account. This enables the contributor to act as the required approver.

**Token generation:**

```powershell
$env:GH_TOKEN = (pwsh ./scripts/get-agent-token.ps1).Trim()
```

The token is short-lived (≤ 60 minutes). Regenerate if a subsequent `gh` call fails with
an auth error.

**Opening a PR:**

```powershell
$env:GH_TOKEN = (pwsh ./scripts/get-agent-token.ps1).Trim()
gh pr create `
  --title "<Conventional Commit summary>" `
  --body  "<body>" `
  --base  main `
  --head  <branch>
```

PR title must follow the same Conventional Commit format as the commit summary line.

**Adding changes to an open PR:**

Push new commits — do not amend or force-push onto a branch with an open PR.
Each follow-up change (fixes, review feedback, additions) must be a fresh commit on the
same branch. Commits will be squashed on merge, so the on-branch history does not need to
be clean.

**Merge policy:**
- PRs require **1 approving review** (the repository owner) before merge
- An agent may open and push to a PR without approval
- An agent must not merge a PR — merge is always a human action

---

## Pre-commit workflow

### Step 1 — Quality gate

Run the quality gate script and retain the log path:

```powershell
./scripts/checks/run-checks-debug.ps1
```

`./scripts/checks/run-full-checks-debug.ps1` also satisfies Step 1 when broader validation
is requested.

Non-blocking cosmetic diagnostics reported by the gate still require handling: fix them in
touched files or state a deferral reason in chat. Do not suppress with `#pragma warning disable`,
`NoWarn`, or similar. Never bypass hooks with `--no-verify`.

### Step 2 — Documentation alignment

Review the staged diff and update only documentation relevant to the current change set.
Documentation includes AGENTS files for any context whose key files, responsibilities, or
dependencies changed, plus any other source listed under "Documentation source of truth" in
root `AGENTS.md`.

---

## Checklist to state before `git commit`

```
Step 1: DONE | SKIPPED – <reason>  [log: <path if applicable>]
Step 2: DONE | SKIPPED – No documentation changes required – <reason>
Message preflight: DONE
```

Rules:
- Print the checklist in chat immediately before running `git commit`
- `Message preflight: DONE` means the summary is a valid Conventional Commit, includes the
  `Agent: GitHub Copilot` trailer, and every non-empty body/trailer line is ≤ 100 chars
- If checklist state changes after printing it, print an updated version before committing
- Do not commit if the checklist is missing or any step is neither `DONE` nor validly `SKIPPED`

---

## Skip conditions and acceptance rules

1. Any `SKIPPED` step must include a one-line reason.
2. **Step 1** may be `SKIPPED` only when:
   - there are no production code changes since the latest successful Step 1-equivalent gate run, and
   - the latest successful log path is shown in the checklist output.

   Step 1-equivalent runs are:
   - `./scripts/checks/run-checks-debug.ps1`
   - `./scripts/checks/run-full-checks-debug.ps1`

   Production code changes include implementation files under `SettleSpace.Domain/`,
   `SettleSpace.Infrastructure/`, `SettleSpace.Application/`, `settlespace-react/src/`, and
   runtime quality-gate script code or config under `scripts/`, excluding test files and
   documentation-only changes.

3. **Step 2** must always be reviewed for the staged diff. It may be `SKIPPED` only as
   `No documentation changes required` with a short reason tied to the staged changes.
4. A documentation-only commit may mark both steps `SKIPPED` only when all Step 1 skip conditions
   are satisfied and no further docs updates are needed.
5. If either step is neither `DONE` nor validly `SKIPPED`, do not commit.

---

## Hook boundaries

- `pre-commit` launches the repository quality gate; it should not own attribution or
  Conventional Commit parsing.
- `commit-msg` validates agent identity or trailer expectations, the Conventional Commit header,
  and commit body line length rules; it should not duplicate the pre-commit gate.
- `pre-push` blocks direct pushes to `main` only; it should not re-run the quality gate.
- Pre-wrap commit body lines to **100 characters or fewer** instead of relying on a failed hook
  run to discover formatting issues.
- Hook installation is handled by `./scripts/setup/setup-hooks.ps1`.
