"""
Tests some of the standard Python functionality
"""

import html
import json
import urllib
import uuid


def check_json_loading():
    print("Checking JSON loading...")

    sample = '{"foo": ["bar"]}'
    assert json.loads(sample) == {"foo": ["bar"]}


def check_html_escaping():
    print("Checking HTML escaping...")

    sample = "Some <sample> & 'text' with \"HTML\" characters"
    exp = "Some &lt;sample&gt; &amp; &#x27;text&#x27; with &quot;HTML&quot; characters"
    assert html.escape(sample) == exp


def check_uuid_gen():
    print("Checking UUID generation...")

    assert type(uuid.uuid1().int) == int


def test_import_everything():
    """
    Module name gathered from https://docs.python.org/3.14/py-modindex.html
    JS:
     const moduleList = Array.from(document.getElementsByTagName('a')).map(e => e.href).filter(e => e.startsWith('https://docs.python.org/3.14/library/')).map(e => e.match(/library\/(.*)\.html/)[1])
     for (m of moduleList) { console.log(`import ${m}`) }
    """
    import __future__
    import __main__
    import _thread
    # import tkinter
    import abc
    # import aifc
    import annotationlib
    import argparse
    import array
    import ast
    # import asynchat
    import asyncio
    # import asyncore
    import atexit
    # import audioop
    import base64
    import bdb
    import binascii
    import bisect
    import builtins
    import bz2
    import calendar
    # import cgi
    # import cgitb
    # import chunk
    import cmath
    import cmd
    import code
    import codecs
    import codeop
    import collections
    import collections.abc
    import colorsys
    import compileall
    import compression
    import compression.zstd
    import concurrent.futures
    import concurrent.interpreters
    import configparser
    import contextlib
    import contextvars
    import copy
    import copyreg
    import profile
    # import crypt
    import csv
    import ctypes
    import curses
    import curses.ascii
    import curses.panel
    import curses
    import dataclasses
    import datetime
    import dbm
    import decimal
    import difflib
    import dis
    # import distutils
    import doctest
    import email
    import email.charset
    import email.contentmanager
    import email.encoders
    import email.errors
    import email.generator
    import email.header
    import email.headerregistry
    import email.iterators
    import email.message
    import email.mime
    import email.parser
    import email.policy
    import email.utils
    import codecs
    # import ensurepip
    import enum
    import errno
    import faulthandler
    import fcntl
    import filecmp
    import fileinput
    import fnmatch
    import fractions
    import ftplib
    import functools
    import gc
    import getopt
    import getpass
    import gettext
    import glob
    import graphlib
    import grp
    import gzip
    import hashlib
    import heapq
    import hmac
    import html
    import html.entities
    import html.parser
    import http
    import http.client
    import http.cookiejar
    import http.cookies
    import http.server
    # import idlelib
    import imaplib
    # import imghdr
    # import imp
    import importlib
    import importlib.metadata
    import importlib.resources
    import importlib.resources.abc
    import importlib
    import inspect
    import io
    import ipaddress
    import itertools
    import json
    import keyword
    import linecache
    import locale
    import logging
    import logging.config
    import logging.handlers
    import lzma
    import mailbox
    # import mailcap
    import marshal
    import math
    import mimetypes
    import mmap
    import modulefinder
    # import msilib
    # import msvcrt
    import multiprocessing
    import multiprocessing.shared_memory
    import multiprocessing
    import netrc
    # import nis
    # import nntplib
    import numbers
    import operator
    import optparse
    import os
    import os.path
    # import ossaudiodev
    import pathlib
    import pdb
    import pickle
    import pickletools
    # import pipes
    import pkgutil
    import platform
    import plistlib
    import poplib
    import posix
    import pprint
    import profile
    import pty
    import pwd
    import py_compile
    import pyclbr
    import pydoc
    import queue
    import quopri
    import random
    import re
    import readline
    import reprlib
    import resource
    import rlcompleter
    import runpy
    import sched
    import secrets
    import select
    import selectors
    import shelve
    import shlex
    import shutil
    import signal
    import site
    # import smtpd
    import smtplib
    # import sndhdr
    import socket
    import socketserver
    # import spwd
    import sqlite3
    import ssl
    import stat
    import statistics
    import string
    import string.templatelib
    import stringprep
    import struct
    import subprocess
    # import sunau
    import symtable
    import sys
    sys.monitoring
    import sysconfig
    import syslog
    import tabnanny
    import tarfile
    # import telnetlib
    import tempfile
    import termios
    import test
    import textwrap
    import threading
    import time
    import timeit
    # import tkinter
    # import tkinter.colorchooser
    # import tkinter.dnd
    # import tkinter.font
    # import tkinter.messagebox
    # import tkinter.scrolledtext
    # import tkinter.ttk
    import token
    import tokenize
    import tomllib
    import trace
    import traceback
    import tracemalloc
    import tty
    # import turtle
    import types
    import typing
    import unicodedata
    import unittest
    import unittest.mock
    import urllib
    import urllib.error
    import urllib.parse
    import urllib.request
    import urllib.robotparser
    import site
    # import uu
    import uuid
    import venv
    import warnings
    import wave
    import weakref
    import webbrowser
    # import winreg
    # import winsound
    import wsgiref
    # import xdrlib
    import xml
    import xml.dom
    import xml.dom.minidom
    import xml.dom.pulldom
    import xml.etree.ElementTree
    import pyexpat
    import xml.sax
    import xml.sax.handler
    import xml.sax.saxutils
    import xml.sax.xmlreader
    import xmlrpc
    import xmlrpc.client
    import xmlrpc.server
    import zipapp
    import zipfile
    import zipimport
    import zlib
    import zoneinfo



if __name__ == "__main__":
    check_json_loading()
    check_html_escaping()
    check_uuid_gen()
    test_import_everything()
