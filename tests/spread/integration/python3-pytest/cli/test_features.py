import os

import pytest


@pytest.mark.parametrize("value", [1, 2])
def test_features(value, tmp_path, monkeypatch, capsys):
    monkeypatch.setenv("PYTEST_SLICE_VALUE", str(value))
    output = tmp_path / "value.txt"
    output.write_text(os.environ["PYTEST_SLICE_VALUE"])
    print(output.read_text())
    assert capsys.readouterr().out.strip() == str(value)
