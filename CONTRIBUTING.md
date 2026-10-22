# Contributing to ProjDesk

## Branching Workflow

```
master (stable, always deployable)
  |
  +-- feature/<name>  (new features)
  +-- fix/<name>      (bug fixes)
  +-- docs/<name>     (documentation)
  +-- refactor/<name> (code cleanup)
```

## Rules

1. **Never commit directly to `master`**
2. Create a feature branch from `master`
3. Commit your work on the feature branch
4. Run full test suite before merging:
   ```powershell
   cd moonbit && moon test
   cd ../web && npm run test && npm run build
   ```
5. Merge to `master` (squash or merge commit)

## Branch Naming

| Type | Prefix | Example |
|------|--------|---------|
| New feature | `feat/` | `feat/dark-theme` |
| Bug fix | `fix/` | `fix/sql-injection` |
| Documentation | `docs/` | `docs/readme-english` |
| Refactoring | `refactor/` | `refactor/projector-trait` |
| CI/Build | `ci/` | `ci/test-pipeline` |

## Commit Messages

Format: `type(scope): description`

Examples:
- `feat(ui): add drag-to-reorder for fields`
- `fix(security): sanitize SQL identifiers`
- `docs(readme): add setup instructions`

## Pre-merge Checklist

- [ ] All tests pass (moon test + vitest)
- [ ] No console errors in dev server
- [ ] No secrets or build artifacts committed
- [ ] Commit messages follow convention
