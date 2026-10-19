# 分 9 步把 Whale Alive 推到你的 GitHub 仓库。
# 为什么分批：一次性推送 221 MB 的包会在 GitHub 上传中途被断开
# （RPC failed; curl 55 OpenSSL SSL_read: unexpected eof，末行却显示 Everything up-to-date）。
# 每一步只上传一个较小的包，某一步失败了重跑同一步即可，已推送的不会重传。
#
# 用法（在“普通” PowerShell 窗口里运行，不要用管理员/受限沙箱）：
#   .\Push-InBatches.ps1
# 若网络走代理且 git 不认系统代理，先设置： $env:HTTPS_PROXY = "http://127.0.0.1:端口"
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

    # 让大包更容易成功：关闭 HTTP/2 上传、加大缓冲；schannel 在本机不可用，改用 OpenSSL。
    git config http.sslBackend openssl
    git config http.version HTTP/1.1
    git config http.postBuffer 524288000

    $current = git remote get-url origin 2>$null
    if ($current -ne $RemoteUrl) {
        if ($current) { git remote set-url origin $RemoteUrl } else { git remote add origin $RemoteUrl }
    }

    # 按从旧到新的顺序逐提交推送：[提交, 说明, 预计上传量]
    $steps = @(
        @('47e3e31', 'source and docs', '0.2 MB'),
        @('adfaede', 'animation frames 1/6', '42.7 MB'),
        @('366a98e', 'animation frames 2/6', '42.5 MB'),
        @('a1a8f37', 'animation frames 3/6', '30.2 MB'),
        @('6d5df7e', 'animation frames 4/6', '36.2 MB'),
        @('40a4aeb', 'animation frames 5/6', '36.9 MB'),
        @('47698c0', 'animation frames 6/6', '29.6 MB'),
        @('03f8e43', 'animation frame manifest', '0.01 MB'),
        @('1d61ab0', 'setup notes and pnpm fix', '0.01 MB'),
        @('7e8ed3a', 'batch push helper', '0.01 MB')
    )

    for ($i = 0; $i -lt $steps.Count; $i++) {
        $number = $i + 1
        if ($number -lt $StartStep) { continue }
        $sha = $steps[$i][0]
        $label = $steps[$i][1]
        $size = $steps[$i][2]

        Write-Host ("Step {0}/{1}: {2} (~{3})" -f $number, $steps.Count, $label, $size) -ForegroundColor Cyan
        $attempt = 1
        while ($true) {
            git push origin "${sha}:refs/heads/main"
            if ($LASTEXITCODE -eq 0) { break }
            if ($attempt -ge $Retries) { throw "Step $number failed after $Retries attempts. Re-run: .\Push-InBatches.ps1 -StartStep $number" }
            $wait = [Math]::Min(60, 5 * $attempt)
            Write-Host ("  attempt {0} failed; retrying in {1}s. If a window asks for credentials, sign in there." -f $attempt, $wait) -ForegroundColor Yellow
            Start-Sleep -Seconds $wait
            $attempt++
        }
    }

    # 让本地 main 跟随远端最终状态
    git fetch origin main
    git branch --set-upstream-to=origin/main main
    Write-Host 'All steps pushed.' -ForegroundColor Green
    Write-Host "Open $RemoteUrl to verify."
}
finally {
    Pop-Location
}
