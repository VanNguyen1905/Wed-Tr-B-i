#Requires -Version 5.1
<#
  CONTINUE-SAFE.ps1 - MOT LENH de kiem tra va tiep tuc he thong Spark an toan.
  Thu tu: (1) kiem thu cuc bo  (2) doc Firebase, chi doc  (3) SETUP-FREE (chay lai an toan)  (4) kiem tra online, chi doc.
  KHONG Billing, KHONG Cloud Run, KHONG Storage, KHONG xoa project/database/Hosting.
  Chay: powershell -NoProfile -ExecutionPolicy Bypass -File .\CONTINUE-SAFE.ps1
#>
[CmdletBinding()]
param(
    [string]$ProjectId = 'edugamehub-free-41819',
    [string]$WebAppId = '1:447641674653:web:c0888b2781030a3b29c574'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
. (Join-Path $root 'lib/Setup-Helpers.ps1')

function Stop-Here([string]$message) {
    Write-Host "`nDUNG: $message" -ForegroundColor Red
    exit 1
}
function Run-Child([string]$script, [string[]]$extra = @()) {
    # Chay script con trong PowerShell rieng de exit code dang tin cay.
    $path = Join-Path $root $script
    # | Out-Host: dau ra cua script con khong duoc tron vao gia tri tra ve (exit code).
    & powershell -NoProfile -ExecutionPolicy Bypass -File $path @extra | Out-Host
    return [int]$LASTEXITCODE
}

Write-Host '[1/4] Kiem thu cuc bo (khong goi Firebase)' -ForegroundColor Cyan
if ((Run-Child 'TEST-LOCAL.ps1') -ne 0) { Stop-Here 'TEST-LOCAL.ps1 co bai FAIL. Sua truoc khi tiep tuc.' }

Write-Host "`n[2/4] Doc trang thai Firebase (CHI DOC)" -ForegroundColor Cyan
$apps = Invoke-Cli -Exe 'firebase' -Arguments @('apps:list', '--project', $ProjectId, '--json')
if ($apps.Code -ne 0) { Stop-Here "firebase apps:list loi: $(Get-SafeSnippet ($apps.Stderr + ' ' + $apps.Stdout) 400)" }
$appsResult = Get-CliResult -Parsed (ConvertFrom-CliJson -Text $apps.Stdout -Context 'apps:list') -Context 'apps:list'
$webApps = @(Select-WebApps -Result $appsResult)
Write-Host "Web App tren Firebase: $($webApps.Count)"
foreach ($w in $webApps) { Write-Host "  - $($w.appId)  $($w.displayName)" }
$dbs = Invoke-Cli -Exe 'gcloud' -Arguments @('firestore', 'databases', 'list', '--project', $ProjectId, '--format=value(name)')
if ($dbs.Code -ne 0) { Stop-Here "gcloud firestore databases list loi: $(Get-SafeSnippet ($dbs.Stderr + ' ' + $dbs.Stdout) 400)" }
Write-Host "Firestore databases: $((@(ConvertTo-FirestoreDatabaseNames -Output $dbs.Stdout -ProjectId $ProjectId)) -join ', ')"
if (-not (Test-WebAppExists -ProjectId $ProjectId -AppId $WebAppId)) {
    Write-Host "Web App $WebAppId chua xac minh bang sdkconfig; SETUP se tim/tao lai theo quy tac khong trung." -ForegroundColor Yellow
}

Write-Host "`n[3/4] SETUP-FREE (chay lai an toan, idempotent)" -ForegroundColor Cyan
if ((Run-Child 'SETUP-FREE.ps1' @('-ProjectId', $ProjectId, '-WebAppId', $WebAppId)) -ne 0) {
    Stop-Here 'SETUP-FREE chua hoan tat. Xem thong bao o tren; script co the chay lai.'
}

Write-Host "`n[4/4] Kiem tra online (CHI DOC)" -ForegroundColor Cyan
if ((Run-Child 'TEST-ONLINE.ps1') -ne 0) { Stop-Here 'TEST-ONLINE.ps1 that bai.' }

Write-Host "`nHOAN TAT. Lenh nay khong bat Billing va khong xoa tai nguyen." -ForegroundColor Green
exit 0
