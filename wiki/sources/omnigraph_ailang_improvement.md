# Using Omnigraph to Improve AILANG Development

Because AILANG is a highly specific, pure functional language with strict syntax constraints (e.g., the `let` vs `in` distinction and the lack of loops), the cognitive load on a developer is high. Omnigraph can be used to bridge the gap between **understanding language rules** and **implementing them correctly**.

## 1. Modeling the AILANG "Constraint Graph"

You can create an Omnigraph repository that models the grammar and semantics of AILANG, treating rules as a structured knowledge base rather than just a markdown file.

### Proposed Schema
```pg
node Rule {
    slug: String @key
    description: String
    category: enum(syntax, pattern, effect, type)
}

node AntiPattern {
    slug: String @key
    description: String
    severity: enum(warning, error)
}

node Error {
    slug: String @key
    message: String
}

edge Prevents: Rule -> AntiPattern
edge Explains: Rule -> Error
```

**The Utility:** When writing a function, you can query: `"What are the rules governing let bindings?"` $\to$ `list_rules(category="syntax")`. This immediately retrieves the rule forbidding `let x = e in` inside `{}` blocks.

## 2. Automated "Architectural Fitness" for Code

You can turn the graph into a ground-truth specification to detect architectural drift:

- **The Graph:** Represents the "Ideal AILANG State" (e.g., "Every function must declare its effects," "No nested recursion without a base case").
- **The Check:** A script parses your `.ail` files and compares the actual implementation against the graph.
- **The Result:** If an implementation violates a rule (like using a `for` loop or missing an effect declaration), the "fitness test" fails.

## 3. Semantic Search for Patterns (Beyond RAG)

Instead of relying on similarity-based RAG which may return outdated or incorrect snippets, use Omnigraph to store **verified, typed patterns**:
- **Node:** `Pattern: Recursive Filter`
- **Node:** `Pattern: Record Update`
- **Edge:** `Implements: Pattern -> Effect(IO)`

When you need to map a list, you query the graph for the specific pattern, ensuring you get the correct `std/list` primitives and `match` syntax.

## 4. The "Speculative Implementation" Workflow

Use **Branching** to design complex module hierarchies (e.g., a networking layer) before writing code:

1. **Branch:** `feature/design-net-layer`.
2. **Mutate:** Add `Component: NetClient` and `Decision: UseAlgebraicEffectsForErrors`.
3. **Simulate:** Define expected effect signatures in the graph: `func connect() -> () ! {IO, Net, Error}`.
4. **Review:** Use the graph to check for circular dependencies or violations of architectural layers.

## Summary: From "Prose Rules" to "Structural Constraints"

| Without Omnigraph | With Omnigraph |
| :--- | :--- |
| You hope you remember not to use `in` inside `{}` | You query `Syntax` rules to verify binding style |
| You search docs for "how to map a list" | You query `Pattern` nodes for `list_map` |
| Your code follows rules by luck/memory | Your code follows rules because the graph enforces them |
| Rules are a static document that rots | Rules are a queryable, living part of the environment |
