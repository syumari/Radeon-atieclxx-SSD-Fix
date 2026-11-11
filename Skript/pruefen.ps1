# Radeon-atieclxx-SSD-Fix – schneller Status, ohne Administratorrechte.
. (Join-Path $PSScriptRoot 'Kern.ps1')
Write-Host ('Radeon-atieclxx-SSD-Fix ' + $script:Version + (Get-FixText 'Message132'))
Write-Host ''
$t = Get-ScheduledTask -TaskName $script:AufgabeName -ErrorAction SilentlyContinue
$eingerichtet = [bool]$t -or (Test-Path -LiteralPath (Join-Path $script:InstallDir 'Skript\schutz.ps1'))
if ($t) {
  $i = $null
  try { $i = Get-ScheduledTaskInfo -TaskName $script:AufgabeName -ErrorAction Stop } catch {}
  Write-Host (Get-FixText 'Message133') -ForegroundColor Green
  if ($i) {
    $letzter = $(if ($i.LastRunTime -and $i.LastRunTime.Year -ge 2000) { $i.LastRunTime.ToString('dd.MM.yyyy HH:mm') } else { 'noch nicht' })
    $naechster = $(if ($i.NextRunTime) { $i.NextRunTime.ToString('dd.MM.yyyy HH:mm') } else { 'unbekannt' })
    Write-Host ((Get-FixText 'Message134') + $letzter + (Get-FixText 'Message135') + $naechster)
  }
} elseif ($eingerichtet) { Write-Host (Get-FixText 'Message136') -ForegroundColor Green }
else { Write-Host (Get-FixText 'Message137') -ForegroundColor Yellow }
Write-Host ((Get-FixText 'Message138') + (Get-DienstText (Get-AmdDienst)))
if (Test-Path -LiteralPath $script:ProtokollDatei) {
  Write-Host (Get-FixText 'Message139')
  Get-Content -LiteralPath $script:ProtokollDatei -Tail 5 -Encoding UTF8 | ForEach-Object { Write-Host ('  ' + $_) }
}
Write-Host ''
if (-not (Get-AmdProzess)) { Write-Host (Get-FixText 'Message140') -ForegroundColor Green; return }
Write-Host (Get-FixText 'Message141')
$rate = Measure-Schreibrate 10
if ($rate -lt 0) { Write-Host (Get-FixText 'Message142'); return }
Write-Host ((Get-FixText 'Message143') -f ($rate / 1KB), ($rate * 86400 / 1e9))
if ($rate -ge $script:SchreibGrenze) {
  if ($eingerichtet) { Write-Host (Get-FixText 'Message144') -ForegroundColor Red }
  else { Write-Host (Get-FixText 'Message145') -ForegroundColor Red }
} else { Write-Host (Get-FixText 'Message146') -ForegroundColor Green }
