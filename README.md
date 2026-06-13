# X-Seti - Deepsearch — Aug 2018–2026

`ds` / `deepsearch` is a fast command-line search and replace tool.
Searches **filenames and file contents** by default, with dry-run replace, regex, backups, diffs, colour search, and more.

## Install

```bash
git clone https://github.com/X-Seti/Deepsearch
cd Deepsearch
chmod +x ds deepsearch
sudo cp ds /usr/local/bin/ds
sudo cp deepsearch /usr/local/bin/deepsearch
```

`ds` and `deepsearch` are the same script — short and long name.

## Usage

```
ds [options] <pattern> [replacement] [path]
```

| Mode | Command |
|---|---|
| Search names + contents | `ds foo` |
| Search filenames only | `ds -n config` |
| Search contents only | `ds -c "debug_print"` |
| List matching files only | `ds --list "todo"` |
| Replace (dry-run) | `ds oldname newname` |
| Replace (apply) | `ds oldname newname --apply` |
| Replace with backup | `ds oldname newname --apply --backup` |
| Regex replace | `ds -E "foo_\w+" bar --apply` |
| Case-insensitive | `ds -i MyFunc` |
| Specific file types | `ds -t '*.py,*.js' function_name` |
| Match by shebang | `ds --shebang python "import os"` |
| Show diff before apply | `ds oldname newname --diff` |
| Per-file match counts | `ds --count "TODO"` |
| View line N in matches | `ds pattern -l 42 -C 3` |

## Options

```
  -i, --ignore-case       Case-insensitive search
  -E, --regex             Treat pattern as regex
  -t, --type <glob>       Limit to file types (e.g. '*.py,*.js')
  -n, --name-only         Search filenames only
  -f, --find              Find files by name
  -c, --content-only      Search file contents only
  --list                  Print matching filenames only, no content (pipeable)
  --shebang <type>        Match files by shebang: bash, python, sh, perl, node
  -r, --replace <string>  Replace pattern with string
  --apply                 Apply changes (default: dry-run)
  --backup                Create .bak backups before replacing
  --diff                  Show unified diff preview
  -cc, --comment <string> Comment out matching lines
  -ct, --comment-type     Comment prefix (# // ;)
  --exclude <glob>        Exclude files/dirs (repeatable)
  --include-old           Include old/ folders (excluded by default)
  --binary                Allow binary files (skipped by default)
  --dirs                  Include directories in filename search
  --context N             Show N lines of context around matches
  --count                 Print match counts per file
  --first                 Stop after first match
  -o, --output <file>     Save results to file
  -e, --editor            Open matches in editor (default: kate)
  -l, --line <N>          Show line N from matched files
  -C <N>                  Lines of context around --line
  -v, --version           Show version
  -h, --help              Show help
```

## Color / Theme Options

```
  -k, --colors <hex>             Find all uses of a hex color
  -k, --colors <hex> <new_hex>   Replace a color everywhere (dry-run by default)
      --apply                    Apply color replacement
      --theme <key>              Show value of a theme key across all JSON files
      --kde                      Compare KDE color roles with theme keys
      --unique                   List all unique hex colors found, with swatches
```

## Excludes

Default excludes: `.git`, `__pycache__`, `.vscode`, `.idea`, `node_modules`, `old/`

```bash
ds foo --exclude '*.log' --exclude 'build/*'
```

## Examples

```bash
# Find all files referencing a function
ds my_function

# Replace across a Python project
ds old_module_name new_module_name -t '*.py' --apply --backup

# List files containing TODO, pipe to xargs
ds --list "TODO" | xargs grep -l "FIXME"

# Find only bash scripts (by shebang, not extension)
ds --shebang bash "set -euo pipefail"

# Show per-file match counts
ds --count "import"

# Regex: rename all v1 references to v2
ds -E "v1\.[0-9]+" v2.0 --apply

# Case-insensitive search in contents only
ds -c -i "todo"

# Preview what would change before applying
ds oldname newname --diff

# Find all hex colors used in a project
ds --unique .

# Find which themes use a specific color
ds -k '#2a2a2a'

# Replace a color across all theme files
ds -k '#2a2a2a' '#1e1e2e' --apply
```

## Files

| File | Description |
|---|---|
| `ds` | Main script (short name) |
| `deepsearch` | Same script (long name) |
| `deepsearch_dolphin.sh` | Dolphin file manager integration |
