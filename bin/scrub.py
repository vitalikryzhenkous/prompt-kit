#!/usr/bin/env python3
"""scrub.py HOME USER HOST — stdin -> stdout with personal data replaced (literal strings, no regex from input).
Home path -> ~, Windows profile name under /mnt/c/Users/ -> <user>, user name and host name -> <user> / <host>
(only as whole words, so a user called `git` does not mangle `git 2.43` or `/usr/bin`)."""
import re
import sys

home, user, host = (sys.argv[1:4] + ["", "", ""])[:3]
text = sys.stdin.read()
if home and home != "/":
    text = text.replace(home, "~")
text = re.sub(r"/mnt/c/Users/[^/\s]+", "/mnt/c/Users/<user>", text)
for name, label in ((user, "<user>"), (host, "<host>")):
    if name:
        text = re.sub(r"(?<![\w.-])" + re.escape(name) + r"(?![\w.-])", label, text)
sys.stdout.write(text)
