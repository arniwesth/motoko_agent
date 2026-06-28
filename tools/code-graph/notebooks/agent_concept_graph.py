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
    import networkx as nx
    import plotly.graph_objects as go
    from sklearn.decomposition import PCA
    from sklearn.manifold import TSNE
    from sklearn.neighbors import NearestNeighbors
    from sklearn.cluster import KMeans
    from sklearn.feature_extraction.text import TfidfVectorizer

    TOOL_ROOT = Path(__file__).resolve().parents[1]
    REPO_ROOT = TOOL_ROOT.parents[1]
    QUERY_ROOT = TOOL_ROOT / "query"
    if str(QUERY_ROOT) not in sys.path:
        sys.path.insert(0, str(QUERY_ROOT))

    from agent_semantic_poc import DEFAULT_CACHE, default_cache_path, split_markdown

    mo.md(
        """
        # `.agent` Concept Graph (3D)

        A 3D, connected concept graph over cached `.agent` section embeddings.

        - **Nodes** are Markdown sections, positioned by a 3D projection (PCA or t-SNE)
          of their embedding vectors.
        - **Edges** connect each section to its nearest neighbours in *cosine* space
          (the original high-dimensional vector space), not in the projected 3D space.
          An edge therefore means "semantically similar", and the 3D layout is only a
          readable arrangement of that graph.

        Reads the same JSONL cache produced by:

        ```bash
        python3 tools/code-graph/query/agent_semantic_poc.py --glob '.agent/**/*.md' "seed query"
        ```
        """
    )
    return (
        DEFAULT_CACHE,
        KMeans,
        NearestNeighbors,
        PCA,
        Path,
        REPO_ROOT,
        TSNE,
        TfidfVectorizer,
        default_cache_path,
        go,
        json,
        mo,
        np,
        nx,
        pd,
        split_markdown,
    )


@app.cell
def _(DEFAULT_CACHE, mo):
    backend = mo.ui.dropdown(options=["ollama", "openrouter"], value="ollama", label="Embedding backend")
    model_input = mo.ui.text(value="", label="Model (blank = backend default)")
    dimension = mo.ui.number(value=0, start=0, stop=3072, step=128, label="Dimension override (0 for backend default)")
    glob_input = mo.ui.text(value=".agent/**/*.md", label="Markdown glob")
    cache_input = mo.ui.text(value="", label="Embedding cache (blank = derived)")
    filter_input = mo.ui.text(value="", label="Filter graphed sections")
    min_chars = mo.ui.slider(0, 600, value=200, step=25, label="Merge sections shorter than")
    max_chars = mo.ui.slider(1000, 12000, value=6000, step=500, label="Max chars per embedded section")
    max_points = mo.ui.slider(100, 3000, value=900, step=50, label="Max graphed nodes")
    projection = mo.ui.dropdown(options=["pca", "tsne"], value="tsne", label="3D projection")
    tsne_perplexity = mo.ui.slider(5, 80, value=30, step=5, label="t-SNE perplexity")
    color_by = mo.ui.dropdown(
        options=["concept (k-means)", "concept (graph community)", "area", "project", "kind"],
        value="concept (graph community)",
        label="Color by",
    )
    n_concepts = mo.ui.slider(2, 30, value=12, step=1, label="k-means concepts")
    community_algo = mo.ui.dropdown(
        options=["louvain", "greedy modularity", "label propagation"],
        value="louvain",
        label="Community algorithm",
    )
    resolution = mo.ui.slider(0.2, 3.0, value=1.0, step=0.1, label="Louvain resolution (higher = more concepts)")
    community_seed = mo.ui.number(value=7, start=0, stop=9999, step=1, label="Community seed")
    k_neighbors = mo.ui.slider(1, 15, value=5, step=1, label="Edges per node (k)")
    edge_threshold = mo.ui.slider(0.0, 0.95, value=0.55, step=0.01, label="Min cosine similarity for an edge")
    show_edges = mo.ui.checkbox(value=True, label="Show edges")
    mo.vstack([
        mo.hstack([backend, model_input, dimension]),
        mo.hstack([glob_input, cache_input]),
        filter_input,
        mo.hstack([min_chars, max_chars, max_points, color_by]),
        mo.hstack([projection, tsne_perplexity]),
        mo.hstack([k_neighbors, edge_threshold, show_edges, n_concepts]),
        mo.hstack([community_algo, resolution, community_seed]),
    ])
    return (
        backend,
        cache_input,
        color_by,
        community_algo,
        community_seed,
        dimension,
        edge_threshold,
        filter_input,
        glob_input,
        k_neighbors,
        max_chars,
        max_points,
        min_chars,
        model_input,
        n_concepts,
        projection,
        resolution,
        show_edges,
        tsne_perplexity,
    )


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
    return (sections,)


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
def _(
    KMeans,
    NearestNeighbors,
    PCA,
    TSNE,
    TfidfVectorizer,
    color_by,
    community_algo,
    community_seed,
    edge_threshold,
    filter_input,
    k_neighbors,
    max_points,
    n_concepts,
    np,
    nx,
    pd,
    projection,
    resolution,
    rows,
    tsne_perplexity,
):
    df = pd.DataFrame(rows)
    if len(df) and filter_input.value.strip():
        _needle = filter_input.value.strip().lower()
        _haystack = (
            df["path"].astype(str)
            + " " + df["heading"].astype(str)
            + " " + df["area"].astype(str)
            + " " + df["project"].astype(str)
            + " " + df["kind"].astype(str)
        ).str.lower()
        df = df[_haystack.str.contains(_needle, regex=False)].reset_index(drop=True)
    if len(df) > max_points.value:
        df = df.sample(max_points.value, random_state=7).reset_index(drop=True)

    edges = []  # list of (i, j, similarity)
    if len(df) >= 2:
        _vectors = np.array(df["embedding"].tolist(), dtype=np.float32)
        _vectors = _vectors / np.maximum(np.linalg.norm(_vectors, axis=1, keepdims=True), 1e-12)

        # 3D layout
        if projection.value == "tsne":
            _perplexity = min(float(tsne_perplexity.value), max(1.0, (len(df) - 1) / 3))
            _coords = TSNE(
                n_components=3,
                perplexity=_perplexity,
                init="pca",
                learning_rate="auto",
                random_state=7,
                metric="cosine",
            ).fit_transform(_vectors)
        else:
            _coords = PCA(n_components=3, random_state=7).fit_transform(_vectors)
        df["x"], df["y"], df["z"] = _coords[:, 0], _coords[:, 1], _coords[:, 2]

        # kNN graph in cosine space (independent of the 3D layout)
        _k = min(int(k_neighbors.value) + 1, len(df))
        _nn = NearestNeighbors(n_neighbors=_k, metric="cosine").fit(_vectors)
        _distances, _indices = _nn.kneighbors(_vectors)
        _seen = set()
        for _i in range(len(df)):
            for _dist, _j in zip(_distances[_i][1:], _indices[_i][1:]):  # skip self
                _sim = 1.0 - float(_dist)
                if _sim < edge_threshold.value:
                    continue
                _a, _b = (_i, int(_j)) if _i < int(_j) else (int(_j), _i)
                if (_a, _b) in _seen:
                    continue
                _seen.add((_a, _b))
                edges.append((_a, _b, _sim))
        df["degree"] = 0
        for _a, _b, _sim in edges:
            df.at[_a, "degree"] += 1
            df.at[_b, "degree"] += 1

        # Concept assignment: semantic clusters, independent of folder location.
        if color_by.value.startswith("concept"):
            if "community" in color_by.value and edges:
                # Communities of densely-connected sections in the kNN graph.
                _graph = nx.Graph()
                _graph.add_nodes_from(range(len(df)))
                for _ea, _eb, _es in edges:
                    _graph.add_edge(_ea, _eb, weight=_es)
                if community_algo.value == "louvain":
                    _comms = nx.community.louvain_communities(
                        _graph, weight="weight",
                        resolution=float(resolution.value),
                        seed=int(community_seed.value),
                    )
                elif community_algo.value == "label propagation":
                    _comms = nx.community.asyn_lpa_communities(
                        _graph, weight="weight", seed=int(community_seed.value),
                    )
                else:  # greedy modularity
                    _comms = nx.community.greedy_modularity_communities(_graph, weight="weight")
                # Largest concept first, so palette order is stable across algorithms.
                _comms = sorted((set(c) for c in _comms), key=len, reverse=True)
                _labels = [0] * len(df)
                for _ci, _comm in enumerate(_comms):
                    for _node in _comm:
                        _labels[_node] = _ci
            else:
                # k-means directly on the (normalized) embedding vectors.
                _nc = min(int(n_concepts.value), len(df))
                _labels = KMeans(n_clusters=_nc, random_state=7, n_init=10).fit_predict(_vectors)

            # Label each concept by its most distinctive terms (headings weighted x2).
            _fname = df["path"].astype(str).str.rsplit("/", n=1).str[-1].str.replace(".md", "", regex=False)
            _docs = (df["heading"].astype(str) + " " + df["heading"].astype(str) + " " + _fname).tolist()
            _tfidf = TfidfVectorizer(
                stop_words="english",
                token_pattern=r"[A-Za-z_][A-Za-z0-9_]{2,}",
                max_features=4000,
            ).fit(_docs)
            _matrix = _tfidf.transform(_docs)
            _terms = np.array(_tfidf.get_feature_names_out())
            _label_text = {}
            for _lab in sorted({int(x) for x in _labels}):
                _mask = np.array([int(x) == _lab for x in _labels])
                _mean = np.asarray(_matrix[_mask].mean(axis=0)).ravel()
                _top = _mean.argsort()[::-1][:3]
                _words = [_terms[i] for i in _top if _mean[i] > 0]
                _label_text[_lab] = (", ".join(_words) or f"concept {_lab}") + f" ({int(_mask.sum())})"
            df["concept"] = [_label_text[int(x)] for x in _labels]
        else:
            df["concept"] = ""
    else:
        for _col in ("x", "y", "z", "degree", "concept"):
            df[_col] = []
    color_col = "concept" if color_by.value.startswith("concept") else color_by.value
    groups = sorted(df[color_col].fillna("unknown").unique().tolist()) if len(df) else []
    len(df), len(edges)
    return color_col, df, edges, groups


@app.cell
def _(color_by, color_col, df, edges, go, groups, mo, projection, show_edges):
    import plotly.express as px

    if not len(df):
        _graph_output = mo.md("No cached sections match the current filters.")
    else:
        _palette = px.colors.qualitative.Light24
        _color_map = {g: _palette[i % len(_palette)] for i, g in enumerate(groups)}

        _traces = []

        # Edge trace: one Scatter3d of line segments separated by None.
        if show_edges.value and edges:
            _xe, _ye, _ze = [], [], []
            for _a, _b, _es in edges:
                _xe += [df.at[_a, "x"], df.at[_b, "x"], None]
                _ye += [df.at[_a, "y"], df.at[_b, "y"], None]
                _ze += [df.at[_a, "z"], df.at[_b, "z"], None]
            _traces.append(go.Scatter3d(
                x=_xe, y=_ye, z=_ze,
                mode="lines",
                line=dict(color="rgba(160,160,180,0.18)", width=1),
                hoverinfo="skip",
                name=f"edges ({len(edges):,})",
                showlegend=True,
            ))

        # Node traces: one per color group for a clickable legend.
        for _g in groups:
            _sub = df[df[color_col].fillna("unknown") == _g]
            _sizes = 4.0 + 1.6 * (_sub["degree"].clip(upper=12))
            _text = [
                f"{_p}:{_sl}<br>{_h}<br>{color_by.value}: {_g}<br>degree: {_d}"
                for _p, _sl, _h, _d in zip(
                    _sub["path"], _sub["start_line"], _sub["heading"], _sub["degree"],
                )
            ]
            _traces.append(go.Scatter3d(
                x=_sub["x"], y=_sub["y"], z=_sub["z"],
                mode="markers",
                marker=dict(size=_sizes, color=_color_map[_g], opacity=0.85, line=dict(width=0)),
                name=str(_g),
                text=_text,
                hoverinfo="text",
            ))

        _fig = go.Figure(data=_traces)
        _fig.update_layout(
            template="plotly_dark",
            title=f".agent concept graph — {projection.value.upper()} 3D, colored by {color_by.value} ({len(df):,} nodes, {len(edges):,} edges)",
            paper_bgcolor="#111113",
            scene=dict(
                xaxis=dict(title=f"{projection.value.upper()} 1", backgroundcolor="#111113", gridcolor="#27272a"),
                yaxis=dict(title=f"{projection.value.upper()} 2", backgroundcolor="#111113", gridcolor="#27272a"),
                zaxis=dict(title=f"{projection.value.upper()} 3", backgroundcolor="#111113", gridcolor="#27272a"),
            ),
            legend=dict(itemsizing="constant"),
            height=760,
            margin=dict(l=0, r=0, t=48, b=0),
        )
        _graph_output = mo.vstack([
            _fig,
            mo.md(
                "Drag to rotate, scroll to zoom. Node size scales with degree (number of "
                "semantic neighbours). Click legend entries to hide groups or the edge layer."
            ),
        ])
    _graph_output
    return


@app.cell
def _(color_by, df, mo):
    preview = (
        df.drop(columns=["embedding", "x", "y", "z"], errors="ignore")
        .sort_values("degree", ascending=False)
        .head(50)
        if "degree" in df.columns else df.head(0)
    )
    mo.vstack([
        mo.md(f"## Most-connected sections\n\nTop 50 nodes by degree, colored by `{color_by.value}`."),
        mo.ui.table(preview, page_size=10),
    ])
    return


if __name__ == "__main__":
    app.run()
