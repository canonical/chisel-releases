#!/usr/bin/env python3
"""
Script to validate hints in slice definition files.
"""

import argparse
import logging
import re
import sys
from typing import List, Optional

import spacy
import yaml

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

# Load NLP model
try:
    NLP = spacy.load("en_core_web_sm")
except OSError:
    logging.warning("Downloading en_core_web_sm model...")
    from spacy.cli import download

    download("en_core_web_sm")
    NLP = spacy.load("en_core_web_sm")

ErrorMessage = str


def no_finite_verbs(text: str) -> Optional[ErrorMessage]:
    """Check that the text does not contain finite verbs."""
    doc = NLP(text)
    findings = []
    for token in doc:
        if token.pos_ in ["VERB", "AUX"] and token.morph.get("VerbForm") == ["Fin"]:
            findings.append(f"{token.text} ({token.lemma_})")

    if findings:
        return f"finite verbs are not allowed: {', '.join(findings)}"
    return None


def no_starting_articles(text: str) -> Optional[ErrorMessage]:
    """Check that the text does not start with an article."""
    words = text.split()
    if not words:
        return None

    first_word = words[0]
    articles = {"a", "an", "the"}
    if first_word.lower() in articles:
        return (
            f"starting with an article ({', '.join(sorted(articles))}) "
            f"is not allowed: '{first_word}'"
        )
    return None


def no_special_characters(text: str) -> Optional[ErrorMessage]:
    """
    Check that the text contains only allowed characters.
    Allowed: alphanumeric, periods, commas, semicolons, parentheses.
    """
    # Regex for characters that are NOT allowed
    forbidden_pattern = r"[^a-zA-Z0-9.,;()\s]"

    bad_chars = re.findall(forbidden_pattern, text)
    if bad_chars:
        unique_bad_chars = set(bad_chars)
        return (
            f"can only contain alphanumeric characters, periods, commas, "
            f"semicolons, parentheses: found {', '.join(unique_bad_chars)}"
        )
    return None


def no_trailing_punctuation(text: str) -> Optional[ErrorMessage]:
    """Check that the text does not end with punctuation, except parentheses."""
    punctuation_marks = {".", "!", "?", ",", ";", ":"}

    if text and text[-1] in punctuation_marks:
        return f"trailing punctuation is not allowed: found '{text[-1]}' at the end"
    return None


def is_sentence_case(text: str) -> Optional[ErrorMessage]:
    """Check that each sentence in the text starts with an uppercase letter."""
    # It is not enough to split the text by '.' and check each sentence separately,
    # because we can have complex punctuation like "Single 1.1 sentence"
    doc = NLP(text)
    findings = []

    for sent in doc.sents:
        s_text = sent.text.strip()
        if not s_text:
            continue

        # Check if first letter is upper
        if not s_text[0].isupper():
            findings.append(
                f"'{s_text}' (first letter '{s_text[0]}' is not uppercase)"
            )

    if findings:
        return f"text must be sentence case: {', '.join(findings)}"
    return None


def validate_hints(file_path: str) -> List[str]:
    """Validate hints in a single slice definition file."""
    logging.info(f"Processing {file_path}...")
    errors = []

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = yaml.safe_load(f)
    except Exception as e:
        return [f"File={file_path}, Error=Failed to parse YAML: {e}"]
    
    slices = content.get("slices", {})
    if not isinstance(slices, dict):
        return []

    validators = [
        no_finite_verbs,
        no_starting_articles,
        no_special_characters,
        no_trailing_punctuation,
        is_sentence_case,
    ]

    for slice_name, values in slices.items():
        if not isinstance(values, dict):
            continue

        hint = values.get("hint", "")
        # Skip empty hints or non-string hints
        if not hint or not isinstance(hint, str):
            continue

        for validator in validators:
            error_msg = validator(hint)
            if error_msg:
                errors.append(
                    f"File={file_path}, Slice={slice_name}, Error={error_msg}"
                )

    return errors


def main():
    parser = argparse.ArgumentParser(
        description="Validate hints in slice definitions"
    )
    parser.add_argument("files", nargs="+", help="Slice definition files to validate")
    args = parser.parse_args()

    logging.info("Validating slice definition hints")

    all_errors = []
    for input_file in args.files:
        all_errors.extend(validate_hints(input_file))

    if all_errors:
        logging.error("\033[91mThe following 'hints' are not valid\033[0m")
        all_errors.sort()
        for error in all_errors:
            logging.error(error)

        sys.exit(1)

    logging.info("All hints are valid")


if __name__ == "__main__":
    main()