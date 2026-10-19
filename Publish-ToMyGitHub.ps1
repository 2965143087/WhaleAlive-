# 把本机安装好的 Whale Alive 推送到你自己的 GitHub 仓库
# 用法：
#   .\Publish-ToMyGitHub.ps1 -RemoteUrl "https://github.com/<账号>/<仓库名>.git"
# 前提：已在 GitHub 网页建好一个空仓库（不要勾选 README / .gitignore / license）。
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RemoteUrl
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
Push-Location $projectRoot
try {
    git rev-parse --git-dir *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Publish: this folder is not a git repository.' }

    $current = git remote get-url origin 2>$null
    if ($current -ne $RemoteUrl) {
        Write-Host "Publish: origin $current -> $RemoteUrl"
        if ($current) { git remote set-url origin $RemoteUrl } else { git remote add origin $RemoteUrl }
    }

    $dirty = git status --porcelain
    if ($dirty) {
        Write-Host 'Publish: uncommitted changes:' -ForegroundColor Yellow
        Write-Host $dirty
        throw 'Publish: commit all changes first (git add -A; git commit -m ...).'
    }

    Write-Host 'Publish: pushing; enter your GitHub credentials when prompted (a PAT with repo scope works).'
    git push -u origin main
    if ($LASTEXITCODE -ne 0) { throw "Publish: git push failed with exit code $LASTEXITCODE." }
    Write-Host "Publish: done -> $RemoteUrl" -ForegroundColor Green
}
finally {
    Pop-Location
}
