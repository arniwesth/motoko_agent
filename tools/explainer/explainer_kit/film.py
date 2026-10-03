"""Read a film file without running it: its scenes in order, and every line it will speak.

The narration has to exist before a scene renders, because the scene times itself by the clip.
So the lines are taken from the source: say(...) and speak(...) calls whose text is a string
literal, wherever in the file they are. A line built at run time is reported as a problem
instead of being silently unvoiced.

A scene may speak from its own methods, from a base class in the same file, or from a function
at module level, so a scene's lines are its own plus those of its bases plus the module's.
"""

from __future__ import annotations

import ast
import pathlib

from . import voice


def _spoken(node):
    """("say" or "speak", [text nodes]) for a narration call, else None."""
    if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)):
        return None
    name = node.func.attr
    if name == "say":
        nodes = list(node.args)
    elif name == "speak":
        nodes = node.args[:1] or [kw.value for kw in node.keywords if kw.arg == "text"]
    else:
        return None
    return (name, nodes) if nodes else None


class Film:
    def __init__(self, path):
        self.path = pathlib.Path(path).resolve()
        tree = ast.parse(self.path.read_text())
        self.say_table = self._literal(tree, "SAY", [])
        self.output = self._literal(tree, "OUTPUT", None)
        self.scenes = []  # in the order they play
        self.bases = {}  # class -> its bases defined in this file
        self.records = []  # (owner, line number, spoken text); owner None is module level
        self.problems = []  # (owner, message)

        constructs = {}
        for node in tree.body:
            if not isinstance(node, ast.ClassDef):
                self._collect(node, None)
                continue
            names = [b.id for b in node.bases if isinstance(b, ast.Name)]
            if not any(b == "Explainer" or b in self.bases for b in names):
                self._collect(node, None)
                continue
            self.bases[node.name] = [b for b in names if b in self.bases]
            own = any(isinstance(n, ast.FunctionDef) and n.name == "construct" for n in node.body)
            constructs[node.name] = own or any(constructs[b] for b in self.bases[node.name])
            if constructs[node.name] and not node.name.startswith("_"):
                self.scenes.append(node.name)
            self._collect(node, node.name)
        self.records.sort(key=lambda r: r[1])

    def _collect(self, tree, owner):
        for node in ast.walk(tree):
            found = _spoken(node)
            if not found:
                continue
            name, nodes = found
            if not all(isinstance(n, ast.Constant) and isinstance(n.value, str) for n in nodes):
                self.problems.append((owner, (
                    f"{self.path.name}:{node.lineno}: {name}() needs string literals, so its "
                    "narration can be made before the scene renders")))
                continue
            strings = [n.value for n in nodes]
            text = voice.spoken(strings, self.say_table) if name == "say" else strings[0]
            self.records.append((owner, node.lineno, text))

    @staticmethod
    def _literal(tree, name, default):
        for node in tree.body:
            if isinstance(node, ast.Assign) and any(
                    isinstance(t, ast.Name) and t.id == name for t in node.targets):
                return ast.literal_eval(node.value)
        return default

    def _owners(self, scenes):
        """The classes whose lines a set of scenes can speak, and None for the module's."""
        owners, todo = {None}, list(self.scenes if scenes is None else scenes)
        while todo:
            name = todo.pop()
            if name not in owners:
                owners.add(name)
                todo += self.bases.get(name, [])
        return owners

    def records_for(self, scenes=None):
        owners = self._owners(scenes)
        return [r for r in self.records if r[0] in owners]

    def texts(self, scenes=None):
        return [text for _, _, text in self.records_for(scenes)]

    def problems_for(self, scenes=None):
        owners = self._owners(scenes)
        return [message for owner, message in self.problems if owner in owners]
