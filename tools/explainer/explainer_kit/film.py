"""Read a film file without running it: its scenes in order, and every line each will speak.

The narration has to exist before a scene renders, because the scene times itself by the clip.
So the lines are taken from the source: say(...) and speak(...) calls whose text is a string
literal. A line built at run time is reported as a problem instead of being silently unvoiced.

A scene's lines are those it can reach: from its construct(), through the methods it calls on
itself (its own or a base class's in this file) and the module-level functions it names. A
helper nothing calls belongs to no scene, and a helper only scene A calls is not scene B's.
What is reached through another file is not seen; narration has to live in the film file.
"""

from __future__ import annotations

import ast
import pathlib

from . import voice

ENTRY = ("construct", "setup", "tear_down")  # what Manim itself calls on a scene


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
        self.bases = {}  # scene or base class -> its bases defined in this file
        self.methods = {}  # class -> {method name: its definition}
        self.functions = {}  # module-level function name -> its definition
        self.owner = {}  # id of a definition -> the class it is in, or None

        constructs = {}
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                self.functions[node.name] = node
                self.owner[id(node)] = None
            if not isinstance(node, ast.ClassDef):
                continue
            names = [b.id for b in node.bases if isinstance(b, ast.Name)]
            if not any(b == "Explainer" or b in self.bases for b in names):
                continue
            self.bases[node.name] = [b for b in names if b in self.bases]
            self.methods[node.name] = {n.name: n for n in node.body
                                       if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))}
            for definition in self.methods[node.name].values():
                self.owner[id(definition)] = node.name
            constructs[node.name] = "construct" in self.methods[node.name] or any(
                constructs[b] for b in self.bases[node.name])
            if constructs[node.name] and not node.name.startswith("_"):
                self.scenes.append(node.name)

    @staticmethod
    def _literal(tree, name, default):
        for node in tree.body:
            if isinstance(node, ast.Assign) and any(
                    isinstance(t, ast.Name) and t.id == name for t in node.targets):
                return ast.literal_eval(node.value)
        return default

    def _lineage(self, scene):
        """The scene and its bases in this file, nearest first."""
        seen, todo = [], [scene]
        while todo:
            name = todo.pop(0)
            if name not in seen:
                seen.append(name)
                todo += self.bases.get(name, [])
        return seen

    def _reached(self, scene):
        """Every definition in this file that the scene's construct() can lead to."""
        lineage = self._lineage(scene)

        def named(name):  # every definition of a method along the lineage: super() reaches up
            return [self.methods[c][name] for c in lineage if name in self.methods[c]]

        seen, todo = {}, [d for name in ENTRY for d in named(name)]
        while todo:
            definition = todo.pop()
            if id(definition) in seen:
                continue
            seen[id(definition)] = definition
            for node in ast.walk(definition):
                if isinstance(node, ast.Attribute):  # self.opening(), scene.opening, super().x()
                    todo += named(node.attr)
                elif isinstance(node, ast.Name) and node.id in self.functions:
                    todo.append(self.functions[node.id])
        return list(seen.values())

    def _lines(self, scenes):
        """(records, problems) for the scenes: what they will say, and what cannot be voiced."""
        records, problems = {}, {}
        for scene in self.scenes if scenes is None else scenes:
            for definition in self._reached(scene):
                owner = self.owner[id(definition)]
                for node in ast.walk(definition):
                    found = _spoken(node)
                    if not found:
                        continue
                    name, nodes = found
                    key = (node.lineno, node.col_offset)
                    if not all(isinstance(n, ast.Constant) and isinstance(n.value, str)
                               for n in nodes):
                        problems[key] = (
                            f"{self.path.name}:{node.lineno}: {name}() needs string literals, so "
                            "its narration can be made before the scene renders")
                        continue
                    strings = [n.value for n in nodes]
                    text = voice.spoken(strings, self.say_table) if name == "say" else strings[0]
                    records[key] = (owner, node.lineno, text)
        return ([records[k] for k in sorted(records)], [problems[k] for k in sorted(problems)])

    def records_for(self, scenes=None):
        """(class or None for module level, line number, spoken text), in source order."""
        return self._lines(scenes)[0]

    def texts(self, scenes=None):
        return [text for _, _, text in self.records_for(scenes)]

    def problems_for(self, scenes=None):
        return self._lines(scenes)[1]
