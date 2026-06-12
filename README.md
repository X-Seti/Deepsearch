# X-Seti - Deepsearch — Aug 2018–2026

#Update; Format fixes, Better terminel output.

`ds` / `deepsearch` is a fast command-line search and replace tool.
Searches **filenames and file contents** by default, with dry-run replace, regex, backups, diffs, and more.

## Install

```bash
git clone https://github.com/X-Seti/Deepsearch
cd Deepsearch
chmod +x ds
sudo cp ds /usr/local/bin/ds          # optional: add to PATH
```

## Usage

```
ds [options] <pattern> [replacement] [path]
```

| Mode | Command |
|---|---|
| Search names + contents | `ds foo` |
| Search filenames only | `ds -n config` |
| Search contents only | `ds -c "debug_print"` |
| Replace (dry-run) | `ds oldname newname` |
| Replace (apply) | `ds oldname newname --apply` |
| Replace with backup | `ds oldname newname --apply --backup` |
| Regex replace | `ds -E "foo_\w+" bar --apply` |
| Case-insensitive | `ds -i MyFunc` |
| Specific file types | `ds -t '*.py,*.js' function_name` |
| Show diff before apply | `ds oldname newname --diff` |
| View line N in matches | `ds pattern -l 42 -C 3` |

## Options

```
  -i, --ignore-case       Case-insensitive search
  -E, --regex             Treat pattern as regex
  -t, --type <glob>       Limit to file types (e.g. '*.py,*.js')
  -n, --name-only         Search filenames only
  -f, --find              Find files by name
  -c, --content-only      Search file contents only
  -r, --replace <string>  Replace pattern with string
  --apply                 Apply changes (default: dry-run)
  --backup                Create .bak backups before replacing
  --diff                  Show unified diff preview
  --exclude <glob>        Exclude files/dirs (repeatable)
  --include-old           Include old/ folders (excluded by default)
  --binary                Allow binary files (skipped by default)
  --dirs                  Include directories in filename search
  --context N             Show N lines of context around matches
  --count                 Print match counts per file only
  --first                 Stop after first match
  -o, --output <file>     Save results to file
  -e, --editor            Open matches in editor (default: kate)
  -l, --line <N>          Show line N from matched files
  -C <N>                  Lines of context around --line
  -v, --version           Show version
  -h, --help              Show help
```

## Excludes

By default excludes: `.git`, `__pycache__`, `.vscode`, `.idea`, `node_modules`, `old/`

Add your own:
```bash
ds foo --exclude '*.log' --exclude 'build/*'
```

## Examples

```bash
# Find all files referencing a function
ds my_function

# Replace across a Python project
ds old_module_name new_module_name -t '*.py' --apply --backup

# Regex: rename all v1 references to v2
ds -E "v1\.[0-9]+" v2.0 --apply

# Case-insensitive search in contents only
ds -c -i "todo"

# Preview what would change before applying
ds oldname newname --diff

# Search a specific directory
ds pattern . /path/to/project
```

## Files

| File | Description |
|---|---|
| `ds` | Main script (short name) |
| `deepsearch.sh` | Same script, long name |
| `deepsearch_dolphin.sh` | Dolphin file manager integration |
