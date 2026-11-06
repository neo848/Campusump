$ErrorActionPreference = 'Stop'
$path = Join-Path (Split-Path $PSScriptRoot) 'windows/campus_wifi.ps1'
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
if ($errors.Count) { throw 'Parse failed' }
$functions = $ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)
$cleanup = ($functions | Where-Object Name -eq 'Restore-CampusSession').Extent.Text
$app = ($functions | Where-Object Name -eq 'Start-CampusWifiApp').Extent.Text
$marker = Join-Path $PSScriptRoot ('cancel-' + [guid]::NewGuid() + '.txt')
$ready = [Threading.ManualResetEventSlim]::new($false)
$worker = [PowerShell]::Create()
try {
    $null = $worker.AddScript({
        param($cleanup, $app, $marker, $ready)
        . ([scriptblock]::Create($cleanup))
        . ([scriptblock]::Create($app))
        # The production reset function is never loaded: no network operation is possible.
        $body = 'param($adapterName) [IO.File]::AppendAllText(''' + $marker.Replace("'", "''") + ''', $adapterName + [Environment]::NewLine); return $true'
        Set-Item Function:Apply-DHCPConfiguration ([scriptblock]::Create($body))
        function Ensure-AdminPrivileges { }
        function Get-WifiAdapterName { 'Wi-Fi Simule' }
        function Connect-CampusWifiInitial {
            $ready.Set()
            Start-Sleep -Seconds 120
        }
        Start-CampusWifiApp
    }).AddArgument($cleanup).AddArgument($app).AddArgument($marker).AddArgument($ready)
    $pending = $worker.BeginInvoke()
    if (!$ready.Wait(10000)) { throw 'Application did not enter test wait' }
    # Stop issues the same PowerShell pipeline cancellation used by Ctrl+C.
    $worker.Stop()
    try { $worker.EndInvoke($pending) } catch [Management.Automation.PipelineStoppedException] { }
    if (!(Test-Path $marker)) { throw 'Cancellation skipped cleanup' }
    if ((Get-Content $marker -Raw).Trim() -ne 'Wi-Fi Simule') { throw 'Wrong cleanup target' }
    Write-Output 'PASS: real pipeline cancellation executes isolated cleanup. No network operation loaded or executed.'
} finally {
    $worker.Dispose()
    $ready.Dispose()
    if (Test-Path $marker) { Remove-Item -LiteralPath $marker }
}
