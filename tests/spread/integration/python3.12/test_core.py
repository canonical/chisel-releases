"""
Tests some of the core Python functionality
"""

import sys
import os
import socket
import time
import urllib
import urllib.request


def hello_world():
    print("Hello, world!")


def check_python_version():
    print("Checking Python version...")
    assert sys.version.startswith(
        "3.12"
    ), f"Wrong Python version installed: {sys.version}. Expected 3.12."


def check_file_operations():
    print("Checking file operations...")
    filename = f"/test-file-{int(time.time())}"

    with open(filename, "w") as f:
        f.write("This is a test file.")
    with open(filename, "r") as f:
        content = f.read()
    os.remove(filename)
    print(f"File operations are working. Content: {content}")


def check_network_operations():
    print("Checking network operations...")
    print(socket.gethostname())


if __name__ == "__main__":
    hello_world()
    check_python_version()
    check_file_operations()
    check_network_operations()
