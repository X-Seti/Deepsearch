# Deepsearch — Changelog

## v1.4 — April 2026

**Bug fixes:**

- `/tmp` crash: `mktemp -d` was called before helper functions (`increment_counter`,
  `is_binary`, `matches_pattern`) were defined. Moved temp dir setup to after all
  function definitions.
- `trap` had unquoted `$TEMP_DIR` — fixed to `'rm -rf "$TEMP_DIR"'`.
- `MATCHES_FILE` used as integer in `if [[ $MATCHES_FILE -eq 1 ]]` — it is a file
  path, not a number. Removed the broken check.
- `FIND_EXCLUDES` (uppercase) referenced in `search_names()` but built as
  `find_excludes` (lowercase). Unified into single `FIND_EXPR` array.
- Replace mode: `NAME_ONLY=1` and `CONTENT_ONLY=1` were both set inside the replace
  block then immediately checked — contradictory logic removed.
- `-f/--find` flag was setting `search_term` instead of `ARGS` — pattern was lost.
  Fixed to `ARGS+=("$2")`.
- Duplicate search logic refactored into `print_name_matches` and
  `print_content_matches` functions.
- `ROOT` now correctly defaults to `.` when only pattern+replacement are given.

---

## v1.3 — January 2026

- Unified search and replace into single script (`ds` / `deepsearch.sh`)
- Added `--diff` preview mode
- Added `-l/--line` viewer with context
- Added `--count`, `--first`, `--summary` output options
- Added `--exclude` (repeatable), `--include-old`, `--binary` flags
- Added `-e/--editor` integration (kate/kwrite/code)
- Dolphin file manager integration (`deepsearch_dolphin.sh`)
- Default excludes: `.git`, `__pycache__`, `.vscode`, `.idea`, `node_modules`, `old/`

---

## v1.0–v1.2 — 2018–2025

- Initial versions: grep wrapper with basic filename and content search
- Moved to GitHub repository

---

## v1.5 — April 2026

**New: Color search mode** (`-k` / `--colors`):
- `ds -k '#2a2a2a'` — find every file and line using a hex color, with
  automatic detection of which theme key it's a fallback for
- `ds -k '#2a2a2a' '#1e1e2e' --apply` — replace a color everywhere
- Shows a terminal color swatch for the searched color

**New: Theme key mode** (`--theme <key>`):
- `ds --theme bg_primary` — show the value of a theme key across all JSON
  theme files, with color swatches

**New: KDE color mode** (`--kde`):
- Reads `~/.config/kdeglobals` and compares KDE color roles to theme keys
- Shows which KDE roles match which theme keys and their hex values

**New: Unique colors mode** (`--unique`):
- `ds --unique .` — list all unique hex color values found across files,
  sorted by frequency, with color swatches
