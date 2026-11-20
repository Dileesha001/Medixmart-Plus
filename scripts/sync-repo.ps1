# Medixmart Plus - Quick Repository Synchronizer
# Fetches all remote updates, prunes deleted branches, and fast-forwards the active branch

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Synchronizing Medixmart Plus with GitHub " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host "[1/2] Fetching all remotes and pruning deleted branches..." -ForegroundColor Yellow
git fetch --all --prune

$currentBranch = (git branch --show-current).Trim()
Write-Host "[2/2] Updating active branch '$currentBranch' from origin..." -ForegroundColor Yellow
git pull origin $currentBranch

Write-Host "`nRepository is fully synchronized!" -ForegroundColor Green

