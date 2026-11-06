# Personal account storage: Windows DPAPI protects both email and password.
function Get-PersonalAccountPath {
    Join-Path $env:LOCALAPPDATA 'CampusConnecte\personal-account.dpapi'
}

function Get-MaskedEmail([string]$Email) {
    $parts = $Email.Split('@')
    if ($parts.Count -ne 2 -or !$parts[0]) { return '***' }
    return $parts[0].Substring(0, 1) + '***@' + $parts[1]
}

function Save-PersonalAccount([PSCredential]$Credential) {
    $path = Get-PersonalAccountPath
    $directory = Split-Path $path
    $null = New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
    ([IO.DirectoryInfo]::new($directory)).SetAccessControl($acl)
    $plain = $null
    $temporary = Join-Path $directory ([guid]::NewGuid().ToString() + '.tmp')
    try {
        $plain = @{ Email = $Credential.UserName; Password = $Credential.GetNetworkCredential().Password } | ConvertTo-Json -Compress
        $protected = ConvertTo-SecureString $plain -AsPlainText -Force | ConvertFrom-SecureString
        [IO.File]::WriteAllText($temporary, $protected)
        if (Test-Path -LiteralPath $path) {
            [IO.File]::Replace($temporary, $path, [NullString]::Value)
        } else {
            [IO.File]::Move($temporary, $path)
        }
    } finally {
        $plain = $null
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Read-PersonalAccount {
    $path = Get-PersonalAccountPath
    if (!(Test-Path -LiteralPath $path)) { return $null }
    $pointer = [IntPtr]::Zero
    try {
        $secret = Get-Content -LiteralPath $path -Raw -ErrorAction Stop | ConvertTo-SecureString -ErrorAction Stop
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
        $account = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) | ConvertFrom-Json -ErrorAction Stop
        if (!$account.Email -or !$account.Password) { throw 'Invalid account' }
        return [PSCredential]::new($account.Email, (ConvertTo-SecureString $account.Password -AsPlainText -Force))
    } catch {
        Write-Warning 'Compte enregistre illisible pour cet utilisateur Windows. Saisissez un nouveau compte pour le remplacer.'
        return $null
    } finally {
        if ($pointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
        $account = $null
    }
}

function Select-PersonalAccount {
    $saved = Read-PersonalAccount
    if ($saved) {
        Write-Host (' Compte enregistre : ' + (Get-MaskedEmail $saved.UserName))
        do { $choice = Read-Host '[1] Reutiliser  [2] Remplacer  [3] Annuler' } until ($choice -in '1', '2', '3')
        if ($choice -eq '1') { return $saved }
        if ($choice -eq '3') { return $null }
    }
    do { $email = (Read-Host ' Email institutionnel UMP').Trim() } until ($email -match '^[^\s@]+@ump\.ac\.ma$')
    do { $password = Read-Host ' Mot de passe' -AsSecureString } until ($password.Length -gt 0)
    $credential = [PSCredential]::new($email, $password)
    Save-PersonalAccount $credential
    Write-Host ' Compte personnel enregistre avec chiffrement Windows.'
    return $credential
}
