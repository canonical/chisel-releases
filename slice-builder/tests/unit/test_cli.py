"""Unit tests for cli.py config parsing."""

from slice_builder.cli import EXIT_CONFIG_ERROR, _parse_config, build_parser


def _parse(args):
    return _parse_config(build_parser().parse_args(args))


def test_retries_zero_rejected():
    r = _parse(
        [
            "generate-sdf",
            "--bin-archive",
            "a",
            "--base",
            "26.04",
            "--package",
            "curl",
            "--track",
            "v1",
            "--output",
            "o",
            "--retries",
            "0",
        ]
    )
    assert r == EXIT_CONFIG_ERROR


def test_retries_negative_rejected():
    r = _parse(
        [
            "generate-sdf",
            "--bin-archive",
            "a",
            "--base",
            "26.04",
            "--package",
            "curl",
            "--track",
            "v1",
            "--output",
            "o",
            "--retries",
            "-1",
        ]
    )
    assert r == EXIT_CONFIG_ERROR


def test_retries_default_accepted():
    r = _parse(
        [
            "generate-sdf",
            "--bin-archive",
            "a",
            "--base",
            "26.04",
            "--package",
            "curl",
            "--track",
            "v1",
            "--output",
            "o",
        ]
    )
    assert hasattr(r, "retries")
    assert r.retries == 3
