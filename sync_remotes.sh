#!/usr/bin/env bash

# Exit on error, except where explicitly handled
set -eo pipefail

ORIGIN_REMOTE="origin"      # GitStation / Gitea
BACKUP_REMOTE="old-repo"    # GitLab

echo "========================================="
echo " Git Remote Sync and Mirror Recovery Tool"
echo "========================================="
echo "Syncing: $ORIGIN_REMOTE <-> $BACKUP_REMOTE"
echo ""

# Ensure we are in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Not a git repository."
    exit 1
fi

# Fetch remote heads using ls-remote (avoids case-insensitive ref lock conflicts on Windows)
echo "Querying branches from $ORIGIN_REMOTE..."
origin_heads=$(git ls-remote --heads "$ORIGIN_REMOTE")

echo "Querying branches from $BACKUP_REMOTE..."
backup_heads=$(git ls-remote --heads "$BACKUP_REMOTE")

# Parse heads into associative arrays (using standard read/loop for compatibility)
declare -A origin_branches
declare -A backup_branches
all_branches=()

while read -r sha ref; do
    if [[ -n "$ref" ]]; then
        branch="${ref#refs/heads/}"
        origin_branches["$branch"]="$sha"
        all_branches+=("$branch")
    fi
done <<< "$origin_heads"

while read -r sha ref; do
    if [[ -n "$ref" ]]; then
        branch="${ref#refs/heads/}"
        backup_branches["$branch"]="$sha"
        all_branches+=("$branch")
    fi
done <<< "$backup_heads"

# Deduplicate all_branches list
uniq_branches=($(echo "${all_branches[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

echo "Found ${#uniq_branches[@]} unique branches to inspect."
echo "-----------------------------------------"

current_branch=$(git branch --show-current 2>/dev/null || echo "main")

for branch in "${uniq_branches[@]}"; do
    sha_origin="${origin_branches["$branch"]}"
    sha_backup="${backup_branches["$branch"]}"

    # Scenario 1: Branch exists only on GitStation (origin)
    if [[ -n "$sha_origin" && -z "$sha_backup" ]]; then
        echo "[+] Branch '$branch' exists only on $ORIGIN_REMOTE. Copying to $BACKUP_REMOTE..."
        git fetch --no-tags "$ORIGIN_REMOTE" "refs/heads/$branch" >/dev/null 2>&1
        git push "$BACKUP_REMOTE" "FETCH_HEAD:refs/heads/$branch"
        continue
    fi

    # Scenario 2: Branch exists only on GitLab (backup)
    if [[ -z "$sha_origin" && -n "$sha_backup" ]]; then
        echo "[+] Branch '$branch' exists only on $BACKUP_REMOTE. Copying to $ORIGIN_REMOTE..."
        git fetch --no-tags "$BACKUP_REMOTE" "refs/heads/$branch" >/dev/null 2>&1
        git push "$ORIGIN_REMOTE" "FETCH_HEAD:refs/heads/$branch"
        continue
    fi

    # Scenario 3: Branch exists on both remotes
    if [[ "$sha_origin" == "$sha_backup" ]]; then
        # Already in sync
        continue
    fi

    echo "[!] Divergence detected on branch '$branch':"
    echo "    $ORIGIN_REMOTE: $sha_origin"
    echo "    $BACKUP_REMOTE: $sha_backup"

    # Fetch both histories locally (using FETCH_HEAD to avoid loose ref conflicts)
    git fetch --no-tags "$ORIGIN_REMOTE" "refs/heads/$branch" >/dev/null 2>&1
    git fetch --no-tags "$BACKUP_REMOTE" "refs/heads/$branch" >/dev/null 2>&1

    # Check if origin is ancestor of backup (backup is ahead)
    if git merge-base --is-ancestor "$sha_origin" "$sha_backup" 2>/dev/null; then
        echo "    -> $BACKUP_REMOTE is ahead of $ORIGIN_REMOTE. Fast-forwarding $ORIGIN_REMOTE..."
        git push "$ORIGIN_REMOTE" "$sha_backup:refs/heads/$branch"
        
    # Check if backup is ancestor of origin (origin is ahead)
    elif git merge-base --is-ancestor "$sha_backup" "$sha_origin" 2>/dev/null; then
        echo "    -> $ORIGIN_REMOTE is ahead of $BACKUP_REMOTE. Fast-forwarding $BACKUP_REMOTE..."
        git push "$BACKUP_REMOTE" "$sha_origin:refs/heads/$branch"
        
    # Neither is ancestor (true divergence)
    else
        echo "    -> Both remotes have diverged. Attempting auto-merge..."
        
        # Save current working state if dirty
        stash_created=false
        if ! git diff-index --quiet HEAD --; then
            echo "    -> Stashing uncommitted local changes..."
            git stash push -m "temp-sync-stash" >/dev/null
            stash_created=true
        fi

        # Perform merge on a temporary branch
        if git checkout -B "temp-sync-merge" "$sha_origin" >/dev/null 2>&1; then
            if git merge "$sha_backup" -m "chore: sync diverged history for '$branch'" --no-edit >/dev/null 2>&1; then
                merge_sha=$(git rev-parse HEAD)
                echo "    -> Auto-merge successful. Pushing merged history to both remotes..."
                git push "$ORIGIN_REMOTE" "$merge_sha:refs/heads/$branch"
                git push "$BACKUP_REMOTE" "$merge_sha:refs/heads/$branch"
            else
                echo "    [ERROR] Auto-merge failed due to conflicts on branch '$branch'."
                echo "            Please resolve conflicts manually:"
                echo "            1. git checkout $branch"
                echo "            2. git merge old-repo/$branch"
                echo "            3. Resolve conflicts, commit, and push to both remotes."
                # Abort the failed merge
                git merge --abort >/dev/null 2>&1
            fi
        fi

        # Restore working branch and stash
        git checkout "$current_branch" >/dev/null 2>&1
        git branch -D "temp-sync-merge" >/dev/null 2>&1
        if [ "$stash_created" = true ]; then
            git stash pop >/dev/null 2>&1
        fi
    fi
done

echo "-----------------------------------------"
echo "Sync process completed successfully."
echo "========================================="
