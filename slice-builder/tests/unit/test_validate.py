"""Unit tests for validate.py."""

from slice_builder.validate import format_errors, validate

GOOD_SDF = (
    "package: curl\n"
    "store: bin\n"
    'default-track: "0.1"\n'
    "essential:\n"
    "  bin-curl_copyright:\n"
    "slices:\n"
    "  bins:\n"
    "    contents:\n"
    "      /usr/bin/curl-bin:\n"
    "  copyright:\n"
    "    contents:\n"
    "      /usr/share/doc/curl-bin/copyright:\n"
)


def test_validate_good_sdf_passes():
    result = validate(GOOD_SDF)
    assert result.ok, result.errors


def test_validate_missing_required_field_fails():
    bad = GOOD_SDF.replace("store: bin\n", "")
    result = validate(bad)
    assert not result.ok
    assert any("store" in e for e in result.errors)


def test_validate_unsorted_contents_fails():
    bad = GOOD_SDF.replace(
        "      /usr/bin/curl-bin:\n",
        "      /usr/bin/curl-bin:\n      /usr/bin/a-bin:\n",
    )
    result = validate(bad)
    assert not result.ok
    assert any("not byte-sorted" in e for e in result.errors)


def test_validate_non_absolute_path_fails():
    bad = GOOD_SDF.replace("/usr/bin/curl-bin:", "relative/path:")
    result = validate(bad)
    assert not result.ok
    assert any("not absolute" in e for e in result.errors)


def test_validate_yaml_parse_error_fails():
    result = validate("package: curl\n  bad: : :")
    assert not result.ok
    assert any("parse error" in e or "YAML parse" in e for e in result.errors)


def test_format_errors_returns_empty_for_no_errors():
    assert format_errors([]) == ""


def test_format_errors_includes_messages():
    out = format_errors(["bad thing", "worse thing"])
    assert "bad thing" in out
    assert "worse thing" in out
    assert "Fix these" in out
