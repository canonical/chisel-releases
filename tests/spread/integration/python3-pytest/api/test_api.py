import pytest


@pytest.fixture
def value():
    return 42


def test_fixture(value):
    assert value == 42
