# AGENTS.md

This is the `ubuntu-26.04` [Chisel](https://github.com/canonical/chisel/) release ([docs](https://ubuntu.com/chisel/docs/latest/)).

 - the Chisel release configuration file is `chisel.yaml`
 - slice definitions for Debian packages MUST go under `slices/`
 - slice definitions for packages of `kind: bin` MUST go under `bin-slices/`
 - [Spread](https://github.com/canonical/spread) tests for slice definitions go under `tests/spread`
 - the Spread configuration file is `spread.yaml`

## Instructions for working on package slices

If creating, modifying or testing slice definitions, you MUST install and use 
the `chisel-slicer` skill (from https://github.com/canonical/mason/tree/main/mason/skills/chisel-slicer/SKILL.md). If missing: `npx tessl i canonical/mason@0.1.0 --skill chisel-slicer`. 


