#Requires -Version 5.1
<#
  Chi DOC Google Cloud. Khong tao project/database, khong deploy, khong Billing.
  Sau khi chay TEST-LOCAL.ps1, dung lenh nay de kiem tra gcloud output that.
#>
[CmdletBinding()]
param([string]$ProjectId = 'edugamehub-free-41819')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'FIRESTORE-DATABASES.ps1')
try {
    if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) { throw 'Khong tim thay gcloud.' }
    $old = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $raw = (& gcloud firestore databases list --project $ProjectId '--format=value(name)' 2>$null | Out-String).Trim()
        $status = $LASTEXITCODE
    } finally { $ErrorActionPreference = $old }
    if ($status -ne 0) {
        Write-Host 'gcloud dang bao loi. Chay lai lenh ben duoi de xem nguyen van:' -ForegroundColor Red
        Write-Host "gcloud firestore databases list --project $ProjectId --format='value(name)'"
        exit 1
    }
    $names = @(ConvertTo-FirestoreDatabaseNames -Output $raw -ProjectId $ProjectId)
    Write-Host 'DOC API THANH CONG, khong co thay doi du lieu.' -ForegroundColor Green
    if ($names.Count -eq 0) {
        Write-Host 'Project CHUA co database Firestore (script se tao default).'
    } else {
        foreach ($name in $names) { Write-Host "Database: $name" }
    }
    exit 0
} catch {
    Write-Host "CHECK READONLY KHONG DAT: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
