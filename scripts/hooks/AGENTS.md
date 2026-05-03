# scripts/hooks AGENTS Metadata

## Role
Own the Git hook source templates that enforce commit-time checks in this repository.

## Responsibilities
- Keep `pre-commit` focused on launching the changed-code quality gate.
- Keep `commit-msg` focused on local agent commit attribution, trailer enforcement, and Conventional Commit validation.
- Preserve lightweight shell compatibility for hooks copied into `.git/hooks`.
- Keep hook documentation aligned with `scripts/setup/setup-hooks.ps1`, `scripts/setup/set-agent-git-identity.ps1`, and the local commit message rules.

## Key files
- `pre-commit`
- `commit-msg`
- `pre-push`
- `../setup/setup-hooks.ps1`
- `../setup/set-agent-git-identity.ps1`
- `../get-agent-token.ps1`

## Hook enforcement scope
These boundaries describe how the local hooks enforce parts of root `COMMIT-POLICY.md` without
re-owning the full workflow.

- `pre-commit` should launch the repository quality gate and should not absorb commit attribution
  or Conventional Commit parsing logic.
- `commit-msg` should validate agent identity/trailer expectations, the Conventional Commit header,
  and commit body line length rules, and should not duplicate the pre-commit quality gate.
- `pre-push` should block direct pushes to `main` only; it should not re-run the quality gate.
- Agents should pre-wrap commit body lines to **100 characters or fewer** instead of relying on a
  failed hook run to discover formatting problems.
- Hook installation remains the responsibility of `setup-hooks.ps1`.

## Commands
- `./scripts/setup/setup-hooks.ps1`
- `./scripts/setup/set-agent-git-identity.ps1`
- `./scripts/setup/set-agent-git-identity.ps1 -ClearLocalIdentity`
- `$env:GH_TOKEN = (pwsh ./scripts/get-agent-token.ps1).Trim()`

## Dependencies
- Git with a working `.git/hooks` directory
- A shell environment compatible with the minimal hook launchers
- Node/npm with the local `scripts/package.json` dev dependencies installed for Conventional Commit validation
- Repo-local Git config values used by the attribution policy (`settlespace.agentName`, `settlespace.agentEmail`, `settlespace.agentTrailer`, `settlespace.requireReviewedBy`)

## Source-of-truth note
Repo-wide AGENTS routing is defined in root `AGENTS.md`. Agent commit workflow, checklist rules,
and commit attribution policy are authoritative in root `COMMIT-POLICY.md`.
The parent `scripts/AGENTS.md` routes broader scripts guidance, and detailed gate behavior lives in `scripts/checks/AGENTS.md`.
