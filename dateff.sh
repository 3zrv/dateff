#!/bin/bash

target_branch="master"
source_branch="staging"
ignored_directories=("path/to/dir_1" "path/to/dir_1")
updated_files_file="updated_files.txt"

# Ensure the file is empty or doesn't exist initially
>"$updated_files_file"

# Get the total number of files to process
total_files=$(git ls-tree -r --name-only $target_branch | grep -vE "$(
    IFS=\|
    echo "${ignored_directories[*]}"
)" | wc -l)
processed_files=0

# Iterate through all files in the repo
git ls-tree -r --name-only $target_branch | grep -vE "$(
    IFS=\|
    echo "${ignored_directories[*]}"
)" | while read file; do
    # Check if the file exists in both branches
    if git show $target_branch:$file >/dev/null 2>&1 && git show $source_branch:$file >/dev/null 2>&1; then

        # Extract file content from the target branch
        target_content=$(git show $target_branch:$file)

        # Extract file content from the source branch
        source_content=$(git show $source_branch:$file)

        # Compare the content of the two branches
        echo "Skipping $file: Content is identical."
        if [ "$target_content" != "$source_content" ]; then
            # Compare timestamps of the two branches
            target_timestamp=$(git log -1 --format=%ct $target_branch -- $file)
            source_timestamp=$(git log -1 --format=%ct $source_branch -- $file)

            # Determine which content to keep based on timestamps
            if [ $target_timestamp -gt $source_timestamp ]; then
                echo "Keeping the version from $target_branch for $file target: $target_timestamp source: $source_timestamp"
                echo "$target_content" >"$file"
                echo "$file" >>"$updated_files_file"
            else
                echo "Keeping the version from $source_branch for $file target: $target_timestamp source: $source_timestamp"
                echo "$source_content" >"$file"
                echo "$file" >>"$updated_files_file"
            fi
        fi
    else
        # in case you want to checkout the file that does not exist
        # git checkout $target_branch -- $file
        echo "Skipping $file: File does not exist in both branches."
    fi

    # Update progress
    ((processed_files++))
    echo -ne "Progress: $processed_files/$total_files files processed\r"
done

echo -e "\nFile comparison and update complete."
echo "Updated file paths written to: $updated_files_file"
