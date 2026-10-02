import errno
from importlib.metadata import version

import smbus

# The extension module must be the one from the slice.
assert smbus.__file__.startswith("/usr/lib/python3/dist-packages/smbus."), smbus.__file__
print("module", smbus.__file__)

# Distribution metadata from the shipped egg-info.
print("version", version("smbus"))

# The full SMBus API surface has to be there.
expected = {
    "block_process_call", "close", "open", "pec", "process_call",
    "read_block_data", "read_byte", "read_byte_data", "read_i2c_block_data",
    "read_word_data", "write_block_data", "write_byte", "write_byte_data",
    "write_i2c_block_data", "write_quick", "write_word_data",
}
present = {a for a in dir(smbus.SMBus) if not a.startswith("_")}
assert expected <= present, expected - present

# Opening a bus that does not exist has to surface the open(2) error.
try:
    smbus.SMBus(999)
except FileNotFoundError as e:
    assert e.errno == errno.ENOENT, e
    print("missing bus ->", e.errno)
else:
    raise AssertionError("SMBus(999) unexpectedly succeeded")

# An unopened object has no descriptor to talk to.
bus = smbus.SMBus()
try:
    bus.read_byte(0x50)
except OSError as e:
    assert e.errno == errno.EBADF, e
    print("unopened ->", e.errno)
else:
    raise AssertionError("read_byte on an unopened bus unexpectedly succeeded")

# /dev/i2c-9 is a plain file created by the task, so open(2) succeeds and every
# transfer below reaches a real ioctl(2) that the kernel rejects because the
# target is not an i2c-dev character device. That is enough to prove the module
# drives the kernel interface rather than failing earlier.
bus = smbus.SMBus(9)
for call in (lambda: bus.read_byte(0x50),
             lambda: bus.write_quick(0x50),
             lambda: bus.read_byte_data(0x50, 0x00),
             lambda: bus.read_i2c_block_data(0x50, 0x00, 4)):
    try:
        call()
    except OSError as e:
        assert e.errno == errno.ENOTTY, e
    else:
        raise AssertionError("transfer on a non-i2c device unexpectedly succeeded")
print("ioctl rejected as expected")

bus.close()
try:
    bus.read_byte(0x50)
except OSError as e:
    assert e.errno == errno.EBADF, e
    print("after close ->", e.errno)
else:
    raise AssertionError("read_byte after close unexpectedly succeeded")

print("ALL-SMBUS-CHECKS-PASSED")
