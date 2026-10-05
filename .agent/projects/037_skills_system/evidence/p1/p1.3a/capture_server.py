#!/usr/bin/env python3
"""037 P1.3a: P1.2's recorder (../p1.2/capture_server.py), run unchanged except for
its fixed SCRIPT, which is replaced by the steps in the JSON file named by the
environment variable P13A_SCRIPT. No model is called.

A step is {"tool": [name, args]} or {"text": "..."}; the last step repeats.
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
P12 = os.path.join(HERE, "..", "p1.2", "capture_server.py")
src = open(P12).read()
src, n = re.subn(r"(?ms)^SCRIPT = \[.*?^\]\n",
                 'SCRIPT = json.load(open(os.environ["P13A_SCRIPT"]))\n', src)
if n != 1:
    sys.exit("p1.3a capture_server: could not find SCRIPT in " + P12)
exec(compile(src, P12 + " [SCRIPT replaced by P13A_SCRIPT]", "exec"))
