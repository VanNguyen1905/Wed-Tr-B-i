#Requires -Version 5.1
<#
  KIEM THU TAI MAY - KHONG goi Google/Firebase that, KHONG ghi du lieu, KHONG Billing.
  Thuc thi that cac ham trong lib/Setup-Helpers.ps1 voi dau ra CLI gia lap.
  Chay: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\TEST-LOCAL.ps1
  Exit code 0 = tat ca bai kiem tra DAT.
#>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$script:checks = 0
$script:failures = New-Object System.Collections.Generic.List[string]

function Check([bool]$ok, [string]$name) {
    $script:checks++
    if ($ok) { Write-Host "OK   $name" -ForegroundColor Green }
    else { $script:failures.Add($name); Write-Host "FAIL $name" -ForegroundColor Red }
}
function ThrowMessage([scriptblock]$block) {
    try { $null = & $block; return '' } catch { return [string]$_.Exception.Message }
}
function New-Resp([int]$Code = 0, [string]$Stdout = '', [string]$Stderr = '') {
    [pscustomobject]@{ Code = $Code; Stdout = $Stdout; Stderr = $Stderr }
}

# ---- Fake CLI: ghi lai moi lenh va tra ve phan hoi theo thu tu ----
$script:Rules = New-Object System.Collections.Generic.List[object]
$script:CallLog = New-Object System.Collections.Generic.List[string]
function Add-FakeRule([string]$Pattern, [object[]]$Responses) {
    $queue = New-Object System.Collections.Generic.List[object]
    foreach ($r in $Responses) { $queue.Add($r) }
    $script:Rules.Add([pscustomobject]@{ Pattern = $Pattern; Queue = $queue })
}
function Reset-Fakes { $script:Rules.Clear(); $script:CallLog.Clear() }
function Get-Calls([string]$Pattern) { @($script:CallLog | Where-Object { $_ -match $Pattern }) }

$script:FakeInvoker = {
    param([string]$exe, [string]$joined)
    $key = "$exe $joined"
    $script:CallLog.Add($key)
    foreach ($rule in $script:Rules) {
        if ($key -match $rule.Pattern) {
            if ($rule.Queue.Count -gt 1) { $resp = $rule.Queue[0]; $rule.Queue.RemoveAt(0) }
            else { $resp = $rule.Queue[0] }
            return $resp
        }
    }
    throw "Khong co fake CLI cho lenh: $key"
}

Write-Host '=== KIEM THU EDUGAME HUB FREE (THUC THI HAM THAT) ===' -ForegroundColor Cyan

# ---------- 1. Tep va cau truc ----------
Write-Host "`n--- 1. Tep va cau truc ---" -ForegroundColor Cyan
$files = @(
    'SETUP-FREE.ps1', 'FIRESTORE-DATABASES.ps1', 'lib/Setup-Helpers.ps1', 'CHECK-FIREBASE-READONLY.ps1',
    'PUBLISH-GAME.ps1', 'REMOVE-GAME.ps1', 'TEST-LOCAL.ps1', 'TEST-ONLINE.ps1', 'CONTINUE-SAFE.ps1', 'firebase.json',
    'firestore.rules.template', 'frontend/index.html', 'frontend/style.css', 'frontend/main.js',
    'frontend/firebase-config.js', 'game-host/index.html', 'sample/duck-grand-prix-pro.html'
)
foreach ($rel in $files) { Check (Test-Path -LiteralPath (Join-Path $root $rel) -PathType Leaf) "File ton tai: $rel" }

# ---------- 2. Ma hoa va cu phap PowerShell ----------
Write-Host "`n--- 2. Ma hoa va AST PowerShell ---" -ForegroundColor Cyan
$psFiles = @(Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File) + @(Get-ChildItem -LiteralPath (Join-Path $root 'lib') -Filter '*.ps1' -File)
foreach ($f in $psFiles) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $hasNonAscii = @($bytes | Where-Object { $_ -gt 127 }).Count -gt 0
    Check ((-not $hasNonAscii) -or $hasBom) "Ma hoa PS 5.1 (BOM neu co tieng Viet): $($f.Name)"
    $tokens = $null; $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$parseErrors)
    Check ($parseErrors.Count -eq 0) "Cu phap AST: $($f.Name)"
    foreach ($e in $parseErrors) { Write-Host "  $($e.Message)" -ForegroundColor Red }
}

# ---------- 3. Phan tich dau ra CLI (ham that, khong gia lap) ----------
Write-Host "`n--- 3. Phan tich dau ra CLI ---" -ForegroundColor Cyan
. (Join-Path $root 'lib/Setup-Helpers.ps1')
. (Join-Path $root 'FIRESTORE-DATABASES.ps1')
# Kiem thu Invoke-Cli THAT (cmd.exe co san tren Windows): tach stdout/stderr, giu exit code.
$script:CliInvoker = $null
$real = Invoke-Cli -Exe 'cmd' -Arguments @('/c', 'echo hi & echo err 1>&2 & exit 3')
Check ($real.Code -eq 3 -and $real.Stdout -match 'hi' -and $real.Stderr -match 'err') 'Invoke-Cli that: tach stdout/stderr, giu exit code'
$APPID = '1:447641674653:web:c0888b2781030a3b29c574'
# Dau ra that ban da thay tren terminal sau apps:create.
$observedCreate = @'
App ID: 1:447641674653:web:c0888b2781030a3b29c574
Display name: EduGame Hub Free

You can run this command to print out your new app's Google Services config:
firebase apps:sdkconfig WEB 1:447641674653:web:c0888b2781030a3b29c574
'@
Check ((Get-WebAppIdFromText -Text $observedCreate) -ceq $APPID) 'Lay App ID tu dau ra apps:create that (loi goc)'
Check ($null -eq (Get-WebAppIdFromText -Text '')) 'Dau ra rong -> khong co App ID'
Check ($null -eq (Get-WebAppIdFromText -Text 'Loi: khong co quyen')) 'Dau ra loi -> khong co App ID'

$warnJson = "Warning: a new version is available`n" + '{"status":"success","result":[]}' + "`nDone."
$p1 = ConvertFrom-CliJson -Text $warnJson -Context 't'
Check ($p1.status -ceq 'success') 'JSON co dong canh bao truoc/sau: van parse'
$emptyList = ConvertFrom-CliJson -Text '{"status":"success","result":[]}' -Context 't'
$emptyResult = Get-CliResult -Parsed $emptyList -Context 't'
Check (($emptyResult -is [System.Array]) -and @($emptyResult).Count -eq 0) 'Mang rong giu nguyen (khong bi lam phang thanh null)'
Check ((ThrowMessage { ConvertFrom-CliJson -Text 'khong co json' -Context 't' }) -match 'khong tim thay JSON') 'Dau ra khong co JSON -> bao loi ro rang'
Check ((ThrowMessage { ConvertFrom-CliJson -Text '' -Context 't' }) -match 'stdout rong') 'Dau ra rong -> bao loi ro rang'
Check ((ThrowMessage { ConvertFrom-CliJson -Text '{bad json}' -Context 't' }) -match 'khong hop le') 'JSON hong -> bao loi co kiem soat'
$errEnv = ConvertFrom-CliJson -Text '{"status":"error","error":{"message":"denied"}}' -Context 't'
Check ((ThrowMessage { Get-CliResult -Parsed $errEnv -Context 'apps:list' }) -match 'status=error') 'status=error -> nem loi, khong nuot'
$noResult = ConvertFrom-CliJson -Text '{"status":"success"}' -Context 't'
Check ((ThrowMessage { Get-CliResult -Parsed $noResult -Context 't' }) -match 'thieu truong result') 'Thieu truong result -> bao loi'

# ---------- 4. Chuan hoa danh sach Web App ----------
Write-Host "`n--- 4. Chuan hoa Web App ---" -ForegroundColor Cyan
$arr = ConvertFrom-Json -InputObject '[{"appId":"1:1:web:abc","platform":"WEB","displayName":"A"},{"appId":"1:2:ios:abc","platform":"IOS"}]'
Check (@(Select-WebApps -Result $arr).Count -eq 1) 'Loc dung: chi lay WEB, bo IOS'
Check (@(Select-WebApps -Result $arr)[0].appId -ceq '1:1:web:abc') 'Lay dung appId'
$obj = ConvertFrom-Json -InputObject '{"apps":[{"appId":"1:1:web:abc","platform":"web"}]}'
Check (@(Select-WebApps -Result $obj).Count -eq 1) 'Chap nhan { apps: [...] } va platform viet thuong'
Check (@(Select-WebApps -Result (ConvertFrom-Json -InputObject '[]')).Count -eq 0) 'Danh sach rong -> 0 app'
Check (@(Select-WebApps -Result (ConvertFrom-Json -InputObject '[{"appId":"web-garbage","platform":"WEB"}]')).Count -eq 0) 'appId sai dinh dang bi bo qua'
Check (@(Select-WebApps -Result (ConvertFrom-Json -InputObject '[{"platform":"WEB"}]')).Count -eq 0) 'Thieu appId bi bo qua'
Check (@(Select-WebApps -Result $null).Count -eq 0) 'Null -> 0 app'

# ---------- 5. Cau hinh Web SDK ----------
Write-Host "`n--- 5. Cau hinh Web SDK ---" -ForegroundColor Cyan
$jsonCfg = '{"status":"success","result":{"apiKey":"AIzaTEST123","authDomain":"p.firebaseapp.com","projectId":"p","appId":"' + $APPID + '"}}'
$cfgA = Get-FirebaseWebConfig -Text $jsonCfg
Check ($cfgA.apiKey -ceq 'AIzaTEST123' -and $cfgA.appId -ceq $APPID) 'Cau hinh JSON co wrapper result'
# Shape actually returned by Firebase CLI --json (result.sdkConfig, not result.apiKey).
$nestedSdkJson = '{"status":"success","result":{"fileName":"google-config.js","fileContents":"...","sdkConfig":{"apiKey":"AIzaNESTED123","authDomain":"p.firebaseapp.com","projectId":"p","appId":"' + $APPID + '"}}}'
$nestedCfg = Get-FirebaseWebConfig -Text $nestedSdkJson
Check ($nestedCfg.apiKey -ceq 'AIzaNESTED123' -and $nestedCfg.projectId -ceq 'p' -and $nestedCfg.appId -ceq $APPID) 'Firebase CLI that: result.sdkConfig duoc doc dung'
# Dinh dang JavaScript: day la gia dinh; ham van phai doc duoc theo khoa, neu khong se bao loi ro rang.
$jsCfg = "const firebaseConfig = {`n  apiKey: `"AIzaTEST123`",`n  authDomain: `"p.firebaseapp.com`",`n  projectId: `"p`",`n  appId: `"$APPID`"`n};"
$cfgB = Get-FirebaseWebConfig -Text $jsCfg
Check ($cfgB.projectId -ceq 'p') 'Cau hinh dang JavaScript: doc theo khoa'
Check ((ThrowMessage { Get-FirebaseWebConfig -Text '{"status":"success","result":{"projectId":"p","appId":"' + $APPID + '"}}' }) -match 'apiKey') 'Thieu apiKey -> bao loi'
Check ((ThrowMessage { Get-FirebaseWebConfig -Text '{"status":"success","result":{"apiKey":"k","projectId":"p","appId":"bad"}}' }) -match 'dinh dang Web App') 'appId sai -> bao loi'

# ---------- 6. Resolve-WebAppId: cac kich ban CLI ----------
Write-Host "`n--- 6. Nhan dien / tao Web App (gia lap CLI) ---" -ForegroundColor Cyan
$script:CliInvoker = $script:FakeInvoker
$listEmpty = New-Resp 0 '{"status":"success","result":[]}'
$listWithApp = New-Resp 0 ('{"status":"success","result":[{"appId":"' + $APPID + '","platform":"WEB","displayName":"EduGame Hub Free"}]}')
$sdkJson = New-Resp 0 ('{"status":"success","result":{"sdkConfig":{"apiKey":"AIzaTEST123","appId":"' + $APPID + '","projectId":"p"}}}')
$createOut = New-Resp 0 $observedCreate

# A. App ID da luu/truyen vao, xac minh duoc -> khong tao, khong liet ke
Reset-Fakes; Add-FakeRule 'apps:sdkconfig WEB .* --json$' @($sdkJson)
$rA = Resolve-WebAppId -ProjectId 'p' -KnownAppId $APPID -ListAttempts 3 -BaseDelaySeconds 0
Check ($rA.Source -eq 'known' -and $rA.AppId -ceq $APPID) 'A. Known App ID xac minh duoc -> dung luon'
Check ((Get-Calls 'apps:create').Count -eq 0) 'A. Khong goi apps:create'

# B. Lan dau list rong, lan 3 moi thay app (Firebase tre dong bo) -> khong tao trung
Reset-Fakes; Add-FakeRule 'apps:list' @($listEmpty, $listEmpty, $listWithApp)
$rB = Resolve-WebAppId -ProjectId 'p' -ListAttempts 3 -BaseDelaySeconds 0
Check ($rB.Source -eq 'listed' -and $rB.AppId -ceq $APPID) 'B. Tre dong bo: retry roi tim thay app'
Check ((Get-Calls 'apps:create').Count -eq 0) 'B. Khong tao app trung khi da ton tai'

# C. Liet ke that bai (IAM) -> phai DUNG, khong duoc tao app moi
Reset-Fakes; Add-FakeRule 'apps:list' @((New-Resp 1 '' 'PERMISSION_DENIED: missing permission'))
$msgC = ThrowMessage { Resolve-WebAppId -ProjectId 'p' -ListAttempts 2 -BaseDelaySeconds 0 }
Check ($msgC -match 'Khong liet ke duoc') 'C. Loi liet ke -> bao loi'
Check ((Get-Calls 'apps:create').Count -eq 0) 'C. Loi liet ke KHONG kich hoat apps:create'

# D. Chua co app, apps:create in App ID -> luu ngay qua callback
Reset-Fakes; Add-FakeRule 'apps:list' @($listEmpty); Add-FakeRule 'apps:create' @($createOut)
$script:savedId = ''; $script:beforeCalled = $false
$rD = Resolve-WebAppId -ProjectId 'p' -ListAttempts 2 -BaseDelaySeconds 0 `
    -OnBeforeCreate { $script:beforeCalled = $true } -OnAppIdKnown { param($id) $script:savedId = [string]$id }
Check ($rD.Source -eq 'created' -and $rD.AppId -ceq $APPID) 'D. Tao moi va lay App ID tu dau ra'
Check ($script:savedId -ceq $APPID) 'D. App ID duoc luu ngay sau khi tao (truoc khi list)'
Check $script:beforeCalled 'D. Danh dau truoc khi tao (chong trung neu gian doan)'

# E. apps:create bao da ton tai -> liet ke lai va tim thay
Reset-Fakes
Add-FakeRule 'apps:list' @($listEmpty, $listEmpty, $listEmpty, $listWithApp)
Add-FakeRule 'apps:create' @((New-Resp 1 '' 'Error: ALREADY_EXISTS: app exists'))
$rE = Resolve-WebAppId -ProjectId 'p' -ListAttempts 3 -BaseDelaySeconds 0
Check ($rE.Source -eq 'listed-after-create' -and $rE.AppId -ceq $APPID) 'E. Da ton tai -> liet ke lai, khong loi'

# F. Lan chay truoc da gui lenh tao nhung khong xac nhan -> KHONG tao lai
Reset-Fakes; Add-FakeRule 'apps:list' @($listEmpty)
$msgF = ThrowMessage { Resolve-WebAppId -ProjectId 'p' -CreateStartedEarlier $true -ListAttempts 2 -BaseDelaySeconds 0 }
Check ($msgF -match 'Khong tao lai de tranh trung') 'F. Lan truoc da tao nhung chua xac nhan -> dung, khong tao lai'
Check ((Get-Calls 'apps:create').Count -eq 0) 'F. Khong goi apps:create'

# G. Tao thanh cong nhung khong in App ID -> liet ke lai
Reset-Fakes
Add-FakeRule 'apps:list' @($listEmpty, $listEmpty, $listEmpty, $listWithApp)
Add-FakeRule 'apps:create' @((New-Resp 0 'Done.' ''))
$rG = Resolve-WebAppId -ProjectId 'p' -ListAttempts 3 -BaseDelaySeconds 0
Check ($rG.AppId -ceq $APPID) 'G. Khong co App ID trong dau ra -> tim lai bang list'

# H. apps:create that bai khong ro ly do -> bao loi, khong nuot
Reset-Fakes; Add-FakeRule 'apps:list' @($listEmpty); Add-FakeRule 'apps:create' @((New-Resp 1 '' 'Billing account required'))
$msgH = ThrowMessage { Resolve-WebAppId -ProjectId 'p' -ListAttempts 2 -BaseDelaySeconds 0 }
Check ($msgH -match 'apps:create that bai' -and $msgH -match 'Billing') 'H. Loi tao -> hien nguyen nhan CLI'

# I. Lay sdkconfig: thu --json truoc, that bai thi thu dang van ban
Reset-Fakes
Add-FakeRule 'apps:sdkconfig .*--json$' @((New-Resp 1 '' 'Error: unknown option --json'))
Add-FakeRule 'apps:sdkconfig WEB' @((New-Resp 0 "const firebaseConfig = { apiKey: `"AIzaX`", projectId: `"p`", appId: `"$APPID`" };"))
$cfgI = Get-WebAppSdkConfig -ProjectId 'p' -AppId $APPID -Attempts 1 -BaseDelaySeconds 0
Check ($cfgI.apiKey -ceq 'AIzaX') 'I. sdkconfig: fallback sang dang van ban khi --json loi'

# ---------- 7. Trang thai va merge ----------
Write-Host "`n--- 7. Trang thai .edugame-setup.json ---" -ForegroundColor Cyan
$existing = ConvertFrom-Json -InputObject ('{"projectId":"p","webAppId":"' + $APPID + '"}')
$merged = Merge-State -Existing $existing -Updates @{ appSiteId = 's' }
Check ($merged['webAppId'] -ceq $APPID -and $merged['appSiteId'] -ceq 's' -and $merged['projectId'] -ceq 'p') 'Merge khong lam mat webAppId khi luu thong tin khac'
$tmp = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($tmp, '{ khong phai json', (New-Object System.Text.UTF8Encoding($false)))
    Check ((ThrowMessage { Read-SetupState -Path $tmp }) -match 'bi hong') 'State hong -> bao loi ro, khong ghi de'
} finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
Check ($null -eq (Read-SetupState -Path (Join-Path $root 'khong-ton-tai.json'))) 'Chua co state -> null'
Check (Test-ProjectIdFormat 'edugamehub-free-41819') 'Project ID hop le'
Check (-not (Test-ProjectIdFormat 'Bad_Project')) 'Project ID sai bi tu choi'
$longSite = Get-GamesSiteId 'edugamehub-free-long-name-12'
Check ($longSite.Length -le 30 -and $longSite.EndsWith('-games')) 'Ten hosting site games khong vuot 30 ky tu'

# ---------- 8. Parser database Firestore ----------
Write-Host "`n--- 8. Parser database Firestore ---" -ForegroundColor Cyan
$project = 'edugamehub-free-41819'
$defaultName = "projects/$project/databases/(default)"
$otherName = "projects/$project/databases/archive"
Check (@(ConvertTo-FirestoreDatabaseNames -Output '' -ProjectId $project).Count -eq 0) 'Project moi: stdout rong'
Check (@(ConvertTo-FirestoreDatabaseNames -Output $defaultName -ProjectId $project)[0] -ceq $defaultName) 'Co (default)'
Check (@(ConvertTo-FirestoreDatabaseNames -Output "$defaultName`r`n$otherName`n$defaultName" -ProjectId $project).Count -eq 2) 'Nhieu database, loai trung'
Check ((ThrowMessage { ConvertTo-FirestoreDatabaseNames -Output '{"databases":[]}' -ProjectId $project }) -match 'dinh dang') 'JSON sai dinh dang bi tu choi'
Check ((ThrowMessage { ConvertTo-FirestoreDatabaseNames -Output 'projects/other-project-99/databases/(default)' -ProjectId $project }) -match 'project khac') 'Database cua project khac bi tu choi'

# ---------- 9. Kiem tra tinh an toan cua script (tinh tu source) ----------
Write-Host "`n--- 9. An toan cau hinh ---" -ForegroundColor Cyan
$setupSrc = [System.IO.File]::ReadAllText((Join-Path $root 'SETUP-FREE.ps1'), [System.Text.Encoding]::UTF8)
Check (-not ($setupSrc -match '(?i)billing\s+projects\s+link|cloud\s*run\s+deploy|storage:bucket|gsutil|storage\s+buckets')) 'SETUP khong co Billing/Cloud Run/Storage'
Check (-not ($setupSrc -match "'deploy', '--only', '[^']*\bauth\b")) 'SETUP khong deploy target auth (khong xac minh)'
$fbJson = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText((Join-Path $root 'firebase.json'), [System.Text.Encoding]::UTF8))
Check (-not (@($fbJson.PSObject.Properties.Name) -contains 'auth')) 'firebase.json khong chua khoa auth khong xac minh'
Check (@($fbJson.hosting).Count -eq 2) 'Hai Hosting target (app, games)'
Check ($setupSrc.Contains('Resolve-WebAppId') -and $setupSrc.Contains('Get-WebAppSdkConfig')) 'SETUP dung ham nhan dien Web App'
$rulesSrc = [System.IO.File]::ReadAllText((Join-Path $root 'firestore.rules.template'), [System.Text.Encoding]::UTF8)
Check ($rulesSrc.Contains('email_verified == true') -and $rulesSrc.Contains('allow create, delete: if false')) 'Rules: Admin xac minh email, client khong tao/xoa game'
$publishSrc = [System.IO.File]::ReadAllText((Join-Path $root 'PUBLISH-GAME.ps1'), [System.Text.Encoding]::UTF8)
Check ($publishSrc.Contains('UTF8.GetBytes($body)')) 'PUBLISH gui JSON tieng Viet dang UTF-8 bytes'

# ---------- 10. JavaScript va HTML ----------
Write-Host "`n--- 10. Frontend ---" -ForegroundColor Cyan
$node = Get-Command 'node' -ErrorAction SilentlyContinue
if ($node) {
    foreach ($js in @('frontend/main.js', 'frontend/firebase-config.js')) {
        & node --check (Join-Path $root $js) 2>&1 | Out-Host
        Check ($LASTEXITCODE -eq 0) "Cu phap JavaScript: $js"
    }
} else { Check $false 'Node.js chua co; khong kiem tra duoc cu phap JavaScript' }
$html = [System.IO.File]::ReadAllText((Join-Path $root 'frontend/index.html'), [System.Text.Encoding]::UTF8)
$js = [System.IO.File]::ReadAllText((Join-Path $root 'frontend/main.js'), [System.Text.Encoding]::UTF8)
foreach ($id in @([regex]::Matches($js, "\`$\('([^']+)'\)") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)) {
    Check ($html -match ('id\s*=\s*"' + [regex]::Escape($id) + '"')) "HTML co phan tu #$id"
}

# ---------- KET QUA ----------
$passed = $script:checks - $script:failures.Count
Write-Host "`nKet qua: $passed/$($script:checks) bai kiem tra DAT." -ForegroundColor Cyan
if ($script:failures.Count -gt 0) {
    Write-Host 'Bai FAIL:' -ForegroundColor Red
    foreach ($f in $script:failures) { Write-Host "  - $f" -ForegroundColor Red }
    Write-Host 'KHONG chay SETUP-FREE.ps1 khi con bai FAIL.' -ForegroundColor Red
    exit 1
}
Write-Host 'Kiem thu tai may DAT. Day KHONG phai bang chung Firebase that: chay CHECK-FIREBASE-READONLY.ps1 va TEST-ONLINE.ps1 sau setup.' -ForegroundColor Green
exit 0
