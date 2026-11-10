#Requires -Version 5.1
<#
  Xoa hoan toan game da dang. Xac nhan bang nhap 'XOA' khi duoc hoi.
  .\REMOVE-GAME.ps1 -Slug 'duck-grand-prix-pro'
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Slug)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
function Run([string]$name, [string[]]$arguments) {
    $old = $ErrorActionPreference
    try { $ErrorActionPreference = 'Continue'; & $name @arguments; $exitCode = $LASTEXITCODE }
    finally { $ErrorActionPreference = $old }
    if ($exitCode -ne 0) { throw "Lenh khong thanh cong: $name $($arguments -join ' ')" }
}
try {
    if ($Slug -notmatch '^[a-z0-9][a-z0-9-]{0,60}$') { throw 'Slug khong hop le.' }
    $statePath = Join-Path $PSScriptRoot '.edugame-setup.json'
    if (-not (Test-Path $statePath)) { throw 'Chua setup Firebase Spark.' }
    $state = Get-Content $statePath -Raw | ConvertFrom-Json
    $confirm = Read-Host "Go XOA de go vinh vien file hosting va document Firestore cua game '$Slug'"
    if ($confirm -cne 'XOA') { Write-Host 'Da huy xoa.'; return }
    $playPath = Join-Path $PSScriptRoot "game-host/play/$Slug.html"
    $downloadPath = Join-Path $PSScriptRoot "game-host/download/$Slug.html"
    if (Test-Path $playPath) { Remove-Item -LiteralPath $playPath -Force }
    if (Test-Path $downloadPath) { Remove-Item -LiteralPath $downloadPath -Force }
    Run 'firebase' @('deploy', '--only', 'hosting:games', '--project', [string]$state.projectId, '--non-interactive')
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $token = (& gcloud auth print-access-token 2>$null | Out-String).Trim()
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    if ($code -ne 0 -or -not $token) { throw 'Khong lay duoc Google access token de xoa metadata.' }
    $uri = "https://firestore.googleapis.com/v1/projects/$($state.projectId)/databases/(default)/documents/games/$Slug"
    try {
        Invoke-RestMethod -Method Delete -Uri $uri -Headers @{Authorization="Bearer $token"} -TimeoutSec 90 | Out-Null
    } catch {
        if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404) {
            $detail = $_.Exception.Message
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $detail = $_.ErrorDetails.Message }
            throw "Firestore API loi: $detail"
        }
    }
    Write-Host "Da go game '$Slug' khoi Firebase Hosting va danh muc Firestore." -ForegroundColor Green
} catch {
    Write-Host "GO GAME THAT BAI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Neu da xoa file hosting nhung Firestore con metadata, chay lai dung lenh de hoan tat.' -ForegroundColor Yellow
    exit 1
}
