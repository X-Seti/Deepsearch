#!/usr/bin/env bash
# X-Seti - deepsearch v1.0 - Unified search and replace tool
# Searches filenames AND file contents by default, with extensive replace capabilities

set -euo pipefail

# --- Configurable ---
DEFAULT_EDITOR="kate"  # Options: kate, kwrite, code

usage() {
    cat <<EOF
Usage: $0 [options] <pattern> [replacement] [path]

SEARCH MODES:
  Default behavior searches BOTH filenames and file contents

OPTIONS:
  -i, --ignore-case       Case-insensitive search
  -E, --regex             Treat pattern as regex (default: literal string)
  -t, --type <glob>       Limit to specific file types (e.g. '*.c,*.h,*.py')
  -n, --name-only         Search filenames only
  -c, --content-only      Search file contents only

REPLACE OPTIONS:
  -r, --replace <string>  Replace pattern with string
  --apply                 Actually perform changes (default: dry-run)
  --backup                Create .bak backups before replacing
  --diff                  Show diff preview of changes

FILTERING:
  --exclude <glob>        Exclude files/dirs matching glob (can be repeated)
  --include-old           Include old/ folders (default: excluded)
  --binary                Allow binary files (default: skip them)
  --dirs                  Include directories in filename search

OUTPUT:
  --context N             Show N lines of context around matches
  --count                 Only print counts of matches per file
  --summary               Print summary report at end
  --first                 Stop after first match
  -o, --output <file>     Save results to file
  -e, --editor            Open matches in editor ($DEFAULT_EDITOR)

  -h, --help              Show this help

Line Viewing:
  -l, --line <N>          Show line N from found files
  --line-context <N>      Show N lines of context around line

EXAMPLES:
  $0 myfunction                                    # search 'myfunction' in names AND contents
  $0 -n config                                     # search filenames only for 'config'
  $0 -c "debug.*print" -E                          # regex search in file contents only
  $0 -i components.img_debug method.img_debug      # case-insensitive replace (dry-run)
  $0 -r newname oldname --apply --backup           # replace with backups
  $0 foo --exclude '*.log' --context 2             # exclude logs, show context
  $0 -t '*.py,*.js' function_name                  # search in Python/JS files only
  $0 foo -l 100 --line-context 5                   # search and show line 100 ±5 lines

POSITIONAL REPLACEMENT:
  $0 old_name new_name --apply     # Replaces 'old_name' with 'new_name'
EOF
    exit 1
}

# --- Defaults ---
IGNORE_CASE=0
REGEX=0
TYPES=""
REPLACE=""
APPLY=0
NAME_ONLY=0
CONTENT_ONLY=0
DIRS_INCLUDE=0
INCLUDE_OLD=0
EXCLUDES=(".git/*" "node_modules/*" "__pycache__/*" ".vscode/*" ".idea/*")
BACKUP=0
DIFF=0
CONTEXT=0
COUNT=0
SUMMARY=0
FIRST=0
ALLOW_BINARY=0
OUTPUT_FILE=""
EDITOR_OPEN=0
SHOW_LINE=0
LINE_NUMBER=""
LINE_CONTEXT=0

ARGS=()

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ignore-case) IGNORE_CASE=1 ;;
        -E|--regex) REGEX=1 ;;
        -t|--type) TYPES=$2; shift ;;
        -r|--replace) REPLACE=$2; shift ;;
        -n|--name-only) NAME_ONLY=1 ;;
        -c|--content-only) CONTENT_ONLY=1 ;;
        --dirs) DIRS_INCLUDE=1 ;;
        --include-old) INCLUDE_OLD=1 ;;
        --exclude) EXCLUDES+=("$2"); shift ;;
        --apply) APPLY=1 ;;
        --backup) BACKUP=1 ;;
        --diff) DIFF=1 ;;
        --context) CONTEXT=$2; shift ;;
        --count) COUNT=1 ;;
        --summary) SUMMARY=1 ;;
        --first) FIRST=1 ;;
        --binary) ALLOW_BINARY=1 ;;
        -l|--line) SHOW_LINE=1; LINE_NUMBER="$2"; shift ;;
        --line-context) LINE_CONTEXT="$2"; shift ;;
        -o|--output) OUTPUT_FILE=$2; shift ;;
        -e|--editor) EDITOR_OPEN=1 ;;
        -h|--help) usage ;;
        *) ARGS+=("$1") ;;
    esac
    shift
done

# --- Handle Arguments ---
if [[ ${#ARGS[@]} -lt 1 ]]; then
    echo "Error: Missing search pattern"
    echo "Usage: $(basename $0) [options] <pattern> [replacement] [path]"
    echo "Use --help for more information"
    exit 1
fi

PATTERN=${ARGS[0]}
ROOT=${ARGS[2]:-.}

# Handle positional replacement (pattern replacement [path])
if [[ ${#ARGS[@]} -ge 2 && -z "$REPLACE" && "${ARGS[1]}" != .* && ! -d "${ARGS[1]}" ]]; then
    REPLACE=${ARGS[1]}
    ROOT=${ARGS[2]:-.}
fi

# --- Add default excludes ---
if [[ $INCLUDE_OLD -eq 0 ]]; then
    EXCLUDES+=("old/*" "*/old/*")
fi

# --- Build find expression ---
FIND_EXPR=()
for excl in "${EXCLUDES[@]}"; do
    FIND_EXPR+=(-not -path "*/$excl")
done

# --- Build grep options ---
GREP_OPTS=""
[[ $IGNORE_CASE -eq 1 ]] && GREP_OPTS+="-i "
[[ $REGEX -eq 0 ]] && GREP_OPTS+="-F "
GREP_OPTS+="-n"

# --- Helper functions ---
increment_counter() {
    local file=$1
    local count=$(cat "$file")
    echo $((count + 1)) > "$file"
}

is_binary() {
    [[ $ALLOW_BINARY -eq 1 ]] && return 1
    file --mime "$1" 2>/dev/null | grep -q "charset=binary"
}

matches_pattern() {
    local text=$1
    local pattern=$2

    if [[ $REGEX -eq 1 ]]; then
        if [[ $IGNORE_CASE -eq 1 ]]; then
            echo "$text" | grep -E -i "$pattern" >/dev/null 2>&1
        else
            echo "$text" | grep -E "$pattern" >/dev/null 2>&1
        fi
    else
        if [[ $IGNORE_CASE -eq 1 ]]; then
            echo "$text" | grep -F -i "$pattern" >/dev/null 2>&1
        else
            echo "$text" | grep -F "$pattern" >/dev/null 2>&1
        fi
    fi
}

apply_replacement() {
    local file=$1
    local pattern=$2
    local replacement=$3

    if [[ $BACKUP -eq 1 ]]; then
        cp "$file" "$file.bak"
        echo "  💾 Backed up: $file.bak"
    fi

    if [[ $DIFF -eq 1 ]]; then
        echo "  📋 Diff for $file:"
        if [[ $REGEX -eq 1 ]]; then
            if [[ $IGNORE_CASE -eq 1 ]]; then
                sed -E "s/${pattern}/${replacement}/gi" "$file" | diff -u "$file" - || true
            else
                sed -E "s/${pattern}/${replacement}/g" "$file" | diff -u "$file" - || true
            fi
        else
            local escaped_pattern=$(printf '%s\n' "$pattern" | sed 's/[[\.*^$()+?{|]/\\&/g')
            local escaped_replacement=$(printf '%s\n' "$replacement" | sed 's/[[\.*^$(){}|]/\\&/g')
            if [[ $IGNORE_CASE -eq 1 ]]; then
                sed "s/${escaped_pattern}/${escaped_replacement}/gi" "$file" | diff -u "$file" - || true
            else
                sed "s/${escaped_pattern}/${escaped_replacement}/g" "$file" | diff -u "$file" - || true
            fi
        fi
    fi

    # Apply the replacement
    if [[ $REGEX -eq 1 ]]; then
        if [[ $IGNORE_CASE -eq 1 ]]; then
            sed -E -i "s/${pattern}/${replacement}/gi" "$file"
        else
            sed -E -i "s/${pattern}/${replacement}/g" "$file"
        fi
    else
        local escaped_pattern=$(printf '%s\n' "$pattern" | sed 's/[[\.*^$()+?{|]/\\&/g')
        local escaped_replacement=$(printf '%s\n' "$replacement" | sed 's/[[\.*^$(){}|]/\\&/g')
        if [[ $IGNORE_CASE -eq 1 ]]; then
            sed -i "s/${escaped_pattern}/${escaped_replacement}/gi" "$file"
        else
            sed -i "s/${escaped_pattern}/${escaped_replacement}/g" "$file"
        fi
    fi
}

# --- Setup temporary files for counters ---
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT
MATCHES_FILE="$TEMP_DIR/matches"
MODIFIED_FILE="$TEMP_DIR/modified"
SCANNED_FILE="$TEMP_DIR/scanned"
echo "0" > "$MATCHES_FILE"
echo "0" > "$MODIFIED_FILE"
echo "0" > "$SCANNED_FILE"

# --- Setup output redirection ---
if [[ -n "$OUTPUT_FILE" ]]; then
    exec > >(tee "$OUTPUT_FILE")
fi

# --- Line Viewing Mode ---
if [[ $SHOW_LINE -eq 1 && -n "$LINE_NUMBER" ]]; then
    echo "📍 Showing line $LINE_NUMBER from files containing \"$PATTERN\""
    if [[ $LINE_CONTEXT -gt 0 ]]; then
        echo "📄 Context: ±$LINE_CONTEXT lines"
    fi
    echo ""

    temp_file=$(mktemp)

    # Find files containing pattern
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -type f -print0 2>/dev/null \
      | while IFS= read -r -d '' file; do
          is_binary "$file" && continue
          if grep -l $GREP_OPTS "$PATTERN" "$file" 2>/dev/null; then
              echo "$file" >> "$temp_file"
          fi
        done

    while IFS= read -r file; do
        [[ -z "$file" || ! -f "$file" ]] && continue

        echo "═══ $file ═══"

        if [[ $LINE_CONTEXT -gt 0 ]]; then
            start_line=$((LINE_NUMBER - LINE_CONTEXT))
            [[ $start_line -lt 1 ]] && start_line=1
            end_line=$((LINE_NUMBER + LINE_CONTEXT))
            sed -n "${start_line},${end_line}p" "$file" 2>/dev/null | nl -v $start_line -w 6 -s ": " || echo "  (line out of range)"
        else
            sed -n "${LINE_NUMBER}p" "$file" 2>/dev/null | sed "s/^/[line $LINE_NUMBER] /" || echo "  (line out of range)"
        fi
        echo ""
    done < "$temp_file"

    rm -f "$temp_file"
    exit 0
fi

# --- REPLACE MODE ---
if [[ -n $REPLACE ]]; then
    echo "🔄 Replace mode: \"$PATTERN\" → \"$REPLACE\" in $ROOT"
    if [[ $APPLY -eq 0 ]]; then
        echo "🔍 DRY RUN - Use --apply to actually make changes"
    fi
    echo

    # Handle filename renaming
    if [[ $CONTENT_ONLY -eq 0 ]]; then
        echo "📁 Files to rename:"
        find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
          | while IFS= read -r -d '' f; do
              [[ $DIRS_INCLUDE -eq 0 && -d $f ]] && continue
              filename=$(basename "$f")
              if matches_pattern "$filename" "$PATTERN"; then
                  if [[ $REGEX -eq 1 ]]; then
                      if [[ $IGNORE_CASE -eq 1 ]]; then
                          newname=$(echo "$filename" | sed -E "s/${PATTERN}/${REPLACE}/gi")
                      else
                          newname=$(echo "$filename" | sed -E "s/${PATTERN}/${REPLACE}/g")
                      fi
                  else
                      newname=$(echo "$filename" | sed "s/${PATTERN}/${REPLACE}/g")
                  fi
                  newpath="$(dirname "$f")/$newname"

                  if [[ $APPLY -eq 1 ]]; then
                      mv "$f" "$newpath"
                      echo "  ✅ Renamed: $f → $newpath"
                      increment_counter "$MODIFIED_FILE"
                  else
                      echo "  Would rename: $f → $newpath"
                  fi
                  increment_counter "$MATCHES_FILE"
                  [[ $FIRST -eq 1 ]] && exit 0
              fi
            done
        echo
    fi

    # Handle content replacement
    if [[ $NAME_ONLY -eq 0 ]]; then
        echo "📄 Files with content to modify:"
        find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
          | while IFS= read -r -d '' f; do
              is_binary "$f" && continue
              increment_counter "$SCANNED_FILE"

              # Check if file contains pattern
              if grep -q $GREP_OPTS "$PATTERN" "$f" 2>/dev/null; then
                  increment_counter "$MATCHES_FILE"
                  if [[ $APPLY -eq 1 ]]; then
                      apply_replacement "$f" "$PATTERN" "$REPLACE"
                      echo "  ✅ Modified: $f"
                      increment_counter "$MODIFIED_FILE"
                  else
                      echo "  Would modify: $f"
                      if [[ $DIFF -eq 1 ]]; then
                          apply_replacement "$f" "$PATTERN" "$REPLACE"
                      fi
                  fi
                  [[ $FIRST -eq 1 ]] && exit 0
              fi
            done
    fi

    echo
    echo "📊 Summary:"
    echo "  Files scanned: $(cat "$SCANNED_FILE")"
    echo "  Matches found: $(cat "$MATCHES_FILE")"
    echo "  Files modified: $(cat "$MODIFIED_FILE")"

    if [[ $APPLY -eq 0 ]]; then
        echo
        echo "💡 To apply changes: add --apply"
        echo "💡 To create backups: add --backup"
        echo "💡 To preview diffs: add --diff"
    fi
    exit 0
fi

# --- SEARCH MODE ---
echo "🔍 Searching for: \"$PATTERN\" in $ROOT"
echo

# Search both filenames and contents by default
if [[ $NAME_ONLY -eq 0 && $CONTENT_ONLY -eq 0 ]]; then
    echo "=== 📁 FILENAME MATCHES ==="
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          [[ $DIRS_INCLUDE -eq 0 && -d $f ]] && continue
          filename=$(basename "$f")
          if matches_pattern "$filename" "$PATTERN"; then
              echo "$f"
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done

    echo
    echo "=== 📄 CONTENT MATCHES ==="
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          is_binary "$f" && continue
          increment_counter "$SCANNED_FILE"
          if grep $GREP_OPTS "$PATTERN" "$f" 2>/dev/null; then
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done

# Search filenames only
elif [[ $NAME_ONLY -eq 1 ]]; then
    echo "=== 📁 FILENAME SEARCH ==="
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          [[ $DIRS_INCLUDE -eq 0 && -d $f ]] && continue
          filename=$(basename "$f")
          if matches_pattern "$filename" "$PATTERN"; then
              echo "$f"
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done

# Search content only
else
    echo "=== 📄 CONTENT SEARCH ==="
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          is_binary "$f" && continue
          increment_counter "$SCANNED_FILE"
          if grep $GREP_OPTS "$PATTERN" "$f" 2>/dev/null; then
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done
fi

# --- Editor Integration ---
if [[ $EDITOR_OPEN -eq 1 ]]; then
    echo
    echo "🖱 Opening matches in $DEFAULT_EDITOR..."
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          is_binary "$f" && continue
          if grep -l $GREP_OPTS "$PATTERN" "$f" 2>/dev/null; then
              # Get line numbers and open in editor
              grep -n $GREP_OPTS "$PATTERN" "$f" 2>/dev/null | head -1 | while IFS=: read -r line _; do
                  [[ "$line" =~ ^[0-9]+$ ]] && "$DEFAULT_EDITOR" "$f" -l "$line" &
              done
          fi
        done
fi

# --- Summary ---
if [[ $SUMMARY -eq 1 ]]; then
    echo
    echo "📊 Summary:"
    echo "  Files scanned: $(cat "$SCANNED_FILE")"
    echo "  Matches found: $(cat "$MATCHES_FILE")"
fi
