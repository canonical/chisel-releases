---
# On-demand slice review, driven by the `chisel-slice-reviewer` skill from
# canonical/mason. The review rules live in mason and are installed at run time;
# this file only wires that skill up to a pull request.
#
# Compile with `gh aw compile` after any change to this frontmatter and commit the
# generated `mason-review.lock.yml` next to this file -- the lock file is what
# GitHub Actions runs.
# Ref: https://github.github.com/gh-aw/reference/frontmatter/

on:
  slash_command:
    name: mason-review
    events:
      - issue_comment
  roles:
    - admin
    - maintainer
    - write

engine:
  id: copilot
  model: gpt-5.5

permissions:
  contents: read
  pull-requests: read
  copilot-requests: write

timeout-minutes: 30

skills:
  # Pinned by tag; `gh aw compile` resolves it to a commit SHA. The path form
  # installs only the reviewer, not mason's write-capable authoring skills.
  - canonical/mason/skills/chisel-slice-reviewer@v0.2.0

network:
  allowed:
    - defaults          # certificates, archive.ubuntu.com, security.ubuntu.com, ppa.launchpad.net
    - github            # github.com, *.githubusercontent.com -- `defaults` does not cover these
    - ports.ubuntu.com  # package lookups for every architecture except amd64/i386

steps:
  - name: Install uv
    uses: astral-sh/setup-uv@20cfd1bf945f4377ade1205e4dbc17946fc9a30d # v10.0.1

tools:
  github:
    toolsets:
      - pull_requests
  bash:
    - git
    - uv run
    - python3
    - ls
    - cat
    - head
    - tail
    - grep
    - wc
    - sort
    - uniq
    - find

safe-outputs:
  add-comment:
    max: 1
    hide-older-comments: true
---

# Mason slice review

The `chisel-slice-reviewer` skill from canonical/mason has been installed for you.
Follow its `SKILL.md`. That skill is the source of truth for what to check and how to
report it; nothing here restates or overrides its rules.

## Context the skill would otherwise ask you for

The skill is written for an interactive session against a checkout you supply.
Neither holds here, so:

- The working directory is already a checkout of this repository at the pull
  request's head commit. Use it. Do not ask where the checkout is, and do not clone
  another one.
- Look up the pull request this command was issued on and take its base branch.
  Fetch that branch before running any check that needs it:
  `git fetch --depth 1 origin <base-branch>:refs/remotes/origin/<base-branch>`, then
  pass `origin/<base-branch>` wherever the skill asks for a base ref.
- Run `_orientation.py` with `python3`; it is deliberately stdlib-only. Run every
  other helper with `uv run`, which resolves the dependencies those scripts declare.
  Plain `python3` on them reports every check as unavailable rather than failing,
  which would produce a silently empty review.
- There is no user to respond to. Your final message is the review, and it is posted
  as a single pull request comment.

## Steering from the triggering comment

The comment that invoked this run is below. Anything after the command is the
reviewer steering the pass -- naming architectures to inspect, narrowing the review
to one area, or calling out changes as deliberate so they are not reported as
regressions. Honour it where it is clear. If it is empty, or you cannot interpret
it, note that in one line and review the pull request in full anyway. Never refuse.

<triggering-comment>
${{ steps.sanitized.outputs.text }}
</triggering-comment>

## Output

Report as the skill specifies, and state two things plainly at the top: the verdict,
in the skill's own vocabulary, and that this review is advisory. Merging still
requires the repository's own CI to pass and two maintainer approvals.
