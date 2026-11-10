#Requires -Version 5.1
<#
  Kiem tra ket qua sau khi SETUP-FREE.ps1 trien khai thanh cong.
  Chi thuc hien doc du lieu qua gcloud/firebase/HTTPS, KHONG ghi/xoa/Billing.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$statePath = Join-Path $root '.edugame-setup.json'
if (-not (Test-Path -LiteralPath $statePath)) { throw 'Thieu .edugame-setup.json. Hay chay SETUP-FREE.ps1.' }
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$id = [string]$state.projectId
$app = [string]$state.appSiteId
$games = [string]$state.gamesSiteId
if (-not $id -or -not $app -or -not $games) { throw 'Project state chua day du.' }
function Must([string]$name, [string[]]$arguments) {
    Write-Host "`n=== $name ===" -ForegroundColor Cyan
    $prior = $ErrorActionPreference
    try { $ErrorActionPreference = 'Continue'; & $name @arguments; $exitCode = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prior }
    if ($exitCode -ne 0) { throw "Lenh kiem tra that bai: $name $($arguments -join ' ')" }
}
Must -name 'gcloud' -arguments @('services', 'list', '--enabled', '--project', $id, '--filter=config.name:firestore.googleapis.com', '--format=value(config.name)')
Must -name 'gcloud' -arguments @('firestore', 'databases', 'describe', '--database=(default)', '--project', $id, '--format=value(name)')
Must -name 'firebase' -arguments @('hosting:sites:list', '--project', $id)

$urls = @("https://$app.web.app", "https://$games.web.app/play/duck-grand-prix-pro.html")
foreach ($url in $urls) {
    Write-Host "`nGET $url" -ForegroundColor Cyan
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
    if ([int]$response.StatusCode -ne 200) { throw "HTTP $($response.StatusCode) cho $url" }
    if ($response.Content -notmatch '<!DOCTYPE html|<html') { throw "Khong co trang HTML hop le: $url" }
    Write-Host 'HTTP 200, co HTML.' -ForegroundColor Green
}
Write-Host "`nKiem tra metadata game mau trong Firestore..." -ForegroundColor Cyan
$prior = $ErrorActionPreference
try { $ErrorActionPreference = 'Continue'; $token = (& gcloud auth print-access-token 2>$null | Out-String).Trim(); $tokenCode = $LASTEXITCODE }
finally { $ErrorActionPreference = $prior }
if ($tokenCode -ne 0 -or -not $token) { throw 'Khong lay duoc access token. Chay gcloud auth login.' }
$docUrl = "https://firestore.googleapis.com/v1/projects/$id/databases/(default)/documents/games/duck-grand-prix-pro"
$document = Invoke-RestMethod -Uri $docUrl -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 30
if (-not $document.fields -or $document.fields.published.booleanValue -ne $true) { throw 'Game mau chua duoc publish trong Firestore.' }
Write-Host 'Game mau da duoc ghi vao Firestore va published=true.' -ForegroundColor Green

Write-Host "`nONLINE KIEM TRA DAT (API / database / 2 Hosting URLs / metadata Firestore)." -ForegroundColor Green
Write-Host 'Chua tu dong kiem thu dang nhap Google va tuong tac trong trinh duyet.' -ForegroundColor Yellow
