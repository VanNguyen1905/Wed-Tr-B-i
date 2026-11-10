#Requires -Version 5.1
<#
  Ham helper cho SETUP-FREE.ps1 va TEST-LOCAL.ps1.
  File nay KHONG tu chay gi va KHONG goi Google/Firebase truc tiep.
  Tat ca lenh CLI di qua Invoke-Cli, de kiem thu co the thay the bang gia lap.
  Tuong thich Windows PowerShell 5.1 va PowerShell 7.
#>
Set-StrictMode -Version Latest

$script:WebAppIdPattern = '^1:\d+:web:[0-9a-fA-F]+$'

function Get-SafeSnippet {
    # Rut gon dau ra CLI de hien thi loi. Khong dung cho token.
    param([AllowNull()][string]$Text, [int]$Max = 400)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '(rong)' }
    $clean = ($Text -replace '\s+', ' ').Trim()
    if ($clean.Length -gt $Max) { return $clean.Substring(0, $Max) + '...' }
    return $clean
}

# Test co the gan scriptblock param($exe, $joinedArgs) de gia lap CLI. Trong SETUP-FREE luon la $null.
$script:CliInvoker = $null

function Invoke-Cli {
    # Chay lenh va thu stdout/stderr RIENG BIET. Khong nuot loi.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Exe,
        [string[]]$Arguments = @()
    )
    if ($null -ne $script:CliInvoker) {
        return (& $script:CliInvoker $Exe ($Arguments -join ' '))
    }
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& $Exe @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prior }
    $out = New-Object System.Collections.Generic.List[string]
    $err = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line -is [System.Management.Automation.ErrorRecord]) { $err.Add([string]$line.ToString()) }
        else { $out.Add([string]$line) }
    }
    return [pscustomobject]@{
        Code   = [int]$code
        Stdout = ($out -join "`n")
        Stderr = ($err -join "`n")
    }
}

function ConvertFrom-CliJson {
    # Tach JSON khoi dau ra co the co dong canh bao truoc/sau JSON.
    [CmdletBinding()]
    param([AllowNull()][string]$Text, [string]$Context = 'CLI')
    if ([string]::IsNullOrWhiteSpace($Text)) { throw "$Context : stdout rong, khong co JSON." }
    $start = $Text.IndexOfAny([char[]]@('{', '['))
    $end = $Text.LastIndexOfAny([char[]]@('}', ']'))
    if ($start -lt 0 -or $end -le $start) {
        throw "$Context : khong tim thay JSON. Dau ra: $(Get-SafeSnippet $Text)"
    }
    $candidate = $Text.Substring($start, $end - $start + 1)
    try {
        # Dau , giu nguyen mang rong: neu khong, PowerShell lam phang [] thanh $null.
        return ,(ConvertFrom-Json -InputObject $candidate)
    } catch {
        throw "$Context : JSON khong hop le ($($_.Exception.Message)). Dau ra: $(Get-SafeSnippet $Text)"
    }
}

function Get-CliResult {
    # Firebase CLI --json tra { status, result } hoac { status, error }.
    [CmdletBinding()]
    param([AllowNull()]$Parsed, [string]$Context = 'CLI')
    if ($null -eq $Parsed) { throw "$Context : JSON rong." }
    if ($Parsed -is [System.Array]) { return ,$Parsed }
    $names = @($Parsed.PSObject.Properties.Name)
    if ($names -contains 'status') {
        if ([string]$Parsed.status -ne 'success') {
            $detail = ''
            if ($names -contains 'error') { $detail = ($Parsed.error | ConvertTo-Json -Compress -Depth 6) }
            throw "$Context : status=$($Parsed.status). $(Get-SafeSnippet $detail 500)"
        }
        if ($names -contains 'result') {
            if ($Parsed.result -is [System.Array]) { return ,$Parsed.result }
            return $Parsed.result
        }
        throw "$Context : JSON co status=success nhung thieu truong result."
    }
    return $Parsed
}

function Get-WebAppIdFromText {
    # Lay App ID tu dong "App ID: 1:...:web:..." in ra boi apps:create.
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $m = [regex]::Match($Text, 'App ID:\s*(1:\d+:web:[0-9a-fA-F]+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Select-WebApps {
    # Chap nhan cac hinh dang: mang truc tiep, { apps: [...] }, hoac mot doi tuong app.
    param([AllowNull()]$Result)
    $apps = New-Object System.Collections.Generic.List[object]
    if ($null -eq $Result) { return ,$apps.ToArray() }
    $items = @()
    if ($Result -is [System.Array]) { $items = @($Result) }
    elseif ($Result.PSObject.Properties.Name -contains 'apps') { $items = @($Result.apps) }
    elseif ($Result.PSObject.Properties.Name -contains 'appId') { $items = @($Result) }
    foreach ($item in $items) {
        if ($null -eq $item) { continue }
        $names = @($item.PSObject.Properties.Name)
        if (-not ($names -contains 'appId') -or -not ($names -contains 'platform')) { continue }
        if (([string]$item.platform).ToUpperInvariant() -ne 'WEB') { continue }
        $appId = [string]$item.appId
        if ($appId -notmatch $script:WebAppIdPattern) { continue }
        $display = ''
        if ($names -contains 'displayName') { $display = [string]$item.displayName }
        $apps.Add([pscustomobject]@{ appId = $appId; platform = 'WEB'; displayName = $display })
    }
    return ,$apps.ToArray()
}

function Get-FirebaseWebConfig {
    # Doc cau hinh Web SDK. Thu JSON truoc; neu CLI in dang JavaScript thi doc theo khoa.
    [CmdletBinding()]
    param([AllowNull()][string]$Text)
    $keys = @('apiKey', 'authDomain', 'projectId', 'appId', 'storageBucket', 'messagingSenderId')
    $config = @{}
    if (-not [string]::IsNullOrWhiteSpace($Text)) {
        $jsonOk = $false
        try {
            $parsed = ConvertFrom-CliJson -Text $Text -Context 'sdkconfig'
            $result = Get-CliResult -Parsed $parsed -Context 'sdkconfig'
            if ($null -ne $result -and -not ($result -is [System.Array])) {
                # Firebase CLI --json returns { status: success, result: { sdkConfig: {...}, fileContents: ... } }.
                # Older tooling can return config directly under result; support both shapes.
                $names = @($result.PSObject.Properties.Name)
                if ($names -contains 'sdkConfig' -and $null -ne $result.sdkConfig) {
                    $result = $result.sdkConfig
                    $names = @($result.PSObject.Properties.Name)
                }
                foreach ($k in $keys) { if ($names -contains $k) { $config[$k] = [string]$result.$k } }
                # Do not mark partial/unrelated JSON as successfully parsed.
                $jsonOk = ($config.ContainsKey('apiKey') -and $config.ContainsKey('appId') -and $config.ContainsKey('projectId'))
            }
        } catch { $jsonOk = $false }
        if (-not $jsonOk) {
            foreach ($k in $keys) {
                $m = [regex]::Match($Text, '["'']?' + $k + '["'']?\s*:\s*["'']([^"'']+)["'']')
                if ($m.Success) { $config[$k] = $m.Groups[1].Value }
            }
        }
    }
    foreach ($req in @('apiKey', 'appId', 'projectId')) {
        if (-not $config.ContainsKey($req) -or [string]::IsNullOrWhiteSpace([string]$config[$req])) {
            throw "Cau hinh Web SDK thieu truong $req. Dau ra: $(Get-SafeSnippet $Text 200)"
        }
    }
    if ([string]$config.appId -notmatch $script:WebAppIdPattern) {
        throw "appId trong cau hinh khong dung dinh dang Web App: $($config.appId)"
    }
    return $config
}

function Test-WebAppExists {
    # Xac minh App ID bang sdkconfig (chi doc). Tra $true chi khi CLI xac nhan duoc cau hinh.
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$ProjectId, [Parameter(Mandatory = $true)][string]$AppId)
    if ($AppId -notmatch $script:WebAppIdPattern) { return $false }
    $r = Invoke-Cli -Exe 'firebase' -Arguments @('apps:sdkconfig', 'WEB', $AppId, '--project', $ProjectId, '--json')
    if ($r.Code -ne 0) { return $false }
    try { $null = Get-FirebaseWebConfig -Text $r.Stdout; return $true } catch { return $false }
}

function Find-WebAppWithRetry {
    # Tra ve @{ AppId; Listed; LastError }. Listed=$true nghia la lenh list THANH CONG (co the rong).
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$ProjectId, [int]$Attempts = 6, [int]$BaseDelaySeconds = 3)
    $listed = $false
    $lastError = ''
    for ($i = 1; $i -le $Attempts; $i++) {
        $r = Invoke-Cli -Exe 'firebase' -Arguments @('apps:list', '--project', $ProjectId, '--json')
        if ($r.Code -ne 0) {
            $lastError = Get-SafeSnippet ($r.Stderr + ' ' + $r.Stdout) 300
        } else {
            try {
                $parsed = ConvertFrom-CliJson -Text $r.Stdout -Context 'apps:list'
                $apps = @(Select-WebApps -Result (Get-CliResult -Parsed $parsed -Context 'apps:list'))
                $listed = $true
                if ($apps.Count -gt 0) { return @{ AppId = [string]$apps[0].appId; Listed = $true; LastError = '' } }
                $lastError = 'Danh sach app khong co Web App nao.'
            } catch {
                $lastError = $_.Exception.Message
            }
        }
        if ($i -lt $Attempts -and $BaseDelaySeconds -gt 0) { Start-Sleep -Seconds ($BaseDelaySeconds * $i) }
    }
    return @{ AppId = $null; Listed = $listed; LastError = $lastError }
}

function Resolve-WebAppId {
    # Thu tu an toan, khong tao trung:
    #  1) App ID da luu/truyen vao, xac minh bang sdkconfig.
    #  2) Liet ke app (co retry vi Firebase co the tre dong bo).
    #  3) Chi tao moi khi liet ke THANH CONG va khong co Web App nao.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ProjectId,
        [AllowNull()][string]$KnownAppId,
        [bool]$CreateStartedEarlier = $false,
        [scriptblock]$OnAppIdKnown = $null,
        [scriptblock]$OnBeforeCreate = $null,
        [int]$ListAttempts = 6,
        [int]$BaseDelaySeconds = 3,
        [string]$DisplayName = 'EduGame Hub Free'
    )
    if (-not [string]::IsNullOrWhiteSpace($KnownAppId) -and (Test-WebAppExists -ProjectId $ProjectId -AppId $KnownAppId)) {
        return [pscustomobject]@{ AppId = $KnownAppId; Source = 'known' }
    }
    $found = Find-WebAppWithRetry -ProjectId $ProjectId -Attempts $ListAttempts -BaseDelaySeconds $BaseDelaySeconds
    if ($found.AppId) { return [pscustomobject]@{ AppId = [string]$found.AppId; Source = 'listed' } }
    if (-not $found.Listed) {
        throw "[Web App] Khong liet ke duoc Firebase apps sau $ListAttempts lan. Khong tao lai de tranh trung. Loi cuoi: $($found.LastError)"
    }
    if ($CreateStartedEarlier) {
        throw '[Web App] Lan chay truoc da gui lenh tao Web App nhung chua xac nhan duoc. Khong tao lai de tranh trung. Chay: firebase apps:list --project PROJECT_ID, roi chay lai voi -WebAppId APP_ID.'
    }
    if ($OnBeforeCreate) { & $OnBeforeCreate }
    $create = Invoke-Cli -Exe 'firebase' -Arguments @('apps:create', 'WEB', $DisplayName, '--project', $ProjectId, '--non-interactive')
    $combined = $create.Stdout + "`n" + $create.Stderr
    $createdId = Get-WebAppIdFromText -Text $combined
    if ($createdId) {
        if ($OnAppIdKnown) { & $OnAppIdKnown $createdId }
        return [pscustomobject]@{ AppId = $createdId; Source = 'created' }
    }
    if ($create.Code -ne 0 -and $combined -notmatch '(?i)already exists|ALREADY_EXISTS|409') {
        throw "[Web App] apps:create that bai (exit $($create.Code)): $(Get-SafeSnippet $combined 600)"
    }
    # Tao co the thanh cong nhung khong in App ID, hoac app da ton tai: liet ke lai.
    $again = Find-WebAppWithRetry -ProjectId $ProjectId -Attempts $ListAttempts -BaseDelaySeconds $BaseDelaySeconds
    if ($again.AppId) {
        if ($OnAppIdKnown) { & $OnAppIdKnown $again.AppId }
        return [pscustomobject]@{ AppId = [string]$again.AppId; Source = 'listed-after-create' }
    }
    throw "[Web App] Lenh tao da chay nhung khong xac dinh duoc App ID. Chay: firebase apps:list --project $ProjectId --json. Loi: $($again.LastError)"
}

function Get-WebAppSdkConfig {
    # Lay cau hinh Web SDK, co retry vi sdkconfig cung co the tre sau khi tao.
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$ProjectId, [Parameter(Mandatory = $true)][string]$AppId,
          [int]$Attempts = 5, [int]$BaseDelaySeconds = 3)
    $lastError = ''
    for ($i = 1; $i -le $Attempts; $i++) {
        # Thu --json truoc; neu CLI khong ho tro, thu dang van ban.
        foreach ($variant in @(@('--json'), @())) {
            $cliArgs = @('apps:sdkconfig', 'WEB', $AppId, '--project', $ProjectId) + $variant
            $r = Invoke-Cli -Exe 'firebase' -Arguments $cliArgs
            if ($r.Code -ne 0) { $lastError = Get-SafeSnippet ($r.Stderr + ' ' + $r.Stdout) 300; continue }
            try { return Get-FirebaseWebConfig -Text $r.Stdout }
            catch { $lastError = $_.Exception.Message }
        }
        if ($i -lt $Attempts -and $BaseDelaySeconds -gt 0) { Start-Sleep -Seconds ($BaseDelaySeconds * $i) }
    }
    throw "Khong lay duoc cau hinh Web SDK cho app $AppId sau $Attempts lan. Loi cuoi: $lastError"
}

function Read-SetupState {
    # Tra ve PSCustomObject hoac $null. Nem loi ro rang neu file JSON bi hong.
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    try { return ConvertFrom-Json -InputObject $raw }
    catch { throw "File trang thai $Path bi hong (JSON khong hop le). Sao luu va xoa file roi chay lai, hoac sua tay." }
}

function Get-StateValue {
    [CmdletBinding()]
    param([AllowNull()]$State, [Parameter(Mandatory = $true)][string]$Name)
    if ($null -eq $State) { return $null }
    if (@($State.PSObject.Properties.Name) -contains $Name) { return $State.$Name }
    return $null
}

function Merge-State {
    # Gop du lieu moi vao trang thai cu: khong lam mat khoa da luu (vi du webAppId).
    [CmdletBinding()]
    param([AllowNull()]$Existing, [Parameter(Mandatory = $true)][hashtable]$Updates)
    $merged = [ordered]@{}
    if ($null -ne $Existing) {
        foreach ($p in $Existing.PSObject.Properties) { $merged[$p.Name] = $p.Value }
    }
    foreach ($k in $Updates.Keys) { $merged[$k] = $Updates[$k] }
    return $merged
}

function Test-ProjectIdFormat {
    param([Parameter(Mandatory = $true)][string]$ProjectId)
    return ($ProjectId -cmatch '^[a-z][a-z0-9-]{4,28}[a-z0-9]$')
}

function Get-GamesSiteId {
    # Hosting site id: toi da 30 ky tu, ket thuc bang -games.
    param([Parameter(Mandatory = $true)][string]$ProjectId)
    $site = "$ProjectId-games"
    if ($site.Length -gt 30) { $site = $ProjectId.Substring(0, 24).TrimEnd('-') + '-games' }
    return $site
}

function Write-Utf8NoBom {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Value)
    [System.IO.File]::WriteAllText($Path, $Value, (New-Object System.Text.UTF8Encoding($false)))
}
