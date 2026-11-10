#Requires -Version 5.1
# Legacy alias. Ban v1.4 chi dung Firebase Spark, khong co lenh Billing hay Cloud Run.
[CmdletBinding()]
param([string]$ProjectId = '', [string]$AdminEmail = '')
& (Join-Path $PSScriptRoot 'SETUP-FREE.ps1') -ProjectId $ProjectId -AdminEmail $AdminEmail
if ($LASTEXITCODE -is [int] -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
