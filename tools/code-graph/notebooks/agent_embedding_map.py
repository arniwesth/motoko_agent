import marimo

__generated_with = "0.0.0"
app = marimo.App(width="full")


@app.cell
def _():
    import json
    import sys
    from pathlib import Path

    import numpy as np
    import pandas as pd
    import marimo as mo
    from bokeh.models import ColumnDataSource, HoverTool
    from bokeh.palettes import Category20, Turbo256
    from bokeh.plotting import figure
    from sklearn.decomposition import PCA
    from sklearn.manifold import TSNE

    TOOL_ROOT = Path(__file__).resolve().parents[1]
    REPO_ROOT = TOOL_ROOT.parents[1]
    QUERY_ROOT = TOOL_ROOT / "query"
    if str(QUERY_ROOT) not in sys.path:
        sys.path.insert(0, str(QUERY_ROOT))

    from agent_semantic_poc import DEFAULT_CACHE, default_cache_path, split_markdown

    mo.md(
        """
        # `.agent` Embedding Map

        Visualize cached EmbeddingGemma vectors for `.agent` Markdown sections.

        This notebook reads the JSONL cache produced by:

        ```bash
        python3 tools/code-graph/query/agent_semantic_poc.py --glob '.agent/**/*.md' "seed query"
        ```
        """
    )
    return (
        Category20,
        DEFAULT_CACHE,
        HoverTool,
        PCA,
        Path,
        REPO_ROOT,
        TSNE,
        Turbo256,
        figure,
        json,
        mo,
        np,
        pd,
        default_cache_path,
        split_markdown,
    )


@app.cell
def _(DEFAULT_CACHE, mo):
    backend = mo.ui.dropdown(options=["ollama", "openrouter"], value="ollama", label="Embedding backend")
    model_input = mo.ui.text(value="", label="Model (blank = backend default)")
    dimension = mo.ui.number(value=0, start=0, stop=3072, step=128, label="Dimension override (0 for backend default)")
    glob_input = mo.ui.text(value=".agent/**/*.md", label="Markdown glob")
    cache_input = mo.ui.text(value="", label="Embedding cache (blank = derived)")
    filter_input = mo.ui.text(value="", label="Filter plotted sections")
    min_chars = mo.ui.slider(0, 600, value=200, step=25, label="Merge sections shorter than")
    max_chars = mo.ui.slider(1000, 12000, value=6000, step=500, label="Max chars per embedded section")
    max_points = mo.ui.slider(100, 5000, value=3000, step=100, label="Max plotted points")
    projection = mo.ui.dropdown(options=["pca", "tsne"], value="pca", label="Projection")
    tsne_perplexity = mo.ui.slider(5, 80, value=35, step=5, label="t-SNE perplexity")
    color_by = mo.ui.dropdown(
        options=["area", "project", "kind"],
        value="area",
        label="Color by",
    )
    mo.vstack([
        mo.hstack([backend, model_input, dimension]),
        mo.hstack([glob_input, cache_input]),
        filter_input,
        mo.hstack([min_chars, max_chars, max_points, color_by]),
        mo.hstack([projection, tsne_perplexity]),
    ])
    return backend, cache_input, color_by, dimension, filter_input, glob_input, max_chars, max_points, min_chars, model_input, projection, tsne_perplexity


@app.cell
def _(Path, REPO_ROOT, glob_input, max_chars, min_chars, split_markdown):
    import glob

    paths = sorted(Path(p) for p in glob.glob(str(REPO_ROOT / glob_input.value), recursive=True))
    sections = [
        section
        for path in paths
        for section in split_markdown(
            path,
            max_chars=max_chars.value,
            min_chars=min_chars.value,
            context_prefix=True,
        )
    ]
    len(paths), len(sections)
    return paths, sections


@app.cell
def _(Path, backend, cache_input, default_cache_path, dimension, json, mo, model_input, sections):
    import hashlib

    _model = model_input.value.strip() or ("google/gemini-embedding-2" if backend.value == "openrouter" else "embeddinggemma")
    _dimension = int(dimension.value or 0)
    if backend.value == "openrouter" and _dimension == 0:
        _dimension = 768
    cache_path = Path(cache_input.value) if cache_input.value.strip() else default_cache_path(backend.value, _model, _dimension)
    embedding_cache = {}
    cache_rows = 0
    if cache_path.exists():
        for line in cache_path.read_text(errors="replace").splitlines():
            if not line.strip():
                continue
            _cache_row = json.loads(line)
            cache_rows += 1
            embedding_cache[_cache_row["cache_key"]] = _cache_row

    rows = []
    missing = 0
    for section in sections:
        cache_key = hashlib.sha256(f"{backend.value}\0{_model}\0{_dimension}\0document\0{section.sha256}".encode()).hexdigest()
        cached = embedding_cache.get(cache_key)
        if cached is None:
            missing += 1
            continue
        path_parts = section.path.split("/")
        area = "/".join(path_parts[:2]) if len(path_parts) >= 2 else section.path
        project = "/".join(path_parts[:4]) if len(path_parts) >= 4 and path_parts[1] == "projects" else area
        kind = path_parts[1] if len(path_parts) > 1 else "other"
        rows.append({
            "item_id": section.item_id,
            "path": section.path,
            "heading": section.heading,
            "start_line": section.start_line,
            "end_line": section.end_line,
            "area": area,
            "project": project,
            "kind": kind,
            "chars": len(section.text),
            "embedding": cached["embedding"],
        })

    mo.md(
        f"""
        **Cache file:** `{cache_path}`  
        **Backend/model:** `{backend.value}` / `{_model}` / dim `{_dimension or "default"}`  
        **Cache rows:** {cache_rows:,}  
        **Loaded sections:** {len(rows):,}  
        **Missing cached sections:** {missing:,}

        If many sections are missing, populate the cache with:

        ```bash
        python3 tools/code-graph/query/agent_semantic_poc.py --glob '.agent/**/*.md' "seed query"
        ```
        """
    )
    return (rows,)


@app.cell
def _(PCA, TSNE, color_by, filter_input, max_points, np, pd, projection, rows, tsne_perplexity):
    df = pd.DataFrame(rows)
    if len(df) and filter_input.value.strip():
        _needle = filter_input.value.strip().lower()
        _haystack = (
            df["path"].astype(str)
            + " "
            + df["heading"].astype(str)
            + " "
            + df["area"].astype(str)
            + " "
            + df["project"].astype(str)
            + " "
            + df["kind"].astype(str)
        ).str.lower()
        df = df[_haystack.str.contains(_needle, regex=False)].reset_index(drop=True)
    if len(df) > max_points.value:
        df = df.sample(max_points.value, random_state=7).reset_index(drop=True)
    if len(df) >= 2:
        vectors = np.array(df["embedding"].tolist(), dtype=np.float32)
        vectors = vectors / np.maximum(np.linalg.norm(vectors, axis=1, keepdims=True), 1e-12)
        if projection.value == "tsne":
            _perplexity = min(float(tsne_perplexity.value), max(1.0, (len(df) - 1) / 3))
            coords = TSNE(
                n_components=2,
                perplexity=_perplexity,
                init="pca",
                learning_rate="auto",
                random_state=7,
                metric="cosine",
            ).fit_transform(vectors)
        else:
            coords = PCA(n_components=2, random_state=7).fit_transform(vectors)
        df["x"] = coords[:, 0]
        df["y"] = coords[:, 1]
    else:
        df["x"] = []
        df["y"] = []
    groups = sorted(df[color_by.value].fillna("unknown").unique().tolist()) if len(df) else []
    df, groups
    return df, groups


@app.cell
def _(Category20, ColumnDataSource, HoverTool, Turbo256, color_by, df, figure, groups, mo, projection):
    if not len(df):
        _plot_output = mo.md("No cached sections match the current filters.")
    else:
        _palette = list(Category20[20])
        if len(groups) > len(_palette):
            _palette = [Turbo256[int(i * (len(Turbo256) - 1) / max(len(groups) - 1, 1))] for i in range(len(groups))]
        _color_map = {_group: _palette[_idx % len(_palette)] for _idx, _group in enumerate(groups)}
        _plot_df = df.copy()
        _plot_df["color"] = _plot_df[color_by.value].map(_color_map).fillna("#9ca3af")
        _plot_df["location"] = _plot_df["path"] + ":" + _plot_df["start_line"].astype(str)
        _source = ColumnDataSource(_plot_df.drop(columns=["embedding"], errors="ignore"))

        _figure = figure(
            title=f".agent embedding {projection.value.upper()} map ({len(_plot_df):,} sections, colored by {color_by.value})",
            width=1100,
            height=720,
            sizing_mode="stretch_width",
            tools="pan,wheel_zoom,box_zoom,reset,save",
            active_scroll="wheel_zoom",
            background_fill_color="#111113",
            border_fill_color="#111113",
            outline_line_color="#3f3f46",
        )
        _figure.scatter(
            x="x",
            y="y",
            source=_source,
            size=7,
            color="color",
            alpha=0.72,
            line_color=None,
            legend_group=color_by.value,
        )
        _figure.add_tools(HoverTool(tooltips=[
            ("path", "@path"),
            ("heading", "@heading"),
            ("lines", "@start_line-@end_line"),
            (color_by.value, f"@{color_by.value}"),
            ("chars", "@chars"),
        ]))
        _figure.xaxis.axis_label = f"{projection.value.upper()} 1"
        _figure.yaxis.axis_label = f"{projection.value.upper()} 2"
        _figure.xaxis.axis_line_color = "#71717a"
        _figure.yaxis.axis_line_color = "#71717a"
        _figure.xaxis.major_label_text_color = "#d4d4d8"
        _figure.yaxis.major_label_text_color = "#d4d4d8"
        _figure.xaxis.axis_label_text_color = "#e4e4e7"
        _figure.yaxis.axis_label_text_color = "#e4e4e7"
        _figure.xgrid.grid_line_color = "#27272a"
        _figure.ygrid.grid_line_color = "#27272a"
        _figure.title.text_color = "#f4f4f5"
        _figure.legend.background_fill_color = "#18181b"
        _figure.legend.border_line_color = "#3f3f46"
        _figure.legend.label_text_color = "#f4f4f5"
        _figure.legend.click_policy = "hide"
        _figure.toolbar.autohide = True

        _plot_output = mo.vstack([
            _figure,
            mo.md(f"{projection.value.upper()} projection of normalized embedding vectors. Hover points for metadata; click legend groups to hide/show them."),
        ])
    _plot_output
    return


@app.cell
def _(color_by, df, mo):
    preview = df.drop(columns=["embedding", "x", "y"], errors="ignore").head(50)
    mo.vstack([
        mo.md(f"## Section Table\n\nFirst 50 plotted sections, colored by `{color_by.value}`."),
        mo.ui.table(preview, page_size=10),
    ])
    return


if __name__ == "__main__":
    app.run()
