# AGENTS.md

## Repository rules

- **BRANCH STRUCTURE:** 
   - `main` is meta-only (reusable CI workflows, CI scripts and their tests, and docs) - there are no slice definitions in `main`
   - each `ubuntu-XX.YY` branch is a [Chisel](https://github.com/canonical/chisel) release, where `XX.YY` maps to the corresponding Ubuntu release (e.g. `26.04`). These branches contain the release definition file `chisel.yaml`, the Slice Definition Files (aka SDFs), and the slices' [Spread](https://github.com/canonical/spread) tests

## Working on `main`

### CI / Workflow rules

- **BLAST RADIUS:** Some workflows under `.github/workflows/` are reusable and are called by the release branches. Any change to these workflows may take effect immediately for every release branch, so treat workflow changes as affecting all branches at once
- **SCRIPTS**: CI helper scripts and their test suites live under `.github/scripts/<name>/`
- **LINTING**: YAML is linted with `yamllint`, configured at `.github/yamllint.yaml`
