"""Read a film file without running it: its scenes in order, and every line each will speak.

The narration has to exist before a scene renders, because the scene times itself by the clip.
So the lines are taken from the source: say(...) and speak(...) calls whose text is a string
literal. A line built at run time is reported as a problem instead of being silently unvoiced.

A scene's lines are those it can reach. The walk starts at the methods Manim calls (construct,
setup, tear_down) and follows, in the code that can run:

- `self.x` and `anything.x`, to the method x the scene would actually get: the first definition
  in Python's own lookup order over its bases in this file, mixins included, so an overridden
  method is not followed;
- `super().x`, to the next definition after the class the call is written in;
- `Base.x`, to that class's own definition;
- a name, to the nested function of that name in this or an enclosing function, or else to the
  module-level function.

A nested function nobody names is not entered, and a helper nothing calls belongs to no scene.
What is reached through another file is not seen; narration has to live in the film file.
"""

from __future__ import annotations

import ast
import pathlib

from . import voice

ENTRY = ("construct", "setup", "tear_down")  # what Manim itself calls on a scene
DEFS = (ast.FunctionDef, ast.AsyncFunctionDef)


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


def _scope(definition):
    """The nodes that run as part of a definition, and the functions defined inside it by name.

    A nested function or class is a definition, not a call: its body is not part of this scope.
    A lambda's body is, since a lambda cannot be named and reached later.
    """
    nodes, nested, todo = [], {}, list(ast.iter_child_nodes(definition))
    while todo:
        node = todo.pop()
        if isinstance(node, DEFS):
            nested[node.name] = node
        elif not isinstance(node, ast.ClassDef):
            nodes.append(node)
            todo += ast.iter_child_nodes(node)
    return nodes, nested


class Film:
    def __init__(self, path):
        self.path = pathlib.Path(path).resolve()
        tree = ast.parse(self.path.read_text())
        self.say_table = self._literal(tree, "SAY", [])
        self.output = self._literal(tree, "OUTPUT", None)
        self.scenes = []  # in the order they play
        self.bases = {}  # every class in the file -> its bases that are also in the file
        self.methods = {}  # every class in the file -> {method name: its definition}
        self.functions = {}  # module-level function name -> its definition

        explainers = set()
        for node in tree.body:
            if isinstance(node, DEFS):
                self.functions[node.name] = node
            if not isinstance(node, ast.ClassDef):
                continue
            names = [b.id for b in node.bases if isinstance(b, ast.Name)]
            self.bases[node.name] = [b for b in names if b in self.bases]
            self.methods[node.name] = {n.name: n for n in node.body if isinstance(n, DEFS)}
            if "Explainer" in names or any(b in explainers for b in names):
                explainers.add(node.name)
                if self._find(node.name, "construct") and not node.name.startswith("_"):
                    self.scenes.append(node.name)

    @staticmethod
    def _literal(tree, name, default):
        for node in tree.body:
            if isinstance(node, ast.Assign) and any(
                    isinstance(t, ast.Name) and t.id == name for t in node.targets):
                return ast.literal_eval(node.value)
        return default

    def _lineage(self, cls):
        """A class and its bases in this file, in the order Python looks a method up (C3).

        Depth-first is not that order: for Child(Left, Right) with both deriving from Root,
        Python tries Right before Root, and a method Right overrides must be the one followed.
        """
        bases = self.bases.get(cls, [])
        rows = [self._lineage(base) for base in bases] + [list(bases)]
        order = [cls]
        while any(rows):
            rows = [row for row in rows if row]
            # the next class is the first row's head that no other row still has waiting behind
            head = next((r[0] for r in rows if not any(r[0] in other[1:] for other in rows)), None)
            if head is None:  # no consistent order; Python would refuse to build the class
                head = rows[0][0]
            order.append(head)
            rows = [[c for c in row if c != head] for row in rows]
        return order

    def _find(self, cls, name, after=None):
        """(class, definition) of the method a class gets for a name; past `after` for super()."""
        lineage = self._lineage(cls)
        if after in lineage:
            lineage = lineage[lineage.index(after) + 1:]
        for c in lineage:
            if name in self.methods[c]:
                return c, self.methods[c][name]
        return None

    def _reached(self, scene):
        """(class or None, definition) for everything the scene can run in this file."""
        seen = {}
        todo = [found + ({},) for name in ENTRY if (found := self._find(scene, name))]
        while todo:
            owner, definition, enclosing = todo.pop()
            if id(definition) in seen:
                continue
            seen[id(definition)] = (owner, definition)
            nodes, nested = _scope(definition)
            visible = {**enclosing, **nested}  # the functions this code can call by name
            for node in nodes:
                found = None
                if isinstance(node, ast.Attribute):
                    target = node.value
                    if (isinstance(target, ast.Call) and isinstance(target.func, ast.Name)
                            and target.func.id == "super"):
                        found = self._find(scene, node.attr, after=owner)
                    elif isinstance(target, ast.Name) and target.id in self.methods:
                        found = self._find(target.id, node.attr)  # Base.method(self)
                    else:
                        found = self._find(scene, node.attr)
                    found = found and found + ({},)
                elif isinstance(node, ast.Name):
                    if node.id in visible:  # a nested function also sees its neighbours
                        found = (owner, visible[node.id], visible)
                    elif node.id in self.functions:
                        found = (None, self.functions[node.id], {})
                if found:
                    todo.append(found)
        return list(seen.values())

    def _lines(self, scenes):
        """(records, problems) for the scenes: what they will say, and what cannot be voiced."""
        records, problems = {}, {}
        for scene in self.scenes if scenes is None else scenes:
            for owner, definition in self._reached(scene):
                for node in _scope(definition)[0]:
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
