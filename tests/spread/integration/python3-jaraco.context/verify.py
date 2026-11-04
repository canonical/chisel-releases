from jaraco.context import ExceptionTrap, suppress

with ExceptionTrap(ValueError) as trap:
    int("x")
assert trap
assert trap.type is ValueError

with ExceptionTrap(ValueError) as trap:
    int("1")
assert not trap

with suppress(KeyError):
    {}["missing"]
