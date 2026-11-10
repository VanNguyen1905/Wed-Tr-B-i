#Requires -Version 5.1
<#
  Ham xu ly thuan tuy; KHONG goi Google/Firebase, KHONG thay doi du lieu.
  Nhan du lieu stdout cua: gcloud firestore databases list --format=value(name)
#>
function ConvertTo-FirestoreDatabaseNames {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Output,
        [Parameter(Mandatory = $true)][string]$ProjectId
    )
    if ($ProjectId -notmatch '^[a-z][a-z0-9-]{4,28}[a-z0-9]$') {
        throw "ProjectId khong hop le: $ProjectId"
    }
    if ([string]::IsNullOrWhiteSpace($Output)) { return @() }
    $results = New-Object 'System.Collections.Generic.List[string]'
    foreach ($rawLine in ($Output -split "`r?`n")) {
        $line = $rawLine.Trim()
        if (-not $line) { continue }
        if ($line -notmatch '^projects/([^/\s]+)/databases/([^/\s]+)$') {
            throw "Dau ra gcloud khong dung dinh dang database name: $line"
        }
        $parts = $line.Split('/')
        if ($parts[1] -cne $ProjectId) {
            throw "gcloud tra ve database thuoc project khac: $line"
        }
        if (-not $results.Contains($line)) { $results.Add($line) }
    }
    return $results.ToArray()
}
