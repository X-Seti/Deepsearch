#!/usr/bin/env bash
# X-Seti - deepsearch v1.4 - Unified search and replace tool
# Searches filenames AND file contents by default, with extensive replace capabilities

set -euo pipefail
VERS="1.4"
APP_NAME="Deepsearch"
DATE="January 2026"

# --- Color Definitions ---
if [[ -t 1 ]]; then
    COLOR_RESET='\033[0m'
    COLOR_BOLD='\033[1m'
    COLOR_DIM='\033[2m'
    COLOR_RED='\033[0;31m'
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_BLUE='\033[0;34m'
    COLOR_MAGENTA='\033[0;35m'
    COLOR_CYAN='\033[0;36m'
    COLOR_WHITE='\033[0;37m'
    COLOR_BOLD_CYAN='\033[1;36m'
    COLOR_BOLD_YELLOW='\033[1;33m'
    COLOR_BOLD_GREEN='\033[1;32m'
    COLOR_BOLD_BLUE='\033[1;34m'
    COLOR_BOLD_WHITE='\033[1;37m'
else
    COLOR_RESET='' COLOR_BOLD='' COLOR_DIM='' COLOR_RED=''
    COLOR_GREEN='' COLOR_YELLOW='' COLOR_BLUE='' COLOR_MAGENTA=''
    COLOR_CYAN='' COLOR_WHITE='' COLOR_BOLD_CYAN='' COLOR_BOLD_YELLOW=''
    COLOR_BOLD_GREEN='' COLOR_BOLD_BLUE='' COLOR_BOLD_WHITE=''
fi

# --- Configurable ---
DEFAULT_EDITOR="kate"

usage() {
    cat <<EOF
Usage: $0 [options] <pattern> [replacement] [path]

SEARCH MODES:
  Default behavior searches BOTH filenames and file contents

OPTIONS:
  -i, --ignore-case       Case-insensitive search
  -E, --regex             Treat pattern as regex (default: literal string)
  -t, --type <glob>       Limit to file types (e.g. '*.c,*.h,*.py')
  -n, --name-only         Search filenames only
  -f, --find              Search filenames or name in file
  -c, --content-only      Search file contents only
  -v, --version           Show script version ($APP_NAME - $VERS)

REPLACE OPTIONS:
  -r, --replace <string>  Replace pattern with string
  --apply                 Actually perform changes (default: dry-run)
  --backup                Create .bak backups before replacing
  --diff                  Show diff preview of changes

FILTERING:
  --exclude <glob>        Exclude files/dirs matching glob (repeatable)
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
  -C, --context <N>       Show N lines of context around line

EXAMPLES:
  $0 myfunction                        # search names AND contents
  $0 -n config                         # filenames only
  $0 -c "debug.*print" -E              # regex in contents only
  $0 oldname newname --apply --backup  # replace with backups
  $0 foo --exclude '*.log' --context 2
  $0 -t '*.py,*.js' function_name
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
FINDWORD=0
show_line=false
line_number=""
line_context=0
SHOW_VERSION=0

ARGS=()

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ignore-case)  IGNORE_CASE=1 ;;
        -E|--regex)        REGEX=1 ;;
        -t|--type)         TYPES=$2; shift ;;
        -r|--replace)      REPLACE=$2; shift ;;
        -f|--find)         FINDWORD=1; ARGS+=("$2"); shift ;;
        -n|--name-only)    NAME_ONLY=1 ;;
        -c|--content-only) CONTENT_ONLY=1 ;;
        -v|--version)      SHOW_VERSION=1 ;;
        --dirs)            DIRS_INCLUDE=1 ;;
        --include-old)     INCLUDE_OLD=1 ;;
        --exclude)         EXCLUDES+=("$2"); shift ;;
        --apply)           APPLY=1 ;;
        --backup)          BACKUP=1 ;;
        --diff)            DIFF=1 ;;
        --context)         CONTEXT=$2; shift ;;
        --count)           COUNT=1 ;;
        --summary)         SUMMARY=1 ;;
        --first)           FIRST=1 ;;
        --binary)          ALLOW_BINARY=1 ;;
        -l|--line)         show_line=true; line_number="$2"; shift ;;
        -C)                line_context="$2"; shift ;;
        -o|--output)       OUTPUT_FILE=$2; shift ;;
        -e|--editor)       EDITOR_OPEN=1 ;;
        -h|--help)         usage ;;
        *)                 ARGS+=("$1") ;;
    esac
    shift
done

# --- Version ---
if [[ $SHOW_VERSION -eq 1 ]]; then
    echo "$APP_NAME $VERS - $DATE"
    exit 0
fi

# --- Ensure search term ---
if [[ ${#ARGS[@]} -lt 1 ]]; then
    echo "Usage: ds [options] <search_term> [replace_term] [path]"
    echo "Use --help for detailed options"
    exit 1
fi

# --- Set PATTERN, REPLACE, ROOT from positional args ---
PATTERN="${ARGS[0]}"

# ARGS[1] is replacement if it doesn't look like a path and -r wasn't set
if [[ ${#ARGS[@]} -ge 2 && -z "$REPLACE" && "${ARGS[1]}" != ./* && ! -d "${ARGS[1]}" ]]; then
    REPLACE="${ARGS[1]}"
    ROOT="${ARGS[2]:-.}"
else
    ROOT="${ARGS[1]:-.}"
fi

# --- Add default excludes ---
if [[ $INCLUDE_OLD -eq 0 ]]; then
    EXCLUDES+=("old/*" "*/old/*")
fi

# --- Build find exclude expression ---
FIND_EXPR=(-type f)
if [[ -n $TYPES ]]; then
    IFS=',' read -ra exts <<< "$TYPES"
    type_expr=()
    for ext in "${exts[@]}"; do
        type_expr+=(-name "$ext" -o)
    done
    unset 'type_expr[${#type_expr[@]}-1]'
    FIND_EXPR=(\( "${type_expr[@]}" \) -type f)
fi

for excl in "${EXCLUDES[@]}"; do
    FIND_EXPR+=(-not -path "*$excl")
done

# --- Helper Functions ---
increment_counter() {
    local file=$1
    local n
    n=$(cat "$file")
    echo $((n + 1)) > "$file"
}

is_binary() {
    local file=$1
    [[ $ALLOW_BINARY -eq 0 ]] && file -b --mime "$file" 2>/dev/null | grep -q binary
}

matches_pattern() {
    local text=$1 pattern=$2
    if [[ $REGEX -eq 1 ]]; then
        [[ $IGNORE_CASE -eq 1 ]] \
            && echo "$text" | grep -E -i "$pattern" >/dev/null 2>&1 \
            || echo "$text" | grep -E    "$pattern" >/dev/null 2>&1
    else
        [[ $IGNORE_CASE -eq 1 ]] \
            && echo "$text" | grep -F -i "$pattern" >/dev/null 2>&1 \
            || echo "$text" | grep -F    "$pattern" >/dev/null 2>&1
    fi
}

apply_replacement() {
    local file=$1 pattern=$2 replacement=$3

    if [[ $BACKUP -eq 1 ]]; then
        cp "$file" "$file.bak"
        echo "  Backed up: $file.bak"
    fi

    if [[ $DIFF -eq 1 ]]; then
        echo "  Diff for $file:"
        if [[ $REGEX -eq 1 ]]; then
            [[ $IGNORE_CASE -eq 1 ]] \
                && sed -E "s/${pattern}/${replacement}/gi" "$file" | diff -u "$file" - || true \
                || sed -E "s/${pattern}/${replacement}/g"  "$file" | diff -u "$file" - || true
        else
            local ep er
            ep=$(printf '%s\n' "$pattern"     | sed 's/[[\.*^$()+?{|]/\\&/g')
            er=$(printf '%s\n' "$replacement" | sed 's/[[\.*^$(){}|]/\\&/g')
            [[ $IGNORE_CASE -eq 1 ]] \
                && sed "s/${ep}/${er}/gi" "$file" | diff -u "$file" - || true \
                || sed "s/${ep}/${er}/g"  "$file" | diff -u "$file" - || true
        fi
    fi

    # Apply
    if [[ $REGEX -eq 1 ]]; then
        [[ $IGNORE_CASE -eq 1 ]] \
            && sed -E -i "s/${pattern}/${replacement}/gi" "$file" \
            || sed -E -i "s/${pattern}/${replacement}/g"  "$file"
    else
        local ep er
        ep=$(printf '%s\n' "$pattern"     | sed 's/[[\.*^$()+?{|]/\\&/g')
        er=$(printf '%s\n' "$replacement" | sed 's/[[\.*^$(){}|]/\\&/g')
        [[ $IGNORE_CASE -eq 1 ]] \
            && sed -i "s/${ep}/${er}/gi" "$file" \
            || sed -i "s/${ep}/${er}/g"  "$file"
    fi
}

# --- Setup temp counters (AFTER functions defined) ---
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
MATCHES_FILE="$TEMP_DIR/matches"
MODIFIED_FILE="$TEMP_DIR/modified"
SCANNED_FILE="$TEMP_DIR/scanned"
echo "0" > "$MATCHES_FILE"
echo "0" > "$MODIFIED_FILE"
echo "0" > "$SCANNED_FILE"

# --- Output redirection ---
[[ -n "$OUTPUT_FILE" ]] && exec > >(tee "$OUTPUT_FILE")

# --- Line Viewing Mode ---
if $show_line && [[ -n "$line_number" ]]; then
    echo "Showing line $line_number from files containing \"$PATTERN\""
    [[ $line_context -gt 0 ]] && echo " Context: ±${line_context} lines"
    echo ""

    tmp_files=$(mktemp)
    grep -rn \
        $([[ $IGNORE_CASE -eq 1 ]] && echo "-i") \
        $([[ $REGEX -eq 0 ]] && echo "-F") \
        --exclude-dir={.git,__pycache__,.vscode,.idea,node_modules} \
        "$PATTERN" "$ROOT" 2>/dev/null \
        | grep -v "/old/" \
        | cut -d: -f1 | sort -u > "$tmp_files"

    while IFS= read -r file; do
        [[ -z "$file" || ! -f "$file" ]] && continue
        echo "═══ $file ═══"
        if [[ $line_context -gt 0 ]]; then
            start_line=$((line_number - line_context))
            [[ $start_line -lt 1 ]] && start_line=1
            end_line=$((line_number + line_context))
            sed -n "${start_line},${end_line}p" "$file" 2>/dev/null \
                | nl -v "$start_line" -w 6 -s ": " || echo "  (line out of range)"
        else
            sed -n "${line_number}p" "$file" 2>/dev/null \
                | sed "s/^/[line $line_number] /" || echo "  (line out of range)"
        fi
        echo ""
    done < "$tmp_files"
    rm -f "$tmp_files"
    exit 0
fi

# --- Build grep options string ---
GREP_OPTS="-H -n --color=always"
[[ $IGNORE_CASE -eq 1 ]] && GREP_OPTS="$GREP_OPTS -i"
[[ $REGEX -eq 0 ]]       && GREP_OPTS="$GREP_OPTS -F"
[[ $CONTEXT -gt 0 ]]     && GREP_OPTS="$GREP_OPTS -C $CONTEXT"
[[ $COUNT -eq 1 ]]       && GREP_OPTS="$GREP_OPTS -c"

# --- REPLACE MODE ---
if [[ -n $REPLACE ]]; then
    echo "Replace mode: \"$PATTERN\" → \"$REPLACE\" in $ROOT"
    if [[ $APPLY -eq 0 ]]; then
        echo "DRY RUN - Use --apply to actually make changes"
    fi
    echo

    # Filename renaming
    if [[ $CONTENT_ONLY -eq 0 ]]; then
        echo "Files to rename:"
        find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
          | while IFS= read -r -d '' f; do
              [[ $DIRS_INCLUDE -eq 0 && -d "$f" ]] && continue
              filename=$(basename "$f")
              if matches_pattern "$filename" "$PATTERN"; then
                  if [[ $REGEX -eq 1 ]]; then
                      [[ $IGNORE_CASE -eq 1 ]] \
                          && newname=$(echo "$filename" | sed -E "s/${PATTERN}/${REPLACE}/gi") \
                          || newname=$(echo "$filename" | sed -E "s/${PATTERN}/${REPLACE}/g")
                  else
                      newname=$(echo "$filename" | sed "s/${PATTERN}/${REPLACE}/g")
                  fi
                  newpath="$(dirname "$f")/$newname"
                  if [[ $APPLY -eq 1 ]]; then
                      mv "$f" "$newpath"
                      echo "  Renamed: $f → $newpath"
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

    # Content replacement
    if [[ $NAME_ONLY -eq 0 ]]; then
        echo "Files with content to modify:"
        find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
          | while IFS= read -r -d '' f; do
              is_binary "$f" && continue
              increment_counter "$SCANNED_FILE"

              if [[ $REGEX -eq 1 ]]; then
                  [[ $IGNORE_CASE -eq 1 ]] && grep_check="grep -E -i" || grep_check="grep -E"
              else
                  [[ $IGNORE_CASE -eq 1 ]] && grep_check="grep -F -i" || grep_check="grep -F"
              fi

              if $grep_check -q "$PATTERN" "$f" 2>/dev/null; then
                  increment_counter "$MATCHES_FILE"
                  if [[ $APPLY -eq 1 ]]; then
                      apply_replacement "$f" "$PATTERN" "$REPLACE"
                      echo "  Modified: $f"
                      increment_counter "$MODIFIED_FILE"
                  else
                      echo "  Would modify: $f"
                      [[ $DIFF -eq 1 ]] && apply_replacement "$f" "$PATTERN" "$REPLACE"
                  fi
                  [[ $FIRST -eq 1 ]] && exit 0
              fi
            done
    fi

    echo
    echo "Summary:"
    echo "  Files scanned:  $(cat "$SCANNED_FILE")"
    echo "  Matches found:  $(cat "$MATCHES_FILE")"
    echo "  Files modified: $(cat "$MODIFIED_FILE")"
    if [[ $APPLY -eq 0 ]]; then
        echo
        echo "To apply changes: add --apply"
        echo "To create backups: add --backup"
        echo "To preview diffs: add --diff"
    fi
    exit 0
fi

# --- SEARCH MODE ---
echo -e "${COLOR_BOLD_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
echo -e "${COLOR_BOLD_CYAN}Searching for:${COLOR_RESET} ${COLOR_BOLD_YELLOW}\"$PATTERN\"${COLOR_RESET}"
echo -e "${COLOR_BOLD_CYAN}Location:${COLOR_RESET} ${COLOR_BLUE}$ROOT${COLOR_RESET}"
echo -e "${COLOR_BOLD_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
echo

print_content_matches() {
    local root=$1
    find "$root" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          is_binary "$f" && continue
          increment_counter "$SCANNED_FILE"

          clean_grep_opts="-H -n"
          [[ $IGNORE_CASE -eq 1 ]] && clean_grep_opts="$clean_grep_opts -i"
          [[ $REGEX -eq 0 ]]       && clean_grep_opts="$clean_grep_opts -F"
          [[ $CONTEXT -gt 0 ]]     && clean_grep_opts="$clean_grep_opts -C $CONTEXT"

          if grep $clean_grep_opts "$PATTERN" "$f" 2>/dev/null | head -1 | grep -q .; then
              echo
              echo -e "${COLOR_BOLD_CYAN}┌─${COLOR_RESET} ${COLOR_BOLD_YELLOW}$f${COLOR_RESET}"
              grep $clean_grep_opts "$PATTERN" "$f" 2>/dev/null \
                | while IFS=: read -r _fp line content; do
                    printf "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_MAGENTA}%6s${COLOR_RESET} ${COLOR_DIM}│${COLOR_RESET} %s\n" "L$line" "$content"
                  done
              echo -e "${COLOR_CYAN}└─${COLOR_RESET}"
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done
}

print_name_matches() {
    local root=$1
    find "$root" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          [[ $DIRS_INCLUDE -eq 0 && -d "$f" ]] && continue
          filename=$(basename "$f")
          if matches_pattern "$filename" "$PATTERN"; then
              echo -e "  ${COLOR_YELLOW}*${COLOR_RESET} ${COLOR_CYAN}$f${COLOR_RESET}"
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done
}

# Search both (default)
if [[ $NAME_ONLY -eq 0 && $CONTENT_ONLY -eq 0 ]]; then
    echo -e "${COLOR_BOLD_GREEN}=== FILENAME MATCHES ===${COLOR_RESET}"
    print_name_matches "$ROOT"
    echo
    echo -e "${COLOR_BOLD_GREEN}=== CONTENT MATCHES ===${COLOR_RESET}"
    print_content_matches "$ROOT"

# Filenames only
elif [[ $NAME_ONLY -eq 1 ]]; then
    echo -e "${COLOR_BOLD_GREEN}=== FILENAME SEARCH ===${COLOR_RESET}"
    print_name_matches "$ROOT"

# Contents only
else
    echo -e "${COLOR_BOLD_GREEN}=== CONTENT SEARCH ===${COLOR_RESET}"
    print_content_matches "$ROOT"
fi

# --- Editor Integration ---
if [[ $EDITOR_OPEN -eq 1 ]]; then
    echo
    echo "Opening matches in $DEFAULT_EDITOR..."
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          is_binary "$f" && continue
          ignore_flag=$([[ $IGNORE_CASE -eq 1 ]] && echo "-i" || echo "")
          fixed_flag=$([[ $REGEX -eq 0 ]] && echo "-F" || echo "")
          if grep -l $ignore_flag $fixed_flag "$PATTERN" "$f" 2>/dev/null; then
              first_line=$(grep -n $ignore_flag $fixed_flag "$PATTERN" "$f" 2>/dev/null \
                  | head -1 | cut -d: -f1)
              [[ "$first_line" =~ ^[0-9]+$ ]] && "$DEFAULT_EDITOR" "$f" -l "$first_line" &
          fi
        done
fi

# --- Summary ---
echo
echo -e "${COLOR_BOLD_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}Summary:${COLOR_RESET}"
echo -e "   ${COLOR_CYAN}Files scanned:${COLOR_RESET} ${COLOR_BOLD_WHITE}$(cat "$SCANNED_FILE")${COLOR_RESET}"
echo -e "   ${COLOR_CYAN}Matches found:${COLOR_RESET} ${COLOR_BOLD_YELLOW}$(cat "$MATCHES_FILE")${COLOR_RESET}"
echo -e "${COLOR_BOLD_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
