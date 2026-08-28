# AGENTS.md

## Repository rules

- **BRANCH STRUCTURE:** 
   - `main` is meta-only (reusable CI workflows, CI scripts and their tests, and docs) - there are no slice definitions in `main`
   - `ubuntu-XX.XX` branches hold [Chisel](https://github.com/canonical/chisel) releases (`chisel.yaml`, Slice Definition Files (aka SDFs) under `slices/`, [Spread](https://github.com/canonical/spread) tests)

## Working on `main`

### CI / Workflow rules

- **BLAST RADIUS:** Some workflows under `.github/workflows/` are reusable and are called by the release branches. Any change to these workflows may take effect immediately for every release branch, so treat workflow changes as affecting all branches at once
- **SCRIPTS**: CI helper scripts and their test suites live under `.github/scripts/<name>/`
- **LINTING**: YAML is linted with `yamllint`, configured at `.github/yamllint.yaml`.
