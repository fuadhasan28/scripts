# Git Remote Sync and Mirror Recovery Tool for PowerShell
$OriginRemote = "origin"
$BackupRemote = "old-repo"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Git Remote Sync and Mirror Recovery Tool (PowerShell)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Syncing: $OriginRemote <-> $BackupRemote`n"

# Verify inside git repo
$isGit = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: Not a git repository."
    exit 1
}

# Fetch remote heads using ls-remote
Write-Host "Querying branches from $OriginRemote..."
$originHeads = git ls-remote --heads $OriginRemote
Write-Host "Querying branches from $BackupRemote..."
$backupHeads = git ls-remote --heads $BackupRemote

$originBranches = @{}
$backupBranches = @{}
$allBranches = @()

foreach ($line in $originHeads) {
    if ($line -match "^([0-9a-fA-F]+)\s+refs/heads/(.+)$") {
        $sha = $Matches[1]
        $branch = $Matches[2]
        $originBranches[$branch] = $sha
        $allBranches += $branch
    }
}

foreach ($line in $backupHeads) {
    if ($line -match "^([0-9a-fA-F]+)\s+refs/heads/(.+)$") {
        $sha = $Matches[1]
        $branch = $Matches[2]
        $backupBranches[$branch] = $sha
        $allBranches += $branch
    }
}

$uniqBranches = $allBranches | Sort-Object -Unique

Write-Host "Found $($uniqBranches.Count) unique branches to inspect."
Write-Host "-----------------------------------------"

$currentBranch = git branch --show-current 2>$null
if (-not $currentBranch) { $currentBranch = "main" }

foreach ($branch in $uniqBranches) {
    $shaOrigin = $originBranches[$branch]
    $shaBackup = $backupBranches[$branch]

    # Scenario 1: Only on GitStation
    if ($shaOrigin -and -not $shaBackup) {
        Write-Host "[+] Branch '$branch' exists only on $OriginRemote. Copying to $BackupRemote..." -ForegroundColor Green
        git fetch --no-tags $OriginRemote "refs/heads/$branch" 2>$null | Out-Null
        git push $BackupRemote "FETCH_HEAD:refs/heads/$branch"
        continue
    }

    # Scenario 2: Only on GitLab
    if (-not $shaOrigin -and $shaBackup) {
        Write-Host "[+] Branch '$branch' exists only on $BackupRemote. Copying to $OriginRemote..." -ForegroundColor Green
        git fetch --no-tags $BackupRemote "refs/heads/$branch" 2>$null | Out-Null
        git push $OriginRemote "FETCH_HEAD:refs/heads/$branch"
        continue
    }

    # Already in sync
    if ($shaOrigin -eq $shaBackup) {
        continue
    }

    Write-Host "[!] Divergence detected on branch '$branch':" -ForegroundColor Yellow
    Write-Host "    $($OriginRemote): $shaOrigin"
    Write-Host "    $($BackupRemote): $shaBackup"

    # Fetch both histories locally
    git fetch --no-tags $OriginRemote "refs/heads/$branch" 2>$null | Out-Null
    git fetch --no-tags $BackupRemote "refs/heads/$branch" 2>$null | Out-Null

    # Check if origin is ancestor of backup
    git merge-base --is-ancestor $shaOrigin $shaBackup 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    -> $BackupRemote is ahead of $OriginRemote. Fast-forwarding $OriginRemote..." -ForegroundColor Green
        git push $OriginRemote "$shaBackup:refs/heads/$branch"
        continue
    }

    # Check if backup is ancestor of origin
    git merge-base --is-ancestor $shaBackup $shaOrigin 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    -> $OriginRemote is ahead of $BackupRemote. Fast-forwarding $BackupRemote..." -ForegroundColor Green
        git push $BackupRemote "$shaOrigin:refs/heads/$branch"
        continue
    }

    # Diverged
    Write-Host "    -> Both remotes have diverged. Attempting auto-merge..." -ForegroundColor Cyan
    
    # Save working state
    $stashCreated = $false
    git diff-index --quiet HEAD -- 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    -> Stashing uncommitted local changes..."
        git stash push -m "temp-sync-stash" | Out-Null
        $stashCreated = $true
    }

    # Merge on a temp branch
    git checkout -B "temp-sync-merge" $shaOrigin 2>$null | Out-Null
    git merge $shaBackup -m "chore: sync diverged history for '$branch'" --no-edit 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $mergeSha = (git rev-parse HEAD).Trim()
        Write-Host "    -> Auto-merge successful. Pushing merged history to both remotes..." -ForegroundColor Green
        git push $OriginRemote "$mergeSha:refs/heads/$branch"
        git push $BackupRemote "$mergeSha:refs/heads/$branch"
    } else {
        Write-Host "    [ERROR] Auto-merge failed due to conflicts on branch '$branch'." -ForegroundColor Red
        Write-Host "            Please resolve conflicts manually:"
        Write-Host "            1. git checkout $branch"
        Write-Host "            2. git merge old-repo/$branch"
        Write-Host "            3. Resolve conflicts, commit, and push to both remotes."
        git merge --abort 2>$null | Out-Null
    }

    # Restore
    git checkout $currentBranch 2>$null | Out-Null
    git branch -D "temp-sync-merge" 2>$null | Out-Null
    if ($stashCreated) {
        git stash pop 2>$null | Out-Null
    }
}

Write-Host "-----------------------------------------"
Write-Host "Sync process completed successfully." -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
