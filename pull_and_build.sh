#!/bin/bash

# Script to run git pull and mvn clean install on multiple folders
# Usage: ./pull_and_build.sh

FOLDERS_FILE="folders.txt"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if folders file exists
if [[ ! -f "$SCRIPT_DIR/$FOLDERS_FILE" ]]; then
    echo "Error: $FOLDERS_FILE not found in $SCRIPT_DIR"
    echo "Please create $FOLDERS_FILE with folder paths, one per line"
    exit 1
fi

# Read folders from file, skip empty lines and comments
while IFS= read -r folder || [[ -n "$folder" ]]; do
    # Skip empty lines and comments
    [[ -z "$folder" || "$folder" =~ ^[[:space:]]*# ]] && continue
    
    # Expand tilde to home directory
    folder="${folder/#\~/$HOME}"
    
    echo "========================================"
    echo "Processing: $folder"
    echo "========================================"
    
    # Check if folder exists
    if [[ ! -d "$folder" ]]; then
        echo "Error: Directory $folder does not exist"
        continue
    fi
    
    # Change to the folder
    cd "$folder" || {
        echo "Error: Could not change to directory $folder"
        continue
    }
    
    # Check if it's a git repository
    if [[ ! -d ".git" ]]; then
        echo "Warning: $folder is not a git repository, skipping git pull"
    else
        echo "Running git pull..."
        git pull
        if [[ $? -ne 0 ]]; then
            echo "Error: git pull failed in $folder"
            continue
        fi
    fi
    
    # Check if pom.xml exists
    if [[ ! -f "pom.xml" ]]; then
        echo "Warning: pom.xml not found in $folder, skipping mvn clean install"
    else
        echo "Running mvn clean install..."
        mvn clean install
        if [[ $? -ne 0 ]]; then
            echo "Error: mvn clean install failed in $folder"
            continue
        fi
    fi
    
    echo "Successfully processed: $folder"
    echo ""
    
    # Return to script directory
    cd "$SCRIPT_DIR"
    
done < "$SCRIPT_DIR/$FOLDERS_FILE"

echo "========================================"
echo "Script completed!"
echo "========================================"