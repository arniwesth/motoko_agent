"""Read a film file without running it: its scenes in order, and every line it will speak.

The narration has to exist before a scene renders, because the scene times itself by the clip.
So the lines are taken from the source: say(...) and speak(...) calls whose arguments are string
literals. A line built at run time is reported as a problem instead of being silently unvoiced.
"""

from __future__ import annotations

import ast
import pathlib

from . import voice


class Film:
    def __init__(self, path):
        self.path = pathlib.Path(path).resolve()
        tree = ast.parse(self.path.read_text())
        self.say_table = self._literal(tree, "SAY", [])
        self.output = self._literal(tree, "OUTPUT", None)
        self.scenes, self.lines, self.problems = [], [], []

        bases = {"Explainer"}
        for node in tree.body:
            if not isinstance(node, ast.ClassDef):
                continue
            if not any(isinstance(b, ast.Name) and b.id in bases for b in node.bases):
                continue
            bases.add(node.name)  # a film may subclass its own base scene
            has_construct = any(isinstance(n, ast.FunctionDef) and n.name == "construct"
                                for n in node.body)
            if not has_construct or node.name.startswith("_"):
                continue
            self.scenes.append(node.name)
            calls = sorted((c for c in ast.walk(node) if self._spoken_call(c)),
                           key=lambda c: (c.lineno, c.col_offset))
            for call in calls:
                args = call.args
                if not all(isinstance(a, ast.Constant) and isinstance(a.value, str)
                           for a in args):
                    self.problems.append(
                        f"{self.path.name}:{call.lineno}: {call.func.attr}() needs string "
                        "literals, so its narration can be made before the scene renders")
                    continue
                strings = [a.value for a in args]
                if call.func.attr == "say":
                    text = voice.spoken(strings, self.say_table)
                else:
                    text = strings[0]
                self.lines.append((node.name, call.lineno, text))

    @staticmethod
    def _spoken_call(node):
        return (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                and node.func.attr in ("say", "speak") and bool(node.args))

    @staticmethod
    def _literal(tree, name, default):
        for node in tree.body:
            if isinstance(node, ast.Assign) and any(
                    isinstance(t, ast.Name) and t.id == name for t in node.targets):
                return ast.literal_eval(node.value)
        return default

    def texts(self, scenes=None):
        return [text for scene, _, text in self.lines if scenes is None or scene in scenes]
