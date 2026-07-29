"""Unit tests for validate.py."""

from slice_builder.validate import format_errors, validate, validate_semantic

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


# --- validate_semantic: the agent-loop check (no yamllint, no sort) ---


def test_validate_semantic_good_sdf_passes():
    assert validate_semantic(GOOD_SDF).ok


def test_validate_semantic_missing_required_field_fails():
    bad = GOOD_SDF.replace("store: bin\n", "")
    result = validate_semantic(bad)
    assert not result.ok
    assert any("store" in e for e in result.errors)


def test_validate_semantic_non_absolute_path_fails():
    bad = GOOD_SDF.replace("/usr/bin/curl-bin:", "relative/path:")
    result = validate_semantic(bad)
    assert not result.ok
    assert any("not absolute" in e for e in result.errors)


def test_validate_semantic_yaml_parse_error_fails():
    result = validate_semantic("package: curl\n  bad: : :")
    assert not result.ok
    assert any("parse error" in e or "YAML parse" in e for e in result.errors)


def test_validate_semantic_ignores_unsorted_contents():
    """The agent loop must NOT retry for a sort issue render() will fix."""
    bad = GOOD_SDF.replace(
        "      /usr/bin/curl-bin:\n",
        "      /usr/bin/curl-bin:\n      /usr/bin/a-bin:\n",
    )
    result = validate_semantic(bad)
    assert result.ok, result.errors


def test_validate_semantic_ignores_yamllint_style_issues():
    """The agent loop must NOT retry for a style issue render() will fix.

    A document-start marker (---) is a yamllint error but not a semantic one.
    """
    bad = "---\n" + GOOD_SDF
    result = validate_semantic(bad)
    assert result.ok, result.errors


def test_full_validate_still_catches_what_semantic_skips():
    """The final-pass validate() must still catch sort + yamllint issues."""
    unsorted = GOOD_SDF.replace(
        "      /usr/bin/curl-bin:\n",
        "      /usr/bin/curl-bin:\n      /usr/bin/a-bin:\n",
    )
    assert not validate(unsorted).ok
    assert not validate("---\n" + GOOD_SDF).ok


def test_validate_rejects_store_not_bin():
    bad = GOOD_SDF.replace("store: bin\n", "store: deb\n")
    result = validate(bad)
    assert not result.ok
    assert any("store must be 'bin'" in e for e in result.errors)


def test_validate_rejects_empty_store():
    bad = GOOD_SDF.replace("store: bin\n", "store: ''\n")
    result = validate(bad)
    assert not result.ok
    assert any("store must be 'bin'" in e for e in result.errors)


def test_validate_rejects_uppercase_slice_name():
    bad = GOOD_SDF.replace("  bins:\n", "  Bins:\n")
    result = validate(bad)
    assert not result.ok
    assert any("invalid slice name 'Bins'" in e for e in result.errors)


def test_validate_rejects_short_slice_name():
    bad = GOOD_SDF.replace("  bins:\n", "  ab:\n")
    result = validate(bad)
    assert not result.ok
    assert any("invalid slice name 'ab'" in e for e in result.errors)


def test_validate_rejects_digit_leading_slice_name():
    bad = GOOD_SDF.replace("  bins:\n", "  123:\n")
    result = validate(bad)
    assert not result.ok
    assert any("invalid slice name '123'" in e for e in result.errors)


def test_validate_yamllint_stdin_filename_not_leaked():
    # Trailing spaces trigger a yamllint error; the bare "stdin" filename header must not
    # appear as a spurious error entry.
    bad = GOOD_SDF.replace("package: curl\n", "package: curl   \n")
    result = validate(bad)
    assert not result.ok
    assert "stdin" not in result.errors
    assert any("trailing spaces" in e for e in result.errors)
