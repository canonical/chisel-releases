"""Unit tests for sdf.py + render.py."""

import pytest
import yaml

from slice_builder.render import render, sort_sdf
from slice_builder.sdf import SDF, Slice, byte_sorted, dump_sdf, parse_sdf


def _make_sdf() -> SDF:
    return SDF(
        package="curl",
        store="bin",
        default_track="0.1",
        essential={"bin-curl_copyright": {}},
        slices={
            "bins": Slice(
                name="bins",
                contents={"/usr/bin/curl-bin": None},
                essential={"libc6_libs": {}},
            ),
            "copyright": Slice(
                name="copyright",
                contents={"/usr/share/doc/curl-bin/copyright": None},
            ),
        },
    )


def test_byte_sorted_matches_utf8_order():
    items = ["/b", "/a", "/c", "/A"]
    assert byte_sorted(items) == ["/A", "/a", "/b", "/c"]


def test_parse_sdf_roundtrip():
    text = (
        "package: curl\nstore: bin\ndefault-track: '0.1'\n"
        "essential:\n  bin-curl_copyright:\n"
        "slices:\n  bins:\n    contents:\n      /usr/bin/curl-bin:\n"
    )
    sdf = parse_sdf(yaml.safe_load(text))
    assert sdf.package == "curl"
    assert sdf.store == "bin"
    assert sdf.default_track == "0.1"
    assert "bins" in sdf.slices
    assert sdf.slices["bins"].contents == {"/usr/bin/curl-bin": None}


def test_parse_sdf_missing_required_raises():
    with pytest.raises(ValueError, match="missing required field"):
        parse_sdf({"package": "x"})


def test_parse_sdf_coerces_v1_list_essential():
    sdf = parse_sdf({"package": "x", "slices": {}, "essential": ["x_copyright"]})
    assert sdf.essential == {"x_copyright": {}}


def test_dump_sdf_quotes_default_track():
    text = dump_sdf(_make_sdf())
    assert 'default-track: "0.1"' in text


def test_dump_sdf_null_valued_keys():
    text = dump_sdf(_make_sdf())
    # Bare content paths and essential entries render as `key:` (not `key: null`).
    assert "/usr/bin/curl-bin:" in text
    assert "bin-curl_copyright:" in text
    assert "null" not in text


def test_dump_sdf_block_style_no_flow():
    text = dump_sdf(_make_sdf())
    assert "{" not in text
    assert "[" not in text
    assert "---" not in text


def test_sort_sdf_byte_orders_contents_and_essential():
    sdf = _make_sdf()
    sdf.slices["bins"].contents = {"/usr/bin/z": None, "/usr/bin/a": None}
    sdf.slices["bins"].essential = {"z_libs": {}, "a_libs": {}}
    sdf.essential = {"bin-curl_z": {}, "bin-curl_a": {}}
    sort_sdf(sdf)
    assert list(sdf.slices["bins"].contents) == ["/usr/bin/a", "/usr/bin/z"]
    assert list(sdf.slices["bins"].essential) == ["a_libs", "z_libs"]
    assert list(sdf.essential) == ["bin-curl_a", "bin-curl_z"]


def test_render_sorts_then_dumps():
    sdf = _make_sdf()
    sdf.slices["bins"].contents = {"/usr/bin/z": None, "/usr/bin/a": None}
    text = render(sdf)
    assert text.index("/usr/bin/a:") < text.index("/usr/bin/z:")


def test_render_matches_canonical_curl_sdf():
    """Rendered output must be byte-for-byte identical to slices/bins/curl.yaml."""

    # Build an SDF matching the canonical curl.yaml exactly (no slice-level essential).
    sdf = SDF(
        package="curl",
        store="bin",
        default_track="0.1",
        essential={"bin-curl_copyright": {}},
        slices={
            "bins": Slice(name="bins", contents={"/usr/bin/curl-bin": None}),
            "copyright": Slice(
                name="copyright",
                contents={"/usr/share/doc/curl-bin/copyright": None},
            ),
        },
    )
    text = render(sdf)
    expected = (
        "package: curl\n"
        "\n"
        'default-track: "0.1"\n'
        "\n"
        "store: bin\n"
        "\n"
        "essential:\n"
        "  bin-curl_copyright:\n"
        "\n"
        "slices:\n"
        "  bins:\n"
        "    contents:\n"
        "      /usr/bin/curl-bin:\n"
        "\n"
        "  copyright:\n"
        "    contents:\n"
        "      /usr/share/doc/curl-bin/copyright:\n"
    )
    assert text == expected


def test_render_inserts_blank_line_between_slices():
    """A blank line must separate each slice block under ``slices:``."""

    text = render(_make_sdf())
    # No blank line right after the ``slices:`` header (first slice follows immediately)...
    assert "slices:\n  bins:\n" in text
    # ...but a blank line separates the first and second slice blocks.
    assert "      /usr/bin/curl-bin:\n\n  copyright:\n" in text


def test_render_no_blank_after_slices_header():
    """The first slice must follow ``slices:`` with no intervening blank line."""

    text = render(_make_sdf())
    assert "slices:\n\n  bins:" not in text


def test_render_ends_with_single_newline_no_trailing_blank():
    text = render(_make_sdf())
    assert text.endswith("copyright:\n")
    assert not text.endswith("\n\n")
