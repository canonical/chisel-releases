"""
Tests some of the core Python functionality
"""

import sys
import os
import socket
import time


def hello_world():
    # Asserting the stdout would require additional modules (like StringIO)
    # that are not available in the "core" slice. So this test case only tests
    # the functionality, but not the outcome.
    print("Hello, world!")


def check_python_version():
    print("Checking Python version...")
    assert sys.version.startswith(
        "3.14"
    ), f"Wrong Python version installed: {sys.version}. Expected 3.14."


def check_file_operations():
    print("Checking file operations...")
    filename = f"/test-file-{int(time.time())}"

    original_content = "This is a test file."
    with open(filename, "w") as f:
        f.write(original_content)
    with open(filename, "r") as f:
        content = f.read()
    assert content == original_content
    os.remove(filename)
    assert not os.path.exists(filename)
    print(f"File operations are working. Content: {content}")


def check_network_operations():
    print("Checking network operations...")
    print(socket.gethostname())


if __name__ == "__main__":
    hello_world()
    check_python_version()
    check_file_operations()
    check_network_operations()
