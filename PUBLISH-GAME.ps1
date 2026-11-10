#Requires -Version 5.1
<#
  Vi du:
  .\PUBLISH-GAME.ps1 -File "G:\Drive cua toi\game.html" -Title "Boc tham" -Category "Chon hoc sinh"
  Khong tai HTML len Cloud Storage. Firebase Hosting site games chua file HTML.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$File,
  [Parameter(Mandatory = $true)][string]$Title,
  [string]$Category = 'Khac',
  [string]$Description = '',
  [string]$Slug = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = $PSScriptRoot
function Capture([string]$exe, [string[]]$argv) {
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $value = (& $exe @argv 2>$null | Out-String).Trim()
        $exit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prior }
    if ($exit -ne 0) { throw "Lenh loi ($exit): $exe $($argv -join ' ')" }
    return $value
}
function Run([string]$exe, [string[]]$argv) {
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $exe @argv
        $exit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prior }
    if ($exit -ne 0) { throw "Lenh loi ($exit): $exe $($argv -join ' ')" }
}
try {
    $stateFile = Join-Path $root '.edugame-setup.json'
    if (-not (Test-Path $stateFile)) { throw 'Chua setup. Hay chay .\SETUP-FREE.ps1 truoc.' }
    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
    if (-not $state.projectId -or -not $state.gamesSiteId) { throw 'Thieu projectId / gamesSiteId trong .edugame-setup.json.' }
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { throw "Khong tim thay file: $File" }
    $source = (Resolve-Path -LiteralPath $File).Path
    if ([System.IO.Path]::GetExtension($source).ToLowerInvariant() -ne '.html') { throw 'Chi ho tro .html don le (khong nhan ZIP/EXE).' }
    $length = (Get-Item -LiteralPath $source).Length
    if ($length -gt 5MB) { throw 'File HTML vuot qua 5 MB.' }
    if ($length -lt 10) { throw 'File HTML rong hoac qua ngan.' }
    if ($Title.Trim().Length -lt 3 -or $Title.Length -gt 100) { throw 'Ten game phai tu 3 den 100 ky tu.' }
    if ($Category.Length -gt 80 -or $Description.Length -gt 800) { throw 'Danh muc/mo ta qua dai.' }
    if (-not $Slug) {
        # Sinh slug tu ten file, bo dau tieng Viet, khong su dung URL do nguoi dung tu nhap.
        $name = [System.IO.Path]::GetFileNameWithoutExtension($source).Replace(([char]0x0111).ToString(), 'd').Replace(([char]0x0110).ToString(), 'D')
        $decomposed = $name.Normalize([System.Text.NormalizationForm]::FormD)
        $slugText = [regex]::Replace($decomposed, '\p{Mn}', '')
        $Slug = ([regex]::Replace($slugText.ToLowerInvariant(), '[^a-z0-9]+', '-')).Trim('-')
    }
    if ($Slug -notmatch '^[a-z0-9][a-z0-9-]{0,60}$') { throw "Slug khong hop le: $Slug" }
    $playDir = Join-Path $root 'game-host/play'
    $downloadDir = Join-Path $root 'game-host/download'
    New-Item -ItemType Directory -Force -Path $playDir, $downloadDir | Out-Null
    $destPlay = Join-Path $playDir "$Slug.html"
    $destDownload = Join-Path $downloadDir "$Slug.html"
    if ($source -ne $destPlay) { Copy-Item -LiteralPath $source -Destination $destPlay -Force }
    if ($source -ne $destDownload) { Copy-Item -LiteralPath $source -Destination $destDownload -Force }
    Write-Host "Dang tai $Slug len Firebase Hosting site rieng..." -ForegroundColor Cyan
    Run 'firebase' @('deploy', '--only', 'hosting:games', '--project', [string]$state.projectId, '--non-interactive')
    Write-Host 'Dang metadata vao Firestore...' -ForegroundColor Cyan
    $token = Capture 'gcloud' @('auth', 'print-access-token')
    $headers = @{ Authorization = "Bearer $token" }
    $uri = "https://firestore.googleapis.com/v1/projects/$($state.projectId)/databases/(default)/documents/games/$Slug"
    $body = @{
      fields = @{
        title = @{ stringValue = $Title.Trim() }
        description = @{ stringValue = $Description.Trim() }
        category = @{ stringValue = $Category.Trim() }
        published = @{ booleanValue = $true }
      }
    } | ConvertTo-Json -Depth 12
    try {
        # Gui bytes UTF-8 tuong minh: Windows PowerShell 5.1 khong ap charset cho chuoi, se lam hong tieng Viet.
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        Invoke-RestMethod -Method Patch -Uri $uri -Headers $headers -Body $bodyBytes -ContentType 'application/json; charset=utf-8' -TimeoutSec 90 | Out-Null
    } catch {
        $detail = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $detail = $_.ErrorDetails.Message }
        throw "Firestore REST khong chap nhan gcloud access token: $detail. Xac minh cung tai khoan Google: gcloud auth list; neu can chay gcloud auth login."
    }
    Write-Host "THANH CONG! Game: https://$($state.gamesSiteId).web.app/play/$Slug.html" -ForegroundColor Green
    Write-Host "Thu vien: https://$($state.appSiteId).web.app" -ForegroundColor Green
} catch {
    Write-Host "DANG GAME THAT BAI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Neu file da deploy nhung Firestore loi, chay lai cung lenh de dong bo danh muc.' -ForegroundColor Yellow
    exit 1
}
