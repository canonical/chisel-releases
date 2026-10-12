# Review instructions

Review slice definition changes with the `chisel-slice-reviewer` skill, installed at
`.github/skills/chisel-slice-reviewer/`. Do not run spread tests since CI already runs
them on every pull request. You can read their result through the GitHub MCP server.

Pull requests against `main` change CI and workflows only; review those as ordinary code,
without the skill.
