X-Seti - Deepsearch - Aug2018-2025 (Moved to git)

`deepsearch` is a flexible command-line tool for searching, replacing, and renaming text or files.  
It extends basic search with powerful options like excludes, regex, backups, diffs, summaries, and more.  

## Features
- Search file contents or filenames
- Replace text inside files or in filenames
- Dry-run by default, safe changes with `--apply`
- Supports regex, case-insensitive, file type filters
- Exclude paths (`--exclude`)
- Backups (`--backup`) and diff preview (`--diff`)
- Optional summary report of matches and changes
- Context lines, match counts, stop at first match
- Rename directories only with `--dirs`
- Skips binary files by default

## Installation
Clone this repository and make the script executable:
```bash
https://github.com/X-Seti/Deepsearch
cd deepsearch
chmod +x deepsearch.sh
