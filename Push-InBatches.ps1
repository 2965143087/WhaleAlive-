# Executable copy for PowerShell 5.1: no non-ASCII text anywhere in the file.
# (A file without BOM is decoded as the ANSI code page by PS 5.1, which corrupts CJK comments
#  and breaks quoting; the documented Push-InBatches.ps1 keeps Chinese comments and needs the .cmd wrapper.)
#
# Pushes one commit at a time so no single pack exceeds ~45 MB: a single 221 MB pack is cut off
# by the server mid-upload (RPC failed; curl 55 OpenSSL SSL_read: unexpected eof).
# Resume from a failed step with:  -StartStep N
[CmdletBinding()]
param(
    [string]$RemoteUrl = 'https://github.com/2965143087/WhaleAlive-.git',
    [int]$StartStep = 1,
    [int]$Retries = 5
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & git -C $projectRoot @Arguments
}

# Runs a git command whose failure must not abort the script (used for best-effort bookkeeping).
function Invoke-GitOptional {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    try { & git -C $projectRoot @Arguments 2>&1 | Out-Null } catch { }
    $global:LASTEXITCODE = 0
}

try {
    Invoke-Git rev-parse --git-dir 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Not a git repository: $projectRoot" }

    # schannel is unusable on this machine; HTTP/1.1 and a large buffer help each pack get through.
    Invoke-Git config http.sslBackend openssl | Out-Null
    Invoke-Git config http.version HTTP/1.1 | Out-Null
    Invoke-Git config http.postBuffer 524288000 | Out-Null

    $current = Invoke-Git remote get-url origin 2>$null
    if ($current -ne $RemoteUrl) {
        if ($current) {
            Invoke-Git remote set-url origin $RemoteUrl | Out-Null
        }
        else {
            Invoke-Git remote add origin $RemoteUrl | Out-Null
        }
    }

    $hashes = @(Invoke-Git rev-list --reverse HEAD)
    if ($hashes.Count -eq 0) { throw 'Cannot enumerate commits.' }

    $last = $hashes.Count
    $firstToRun = [Math]::Max(1, $StartStep)
    Write-Host ("{0} commits to push; running steps {1}..{2}." -f $last, $firstToRun, $last)

    for ($i = 0; $i -lt $hashes.Count; $i++) {
        $number = $i + 1
        if ($number -lt $StartStep) { continue }

        $sha = $hashes[$i]
        $subject = (Invoke-Git log -1 --format='%s' $sha)
        Write-Host ("Step {0}/{1}: {2}" -f $number, $last, $subject) -ForegroundColor Cyan

        $attempt = 1
        $pushed = $false
        while (-not $pushed) {
            Invoke-Git push origin "${sha}:refs/heads/main"
            if ($LASTEXITCODE -eq 0) {
                $pushed = $true
                break
            }
            if ($attempt -ge $Retries) {
                throw "Step $number failed after $Retries attempts. Re-run with -StartStep $number"
            }
            $wait = [Math]::Min(60, 5 * $attempt)
            Write-Host ("  attempt {0} failed; retrying in {1}s. Complete any sign-in window that appears." -f $attempt, $wait) -ForegroundColor Yellow
            Start-Sleep -Seconds $wait
            $attempt++
        }
    }

    # Best effort only: with $ErrorActionPreference='Stop', native stderr would otherwise abort here.
    Invoke-GitOptional fetch origin main
    Invoke-GitOptional branch --set-upstream-to=origin/main main
    Write-Host 'All commits pushed.' -ForegroundColor Green
    Write-Host "Verify: $RemoteUrl"
}
catch {
    Write-Host ("FAILED: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
