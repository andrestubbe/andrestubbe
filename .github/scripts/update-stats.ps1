$ErrorActionPreference = "Stop"

$username = "andrestubbe"
$reposJson = gh api "users/$username/repos?per_page=100" 2>$null
if (-not $reposJson) {
    Write-Error "Failed to fetch repositories."
    exit 1
}

$repos = $reposJson | ConvertFrom-Json | Where-Object { $_.name -like "Fast*" }

$results = @()

foreach ($repo in $repos) {
    $repoName = "$username/" + $repo.name
    $stars = $repo.stargazers_count

    # Get Views (last 14 days)
    $viewsJson = gh api "repos/$repoName/traffic/views" 2>$null
    $views = 0
    if ($viewsJson) {
        $viewsData = $viewsJson | ConvertFrom-Json
        $views = $viewsData.count
    }

    # Get Clones (last 14 days)
    $clonesJson = gh api "repos/$repoName/traffic/clones" 2>$null
    $clones = 0
    if ($clonesJson) {
        $clonesData = $clonesJson | ConvertFrom-Json
        $clones = $clonesData.count
    }

    $results += [PSCustomObject]@{
        Repository = $repo.name
        Stars      = $stars
        Views      = $views
        Clones     = $clones
    }
}

$sorted = $results | Sort-Object Clones, Views, Stars -Descending

# Generate Markdown Table
$markdown = @()
$markdown += "| Repository | 📥 Clones (14d) | 👀 Views (14d) | ⭐ Stars |"
$markdown += "|:---|---:|---:|---:|"
foreach ($r in $sorted) {
    $markdown += "| **$($r.Repository)** | $($r.Clones) | $($r.Views) | $($r.Stars) |"
}
$dateStr = Get-Date -Format "dd.MM.yyyy, HH:mm"
$markdown += "*(Automatisch aktualisiert: $dateStr Uhr)*"

$markdownText = $markdown -join "`n"

# Update README.md
$readmePath = "README.md"
if (Test-Path $readmePath) {
    $content = Get-Content -Path $readmePath -Raw
    $pattern = '(?s)<!-- STATS_START -->.*?<!-- STATS_END -->'
    $replacement = "<!-- STATS_START -->`n$markdownText`n<!-- STATS_END -->"
    $newContent = $content -replace $pattern, $replacement
    Set-Content -Path $readmePath -Value $newContent -Encoding UTF8
    Write-Host "Updated README.md successfully."
} else {
    Write-Error "README.md not found!"
    exit 1
}
