#!/usr/bin/env python3
"""Sync docs/ into a GitHub wiki checkout, flattening nested paths.

GitHub's wiki does not support multi-segment page URLs (a page stored at
schema/task.md is unreachable at /wiki/schema/task - GitHub redirects to
/wiki/schema, dropping the rest). So every docs/ file is flattened into a
single-level wiki page name (schema/task.md -> schema-task.md), except the
gollum special files (Home.md, _Sidebar.md, _Footer.md) which must stay at
the wiki root. Relative markdown links inside the synced files are rewritten
to match.
"""
import os
import re
import shutil
import sys
from pathlib import Path, PurePosixPath

ROOT_FILES = {"Home.md", "_Sidebar.md", "_Footer.md"}
LINK_RE = re.compile(r"(\[[^\]]*\]\()([^)\s]+)(\))")
EXTERNAL_RE = re.compile(r"^([a-z][a-z0-9+.-]*:)", re.IGNORECASE)


def flat_name(rel_posix: str) -> str:
    return rel_posix if rel_posix in ROOT_FILES else rel_posix.replace("/", "-")


def rewrite_target(target: str, src_dir: PurePosixPath) -> str:
    if EXTERNAL_RE.match(target):
        return target
    frag = ""
    if "#" in target:
        target, frag = target.split("#", 1)
        frag = "#" + frag
    if not target:
        return frag
    resolved = os.path.normpath(str(src_dir / target))
    if not resolved.endswith(".md"):
        resolved += ".md"
    flat = flat_name(resolved)
    if flat.endswith(".md"):
        flat = flat[:-3]
    return flat + frag


def main() -> None:
    docs_dir = Path(sys.argv[1])
    wiki_dir = Path(sys.argv[2])

    for entry in wiki_dir.iterdir():
        if entry.name == ".git":
            continue
        shutil.rmtree(entry) if entry.is_dir() else entry.unlink()

    for md_file in docs_dir.rglob("*.md"):
        rel = md_file.relative_to(docs_dir)
        rel_posix = rel.as_posix()
        parent_posix = rel.parent.as_posix()
        src_dir = PurePosixPath("" if parent_posix == "." else parent_posix)

        text = md_file.read_text()
        text = LINK_RE.sub(
            lambda m: m.group(1) + rewrite_target(m.group(2), src_dir) + m.group(3),
            text,
        )

        out_path = wiki_dir / flat_name(rel_posix)
        out_path.write_text(text)


if __name__ == "__main__":
    main()
