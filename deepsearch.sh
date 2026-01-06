#!/usr/bin/env bash
# X-Seti - deepsearch v1.3 - Unified search and replace tool
# Searches filenames AND file contents by default, with extensive replace capabilities

set -euo pipefail
VERS="1.3"
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
    COLOR_RESET=''
    COLOR_BOLD=''
    COLOR_DIM=''
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_MAGENTA=''
    COLOR_CYAN=''
    COLOR_WHITE=''
    COLOR_BOLD_CYAN=''
    COLOR_BOLD_YELLOW=''
    COLOR_BOLD_GREEN=''
    COLOR_BOLD_BLUE=''
    COLOR_BOLD_WHITE=''
fi

# --- Configurable ---
DEFAULT_EDITOR="kate"  # Options: kate, kwrite, code, ed, golded

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
  -f, --find              Search filenames or name in file
  -c, --content-only      Search file contents only
  -v, --version           Show script version ($APP_NAME - $VERS)

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
  -C, --context <N>       Show N lines of context around line"

EXAMPLES:
  $0 myfunction                                    # search 'myfunction' in names AND contents
  $0 -n config                                     # search filenames only for 'config'
  $0 -c "debug.*print" -E                          # regex search in file contents only
  $0 -i components.img_debug method.img_debug      # case-insensitive replace (dry-run)
  $0 -r newname oldname --apply --backup           # replace with backups
  $0 foo --exclude '*.log' --context 2             # exclude logs, show context
  $0 -t '*.py,*.js' function_name                  # search in Python/JS files only
  $0 foo -l 100 -c 5                               # search and show line 100 ±5 lines

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
FINDWORD=0

# --- Parse CLI Args ---
search_term=""
search_mode=""
replace_term=""
target_dir="."
ignore_case=false
editor_open=false
output_file=""
include_old=false
apply_changes=false
backup_files=false
show_diff=false
show_line=false
line_number=""
line_context=0

ARGS=()

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ignore-case) IGNORE_CASE=1 ;;
        -E|--regex) REGEX=1 ;;
        -t|--type) TYPES=$2; shift ;;
        -r|--replace) REPLACE=$2; shift ;;
        -f|--find) FINDWORD=1; search_term="$2"; shift ;;
        -n|--name-only) NAME_ONLY=1 ;;
        -c|--content-only) CONTENT_ONLY=1 ;;
        -v|--version) SHOW_VERSION=1 ;;
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
        -l|--line) show_line=true; line_number="$2"; shift ;;
        -C|--context) line_context="$2"; shift ;;
        -o|--output) OUTPUT_FILE=$2; shift ;;
        -e|--editor) EDITOR_OPEN=1 ;;
        -h|--help) usage ;;
        *) ARGS+=("$1") ;;
    esac
    shift
done

# --- Check for version flag FIRST ---
if [[ ${SHOW_VERSION:-0} -eq 1 ]]; then
    echo "$APP_NAME $VERS - $DATE"
    exit 0
fi

# --- GUI fallback if invoked from Dolphin ---
if [[ ${#ARGS[@]} -eq 0 && -n "$target_dir" && "$target_dir" != "." ]]; then
    PATTERN=$(kdialog --inputbox "Enter search term:" "myfile" 2>/dev/null)
    [[ -z "$search_term" ]] && exit 1

    if kdialog --yesno "Do you want to replace the search term?" 2>/dev/null; then
        replace_term=$(kdialog --inputbox "Enter replacement text:" "Replace" 2>/dev/null)
    fi
fi

# --- Ensure search term exists ---
if [[ $FINDWORD -eq 0 && ${#ARGS[@]} -lt 1 ]]; then
    echo "Usage: ds [options] <search_term> [replace_term]"
    echo "Use --help for detailed options"
    exit 1
fi

if [[ $FINDWORD -eq 0 && ${#ARGS[@]} -lt 1 ]]; then
    usage
fi

# --- Build exclude directories ---
exclude_dirs=".git,__pycache__,.vscode,.idea,node_modules"
if ! $include_old; then
    exclude_dirs+=",old"
fi

# --- Build grep flags ---
grep_flags="-rn"
$ignore_case && grep_flags+="i"

# --- Handle Arguments ---
if [[ $FINDWORD -eq 0 && ${#ARGS[@]} -lt 1 ]]; then
    usage
fi

# Set PATTERN based on mode
if [[ $FINDWORD -eq 1 ]]; then
    PATTERN="$search_term"
    ROOT="."
else
    PATTERN=${ARGS[0]}
    ROOT=${ARGS[2]:-.}
fi


# Handle positional replacement (pattern replacement [path])
if [[ ${#ARGS[@]} -ge 2 && -z "$REPLACE" && "${ARGS[1]}" != .* && ! -d "${ARGS[1]}" ]]; then
    REPLACE=${ARGS[1]}
    ROOT=${ARGS[2]:-.}
fi

# --- Add default excludes ---
if [[ $INCLUDE_OLD -eq 0 ]]; then
    EXCLUDES+=("old/*" "*/old/*")
fi

# --- Build find exclude patterns ---
find_excludes=()
if ! $include_old; then
    find_excludes+=(-not -path "*/old/*")
fi

find_excludes+=(-not -path "*/.git/*" -not -path "*/__pycache__/*" -not -path "*/.vscode/*" -not -path "*/.idea/*" -not -path "*/node_modules/*")

# --- Line Viewing Mode ---
if $show_line && [[ -n "$line_number" ]]; then
    echo "📍 Showing line $line_number from files containing \"$search_term\""
    if [[ $line_context -gt 0 ]]; then
        echo " Context: ±$line_context lines"
    fi
    echo ""

    temp_file=$(mktemp)
    if $include_old; then
        grep $grep_flags --exclude-dir={.git,__pycache__,.vscode,.idea,node_modules} "$search_term" "$target_dir" 2>/dev/null | cut -d: -f1 | sort -u > "$temp_file"
    else
        grep $grep_flags --exclude-dir={.git,__pycache__,.vscode,.idea,node_modules} "$search_term" "$target_dir" 2>/dev/null | grep -v "/old/" | cut -d: -f1 | sort -u > "$temp_file"
    fi

    while IFS= read -r file; do
        [[ -z "$file" || ! -f "$file" ]] && continue

        echo "═══ $file ═══"

        if [[ $line_context -gt 0 ]]; then
            start_line=$((line_number - line_context))
            [[ $start_line -lt 1 ]] && start_line=1
            end_line=$((line_number + line_context))
            sed -n "${start_line},${end_line}p" "$file" 2>/dev/null | nl -v $start_line -w 6 -s ": " || echo "  (line out of range)"
        else
            sed -n "${line_number}p" "$file" 2>/dev/null | sed "s/^/[line $line_number] /" || echo "  (line out of range)"
        fi
        echo ""
    done < "$temp_file"

    rm -f "$temp_file"
    exit 0
fi

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

# --- Build grep options ---
GREP_OPTS="-H -n --color=always"
[[ $IGNORE_CASE -eq 1 ]] && GREP_OPTS="$GREP_OPTS -i"
[[ $REGEX -eq 0 ]] && GREP_OPTS="$GREP_OPTS -F"
[[ $CONTEXT -gt 0 ]] && GREP_OPTS="$GREP_OPTS -C $CONTEXT"
[[ $COUNT -eq 1 ]] && GREP_OPTS="$GREP_OPTS -c"

# --- Build find expression ---
FIND_EXPR=(-type f)
if [[ -n $TYPES ]]; then
    IFS=',' read -ra exts <<< "$TYPES"
    FIND_EXPR=()
    for ext in "${exts[@]}"; do
        FIND_EXPR+=(-name "$ext" -o)
    done
    unset 'FIND_EXPR[${#FIND_EXPR[@]}-1]'
fi

for excl in "${EXCLUDES[@]}"; do
    FIND_EXPR+=(-not -path "*$excl")
done

# Filename search
search_names() {
  find . -type f \
    "${FIND_EXCLUDES[@]}" \
    $( [[ $IGNORE_CASE -eq 1 ]] && echo "-iname" || echo "-name" ) \
    "*$search_term*"
}

# Content search
search_contents() {
  GREP_OPTS=(-R -n)
  [[ $IGNORE_CASE -eq 1 ]] && GREP_OPTS+=(-i)
  [[ $REGEX -eq 0 ]] && GREP_OPTS+=(-F)
  [[ $ALLOW_BINARY -eq 0 ]] && GREP_OPTS+=(--binary-files=without-match)
  [[ $COUNT -eq 1 ]] && GREP_OPTS+=(-c)
  [[ $FIRST -eq 1 ]] && GREP_OPTS+=(-m 1)

  for ex in "${EXCLUDES[@]}"; do
    GREP_OPTS+=(--exclude-dir="$ex")
  done

  grep "${GREP_OPTS[@]}" "$search_term" .
}


# --- Helper Functions ---
increment_counter() {
    local file=$1
    echo $(($(cat "$file") + 1)) > "$file"
}


is_binary() {
    local file=$1
    [[ $ALLOW_BINARY -eq 0 ]] && file -b --mime "$file" 2>/dev/null | grep -q binary
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


find_word() {
if [[ $FINDWORD -eq 1 && -z "$REPLACE" ]]; then

    FOUND=0

    # Filename search
    if [[ $CONTENT_ONLY -eq 0 ]]; then
        while IFS= read -r f; do
            echo "$f"
            increment_counter "$MATCHES_FILE"
            FOUND=1
            [[ $FIRST -eq 1 ]] && exit 0
        done < <(search_names)
    fi

    # Content search
    if [[ $NAME_ONLY -eq 0 ]]; then
        find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null |
        while IFS= read -r -d '' f; do
            is_binary "$f" && continue

            if matches_pattern "$f" "$PATTERN"; then
                echo "$f"
                increment_counter "$MATCHES_FILE"
                FOUND=1
                [[ $FIRST -eq 1 ]] && exit 0
            fi
        done
    fi

    if [[ $FOUND -eq 0 ]]; then
        echo "search term \"$PATTERN\" not found"
        exit 1
    fi

    exit 0
fi
}



apply_replacement() {
    local file=$1
    local pattern=$2
    local replacement=$3
    
    if [[ $BACKUP -eq 1 ]]; then
        cp "$file" "$file.bak"
        echo "  Backed up: $file.bak"
    fi
    
    if [[ $DIFF -eq 1 ]]; then
        echo "  Diff for $file:"
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

# --- REPLACE MODE ---
if [[ -n $REPLACE ]]; then
    echo "Replace mode: \"$PATTERN\" → \"$REPLACE\" in $ROOT"
    if [[ $APPLY -eq 0 ]]; then
        echo "🔍 DRY RUN - Use --apply to actually make changes"
    fi
    echo

    # Handle filename renaming
    if [[ $CONTENT_ONLY -eq 0 ]]; then
        echo "Files to rename:"
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


    # Default behavior
    if [[ $NAME_ONLY -eq 0 && $CONTENT_ONLY -eq 0 ]]; then
    NAME_ONLY=1
    CONTENT_ONLY=1
    fi


    if [[ $MATCHES_FILE -eq 1 ]]; then
        echo "search term \"$PATTERN\" not found"
        exit 1
    fi

    # Handle content replacement
    if [[ $NAME_ONLY -eq 0 ]]; then
        echo "Files with content to modify:"
        find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
          | while IFS= read -r -d '' f; do
              is_binary "$f" && continue
              increment_counter "$SCANNED_FILE"
              
              # Check if file contains pattern
              if [[ $REGEX -eq 1 ]]; then
                  if [[ $IGNORE_CASE -eq 1 ]]; then
                      grep_check="grep -E -i"
                  else
                      grep_check="grep -E"
                  fi
              else
                  if [[ $IGNORE_CASE -eq 1 ]]; then
                      grep_check="grep -F -i"
                  else
                      grep_check="grep -F"
                  fi
              fi
              
              if $grep_check -q "$PATTERN" "$f" 2>/dev/null; then
                  increment_counter "$MATCHES_FILE"
                  if [[ $APPLY -eq 1 ]]; then
                      apply_replacement "$f" "$PATTERN" "$REPLACE"
                      echo "  Modified: $f"
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
    echo "Summary:"
    echo "  Files scanned: $(cat "$SCANNED_FILE")"
    echo "  Matches found: $(cat "$MATCHES_FILE")"
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

if [[ $CONTENT_ONLY -eq 1 ]]; then
  RESULTS+=$(search_contents)$'\n'
fi


# Search both filenames and contents by default
if [[ $NAME_ONLY -eq 0 && $CONTENT_ONLY -eq 0 ]]; then
    echo -e "${COLOR_BOLD_GREEN}=== FILENAME MATCHES ===${COLOR_RESET}"
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          [[ $DIRS_INCLUDE -eq 0 && -d $f ]] && continue
          filename=$(basename "$f")
          if matches_pattern "$filename" "$PATTERN"; then
              echo -e "  ${COLOR_YELLOW} ${COLOR_RESET} ${COLOR_CYAN}$f${COLOR_RESET}"
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done
    
    echo
    echo -e "${COLOR_BOLD_GREEN}=== CONTENT MATCHES ===${COLOR_RESET}"
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          is_binary "$f" && continue
          increment_counter "$SCANNED_FILE"
          
          # Build clean grep command without color codes for parsing
          clean_grep_opts="-H -n"
          [[ $IGNORE_CASE -eq 1 ]] && clean_grep_opts="$clean_grep_opts -i"
          [[ $REGEX -eq 0 ]] && clean_grep_opts="$clean_grep_opts -F"
          [[ $CONTEXT -gt 0 ]] && clean_grep_opts="$clean_grep_opts -C $CONTEXT"
          
          # Get matches for this file
          if grep $clean_grep_opts "$PATTERN" "$f" 2>/dev/null | head -1 | grep -q .; then
              # Print file header
              echo
              echo -e "${COLOR_BOLD_CYAN}┌─${COLOR_RESET} ${COLOR_BOLD_YELLOW}$f${COLOR_RESET}"
              
              # Print matches with line numbers
              grep $clean_grep_opts "$PATTERN" "$f" 2>/dev/null | while IFS=: read -r filepath line content; do
                  printf "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_MAGENTA}%6s${COLOR_RESET} ${COLOR_DIM}│${COLOR_RESET} %s\n" "L$line" "$content"
              done
              echo -e "${COLOR_CYAN}└─${COLOR_RESET}"
              
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done

# Search filenames only
elif [[ $NAME_ONLY -eq 1 ]]; then
    echo -e "${COLOR_BOLD_GREEN}=== FILENAME SEARCH ===${COLOR_RESET}"
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          [[ $DIRS_INCLUDE -eq 0 && -d $f ]] && continue
          filename=$(basename "$f")
          if matches_pattern "$filename" "$PATTERN"; then
              echo -e "  ${COLOR_YELLOW} ${COLOR_RESET} ${COLOR_CYAN}$f${COLOR_RESET}"
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done

# Search content only
else
    echo -e "${COLOR_BOLD_GREEN}=== CONTENT SEARCH ===${COLOR_RESET}"
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          is_binary "$f" && continue
          increment_counter "$SCANNED_FILE"
          
          # Build clean grep command without color codes for parsing
          clean_grep_opts="-H -n"
          [[ $IGNORE_CASE -eq 1 ]] && clean_grep_opts="$clean_grep_opts -i"
          [[ $REGEX -eq 0 ]] && clean_grep_opts="$clean_grep_opts -F"
          [[ $CONTEXT -gt 0 ]] && clean_grep_opts="$clean_grep_opts -C $CONTEXT"
          
          # Get matches for this file
          if grep $clean_grep_opts "$PATTERN" "$f" 2>/dev/null | head -1 | grep -q .; then
              # Print file header
              echo
              echo -e "${COLOR_BOLD_CYAN}┌─${COLOR_RESET} ${COLOR_BOLD_YELLOW}$f${COLOR_RESET}"
              
              # Print matches with line numbers
              grep $clean_grep_opts "$PATTERN" "$f" 2>/dev/null | while IFS=: read -r filepath line content; do
                  printf "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_MAGENTA}%6s${COLOR_RESET} ${COLOR_DIM}│${COLOR_RESET} %s\n" "L$line" "$content"
              done
              echo -e "${COLOR_CYAN}└─${COLOR_RESET}"
              
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done
fi

# --- Editor Integration ---
if [[ $EDITOR_OPEN -eq 1 ]]; then
    echo
    echo "Opening matches in $DEFAULT_EDITOR..."
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          is_binary "$f" && continue
          if grep -l $([[ $IGNORE_CASE -eq 1 ]] && echo "-i") $([[ $REGEX -eq 0 ]] && echo "-F") "$PATTERN" "$f" 2>/dev/null; then
              # Get line numbers and open in editor
              grep -n $([[ $IGNORE_CASE -eq 1 ]] && echo "-i") $([[ $REGEX -eq 0 ]] && echo "-F") "$PATTERN" "$f" 2>/dev/null | head -1 | while IFS=: read -r line _; do
                  [[ "$line" =~ ^[0-9]+$ ]] && "$DEFAULT_EDITOR" "$f" -l "$line" &
              done
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
