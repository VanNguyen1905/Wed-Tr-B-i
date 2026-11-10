#Requires -Version 5.1
<#
  EDU GAME HUB FREE - Firebase Spark, khong Cloud Run, khong Storage, khong Billing.
  Chay: powershell -NoProfile -ExecutionPolicy Bypass -File .\SETUP-FREE.ps1
  Co the chay lai an toan. Trang thai luu o .edugame-setup.json.
  Neu Web App da tao tren Firebase nhung script bi gian doan, them -WebAppId APP_ID
  (lay bang: firebase apps:list --project PROJECT_ID --json).
#>
[CmdletBinding()]
param(
    [string]$ProjectId = '',
    [string]$AdminEmail = '',
    [string]$Region = 'asia-southeast1',
    [string]$WebAppId = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = $PSScriptRoot
$stateFile = Join-Path $root '.edugame-setup.json'
. (Join-Path $root 'lib/Setup-Helpers.ps1')
. (Join-Path $root 'FIRESTORE-DATABASES.ps1')

function Step([string]$message) { Write-Host "`n=== $message ===" -ForegroundColor Cyan }
function Need([string]$exe, [string]$install) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { throw "Chua co $exe. $install" }
}
function Run([string]$exe, [string[]]$argv) {
    # Lenh chay that (deploy, tao database): stream ra console de thay tien trinh.
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $exe @argv
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    if ($code -ne 0) { throw "Lenh THAT BAI (exit $code): $exe $($argv -join ' ')" }
}
function Save-State([hashtable]$Updates) {
    $existing = Read-SetupState -Path $stateFile
    $merged = Merge-State -Existing $existing -Updates $Updates
    Write-Utf8NoBom $stateFile ($merged | ConvertTo-Json -Depth 6)
}
function HostingSites([string]$project) {
    $r = Invoke-Cli -Exe 'firebase' -Arguments @('hosting:sites:list', '--project', $project, '--json')
    if ($r.Code -ne 0) { throw "firebase hosting:sites:list that bai (exit $($r.Code)): $(Get-SafeSnippet ($r.Stderr + ' ' + $r.Stdout) 500)" }
    $result = Get-CliResult -Parsed (ConvertFrom-CliJson -Text $r.Stdout -Context 'hosting:sites:list') -Context 'hosting:sites:list'
    if ($null -eq $result -or -not (@($result.PSObject.Properties.Name) -contains 'sites')) {
        throw 'firebase hosting:sites:list khong tra ve truong sites. Kiem tra phien ban Firebase CLI.'
    }
    return @($result.sites | Where-Object {
        $null -ne $_ -and @($_.PSObject.Properties.Name) -contains 'name' -and -not [string]::IsNullOrWhiteSpace([string]$_.name)
    })
}

try {
    Step '1/8: Kiem tra Firebase CLI va Google Cloud CLI'
    Need 'gcloud' 'Cai: winget install -e --id Google.CloudSDK'
    Need 'npm' 'Cai: winget install -e --id OpenJS.NodeJS.LTS'
    if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) { Run 'npm' @('install', '-g', 'firebase-tools') }
    Need 'firebase' 'Cai: npm install -g firebase-tools'
    $fbVersion = Invoke-Cli -Exe 'firebase' -Arguments @('--version')
    $gcVersion = Invoke-Cli -Exe 'gcloud' -Arguments @('--version')
    Write-Host "Firebase CLI: $(($fbVersion.Stdout -split "`n")[0].Trim())"
    Write-Host "Google Cloud CLI: $((($gcVersion.Stdout -split "`n")[0]).Trim())"

    Step '2/8: Dang nhap Google (KHONG YEU CAU THE THANH TOAN)'
    $acc = Invoke-Cli -Exe 'gcloud' -Arguments @('auth', 'list', '--filter=status:ACTIVE', '--format=value(account)')
    $account = ''
    if ($acc.Code -eq 0) { $account = (($acc.Stdout -split "`n") | Where-Object { $_.Trim() } | Select-Object -First 1) }
    if ($account) { $account = $account.Trim() }
    if (-not $account) {
        Run 'gcloud' @('auth', 'login')
        $acc = Invoke-Cli -Exe 'gcloud' -Arguments @('auth', 'list', '--filter=status:ACTIVE', '--format=value(account)')
        if ($acc.Code -eq 0) { $account = (($acc.Stdout -split "`n") | Where-Object { $_.Trim() } | Select-Object -First 1) }
        if ($account) { $account = $account.Trim() }
    }
    if (-not $account -or $account -notmatch '^[^@\s]+@[^@\s]+$') { throw 'Google Cloud CLI chua dang nhap.' }
    $fbList = Invoke-Cli -Exe 'firebase' -Arguments @('projects:list', '--json')
    if ($fbList.Code -ne 0) { Run 'firebase' @('login') }

    $state = Read-SetupState -Path $stateFile
    $stateProject = [string](Get-StateValue $state 'projectId')
    if (-not $AdminEmail) {
        $stateAdmin = [string](Get-StateValue $state 'adminEmail')
        if ($stateAdmin) { $AdminEmail = $stateAdmin } else { $AdminEmail = $account }
    }
    $AdminEmail = $AdminEmail.Trim().ToLowerInvariant()
    if ($AdminEmail -notmatch '^[^@\s]+@[^@\s]+$') { throw 'AdminEmail khong hop le.' }
    Write-Host "Google: $account | Admin: $AdminEmail" -ForegroundColor Green

    Step '3/8: Tao hoac tiep tuc Firebase project Spark'
    if (-not $ProjectId) {
        if ($stateProject) { $ProjectId = $stateProject }
        else { $ProjectId = 'edugamehub-free-' + (Get-Random -Minimum 10000 -Maximum 99999) }
    }
    $ProjectId = $ProjectId.Trim().ToLowerInvariant()
    if (-not (Test-ProjectIdFormat $ProjectId)) { throw "Project ID khong hop le: $ProjectId" }
    if ($stateProject -and $stateProject -cne $ProjectId) {
        throw "Trang thai hien tai thuoc project '$stateProject', ban yeu cau '$ProjectId'. Dung doi project de tranh tao tai nguyen thu hai."
    }
    $gamesSite = Get-GamesSiteId $ProjectId
    Save-State @{ projectId = $ProjectId; gamesSiteId = $gamesSite; adminEmail = $AdminEmail; region = $Region; mode = 'Spark' }
    $existing = Invoke-Cli -Exe 'gcloud' -Arguments @('projects', 'describe', $ProjectId, '--format=value(projectId)')
    if ($existing.Code -eq 0 -and (($existing.Stdout -split "`n")[0].Trim() -ceq $ProjectId)) {
        Write-Host "Tai su dung project: $ProjectId" -ForegroundColor Green
    } else {
        Run 'firebase' @('projects:create', $ProjectId, '--display-name', 'EduGame Hub Free', '--non-interactive')
    }
    Write-Host 'Goi su dung: Spark (khong lien ket Billing trong script).' -ForegroundColor Green

    # Firebase KHONG tu tao default Hosting site luc tao project.
    $sites = @(HostingSites $ProjectId)
    if ($sites.Count -eq 0) { Run 'firebase' @('hosting:sites:create', $ProjectId, '--project', $ProjectId) }
    $defaultSite = $null
    for ($attempt = 0; $attempt -lt 8; $attempt++) {
        $sites = @(HostingSites $ProjectId)
        $defaultSite = $sites | Where-Object { [string]$_.type -eq 'DEFAULT_SITE' } | Select-Object -First 1
        if ($defaultSite) { break }
        Start-Sleep -Seconds 3
    }
    if (-not $defaultSite) { throw 'Khong tim thay default Hosting site. Chay firebase hosting:sites:list --project PROJECT_ID de kiem tra.' }
    $appSite = ([string]$defaultSite.name).Split('/')[-1]
    if (-not $appSite) { throw 'Khong xac dinh duoc ten default Hosting site.' }
    Save-State @{ appSiteId = $appSite }
    Write-Host "Default site: $appSite" -ForegroundColor Green

    Step '4/8: Bat Firestore API, Identity Toolkit API va tao database (Spark)'
    Run 'gcloud' @('services', 'enable', 'firestore.googleapis.com', 'identitytoolkit.googleapis.com', '--project', $ProjectId, '--quiet')
    $databaseResult = $null
    for ($attempt = 1; $attempt -le 8; $attempt++) {
        $databaseResult = Invoke-Cli -Exe 'gcloud' -Arguments @('firestore', 'databases', 'list', '--project', $ProjectId, '--format=value(name)')
        if ($databaseResult.Code -eq 0) { break }
        Write-Host "Firestore API chua san sang ($attempt/8): $(Get-SafeSnippet $databaseResult.Stderr 160)" -ForegroundColor Yellow
        Start-Sleep -Seconds 6
    }
    if ($databaseResult.Code -ne 0) {
        throw "Khong truy van duoc Firestore databases sau 8 lan thu. Loi cuoi: $(Get-SafeSnippet ($databaseResult.Stderr + ' ' + $databaseResult.Stdout) 500)"
    }
    $databaseNames = @(ConvertTo-FirestoreDatabaseNames -Output $databaseResult.Stdout -ProjectId $ProjectId)
    $defaultName = "projects/$ProjectId/databases/(default)"
    if ($databaseNames -contains $defaultName) {
        Write-Host 'Firestore (default) da ton tai, bo qua buoc tao database.' -ForegroundColor Green
    } elseif ($databaseNames.Count -gt 0) {
        throw "Da co database khac: $($databaseNames -join ', '). Khong tu tao them vi Spark chi cap free tier cho 1 database."
    } else {
        Write-Host "Chua co database. Tao Firestore Native (default) tai $Region..." -ForegroundColor Cyan
        $created = $false
        for ($attempt = 1; $attempt -le 5; $attempt++) {
            $probe = Invoke-Cli -Exe 'gcloud' -Arguments @('firestore', 'databases', 'list', '--project', $ProjectId, '--format=value(name)')
            if ($probe.Code -ne 0) { throw "Khong kiem tra duoc database truoc khi tao: $(Get-SafeSnippet $probe.Stderr 400)" }
            $namesNow = @(ConvertTo-FirestoreDatabaseNames -Output $probe.Stdout -ProjectId $ProjectId)
            if ($namesNow -contains $defaultName) { $created = $true; break }
            if ($namesNow.Count -gt 0) { throw 'Project da co database khac; dung de bao ve free tier.' }
            try {
                Run 'firebase' @('firestore:databases:create', '(default)', '--location', $Region, '--project', $ProjectId)
                $created = $true
                break
            } catch {
                Write-Host "Tao database chua thanh cong ($attempt/5): $($_.Exception.Message)" -ForegroundColor Yellow
                if ($attempt -eq 5) { throw }
                Start-Sleep -Seconds 8
            }
        }
        if (-not $created) { throw 'Khong the tao Firestore database (default).' }
        Write-Host 'Da tao/kiem tra Firestore Native (default).' -ForegroundColor Green
    }

    Step '5/8: Tao hoac nhan dien Firebase Web App, tu dien config'
    $state = Read-SetupState -Path $stateFile
    $known = $WebAppId
    if (-not $known) { $known = [string](Get-StateValue $state 'webAppId') }
    $createStarted = [bool](Get-StateValue $state 'webAppCreateStarted')
    $app = Resolve-WebAppId -ProjectId $ProjectId -KnownAppId $known -CreateStartedEarlier $createStarted `
        -OnBeforeCreate { Save-State @{ webAppCreateStarted = $true } } `
        -OnAppIdKnown { param($id) Save-State @{ webAppId = [string]$id; webAppCreateStarted = $false } }
    $appId = [string]$app.AppId
    Save-State @{ webAppId = $appId; webAppCreateStarted = $false }
    Write-Host "Web App: $appId (nguon: $($app.Source))" -ForegroundColor Green
    $sdk = Get-WebAppSdkConfig -ProjectId $ProjectId -AppId $appId
    if ($sdk.projectId -cne $ProjectId) { throw "Cau hinh Web SDK thuoc project '$($sdk.projectId)', khong phai '$ProjectId'." }
    if ($sdk.appId -cne $appId) { throw "appId trong cau hinh ($($sdk.appId)) khac App ID da chon ($appId)." }
    $webConfig = [ordered]@{
        adminEmail = $AdminEmail
        gamesOrigin = "https://$gamesSite.web.app"
        firebaseConfig = [ordered]@{
            apiKey = [string]$sdk.apiKey
            authDomain = "$appSite.firebaseapp.com"
            projectId = $ProjectId
            appId = $appId
        }
    }
    $jsonConfig = $webConfig | ConvertTo-Json -Depth 15
    Write-Utf8NoBom (Join-Path $root 'frontend/firebase-config.js') "// Firebase web config is public. Do NOT put service account keys here.`nwindow.EDUGAME_CONFIG = $jsonConfig;"

    Step '6/8: Cau hinh Firestore Rules (Admin theo email da xac minh)'
    $rules = [System.IO.File]::ReadAllText((Join-Path $root 'firestore.rules.template'), [System.Text.Encoding]::UTF8)
    $rules = $rules.Replace('SETUP_ADMIN_EMAIL', $AdminEmail.Replace("'", ''))
    Write-Utf8NoBom (Join-Path $root 'firestore.rules') $rules

    Step '7/8: Tao site game rieng va deploy Hosting + Firestore Rules'
    $sites = @(HostingSites $ProjectId)
    $gameSiteExists = @($sites | Where-Object { ([string]$_.name).Split('/')[-1] -eq $gamesSite }).Count -gt 0
    if (-not $gameSiteExists) { Run 'firebase' @('hosting:sites:create', $gamesSite, '--project', $ProjectId) }
    Run 'firebase' @('target:apply', 'hosting', 'app', $appSite, '--project', $ProjectId)
    Run 'firebase' @('target:apply', 'hosting', 'games', $gamesSite, '--project', $ProjectId)
    Run 'firebase' @('deploy', '--only', 'firestore:rules,hosting', '--project', $ProjectId, '--non-interactive')

    # Google Sign-In: chi doc trang thai. Firebase Spark bat provider qua Console, script khong gia dinh bat duoc.
    $googleOk = $false
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $tokenOut = (& gcloud auth print-access-token 2>$null | Out-String).Trim()
        $tokenCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prior }
    if ($tokenCode -eq 0 -and $tokenOut) {
        try {
            $idp = 'https://identitytoolkit.googleapis.com/admin/v2/projects/' + $ProjectId + '/defaultSupportedIdpConfigs/google.com'
            $null = Invoke-RestMethod -Method Get -Uri $idp -Headers @{ Authorization = "Bearer $tokenOut" } -TimeoutSec 30
            $googleOk = $true
            Write-Host 'Google Sign-In: da bat.' -ForegroundColor Green
        } catch {
            $status = 0
            if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
            if ($status -eq 404) {
                Write-Host 'Google Sign-In: CHUA BAT.' -ForegroundColor Yellow
                Write-Host "Mo https://console.firebase.google.com/project/$ProjectId/authentication/providers , bat Google, chon email $AdminEmail lam support email, roi chay lai SETUP-FREE.ps1." -ForegroundColor Yellow
            } else {
                Write-Host "Khong xac minh duoc Google Sign-In (HTTP $status). Kiem tra thu cong trong Authentication > Sign-in method." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host 'Khong lay duoc token de kiem tra Google Sign-In. Kiem tra thu cong.' -ForegroundColor Yellow
    }
    $tokenOut = $null

    Step '8/8: Dang game mau va kiem tra website'
    & (Join-Path $root 'PUBLISH-GAME.ps1') -File (Join-Path $root 'sample/duck-grand-prix-pro.html') `
       -Title 'Đua vịt Grand Prix Pro' -Category 'Chọn học sinh' `
       -Description 'Đua vịt chọn học sinh trả bài, hỗ trợ tối đa 50 học sinh.' -Slug 'duck-grand-prix-pro'
    if ($LASTEXITCODE -ne 0) { throw 'Khong dang duoc game mau.' }
    $homepage = "https://$appSite.web.app"
    Write-Host "`nHOAN TAT SETUP SPARK - KHONG LIEN KET BILLING" -ForegroundColor Green
    Write-Host "Trang giao vien: $homepage" -ForegroundColor Green
    Write-Host "Hosting tro choi: https://$gamesSite.web.app" -ForegroundColor Cyan
    Write-Host "Admin: $AdminEmail"
    if (-not $googleOk) {
        Write-Host 'CANH BAO: Google Sign-In chua duoc xac nhan. Dang nhap quan tri se khong hoat dong cho den khi bat provider.' -ForegroundColor Yellow
        exit 2
    }
    Write-Host 'Dang game moi: .\PUBLISH-GAME.ps1 -File "D:\duong-dan\game.html" -Title "Ten game"' -ForegroundColor Yellow
    Start-Process $homepage
    exit 0
} catch {
    Write-Host "`nDUNG O BUOC LOI: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Trang thai da luu o: $stateFile. KHONG xoa project/database/Hosting; chay lai script de tiep tuc." -ForegroundColor Yellow
    exit 1
}
