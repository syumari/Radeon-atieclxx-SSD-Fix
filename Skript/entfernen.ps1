# Radeon-atieclxx-SSD-Fix – Entfernen (wird von ENTFERNEN.cmd mit Administratorrechten gestartet).
# Nimmt alle Eingriffe zurück und löscht den Programmordner.
. (Join-Path $PSScriptRoot 'Kern.ps1')
if (-not (Test-IstAdmin)) { Write-Host (Get-FixText 'Message118') -ForegroundColor Red; return }
Write-Host ('Radeon-atieclxx-SSD-Fix ' + $script:Version + (Get-FixText 'Message119'))
Write-Host ''
Remove-Alles
& logman stop $script:TraceName -ets *> $null
Write-Host ((Get-FixText 'Message120') + $(if (Get-ScheduledTask -TaskName $script:AufgabeName -ErrorAction SilentlyContinue) { (Get-FixText 'Message121') } else { (Get-FixText 'Message122') }))
Write-Host ((Get-FixText 'Message123') + $(if (Test-Schutz) { (Get-FixText 'Message124') } else { (Get-FixText 'Message122') }))
Write-Host ((Get-FixText 'Message125') + (Get-DienstText (Get-AmdDienst)))
if (Test-Path -LiteralPath $script:InstallDir) {
  $vonDrinnen = $PSScriptRoot.StartsWith($script:InstallDir + '\', [StringComparison]::OrdinalIgnoreCase)
  if ($vonDrinnen) {
    # Läuft aus dem Programmordner: erst löschen, wenn dieses Fenster geschlossen ist.
    $warte = $PID
    try {
      $ich = Get-CimInstance Win32_Process -Filter "ProcessId=$PID"
      $eltern = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $ich.ParentProcessId)
      if ($eltern -and $eltern.Name -eq 'cmd.exe') { $warte = [int]$eltern.ProcessId }
    } catch {}
    $befehl = 'Wait-Process -Id ' + $warte + ' -ErrorAction SilentlyContinue; Start-Sleep -Seconds 1; Remove-Item -LiteralPath ''' + $script:InstallDir + ''' -Recurse -Force -ErrorAction SilentlyContinue'
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($befehl))
    Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList ('-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ' + $enc) -WindowStyle Hidden -WorkingDirectory $env:SystemRoot
    Write-Host ((Get-FixText 'Message126') + $script:InstallDir + ')')
  } else {
    Remove-Item -LiteralPath $script:InstallDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host ((Get-FixText 'Message128') + $(if (Test-Path -LiteralPath $script:InstallDir) { (Get-FixText 'Message129') } else { (Get-FixText 'Message130') }))
  }
}
Write-Host ''
Write-Host (Get-FixText 'Message131') -ForegroundColor Yellow
