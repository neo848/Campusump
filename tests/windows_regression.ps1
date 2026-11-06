$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
# Import function ASTs only: never execute application startup or configuration.
foreach ($file in @('personal_account.ps1', 'campus_wifi.ps1')) {
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root "windows/$file"), [ref]$null, [ref]$errors)
    if ($errors.Count) { throw "Syntax errors in $file" }
    foreach ($fn in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
        . ([scriptblock]::Create($fn.Extent.Text))
    }
}
function Assert($condition, $message) { if (!$condition) { throw $message } }
$testDirectory = Join-Path $PSScriptRoot ('account-' + [guid]::NewGuid())
function Get-PersonalAccountPath { Join-Path $testDirectory 'account.dpapi' }
try {
    $password = ' fictional & <password> with spaces '
    $credential = [PSCredential]::new('alice@ump.ac.ma', (ConvertTo-SecureString $password -AsPlainText -Force))
    Save-PersonalAccount $credential
    $stored = Get-Content (Get-PersonalAccountPath) -Raw
    Assert (!$stored.Contains('alice') -and !$stored.Contains($password)) 'Plaintext leaked into storage'
    $loaded = Read-PersonalAccount
    Assert ($loaded.UserName -eq $credential.UserName) 'Email roundtrip failed'
    Assert ($loaded.GetNetworkCredential().Password -ceq $password) 'Password roundtrip failed'
    Assert ((Get-MaskedEmail $loaded.UserName) -eq 'a***@ump.ac.ma') 'Mask failed'
    $replacement = [PSCredential]::new('bob@ump.ac.ma', (ConvertTo-SecureString 'replacement' -AsPlainText -Force))
    Save-PersonalAccount $replacement
    Assert ((Read-PersonalAccount).UserName -eq 'bob@ump.ac.ma') 'Replacement failed'
    function Read-Host { '1' }
    Assert ((Select-PersonalAccount).UserName -eq 'bob@ump.ac.ma') 'Reuse failed'
    function Read-Host { '3' }
    Assert ($null -eq (Select-PersonalAccount)) 'Cancel failed'
    $script:answers = [Collections.Queue]::new()
    foreach ($answer in @('2', 'carol@ump.ac.ma', ' new password & <> ')) { $script:answers.Enqueue($answer) }
    function Read-Host { param($Prompt, [switch]$AsSecureString)
        $answer = $script:answers.Dequeue()
        if ($AsSecureString) { return ConvertTo-SecureString $answer -AsPlainText -Force }
        return $answer
    }
    $selected = Select-PersonalAccount
    Assert ($selected.UserName -eq 'carol@ump.ac.ma') 'Interactive replacement failed'
    Assert ((Read-PersonalAccount).GetNetworkCredential().Password -ceq ' new password & <> ') 'Interactive password changed'
    $acl = Get-Acl -LiteralPath $testDirectory
    Assert $acl.AreAccessRulesProtected 'Storage inherits permissions'
    Set-Content (Get-PersonalAccountPath) 'corrupt'
    Assert ($null -eq (Read-PersonalAccount)) 'Corrupt storage was accepted'

    $script:calls = @()
    function netsh { $script:calls += ,@($args); $global:LASTEXITCODE = 0 }
    Assert (Apply-DHCPConfiguration 'Wi-Fi Test') 'Reset failed'
    Assert ($script:calls.Count -eq 2) 'Must reset both IP and DNS'
    Assert ($script:calls[0][3] -eq 'address') 'Missing IP reset'
    Assert ($script:calls[1][3] -eq 'dnsservers') 'Missing DNS reset'
    Assert ($script:calls[1][-1] -eq 'source=dhcp') 'DNS must be automatic'
    function netsh { $script:calls += ,@($args); $global:LASTEXITCODE = 1 }
    Assert (!(Apply-DHCPConfiguration 'Wi-Fi Test')) 'Failed reset reported success'
    Assert ($script:calls.Count -eq 4) 'DNS must be attempted after IP failure'

    function Restore-CampusSession($Adapters) { foreach ($adapter in $Adapters) { $null = Apply-DHCPConfiguration $adapter } }
    function Ensure-AdminPrivileges { }
    function Get-WifiAdapterName { 'Wi-Fi Test' }
    function Connect-CampusWifiInitial { }
    function Show-Banner { }
    function Show-CurrentAdapterStatus { }
    function Show-Separator { }
    function Start-Sleep { }
    function Read-Host { '0' }
    $script:restored = @()
    function Apply-DHCPConfiguration($adapterName) { $script:restored += $adapterName; $true }
    Start-CampusWifiApp
    Assert ($script:restored -contains 'Wi-Fi Test') 'Normal exit did not restore adapter'
    $script:restored = @()
    function Connect-CampusWifiInitial { throw 'Simulated failure' }
    try { Start-CampusWifiApp } catch { Assert ($_.Exception.Message -eq 'Simulated failure') 'Unexpected failure' }
    Assert ($script:restored -contains 'Wi-Fi Test') 'Exception exit did not restore adapter'
    Write-Output 'PASS: encrypted persistence, replacement, reuse, masking, cancel, corruption, DHCP/DNS reset and exit cleanup. No network commands executed.'
} finally {
    # Only delete exact test files in the uniquely created directory.
    if (Test-Path (Get-PersonalAccountPath)) { Remove-Item -LiteralPath (Get-PersonalAccountPath) -Force }
    if (Test-Path $testDirectory) { Remove-Item -LiteralPath $testDirectory }
}
