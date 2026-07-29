"""omp (oh-my-pi) agent invocation: prompt assembly + one-shot `omp -p` runner.

The builder assembles a single prompt (paths, deps, dep-SDF summaries, skill pointer), runs
``omp -p`` with ``--tools read,write,search,bash`` and the checkout as ``--cwd``, and reads the
SDF the agent writes to a known temp path inside the checkout. On validation failure the builder
re-runs with the validation errors appended (up to ``--retries``).
"""

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path

from slice_builder.config import BuildConfig, DepRef

# The agent writes its SDF here (inside the checkout so its `write` tool can reach it).
AGENT_OUTPUT_NAME = ".slice-builder-agent-output.yaml"

# Tools the agent is allowed to use.
AGENT_TOOLS = "read,write,search,bash"


@dataclass
class AgentPaths:
    """Paths derived from a checkout for agent I/O."""

    checkout: Path
    agent_output: Path
    system_prompt: Path
    skill: Path


def agent_paths(checkout: str | Path) -> AgentPaths:
    """Compute the agent's I/O paths for a checkout.

    The system prompt and skill live under the slice-builder source tree (two levels up from
    this module's parent package dir).
    """

    root = Path(__file__).resolve().parents[2]
    checkout = Path(checkout)
    return AgentPaths(
        checkout=checkout,
        agent_output=checkout / AGENT_OUTPUT_NAME,
        system_prompt=root / "prompts" / "system.md",
        skill=root / "skills" / "sdf-generation" / "SKILL.md",
    )


def _summarise_dep(dep: DepRef) -> str:
    """Build a compact text summary of a dependency SDF for the agent prompt."""

    sdf = dep.sdf
    pkg = sdf.get("package", dep.sd_name)
    store = sdf.get("store")
    kind = "bin" if store == "bin" else "deb"
    ref_prefix = dep.prefix
    lines = [f"### Dependency: {dep.sd_name} ({kind})"]
    lines.append(f"package: {pkg}")
    if store:
        lines.append(f"store: {store}")
    slices = sdf.get("slices") or {}
    lines.append("slices:")
    for name, sl in slices.items():
        full = f"{ref_prefix}{dep.sd_name}_{name}"
        contents = (sl or {}).get("contents") or {}
        paths = list(contents.keys())
        lines.append(f"  - {name} (ref: {full}) paths: {paths}")
    return "\n".join(lines)


def build_prompt(
    config: BuildConfig,
    paths: list[str],
    extracted_dir: Path,
    deps: list[DepRef],
    ap: AgentPaths,
    own_identifier: str,
) -> str:
    """Assemble the full agent prompt (system prompt + task).

    ``extracted_dir`` is the directory the archive was extracted into; the agent can inspect file
    types and contents there with its ``read``/``bash`` tools (e.g. ``file``, ``cat``) to make
    better classification decisions than path names alone allow.
    """

    sys_prompt = ap.system_prompt.read_text(encoding="utf-8") if ap.system_prompt.is_file() else ""
    skill_text = ap.skill.read_text(encoding="utf-8") if ap.skill.is_file() else ""

    sections: list[str] = []
    if sys_prompt:
        sections.append(sys_prompt)
    if skill_text:
        sections.append("# sdf-generation skill\n\n" + skill_text)

    task_lines = [
        "# Task",
        "",
        f"Generate an SDF for the bin package `{config.package}`.",
        "- store: bin",
        f"- default-track: {config.track} (emit double-quoted)",
        f"- unique package identifier: {own_identifier}",
        "",
        "## Extracted archive",
        "",
        f"The bin archive has been extracted to `{extracted_dir}`. Inspect file types and",
        "contents there with your `read` and `bash` tools (e.g. `file`, `cat`) as needed to",
        "classify paths correctly. The Chisel content paths in the SDF must be absolute",
        "(leading `/`), matching the archive member paths listed below.",
        "",
        "## Archive paths",
        "",
        "Classify each path into a slice using the skill's path table. Do not drop any path.",
        "",
        "```",
    ]
    task_lines.extend(paths)
    task_lines.append("```")
    sections.append("\n".join(task_lines))

    if deps:
        dep_block = ["## Dependencies", ""]
        dep_block.append(
            "Resolve essential slices for the `bins` slice (or other slices as appropriate). "
            "Bin deps use the prefixed ref; deb deps use the bare ref."
        )
        dep_block.append("")
        for dep in deps:
            dep_block.append(_summarise_dep(dep))
            dep_block.append("")
        sections.append("\n".join(dep_block))

    sections.append(
        f"## Output\n\nWrite the final SDF to `{ap.agent_output}` using the `write` tool, "
        "then stop. The builder will sort, apply `prefer`, and validate."
    )

    return "\n\n".join(s for s in sections if s)


def run_omp(
    prompt: str,
    ap: AgentPaths,
    config: BuildConfig,
    extra_retry_note: str = "",
) -> str:
    """Run `omp -p` one-shot and return the agent's stdout.

    Raises ``RuntimeError`` if omp is not on PATH or exits non-zero.
    """

    full_prompt = prompt
    if extra_retry_note:
        full_prompt = full_prompt + "\n\n" + extra_retry_note

    cmd = [
        config.omp,
        "-p",
        full_prompt,
        "--tools",
        AGENT_TOOLS,
        "--cwd",
        str(ap.checkout),
        "--auto-approve",
        "--no-session",
    ]
    if config.omp_model:
        cmd.extend(["--model", config.omp_model])

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except FileNotFoundError as exc:
        raise RuntimeError(f"omp not found on PATH: {config.omp}") from exc

    if proc.returncode != 0:
        stderr = proc.stderr.strip()
        raise RuntimeError(f"omp exited {proc.returncode}: {stderr}")
    return proc.stdout


def read_agent_output(ap: AgentPaths) -> str:
    """Read the SDF the agent wrote to ``ap.agent_output``.

    Raises ``RuntimeError`` if the file is missing (agent wrote nothing).
    """

    if not ap.agent_output.is_file():
        raise RuntimeError(f"agent wrote no SDF at {ap.agent_output}")
    return ap.agent_output.read_text(encoding="utf-8")
