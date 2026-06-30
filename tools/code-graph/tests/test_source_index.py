from pathlib import Path

from extractor.source_index import build_source_index, is_comment_line


def write(root: Path, rel: str, text: str) -> Path:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


def copy_fixture(root: Path, name: str, rel: str | None = None) -> None:
    fixture = Path(__file__).parent / "fixtures" / "source_index" / name
    write(root, rel or name, fixture.read_text())


def test_comment_detection_by_file_kind():
    assert is_comment_line("ailang", "  -- comment") == 1
    assert is_comment_line("typescript", " // comment") == 1
    assert is_comment_line("shell", " # comment") == 1
    assert is_comment_line("toml", "# comment") == 1
    assert is_comment_line("markdown", "# heading") == 0
    assert is_comment_line("json", ' {"k": 1}') == 0


def test_source_index_chunks_csv_text_and_host_line_only(tmp_path):
    copy_fixture(tmp_path, "csv_quotes_commas_newlines.ail", "src/core/csv_quotes_commas_newlines.ail")
    copy_fixture(tmp_path, "host_only.md", "AGENTS.md")
    files, lines, chunks = build_source_index(tmp_path, profile="core", include_tests=False)

    assert any(row["path"] == "AGENTS.md" and row["lang"] == "markdown" for row in files)
    assert any(row["path"] == "AGENTS.md" for row in lines)
    assert not any(row["path"] == "AGENTS.md" for row in chunks)
    chunk = next(row for row in chunks if row["name"] == "quoted")
    assert 'one, two, \\"three\\"' in chunk["text"]
    assert "\nfour" in chunk["text"]


def test_chunk_boundaries_and_slug_join_key(tmp_path):
    copy_fixture(tmp_path, "chunk_boundaries.ail", "src/core/chunk_boundaries.ail")
    copy_fixture(tmp_path, "slug_join.ail", "src/core/slug_join.ail")
    _files, _lines, chunks = build_source_index(tmp_path, profile="core", include_tests=False)

    by_name = {row["name"]: row for row in chunks}
    assert "type T" not in by_name["before_type"]["text"]
    assert "module nested" not in by_name["before_module"]["text"]
    assert "import std/io" not in by_name["before_import"]["text"]
    slug = by_name["target"]
    assert slug["chunk_slug"] == "src/core/slug_join#func:target"
    assert slug["func_slug"] == "src/core/slug_join#target"
    assert slug["chunk_slug"] != slug["func_slug"]


def test_profile_and_include_tests_filtering(tmp_path):
    write(tmp_path, "src/core/main.ail", "module src/core/main\nfunc main() -> int { 1 }\n")
    write(tmp_path, "src/core/main_test.ail", "module src/core/main_test\nfunc test_main() -> int { 1 }\n")
    write(tmp_path, "examples/demo.ail", "module examples/demo\nfunc demo() -> int { 1 }\n")

    core_files, _lines, _chunks = build_source_index(tmp_path, profile="core", include_tests=False)
    assert "src/core/main.ail" in {row["path"] for row in core_files}
    assert "src/core/main_test.ail" not in {row["path"] for row in core_files}
    assert "examples/demo.ail" not in {row["path"] for row in core_files}

    test_files, _lines, _chunks = build_source_index(tmp_path, profile="core", include_tests=True)
    assert "src/core/main_test.ail" in {row["path"] for row in test_files}
