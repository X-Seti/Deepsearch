#!/usr/bin/env bash
# X-Seti - deepsearch v1.5 - Unified search, replace, and color analysis tool
# Searches filenames AND file contents by default, with extensive replace capabilities
#
# Sun, May 26 - Added name search, comment line out function.

set -euo pipefail
VERS="1.5"
APP_NAME="Deepsearch"
DATE="April 2026"

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
COMMENT_PREFIX="#"

usage() {
    cat <<EOF
Usage: $0 [options] <pattern> [replacement] [path]

SEARCH MODES:
  Default behavior searches BOTH filenames and file contents

OPTIONS:
  -i, --ignore-case       Case-insensitive search
  -E, --regex             Treat pattern as regex (default: literal string)
  -t, --type <glob>       Limit to file types (e.g. '*.py,*.json')
  -n, --name-only         Search filenames only
  -f, --find              Find files by name
  -c, --content-only      Search file contents only
  -v, --version           Show version

REPLACE OPTIONS:
  -r, --replace <string>  Replace pattern with string
  --apply                 Apply changes (default: dry-run)
  --backup                Create .bak backups before replacing
  --diff                  Show unified diff preview

COLOR / THEME OPTIONS:
  -k, --colors <hex>             Find all uses of a hex color (e.g. '#2a2a2a')
  -k, --colors <hex> <new_hex>   Replace a color value (dry-run by default)
      --apply                    Apply color replacement
      --theme <key>              Show value of a theme key across all JSON files
      --kde                      Compare KDE color roles with theme keys
      --unique                   Show unique hex color values found in matches

FILTERING:
  --exclude <glob>        Exclude files/dirs (repeatable)
  --include-old           Include old/ folders (excluded by default)
  --binary                Allow binary files (skipped by default)
  --dirs                  Include directories in filename search

OUTPUT:
  --context N             Show N lines of context around matches
  --count                 Print match counts per file only
  --first                 Stop after first match
  --comment <string>      Comment out matching lines with ($COMMENT_PREFIX)
  -o, --output <file>     Save results to file
  -e, --editor            Open matches in editor ($DEFAULT_EDITOR)
  -l, --line <N>          Show line N from matched files
  -C <N>                  Lines of context around --line
  -h, --help              Show this help


EXAMPLES:
  $0 myfunction                             # search names AND contents
  $0 oldname newname --apply --backup       # replace with backups
  $0 -k '#2a2a2a'                           # find all uses of a color
  $0 -k '#2a2a2a' '#1e1e2e' --apply        # replace a color everywhere
  $0 --theme bg_primary                     # show key across all themes
  $0 --kde                                  # compare KDE palette to themes
  $0 --unique -c '#' -t '*.py'             # list all hex colors in Python files
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
FIRST=0
ALLOW_BINARY=0
OUTPUT_FILE=""
EDITOR_OPEN=0
show_line=false
line_number=""
line_context=0
SHOW_VERSION=0
COLOR_MODE=0
COLOR_HEX=""
COLOR_NEW=""
THEME_KEY=""
KDE_MODE=0
UNIQUE_MODE=0
COMMENT_MODE=0


ARGS=()

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ignore-case)  IGNORE_CASE=1 ;;
        -E|--regex)        REGEX=1 ;;
        -t|--type)         TYPES=$2; shift ;;
        -r|--replace)      REPLACE=$2; shift ;;
        --comment)         COMMENT_MODE=1; PATTERN="$2"; shift ;;
        -f|--find)         ARGS+=("$2"); shift ;;
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
        --first)           FIRST=1 ;;
        --binary)          ALLOW_BINARY=1 ;;
        -l|--line)         show_line=true; line_number="$2"; shift ;;
        -C)                line_context="$2"; shift ;;
        -o|--output)       OUTPUT_FILE=$2; shift ;;
        -e|--editor)       EDITOR_OPEN=1 ;;
        -k|--colors)       COLOR_MODE=1; COLOR_HEX="$2"; shift
                           [[ $# -gt 0 && "${2:-}" == "#"* ]] && { COLOR_NEW="$2"; shift; } ;;
        --theme)           THEME_KEY="$2"; shift ;;
        --kde)             KDE_MODE=1 ;;
        --unique)          UNIQUE_MODE=1 ;;
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

# --- Helper Functions ---
increment_counter() {
    local file=$1
    local n; n=$(cat "$file")
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
    [[ $BACKUP -eq 1 ]] && cp "$file" "$file.bak" && echo "  Backed up: $file.bak"
    if [[ $DIFF -eq 1 ]]; then
        echo "  Diff for $file:"
        sed "s|${pattern}|${replacement}|g" "$file" | diff -u "$file" - || true
    fi
    sed -i "s|${pattern}|${replacement}|g" "$file"
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

# --- Add default excludes ---
[[ $INCLUDE_OLD -eq 0 ]] && EXCLUDES+=("old/*" "*/old/*")

# --- Build find expression ---
FIND_EXPR=(-type f)
if [[ -n $TYPES ]]; then
    IFS=',' read -ra exts <<< "$TYPES"
    type_expr=()
    for ext in "${exts[@]}"; do type_expr+=(-name "$ext" -o); done
    unset 'type_expr[${#type_expr[@]}-1]'
    FIND_EXPR=(\( "${type_expr[@]}" \) -type f)
fi
for excl in "${EXCLUDES[@]}"; do
    FIND_EXPR+=(-not -path "*$excl")
done


# THEME KEY MODE  --theme <key>
# Show the value of a theme key across all JSON theme files

if [[ -n "$THEME_KEY" ]]; then
    ROOT="${ARGS[0]:-.}"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo -e "${COLOR_BOLD_CYAN}Theme key:${COLOR_RESET} ${COLOR_BOLD_YELLOW}\"$THEME_KEY\"${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo

    found=0
    while IFS= read -r -d '' f; do
        # Extract value for key from JSON
        val=$(python3 -c "
import json, sys
try:
    d = json.load(open('$f'))
    c = d.get('colors', d)
    v = c.get('$THEME_KEY')
    if v: print(v)
except: pass
" 2>/dev/null)
        if [[ -n "$val" ]]; then
            # Show a color swatch if it looks like a hex color
            swatch=""
            if [[ "$val" =~ ^#[0-9a-fA-F]{6}$ ]]; then
                r=$((16#${val:1:2}))
                g=$((16#${val:3:2}))
                b=$((16#${val:5:2}))
                swatch="\033[48;2;${r};${g};${b}m   \033[0m"
            fi
            name=$(basename "$f" .json)
            printf "${COLOR_CYAN}%-40s${COLOR_RESET} ${COLOR_BOLD_YELLOW}%-20s${COLOR_RESET} %b\n" \
                "$name" "$val" "$swatch"
            ((found++)) || true
            increment_counter "$MATCHES_FILE"
        fi
    done < <(find "$ROOT" -name "*.json" -not -path "*/.git/*" -not -path "*/__pycache__/*" -print0 2>/dev/null)

    echo
    [[ $found -eq 0 ]] && echo "Key '$THEME_KEY' not found in any theme file."
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo -e "   ${COLOR_CYAN}Themes with key:${COLOR_RESET} ${COLOR_BOLD_WHITE}$(cat "$MATCHES_FILE")${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    exit 0
fi


# KDE COLOR MODE  --kde
# Compare KDE color roles with theme JSON keys

if [[ $KDE_MODE -eq 1 ]]; then
    ROOT="${ARGS[0]:-.}"
    kdeglobals="${HOME}/.config/kdeglobals"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo -e "${COLOR_BOLD_CYAN}KDE Color Roles vs Theme Keys${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo

    # KDE role -> our theme key mapping
    declare -A KDE_MAP=(
        ["Colors:Window/BackgroundNormal"]="bg_primary"
        ["Colors:Window/ForegroundNormal"]="text_primary"
        ["Colors:Window/ForegroundInactive"]="text_secondary"
        ["Colors:Button/BackgroundNormal"]="button_normal"
        ["Colors:Button/ForegroundNormal"]="button_text_color"
        ["Colors:Selection/BackgroundNormal"]="selection_background"
        ["Colors:Selection/ForegroundNormal"]="selection_text"
        ["Colors:Tooltip/BackgroundNormal"]="tooltip_bg"
        ["Colors:Tooltip/ForegroundNormal"]="tooltip_text"
        ["Colors:View/BackgroundNormal"]="viewport_bg"
        ["Colors:View/ForegroundNormal"]="viewport_text"
        ["Colors:View/BackgroundAlternate"]="alternate_base"
        ["Colors:Window/DecorationFocus"]="accent_primary"
        ["Colors:Window/DecorationHover"]="accent_secondary"
    )

    if [[ ! -f "$kdeglobals" ]]; then
        echo -e "${COLOR_RED}KDE globals not found: $kdeglobals${COLOR_RESET}"
        echo "Not running KDE, or file missing."
        exit 1
    fi

    printf "${COLOR_BOLD_WHITE}%-35s %-20s %-20s %s${COLOR_RESET}\n" \
        "KDE Role" "KDE Value" "Theme Key" "Match?"
    echo " ─ "

    for kde_key in "${!KDE_MAP[@]}"; do
        theme_key="${KDE_MAP[$kde_key]}"
        section=$(echo "$kde_key" | cut -d/ -f1)
        role=$(echo "$kde_key" | cut -d/ -f2)

        # Read KDE value (stored as R,G,B)
        kde_rgb=$(awk -F= "/^\[${section}\]/{f=1} f && /^${role}=/{print \$2; f=0}" \
            "$kdeglobals" 2>/dev/null | head -1)

        if [[ -n "$kde_rgb" ]]; then
            # Convert R,G,B to hex
            IFS=',' read -r r g b <<< "$kde_rgb"
            kde_hex=$(printf '#%02x%02x%02x' "${r:-0}" "${g:-0}" "${b:-0}" 2>/dev/null)
            swatch="\033[48;2;${r:-0};${g:-0};${b:-0}m   \033[0m"

            # Find theme key in first JSON file found
            theme_val=$(find "$ROOT" -name "*.json" -not -path "*/.git/*" 2>/dev/null | \
                head -1 | xargs python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    c = d.get('colors', d)
    print(c.get('$theme_key', 'not set'))
except: print('?')
" 2>/dev/null)

            match="—"
            [[ "${theme_val,,}" == "${kde_hex,,}" ]] && match="${COLOR_BOLD_GREEN}✓${COLOR_RESET}"

            printf "${COLOR_CYAN}%-35s${COLOR_RESET} %b %-15s  ${COLOR_YELLOW}%-20s${COLOR_RESET} %b  %s\n" \
                "$role" "$swatch" "$kde_hex" "$theme_key" "$swatch" "$match"
        fi
    done

    echo
    echo -e "${COLOR_DIM}KDE globals: $kdeglobals${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    exit 0
fi


# COLOR SEARCH MODE  -k / --colors <hex> [new_hex]
# Find all uses of a hex color, optionally replace
# Also shows which theme key the color is used as fallback for

if [[ $COLOR_MODE -eq 1 ]]; then
    ROOT="${ARGS[0]:-.}"
    hex_lower="${COLOR_HEX,,}"
    hex_upper="${COLOR_HEX^^}"

    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo -e "${COLOR_BOLD_CYAN}Color search:${COLOR_RESET} ${COLOR_BOLD_YELLOW}${COLOR_HEX}${COLOR_RESET}"
    [[ -n "$COLOR_NEW" ]] && echo -e "${COLOR_BOLD_CYAN}Replace with:${COLOR_RESET} ${COLOR_BOLD_YELLOW}${COLOR_NEW}${COLOR_RESET}"
    echo -e "${COLOR_BOLD_CYAN}Location:${COLOR_RESET} ${COLOR_BLUE}$ROOT${COLOR_RESET}"
    [[ -n "$COLOR_NEW" && $APPLY -eq 0 ]] && \
        echo -e "${COLOR_BOLD_YELLOW}DRY RUN${COLOR_RESET} — add --apply to make changes"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo

    # Show color swatch
    if [[ "${COLOR_HEX}" =~ ^#[0-9a-fA-F]{6}$ ]]; then
        r=$((16#${COLOR_HEX:1:2}))
        g=$((16#${COLOR_HEX:3:2}))
        b=$((16#${COLOR_HEX:5:2}))
        echo -e "  Color: \033[48;2;${r};${g};${b}m        \033[0m  ${COLOR_HEX}"
        echo
    fi

    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          is_binary "$f" && continue
          increment_counter "$SCANNED_FILE"

          # Search case-insensitively for the hex value
          if grep -qi "$hex_lower\|$hex_upper" "$f" 2>/dev/null; then
              echo -e "${COLOR_BOLD_CYAN}┌─${COLOR_RESET} ${COLOR_BOLD_YELLOW}$f${COLOR_RESET}"

              # Show matching lines with context about what key it's a fallback for
              grep -in "$COLOR_HEX" "$f" 2>/dev/null | while IFS=: read -r lineno content; do
                  # Extract theme key name if this is a .get() fallback pattern
                  key_hint=""
                  if echo "$content" | grep -qE "\.get\(|colors\[|theme_colors"; then
                      key_hint=$(echo "$content" | \
                          grep -oE "'[a-z_]+',\s*['\"]${COLOR_HEX}['\"]|\"[a-z_]+\",\s*['\"]${COLOR_HEX}['\"]" | \
                          grep -oE "'[a-z_]+'|\"[a-z_]+\"" | head -1 | tr -d "'\"")
                      [[ -n "$key_hint" ]] && key_hint=" ${COLOR_MAGENTA}← key: ${key_hint}${COLOR_RESET}"
                  fi
                  printf "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_MAGENTA}%6s${COLOR_RESET} ${COLOR_DIM}│${COLOR_RESET} %s%b\n" \
                      "L${lineno}" "$content" "$key_hint"
              done

              echo -e "${COLOR_CYAN}└─${COLOR_RESET}"
              increment_counter "$MATCHES_FILE"

              # Apply color replacement if requested
              if [[ -n "$COLOR_NEW" ]]; then
                  if [[ $APPLY -eq 1 ]]; then
                      [[ $BACKUP -eq 1 ]] && cp "$f" "${f}.bak" && echo "  Backed up: ${f}.bak"
                      # Replace both cases
                      sed -i "s|${COLOR_HEX}|${COLOR_NEW}|gi" "$f"
                      echo -e "  ${COLOR_GREEN}Modified:${COLOR_RESET} $f"
                      increment_counter "$MODIFIED_FILE"
                  else
                      echo -e "  ${COLOR_YELLOW}Would replace:${COLOR_RESET} ${COLOR_HEX} → ${COLOR_NEW} in $f"
                  fi
              fi
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done

    echo
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo -e "${COLOR_BOLD_GREEN}Summary:${COLOR_RESET}"
    echo -e "   ${COLOR_CYAN}Files scanned:${COLOR_RESET}  ${COLOR_BOLD_WHITE}$(cat "$SCANNED_FILE")${COLOR_RESET}"
    echo -e "   ${COLOR_CYAN}Files matched:${COLOR_RESET}  ${COLOR_BOLD_YELLOW}$(cat "$MATCHES_FILE")${COLOR_RESET}"
    [[ -n "$COLOR_NEW" ]] && \
        echo -e "   ${COLOR_CYAN}Files modified:${COLOR_RESET} ${COLOR_BOLD_GREEN}$(cat "$MODIFIED_FILE")${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    exit 0
fi

# UNIQUE HEX COLORS MODE  --unique
# Find all unique hex color values in matched files

if [[ $UNIQUE_MODE -eq 1 ]]; then
    PATTERN="${ARGS[0]:-.}"
    ROOT="${ARGS[1]:-.}"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo -e "${COLOR_BOLD_CYAN}Unique hex colors in:${COLOR_RESET} ${COLOR_BLUE}$ROOT${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo

    declare -A color_counts
    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          is_binary "$f" && continue
          # Extract all hex colors from file
          grep -oiE '#[0-9a-fA-F]{6}\b' "$f" 2>/dev/null
        done | sort | uniq -c | sort -rn \
      | while read -r count hex; do
          hex_lower="${hex,,}"
          r=$((16#${hex_lower:1:2}))
          g=$((16#${hex_lower:3:2}))
          b=$((16#${hex_lower:5:2}))
          swatch="\033[48;2;${r};${g};${b}m   \033[0m"
          printf "%b  ${COLOR_BOLD_YELLOW}%-12s${COLOR_RESET} ${COLOR_DIM}%4s occurrences${COLOR_RESET}\n" \
              "$swatch" "$hex_lower" "$count"
        done

    echo
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    exit 0
fi


# STANDARD SEARCH / REPLACE MODES

# --- Ensure search term ---
if [[ ${#ARGS[@]} -lt 1 ]]; then
    echo "Usage: ds [options] <search_term> [replace_term] [path]"
    echo "Use --help for detailed options"
    exit 1
fi

# --- Set PATTERN, REPLACE, ROOT ---
PATTERN="${ARGS[0]}"
if [[ ${#ARGS[@]} -ge 2 && -z "$REPLACE" && "${ARGS[1]}" != ./* && ! -d "${ARGS[1]}" ]]; then
    REPLACE="${ARGS[1]}"
    ROOT="${ARGS[2]:-.}"
else
    ROOT="${ARGS[1]:-.}"
fi

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
        "$PATTERN" "$ROOT" 2>/dev/null | grep -v "/old/" \
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

# --- REPLACE MODE ---
if [[ -n $REPLACE ]]; then
    echo "Replace mode: \"$PATTERN\" → \"$REPLACE\" in ${ROOT}"
    [[ $APPLY -eq 0 ]] && echo "DRY RUN — add --apply to make changes"
    echo

    # Filename renaming
    if [[ $CONTENT_ONLY -eq 0 ]]; then
        echo "Files to rename:"
        find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
          | while IFS= read -r -d '' f; do
              [[ $DIRS_INCLUDE -eq 0 && -d "$f" ]] && continue
              filename=$(basename "$f")
              if matches_pattern "$filename" "$PATTERN"; then
                  [[ $REGEX -eq 1 ]] \
                      && newname=$(echo "$filename" | sed -E "s/${PATTERN}/${REPLACE}/g") \
                      || newname=$(echo "$filename" | sed "s/${PATTERN}/${REPLACE}/g")
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
              [[ $REGEX -eq 1 && $IGNORE_CASE -eq 1 ]] && grep_check="grep -E -i" \
                  || { [[ $REGEX -eq 1 ]] && grep_check="grep -E" \
                  || { [[ $IGNORE_CASE -eq 1 ]] && grep_check="grep -F -i" \
                  || grep_check="grep -F"; }; }
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
    [[ $APPLY -eq 0 ]] && echo -e "\nTo apply: add --apply  |  Backups: add --backup  |  Preview: add --diff"
    exit 0
fi



# COMMENT MODE
# Comment out matching lines with #

if [[ $COMMENT_MODE -eq 1 ]]; then
    ROOT="${ARGS[0]:-.}"

    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo -e "${COLOR_BOLD_CYAN}Commenting lines containing:${COLOR_RESET} ${COLOR_BOLD_YELLOW}\"$PATTERN\"${COLOR_RESET}"
    echo -e "${COLOR_BOLD_CYAN}Location:${COLOR_RESET} ${COLOR_BLUE}${ROOT}${COLOR_RESET}"
    [[ $APPLY -eq 0 ]] && \
        echo -e "${COLOR_BOLD_YELLOW}DRY RUN${COLOR_RESET} — add --apply to modify files"
    echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
    echo

    find "$ROOT" \( "${FIND_EXPR[@]}" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do

          is_binary "$f" && continue
          increment_counter "$SCANNED_FILE"

          if grep -F -q "$PATTERN" "$f" 2>/dev/null; then
              echo -e "${COLOR_BOLD_CYAN}┌─${COLOR_RESET} ${COLOR_BOLD_YELLOW}$f${COLOR_RESET}"

              grep -n -F "$PATTERN" "$f" 2>/dev/null \
                | grep -v '^[0-9]*:#' \
                | while IFS=: read -r lineno content; do

                    printf "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_MAGENTA}%6s${COLOR_RESET} ${COLOR_DIM}│${COLOR_RESET} %s\n" \
                        "L${lineno}" "$content"
                done

              echo -e "${COLOR_CYAN}└─${COLOR_RESET}"

              if [[ $APPLY -eq 1 ]]; then
                  [[ $BACKUP -eq 1 ]] && cp "$f" "$f.bak"

                  sed -i "/${PATTERN}/ {
                      /^[[:space:]]*#/! s/^/#/
                  }" "$f"

                  echo -e "  ${COLOR_GREEN}Modified:${COLOR_RESET} $f"
                  increment_counter "$MODIFIED_FILE"
              else
                  echo -e "  ${COLOR_YELLOW}Would modify:${COLOR_RESET} $f"
              fi

              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
      done

    echo
    echo "Summary:"
    echo "  Files scanned:  $(cat "$SCANNED_FILE")"
    echo "  Matches found:  $(cat "$MATCHES_FILE")"
    echo "  Files modified: $(cat "$MODIFIED_FILE")"

    exit 0
fi

# --- SEARCH MODE ---
echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
echo -e "${COLOR_BOLD_CYAN}Searching for:${COLOR_RESET} ${COLOR_BOLD_YELLOW}\"$PATTERN\"${COLOR_RESET}"
echo -e "${COLOR_BOLD_CYAN}Location:${COLOR_RESET} ${COLOR_BLUE}${ROOT}${COLOR_RESET}"
echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
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
                    printf "${COLOR_CYAN}│${COLOR_RESET} ${COLOR_MAGENTA}%6s${COLOR_RESET} ${COLOR_DIM}│${COLOR_RESET} %s\n" \
                        "L$line" "$content"
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
          if matches_pattern "$(basename "$f")" "$PATTERN"; then
              echo -e "  ${COLOR_YELLOW}*${COLOR_RESET} ${COLOR_CYAN}$f${COLOR_RESET}"
              increment_counter "$MATCHES_FILE"
              [[ $FIRST -eq 1 ]] && exit 0
          fi
        done
}

if [[ $NAME_ONLY -eq 0 && $CONTENT_ONLY -eq 0 ]]; then
    echo -e "${COLOR_BOLD_GREEN}=== FILENAME MATCHES ===${COLOR_RESET}"
    print_name_matches "$ROOT"
    echo
    echo -e "${COLOR_BOLD_GREEN}=== CONTENT MATCHES ===${COLOR_RESET}"
    print_content_matches "$ROOT"
elif [[ $NAME_ONLY -eq 1 ]]; then
    echo -e "${COLOR_BOLD_GREEN}=== FILENAME SEARCH ===${COLOR_RESET}"
    print_name_matches "$ROOT"
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
echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}Summary:${COLOR_RESET}"
echo -e "   ${COLOR_CYAN}Files scanned:${COLOR_RESET} ${COLOR_BOLD_WHITE}$(cat "$SCANNED_FILE")${COLOR_RESET}"
echo -e "   ${COLOR_CYAN}Matches found:${COLOR_RESET} ${COLOR_BOLD_YELLOW}$(cat "$MATCHES_FILE")${COLOR_RESET}"
echo -e "${COLOR_BOLD_BLUE} ━ ${COLOR_RESET}"
