# 分步把 Whale Alive 推到你的 GitHub 仓库，每次只上传一个提交的包。
# 为什么分批：一次性推送 221 MB 的包会在 GitHub 上传中途被断开
# （RPC failed; curl 55 OpenSSL SSL_read: unexpected eof，末行却显示 Everything up-to-date）。
# 某一步失败时，重跑同一步即可，已推送的对象不会重传。
#
# 用法（在普通 PowerShell 窗口里运行）：
#   .\Push-InBatches.ps1                 # 从第 1 步开始
#   .\Push-InBatches.ps1 -StartStep 4    # 从第 4 步续传
# 需要代理时： $env:HTTPS_PROXY = "http://127.0.0.1:端口"
[CmdletBinding()]
param(
    [string]$RemoteUrl = 'https://github.com/2965143087/WhaleAlive-.git',
    [int]$StartStep = 1,
    [int]$Retries = 5
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
Push-Location $projectRoot
try {
    git rev-parse --git-dir *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Not a git repository.' }

    # 本机 schannel 不可用 → OpenSSL；HTTP/1.1 + 大缓冲让每个包更容易过。
    git config http.sslBackend openssl
    git config http.version HTTP/1.1
    git config http.postBuffer 524288000

    $current = git remote get-url origin 2>$null
    if ($current -ne $RemoteUrl) {
        if ($current) { git remote set-url origin $RemoteUrl } else { git remote add origin $RemoteUrl }
    }

    # 从仓库根提交开始、按提交顺序逐步推送；最后一个提交就是当前 HEAD。
    $hashes = @(git rev-list --reverse HEAD)
    if ($LASTEXITCODE -ne 0 -or $hashes.Count -eq 0) { throw 'Cannot enumerate commits.' }
    Write-Host ("{0} commits to push, {1} step(s) to run." -f $hashes.Count, ($hashes.Count - $StartStep + 1))

    for ($i = 0; $i -lt $hashes.Count; $i++) {
        $number = $i + 1
        if ($number -lt $StartStep) { continue }
        $sha = $hashes[$i]
        $subject = (git log -1 --format='%s' $sha)
        Write-Host ("Step {0}/{1}: {2}" -f $number, $hashes.Count, $subject) -ForegroundColor Cyan

        $attempt = 1
        while ($true) {
            git push origin "${sha}:refs/heads/main"
            if ($LASTEXITCODE -eq 0) { break }
            if ($attempt -ge $Retries) { throw "Step $number failed after $Retries attempts. Re-run: .\Push-InBatches.ps1 -StartStep $number" }
            $wait = [Math]::Min(60, 5 * $attempt)
            Write-Host ("  attempt {0} failed; retrying in {1}s. If a sign-in window appears, complete it there." -f $attempt, $wait) -ForegroundColor Yellow
            Start-Sleep -Seconds $wait
            $attempt++
        }
    }

    git fetch origin main
    git branch --set-upstream-to=origin/main main
    Write-Host 'All commits pushed.' -ForegroundColor Green
    Write-Host "Verify: $RemoteUrl"
}
finally {
    Pop-Location
}
