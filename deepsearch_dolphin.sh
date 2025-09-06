#!/bin/bash

# Get target folder from Dolphin
target_folder="$1"

# Ask user for search term
search_term=$(kdialog --inputbox "Enter search word (case-sensitive):" "Deep Search")
[[ -z "$search_term" ]] && exit 1

# Run the search and collect results
result=$(mktemp)
{
    echo "🔍 Searching for: \"$search_term\" in $target_folder"
    echo
    echo "📁 Files with name containing \"$search_term\":"
    find "$target_folder" -type f -iname "*$search_term*" 2>/dev/null
    echo
    echo "📄 Files with contents containing \"$search_term\":"
    grep -rn --exclude-dir={.git,__pycache__} "$search_term" "$target_folder" 2>/dev/null
} > "$result"

# Show results in a scrollable dialog
kdialog --textbox "$result" 800 600

# Cleanup
rm -f "$result"
