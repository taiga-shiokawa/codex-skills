#!/usr/bin/env python3
"""Extract visible user/assistant messages from a Codex session JSONL."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Iterable


def codex_root() -> Path:
    configured = os.environ.get("CODEX_HOME")
    return Path(configured).expanduser() if configured else Path.home() / ".codex"


def session_files(root: Path) -> Iterable[Path]:
    for directory in (root / "sessions", root / "archived_sessions"):
        if directory.is_dir():
            yield from directory.rglob("*.jsonl")


def read_session_meta(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                record = json.loads(line)
                if record.get("type") == "session_meta":
                    payload = record.get("payload")
                    return payload if isinstance(payload, dict) else {}
    except (OSError, UnicodeError, json.JSONDecodeError):
        return {}
    return {}


def normalized_path(value: str) -> str:
    return os.path.normcase(os.path.abspath(os.path.expanduser(value)))


def select_session(files: list[Path], session_id: str | None, cwd: str | None) -> Path:
    candidates: list[tuple[Path, str]] = []
    for path in files:
        meta = read_session_meta(path)
        candidate_id = str(meta.get("session_id") or meta.get("id") or "")
        if session_id and not (candidate_id.startswith(session_id) or session_id in path.name):
            continue
        if cwd:
            candidate_cwd = meta.get("cwd")
            if not isinstance(candidate_cwd, str) or normalized_path(candidate_cwd) != normalized_path(cwd):
                continue
        candidates.append((path, candidate_id))

    if not candidates:
        selector = f"session ID '{session_id}'" if session_id else f"cwd '{cwd}'"
        raise SystemExit(f"No Codex session found for {selector}.")

    candidates.sort(key=lambda item: item[0].stat().st_mtime, reverse=True)
    if session_id:
        exact = [item for item in candidates if item[1] == session_id]
        if exact:
            return exact[0][0]
        matching_ids = {candidate_id for _, candidate_id in candidates if candidate_id}
        if len(matching_ids) > 1:
            matches = ", ".join(sorted(matching_ids))
            raise SystemExit(f"Session ID prefix '{session_id}' is ambiguous: {matches}")
    return candidates[0][0]


def visible_message(payload: dict[str, Any]) -> tuple[str, str] | None:
    if payload.get("type") != "message":
        return None
    role = payload.get("role")
    if role not in {"user", "assistant"}:
        return None

    metadata = payload.get("internal_chat_message_metadata_passthrough")
    if role == "user" and isinstance(metadata, dict):
        kinds = metadata.get("content_item_kinds")
        if isinstance(kinds, list) and "user.text" not in kinds:
            return None

    texts: list[str] = []
    expected_type = "input_text" if role == "user" else "output_text"
    for item in payload.get("content") or []:
        if not isinstance(item, dict):
            continue
        if item.get("type") == expected_type and isinstance(item.get("text"), str):
            text = item["text"].strip()
            if text:
                texts.append(text)
    if not texts:
        return None
    return role, "\n\n".join(texts)


def extract(path: Path) -> tuple[dict[str, Any], list[tuple[str, str]]]:
    meta: dict[str, Any] = {}
    messages: list[tuple[str, str]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            try:
                record = json.loads(line)
            except json.JSONDecodeError as error:
                print(f"Skipping malformed JSON at line {line_number}: {error}", file=sys.stderr)
                continue
            if record.get("type") == "session_meta" and isinstance(record.get("payload"), dict):
                meta = record["payload"]
            elif record.get("type") == "response_item" and isinstance(record.get("payload"), dict):
                message = visible_message(record["payload"])
                if message:
                    messages.append(message)
    return meta, messages


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    selector = parser.add_mutually_exclusive_group(required=True)
    selector.add_argument("--cwd", help="Select the newest session whose recorded cwd matches this path.")
    selector.add_argument("--session-id", help="Select a session by full ID or unique ID prefix.")
    args = parser.parse_args()

    path = select_session(list(session_files(codex_root())), args.session_id, args.cwd)
    meta, messages = extract(path)
    session_id = str(meta.get("session_id") or meta.get("id") or "unknown")
    print(f"# Codex session {session_id}")
    print(f"Source: {path}")
    for role, body in messages:
        print(f"\n## {role.capitalize()}\n")
        print(body)


if __name__ == "__main__":
    main()
