#!/usr/bin/env python3
"""Sync docs/ into a GitHub wiki checkout, flattening nested paths.

GitHub's wiki does not support multi-segment page URLs (a page stored at
schema/task.md is unreachable at /wiki/schema/task - GitHub redirects to
/wiki/schema, dropping the rest). So every docs/ file is flattened into a
single-level wiki page name (schema/task.md -> schema-task.md), except the
gollum special files (Home.md, _Sidebar.md, _Footer.md) which must stay at
the wiki root. Relative markdown links inside the synced files are rewritten
to match.

Images: a wiki only holds what is committed to the wiki repo, so every local
image a page references (![alt](../../mockups/screens/x.png), or an <img src="..."> tag, which lets a page set a width) is copied into
the wiki's images/ folder under a flat name built from its path in the repo,
and the link is rewritten to images/<name>. Docs keep ordinary relative paths,
which also work in the repo view.

A link to a file or folder elsewhere in the repo (outside docs/) becomes a link to it on GitHub.

Code fences (``` and ~~~, which is where the Mermaid diagrams live) are left
exactly as written. A missing image or a link to a missing page stops the sync
with a list, rather than publishing something broken.
"""
import os
import re
import shutil
import sys
from pathlib import Path, PurePosixPath

ROOT_FILES = {"Home.md", "_Sidebar.md", "_Footer.md"}
LINK_RE = re.compile(r"(!?\[[^\]]*\]\()([^)\s]+)(\))")
IMG_TAG_RE = re.compile(r'(<img\b[^>]*?\bsrc=")([^"]+)(")', re.IGNORECASE)
EXTERNAL_RE = re.compile(r"^([a-z][a-z0-9+.-]*:)", re.IGNORECASE)
FENCE_RE = re.compile(r"^\s*(```|~~~)")
IMAGE_DIR = "images"


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


def sync(docs_dir: Path, wiki_dir: Path) -> list:
    """Writes the wiki; returns a list of problems (empty when all is well)."""
    docs_dir = docs_dir.resolve()
    repo_root = docs_dir.parent
    repo_url = "https://github.com/" + os.environ.get("GITHUB_REPOSITORY", "fahadahmed/jamaal-app")
    problems = []
    pages = {p.relative_to(docs_dir).as_posix() for p in docs_dir.rglob("*.md")}

    for entry in wiki_dir.iterdir():
        if entry.name == ".git":
            continue
        shutil.rmtree(entry) if entry.is_dir() else entry.unlink()

    for rel_posix in sorted(pages):
        md_file = docs_dir / rel_posix
        parent_posix = PurePosixPath(rel_posix).parent.as_posix()
        src_dir = PurePosixPath("" if parent_posix == "." else parent_posix)

        def copy_image(target):
            """Copies a local image into the wiki and returns its new link, or None (with a problem noted)."""
            path_part = target.split("#", 1)[0]
            if not path_part:
                return None
            source = (docs_dir / src_dir / path_part).resolve()
            if not source.is_file():
                problems.append(f"{rel_posix}: missing image {target}")
                return None
            try:
                repo_rel = source.relative_to(repo_root).as_posix()
            except ValueError:
                problems.append(f"{rel_posix}: image outside the repo {target}")
                return None
            name = repo_rel.replace("/", "-")
            out = wiki_dir / IMAGE_DIR / name
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, out)
            return f"{IMAGE_DIR}/{name}"

        def replace_img_tag(m):
            if EXTERNAL_RE.match(m.group(2)):
                return m.group(0)
            new = copy_image(m.group(2))
            return m.group(0) if new is None else m.group(1) + new + m.group(3)

        def replace(m):
            opener, target = m.group(1), m.group(2)
            if EXTERNAL_RE.match(target):
                return m.group(0)
            path_part = target.split("#", 1)[0]
            if opener.startswith("!"):
                new = copy_image(target)
                return m.group(0) if new is None else opener + new + m.group(3)
            if path_part:
                resolved = os.path.normpath(str(src_dir / path_part))
                if resolved.startswith(".."):
                    # Outside docs/: a file or folder elsewhere in the repo, which a wiki cannot hold. Point at it on GitHub.
                    source = (docs_dir / src_dir / path_part).resolve()
                    for candidate, kind in ((source, "tree" if source.is_dir() else "blob"), (Path(str(source) + ".md"), "blob")):
                        if candidate.exists():
                            frag = "#" + target.split("#", 1)[1] if "#" in target else ""
                            return opener + f"{repo_url}/{kind}/main/{candidate.relative_to(repo_root).as_posix()}{frag}" + m.group(3)
                    problems.append(f"{rel_posix}: link to a missing file {target}")
                    return m.group(0)
                if not resolved.endswith(".md"):
                    resolved += ".md"
                if resolved not in pages:
                    problems.append(f"{rel_posix}: link to a missing page {target}")
            return opener + rewrite_target(target, src_dir) + m.group(3)

        out_lines = []
        in_fence = False
        for line in md_file.read_text().split("\n"):
            if FENCE_RE.match(line):
                in_fence = not in_fence
                out_lines.append(line)
            elif in_fence:
                out_lines.append(line)
            else:
                out_lines.append(LINK_RE.sub(replace, IMG_TAG_RE.sub(replace_img_tag, line)))

        (wiki_dir / flat_name(rel_posix)).write_text("\n".join(out_lines))
    return problems


def main() -> None:
    problems = sync(Path(sys.argv[1]), Path(sys.argv[2]))
    if problems:
        print("Wiki sync found problems:", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
