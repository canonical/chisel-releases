#!/usr/bin/env python3
"""
Unit tests for validate_hints.py
"""
import sys
import os
from unittest.mock import patch

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import validate_hints


class TestValidators:
    """Test individual validator functions, including NLP initialization."""

    def test_get_nlp_caching(self):
        # Ensure that the NLP model is loaded and cached
        nlp1 = validate_hints.get_nlp()
        nlp2 = validate_hints.get_nlp()
        assert nlp1 is nlp2, "NLP model should be cached and reused"

    @patch("spacy.load")
    @patch("spacy.cli.download")
    def test_nonexistent_model(self, mock_download, mock_load):
        # Simulate the case where the model is not available and needs to be downloaded
        validate_hints.get_nlp()  # Ensure model is loaded and cached
        mock_load.side_effect = [OSError("Model not found"), validate_hints._NLP_CACHE]
        
        validate_hints._NLP_CACHE = None  # Reset cache
        nlp = validate_hints.get_nlp()
        mock_load.assert_called_with("en_core_web_sm")
        mock_download.assert_called_with("en_core_web_sm")
        assert nlp is not None, "NLP model should be loaded after download"

    def test_no_finite_verbs(self):
        # Valid cases
        assert validate_hints.no_finite_verbs("System configuration") is None
        assert validate_hints.no_finite_verbs("Installation of packages") is None

        # Invalid cases
        err = []
        err.append(validate_hints.no_finite_verbs("This contains a verb"))
        err.append(validate_hints.no_finite_verbs("This is a verb"))
        assert len(err) == 2
        assert all("finite verbs are not allowed" in e for e in err)
        assert "contains" in err[0]
        assert "is" in err[1]

    def test_no_starting_articles(self):
        # Valid
        assert validate_hints.no_starting_articles("System configuration") is None

        # Invalid
        assert (
            validate_hints.no_starting_articles("The system configuration") is not None
        )
        assert validate_hints.no_starting_articles("A configuration") is not None
        assert validate_hints.no_starting_articles("An apple") is not None

        # Case sensitivity
        assert validate_hints.no_starting_articles("the system") is not None

    def test_no_special_characters(self):
        # Valid
        assert validate_hints.no_special_characters("System configuration") is None
        assert validate_hints.no_special_characters("File (config.yaml)") is None
        assert validate_hints.no_special_characters("Items one, two; three.") is None

        # Invalid
        set_of_invalid_chars = "@#$%^:&*!~`<>/\\|"
        err = validate_hints.no_special_characters(
            f"Some invalid chars: {set_of_invalid_chars}"
        )
        assert err is not None
        assert all(char in err for char in set_of_invalid_chars)

    def test_no_trailing_punctuation(self):
        # Valid
        assert validate_hints.no_trailing_punctuation("System configuration") is None
        assert validate_hints.no_trailing_punctuation("Ends with parenthesis)") is None

        # Invalid
        for punct in {".", "!", "?", ",", ";", ":", " "}:
            assert (
                validate_hints.no_trailing_punctuation(f"Ends with {punct}") is not None
            )

    def test_is_sentence_case(self):
        # Valid
        assert validate_hints.is_sentence_case("System configuration") is None
        assert (
            validate_hints.is_sentence_case("System configuration. Another sentence.")
            is None
        )

        # Invalid
        err = validate_hints.is_sentence_case("system configuration")
        assert err is not None
        assert "first letter" in err

        err = validate_hints.is_sentence_case("First sentence. second sentence.")
        assert err is not None
        assert "'s'" in err

    def test_no_consecutive_spaces(self):
        # Valid
        assert validate_hints.no_consecutive_spaces("System configuration") is None

        # Invalid
        err = [
            validate_hints.no_consecutive_spaces("No  consecutive spaces"),
            validate_hints.no_consecutive_spaces("Ends with\t\tspace"),
        ]

        assert None not in err
        assert all("two or more consecutive spaces" in e for e in err)


class TestValidateHints:
    """Test the file validation logic."""

    def test_validate_hints(self, tmp_path):
        f = tmp_path / "sdf.yaml"
        yaml_content = """slices:
  good:
    hint: Pass the test

  bad-article:
    hint: A bad hint

  bad-chars:
    hint: Hint with invalid characters @#$%^&*() - the end

  bad-sentence-case:
    hint: Ok. but not sentence case

  bad-trailing-punctuation:
    hint: With trailing punctuation.

  bad-verbs:
    hint: Has to fail the test, it is not valid, contains finite verbs
"""
        f.write_text(yaml_content, encoding="utf-8")

        errors = validate_hints.validate_hints(str(f))
        assert len(errors) == 5
        assert "article (a, an, the) is not allowed: 'A'" in errors[0]
        assert "can only contain alphanumeric characters" in errors[1]
        assert "(first letter 'b' is not uppercase)" in errors[2]
        assert (
            "trailing punctuation and spaces are not allowed: found '.' at the end"
            in errors[3]
        )
        assert "finite verbs are not allowed" in errors[4]

    def test_validate_hints_malformed_yaml(self, tmp_path):
        f = tmp_path / "bad.yaml"
        f.write_text("slices: [", encoding="utf-8")

        errors = validate_hints.validate_hints(str(f))
        assert len(errors) == 1
        assert "Failed to parse YAML" in errors[0]

    def test_validate_hints_non_dict_yaml(self, tmp_path):
        f = tmp_path / "bad.yaml"
        f.write_text("- foo", encoding="utf-8")

        errors = validate_hints.validate_hints(str(f))
        assert len(errors) == 1
        assert "Failed to parse YAML" in errors[0]
        assert "YAML mapping" in errors[0]


class TestMain:
    """Test the main execution flow."""

    @patch("validate_hints.validate_hints")
    @patch("sys.exit")
    def test_main_success(self, mock_exit, mock_validate):
        mock_validate.return_value = []
        with patch("sys.argv", ["script", "file.yaml"]):
            validate_hints.main()
            mock_exit.assert_not_called()

    @patch("validate_hints.validate_hints")
    @patch("sys.exit")
    def test_main_failure(self, mock_exit, mock_validate):
        mock_validate.return_value = ["Some error"]
        with patch("sys.argv", ["script", "file.yaml"]):
            validate_hints.main()
            mock_exit.assert_called_with(1)
