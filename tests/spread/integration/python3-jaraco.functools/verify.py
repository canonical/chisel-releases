from jaraco.functools import compose, once, pass_none

calls = []

@once
def setup():
    calls.append(1)
    return "done"

assert setup() == setup() == "done"
assert calls == [1]
assert compose(str, abs)(-3) == "3"
assert pass_none(str.upper)(None) is None
assert pass_none(str.upper)("a") == "A"
