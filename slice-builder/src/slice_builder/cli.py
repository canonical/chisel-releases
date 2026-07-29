"""argparse CLI + main() orchestration for `slice-builder`.

Mirrors slupgrader's `cli.py` / `__main__.py` split. Exit codes:
- 0 success
- 1 SDF generation failed (agent / validation failure)
- 2 input/config error (bad archive, missing dep SDF, bad args, omp not on PATH, output exists)
"""

from __future__ import annotations

import argparse
import shutil
import sys
import tempfile
from pathlib import Path

from slice_builder.agent import (
    agent_paths,
    build_prompt,
    read_agent_output,
    run_omp,
)
from slice_builder.archive import extract_archive, extract_paths
from slice_builder.checkout import shallow_clone
from slice_builder.config import BuildConfig
from slice_builder.deps import resolve_deps
from slice_builder.overlay import overlay
from slice_builder.prefer import apply_prefer, scan_prefer
from slice_builder.release import parse_chisel_yaml
from slice_builder.render import render
from slice_builder.sdf import parse_sdf
from slice_builder.validate import format_errors, validate, validate_semantic

# Exit codes.
EXIT_OK = 0
EXIT_GEN_FAILED = 1
EXIT_CONFIG_ERROR = 2


def build_parser() -> argparse.ArgumentParser:
    """Construct the top-level argument parser."""

    parser = argparse.ArgumentParser(
        prog="slice-builder",
        description="Generate Chisel slice definition files (SDFs) for bin packages.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    gen = sub.add_parser("generate-sdf", help="Generate an SDF for a bin archive.")
    gen.add_argument("--bin-archive", required=True, help="Path to the .tar.xz bin archive.")
    gen.add_argument("--base", required=True, help="Ubuntu base (e.g. 26.04).")
    gen.add_argument("--package", required=True, help="Bin's SD name, bare (e.g. curl).")
    gen.add_argument("--track", required=True, help="Bin's track (e.g. v1.2.3).")
    gen.add_argument(
        "--dependencies",
        default="",
        help="Comma-separated sd_name values (may be empty).",
    )
    gen.add_argument(
        "--sdf-lookup-dir",
        default=None,
        help="Read-only cache of already-generated bin SDFs.",
    )
    gen.add_argument("--output", required=True, help="Full output path for the SDF.")
    gen.add_argument("--omp", default="omp", help="Path to omp binary; default 'omp' on PATH.")
    gen.add_argument("--omp-model", default=None, help="Model selector for omp.")
    gen.add_argument("--retries", type=int, default=3, help="Max agent retries on validation fail.")
    return parser


def _parse_config(args: argparse.Namespace) -> BuildConfig | int:
    """Build a BuildConfig from parsed args, validating simple invariants.

    Returns a :class:`BuildConfig` on success, or an exit code (int) on a config error.
    """

    if args.retries < 1:
        print(
            f"slice-builder: error: --retries must be >= 1, got: {args.retries}",
            file=sys.stderr,
        )
        return EXIT_CONFIG_ERROR
    deps = (
        [d.strip() for d in args.dependencies.split(",") if d.strip()] if args.dependencies else []
    )
    return BuildConfig(
        bin_archive=args.bin_archive,
        base=args.base,
        package=args.package,
        track=args.track,
        dependencies=deps,
        sdf_lookup_dir=args.sdf_lookup_dir,
        output=args.output,
        omp=args.omp,
        omp_model=args.omp_model,
        retries=args.retries,
    )


def _fail(msg: str, code: int) -> int:
    """Print an error to stderr and return an exit code."""

    print(f"slice-builder: error: {msg}", file=sys.stderr)
    return code


def generate_sdf(config: BuildConfig) -> int:
    """Run the full generate-sdf pipeline. Returns an exit code."""

    # --- input/config validation ---
    if not Path(config.bin_archive).is_file():
        return _fail(f"bin archive not found: {config.bin_archive}", EXIT_CONFIG_ERROR)
    if shutil.which(config.omp) is None:
        return _fail(f"omp not found on PATH: {config.omp}", EXIT_CONFIG_ERROR)
    if Path(config.output).exists():
        return _fail(
            f"output already exists, refusing to overwrite: {config.output}",
            EXIT_CONFIG_ERROR,
        )

    # --- extract archive paths (for early validation + the prompt path list) ---
    try:
        paths = extract_paths(config.bin_archive)
    except ValueError as exc:
        return _fail(str(exc), EXIT_CONFIG_ERROR)
    if not paths:
        return _fail("archive contains no paths", EXIT_CONFIG_ERROR)

    # --- shallow clone + parse chisel.yaml ---
    with tempfile.TemporaryDirectory(prefix="slice-builder-") as tmp:
        checkout = Path(tmp) / "checkout"
        try:
            shallow_clone(config.base, checkout)
        except RuntimeError as exc:
            return _fail(str(exc), EXIT_CONFIG_ERROR)

        try:
            release = parse_chisel_yaml(checkout)
        except ValueError as exc:
            return _fail(str(exc), EXIT_CONFIG_ERROR)

        # --- overlay lookup SDFs ---
        overlay(config.sdf_lookup_dir, checkout, release.bin_sdf_dir)

        # --- resolve deps ---
        try:
            deps = resolve_deps(
                config.dependencies, config.sdf_lookup_dir, checkout, release.bin_prefix
            )
        except ValueError as exc:
            return _fail(str(exc), EXIT_CONFIG_ERROR)

        own_identifier = f"{release.bin_prefix}{config.package}"
        ap = agent_paths(checkout)

        # --- extract the archive to a directory the agent can inspect ---
        # The agent needs file types and contents (not just names) to classify paths correctly.
        extracted_dir = checkout / ".bin-archive-extracted"
        try:
            extract_archive(config.bin_archive, extracted_dir)
        except ValueError as exc:
            return _fail(str(exc), EXIT_CONFIG_ERROR)

        # --- build prompt ---
        prompt = build_prompt(config, paths, extracted_dir, deps, ap, own_identifier)

        # --- agent loop with retries ---
        sdf_text = ""
        last_errors: list[str] = []
        for attempt in range(1, config.retries + 1):
            retry_note = format_errors(last_errors) if last_errors else ""
            # Clean any stale agent output from a previous attempt.
            ap.agent_output.unlink(missing_ok=True)
            try:
                run_omp(prompt, ap, config, retry_note)
            except RuntimeError as exc:
                return _fail(f"omp invocation failed (attempt {attempt}): {exc}", EXIT_GEN_FAILED)

            try:
                sdf_text = read_agent_output(ap)
            except RuntimeError as exc:
                last_errors = [str(exc)]
                continue

            # --- validate (semantic only: parse + required + absolute paths) ---
            # yamllint and byte-sort are skipped here because render() re-imposes them
            # deterministically; retrying the agent for a style issue wastes a round-trip.
            result = validate_semantic(sdf_text)
            if result.ok:
                break
            last_errors = result.errors
        else:
            return _fail(
                f"validation failed after {config.retries} attempts: {'; '.join(last_errors)}",
                EXIT_GEN_FAILED,
            )

        # --- post-process: parse, apply prefer, sort, render ---
        import yaml

        sdf = parse_sdf(yaml.safe_load(sdf_text))
        prefer_result = scan_prefer(sdf, checkout, release.bin_prefix, own_identifier)
        apply_prefer(sdf, prefer_result)
        final_text = render(sdf)

        # --- re-validate after post-processing ---
        result = validate(final_text)
        if not result.ok:
            return _fail(
                f"post-processing validation failed: {'; '.join(result.errors)}",
                EXIT_GEN_FAILED,
            )

        # --- write output ---
        out_path = Path(config.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(final_text, encoding="utf-8")

    return EXIT_OK


def main(argv: list[str] | None = None) -> int:
    """Entry point. Returns an exit code."""

    parser = build_parser()
    args = parser.parse_args(argv)
    config = _parse_config(args)
    if isinstance(config, int):
        return config
    if args.command == "generate-sdf":
        return generate_sdf(config)
    return _fail(f"unknown command: {args.command}", EXIT_CONFIG_ERROR)
