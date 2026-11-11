# Radeon-atieclxx-SSD-Fix – Fenster mit Analyse, Schadensschätzung und Fix-Knöpfen.
# Start über START.cmd (mit Administratorrechten). Messungen laufen im Hintergrund, das Fenster bleibt bedienbar.
# Test: $Global:AMDFIX_NOSHOW = $true; $Global:AMDFIX_TEST = $true; . .\Oberflaeche.ps1; $f = Build-Form
$script:SkriptDir = $PSScriptRoot
$script:KernDatei = Join-Path $PSScriptRoot 'Kern.ps1'
. $script:KernDatei
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Ctrl = @{}
$script:Async = $null
$script:Letzte = $null
$script:Beenden = $false
$script:Timer = $null
$script:Mutex = $null
$script:TestMeldungen = New-Object System.Collections.ArrayList
$script:Sync = [hashtable]::Synchronized(@{ Phase = ''; Ende = [datetime]::MinValue })
$script:NL = [Environment]::NewLine
$script:Farbe = @{
  Rot    = [System.Drawing.Color]::FromArgb(176, 0, 32)
  Gruen  = [System.Drawing.Color]::FromArgb(30, 120, 54)
  Orange = [System.Drawing.Color]::FromArgb(176, 96, 0)
  Grau   = [System.Drawing.Color]::FromArgb(90, 90, 90)
  Text   = [System.Drawing.Color]::FromArgb(32, 32, 32)
}

# Läuft in einem eigenen Runspace: Aktion ausführen, danach neu analysieren.
$script:HintergrundSkript = {
  param($kern, $aktion, $quelle, $rateVorher, $sync)
  . $kern
  $script:Fortschritt = $sync
  $ergebnis = @{}
  switch ($aktion) {
    'Schutz' {
      Set-Phase (Get-FixText 'Message0')
      $ok = Set-Schutz
      $auf = $false
      if ($ok) {
        Save-SchutzBefund -Art 'Schutz' -RateVorher $rateVorher -ErlaubeAnnahme
        Set-Phase (Get-FixText 'Message1')
        $auf = Install-Aufgabe -Quelle $quelle
        Write-Protokoll (Get-FixText 'Message2')
      }
      $ergebnis = @{ Ok = $ok; Aufgabe = $auf }
    }
    'Dienst' {
      Set-Phase (Get-FixText 'Message3')
      $r = Disable-Dienst
      if ($r -eq 'OK' -or $r -eq 'LaeuftNoch') {
        Save-SchutzBefund -Art 'Dienst' -RateVorher $rateVorher
        Write-Protokoll (Get-FixText 'Message4')
      }
      $ergebnis = @{ Ergebnis = $r }
    }
    'Zurueck' {
      Set-Phase (Get-FixText 'Message5')
      Remove-Alles
      Write-Protokoll (Get-FixText 'Message6')
      $ergebnis = @{ Ok = $true }
    }
  }
  $analyse = Get-Analyse -MessSekunden 8
  [pscustomobject]@{ Aktion = $aktion; Ergebnis = $ergebnis; Analyse = $analyse }
}

# ------------------------------------------------------------------ Hilfsfunktionen
function Zeige-Nachricht {
  param([string]$Text, [string]$Knoepfe = 'OK', [string]$Symbol = 'Information', [string]$Titel = 'Radeon-atieclxx-SSD-Fix')
  if ($Global:AMDFIX_TEST) { [void]$script:TestMeldungen.Add($Text); if ($Knoepfe -eq 'YesNo') { return 'Yes' }; return 'OK' }
  $f = $script:Ctrl.Form
  if ($f -and -not $f.IsDisposed -and $f.Visible) { return [string][System.Windows.Forms.MessageBox]::Show($f, $Text, $Titel, $Knoepfe, $Symbol) }
  return [string][System.Windows.Forms.MessageBox]::Show($Text, $Titel, $Knoepfe, $Symbol)
}
function Format-Rate([double]$b) {
  if ($b -lt 0) { return 'nicht messbar' }
  if ($b -ge 1MB) { return ('{0:N2} MB/s' -f ($b / 1MB)) }
  return ('{0:N0} KB/s' -f ($b / 1KB))
}
function Format-Menge([double]$Bytes) {
  if ($Bytes -ge 1e11) { return ('{0:N1} TB' -f ($Bytes / 1e12)) }
  return ('{0:N0} GB' -f ($Bytes / 1e9))
}
function New-Beschriftung($Eltern, [int]$X, [int]$Y, [int]$B, [int]$H, [string]$Text = '') {
  $l = New-Object System.Windows.Forms.Label
  $l.Location = New-Object System.Drawing.Point($X, $Y)
  $l.Size = New-Object System.Drawing.Size($B, $H)
  $l.Text = $Text
  $Eltern.Controls.Add($l)
  return $l
}
function New-Knopf($Eltern, [int]$X, [int]$Y, [int]$B, [int]$H, [string]$Text) {
  $k = New-Object System.Windows.Forms.Button
  $k.Location = New-Object System.Drawing.Point($X, $Y)
  $k.Size = New-Object System.Drawing.Size($B, $H)
  $k.Text = $Text
  $Eltern.Controls.Add($k)
  return $k
}
function New-Gruppe($Eltern, [int]$X, [int]$Y, [int]$B, [int]$H, [string]$Text) {
  $g = New-Object System.Windows.Forms.GroupBox
  $g.Location = New-Object System.Drawing.Point($X, $Y)
  $g.Size = New-Object System.Drawing.Size($B, $H)
  $g.Text = $Text
  $Eltern.Controls.Add($g)
  return $g
}

# ------------------------------------------------------------------ Fenster
function Build-Form {
  $f = New-Object System.Windows.Forms.Form
  $f.SuspendLayout()
  $f.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
  $f.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
  $f.Text = 'Radeon-atieclxx-SSD-Fix ' + $script:Version
  $f.ClientSize = New-Object System.Drawing.Size(660, 620)
  $f.StartPosition = 'CenterScreen'
  $f.FormBorderStyle = 'FixedSingle'
  $f.MaximizeBox = $false
  $f.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
  $f.BackColor = [System.Drawing.Color]::White
  try { $f.Icon = [System.Drawing.SystemIcons]::Shield } catch {}
  $fett = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

  $kopf = New-Beschriftung $f 18 14 624 32 (Get-FixText 'Message7')
  $kopf.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
  $kopf.ForeColor = $script:Farbe.Grau
  $unter = New-Beschriftung $f 20 48 624 20 (Get-FixText 'Message8')
  $unter.ForeColor = $script:Farbe.Grau

  $g1 = New-Gruppe $f 18 74 624 134 (Get-FixText 'Message9')
  $befund = New-Beschriftung $g1 14 22 596 104
  $g2 = New-Gruppe $f 18 214 624 160 (Get-FixText 'Message10')
  $schaden = New-Beschriftung $g2 14 22 596 130
  $g3 = New-Gruppe $f 18 380 624 168 (Get-FixText 'Message11')
  $btnSchutz = New-Knopf $g3 16 26 250 40 (Get-FixText 'Message12')
  $l1 = New-Beschriftung $g3 276 26 334 42 (Get-FixText 'Message13')
  $btnDienst = New-Knopf $g3 16 74 250 38 (Get-FixText 'Message14')
  $l2 = New-Beschriftung $g3 276 74 334 40 (Get-FixText 'Message15')
  $btnZurueck = New-Knopf $g3 16 120 250 36 (Get-FixText 'Message16')
  $l3 = New-Beschriftung $g3 276 120 334 40 (Get-FixText 'Message17')
  foreach ($l in $l1, $l2, $l3) { $l.ForeColor = $script:Farbe.Grau }

  $btnPruefen = New-Knopf $f 18 558 140 30 (Get-FixText 'Message18')
  $btnReBar = New-Knopf $f 166 558 180 30 (Get-FixText 'Message19')
  $btnProt = New-Knopf $f 354 558 130 30 (Get-FixText 'Message20')
  $btnHilfe = New-Knopf $f 492 558 150 30 (Get-FixText 'Message21')
  $fuss = New-Beschriftung $f 20 594 624 22
  $fuss.ForeColor = $script:Farbe.Grau

  $script:Ctrl = @{ Form = $f; Kopf = $kopf; Unter = $unter; Befund = $befund; Schaden = $schaden; Fett = $fett; Normal = $f.Font
    BtnSchutz = $btnSchutz; BtnDienst = $btnDienst; BtnZurueck = $btnZurueck; BtnPruefen = $btnPruefen
    BtnReBar = $btnReBar; BtnProt = $btnProt; BtnHilfe = $btnHilfe; Fuss = $fuss }
  foreach ($k in 'BtnSchutz', 'BtnDienst', 'BtnZurueck', 'BtnPruefen') { $script:Ctrl[$k].Enabled = $false }
  $btnProt.Enabled = Test-Path -LiteralPath $script:ProtokollDatei

  $btnPruefen.Add_Click({ Klick-Pruefen })
  $btnSchutz.Add_Click({ Klick-Schutz })
  $btnDienst.Add_Click({ Klick-Dienst })
  $btnZurueck.Add_Click({ Klick-Zurueck })
  $btnReBar.Add_Click({ Klick-ReBar })
  $btnProt.Add_Click({ Klick-Protokoll })
  $btnHilfe.Add_Click({ Klick-Hilfe })
  $f.Add_FormClosing({ Beim-Schliessen $_ })

  $script:Timer = New-Object System.Windows.Forms.Timer
  $script:Timer.Interval = 200
  $script:Timer.Add_Tick({ Tick-Hintergrund })

  $f.ResumeLayout($false)
  return $f
}

function Setze-Knoepfe($a) {
  $c = $script:Ctrl
  $deaktiviert = [bool]($a.Dienst -and [string]$a.Dienst.StartType -eq 'Disabled')
  $c.BtnSchutz.Enabled = ($a.Status -eq 'BetroffenSelbstkopie') -or ($a.Status -eq 'Geschuetzt' -and -not $a.Aufgabe)
  $c.BtnDienst.Enabled = [bool]$a.Dienst -and -not $deaktiviert
  $c.BtnZurueck.Enabled = [bool]($a.Schutz -or $a.Aufgabe -or $deaktiviert -or $a.Befund)
  $c.BtnPruefen.Enabled = $true
  $c.BtnProt.Enabled = Test-Path -LiteralPath $script:ProtokollDatei
  $c.BtnSchutz.Font = $(if ($c.BtnSchutz.Enabled) { $c.Fett } else { $c.Normal })
  $c.BtnDienst.Font = $(if ($a.Status -in 'BetroffenAndere', 'SchutzWirktNicht') { $c.Fett } else { $c.Normal })
}
function Set-Bedienbar([bool]$An) {
  $c = $script:Ctrl
  if ($An) {
    if ($script:Letzte) { Setze-Knoepfe $script:Letzte } else { $c.BtnPruefen.Enabled = $true }
  } else {
    foreach ($k in 'BtnSchutz', 'BtnDienst', 'BtnZurueck', 'BtnPruefen') { $c[$k].Enabled = $false }
  }
}

function Refresh-Ansicht {
  param($a)
  $c = $script:Ctrl
  if (-not $c.Form -or $c.Form.IsDisposed) { return }
  $kopf = @{
    KeinDienst            = @((Get-FixText 'Message22'), 'Gruen')
    DienstAus             = @((Get-FixText 'Message23'), 'Gruen')
    DienstGestoppt        = @((Get-FixText 'Message24'), 'Grau')
    MessungFehlgeschlagen = @((Get-FixText 'Message25'), 'Orange')
    Geschuetzt            = @((Get-FixText 'Message26'), 'Gruen')
    NichtBetroffen        = @((Get-FixText 'Message27'), 'Gruen')
    BetroffenSelbstkopie  = @((Get-FixText 'Message28'), 'Rot')
    BetroffenAndere       = @((Get-FixText 'Message29'), 'Rot')
    SchutzWirktNicht      = @((Get-FixText 'Message30'), 'Rot')
  }[[string]$a.Status]
  if (-not $kopf) { $kopf = @([string]$a.Status, 'Grau') }
  $c.Kopf.Text = $kopf[0]
  $c.Kopf.ForeColor = $script:Farbe[$kopf[1]]
  $c.Unter.Text = (Get-FixText 'Message31') + $a.Zeit.ToString('HH:mm:ss') + (Get-FixText 'Message32') + $(if ($a.Rate -lt 0) { (Get-FixText 'Message33') } else { (Get-FixText 'Message34') + (Format-Rate $a.Rate) })

  $z = New-Object System.Collections.ArrayList
  switch ([string]$a.Status) {
    'BetroffenSelbstkopie' {
      [void]$z.Add((Get-FixText 'Message35'))
      [void]$z.Add('    ' + $script:ZielDatei)
      [void]$z.Add((Get-FixText 'Message36'))
    }
    'BetroffenAndere' {
      [void]$z.Add((Get-FixText 'Message37'))
      if (@($a.Ziele).Count) { foreach ($p in @($a.Ziele)) { [void]$z.Add('    ' + $p) } } else { [void]$z.Add((Get-FixText 'Message38')) }
      [void]$z.Add((Get-FixText 'Message39'))
    }
    'SchutzWirktNicht' {
      [void]$z.Add((Get-FixText 'Message40'))
      [void]$z.Add('    ' + $script:ZielDatei)
      [void]$z.Add((Get-FixText 'Message41'))
    }
    'Geschuetzt' {
      [void]$z.Add((Get-FixText 'Message42'))
      [void]$z.Add('    ' + $script:ZielDatei)
      [void]$z.Add((Get-FixText 'Message43'))
      [void]$z.Add((Get-FixText 'Message44') + $(if ($a.Aufgabe) { (Get-FixText 'Message45') } else { (Get-FixText 'Message46') }))
    }
    'DienstAus' {
      [void]$z.Add((Get-FixText 'Message47'))
      [void]$z.Add((Get-FixText 'Message48'))
    }
    'NichtBetroffen' { [void]$z.Add((Get-FixText 'Message49')) }
    'DienstGestoppt' { [void]$z.Add((Get-FixText 'Message50')) }
    'KeinDienst' { [void]$z.Add((Get-FixText 'Message51')) }
    'MessungFehlgeschlagen' { [void]$z.Add((Get-FixText 'Message52')) }
  }
  $c.Befund.Text = ($z -join $script:NL)
  $c.Befund.ForeColor = $(if ($a.Betroffen) { $script:Farbe.Rot } else { $script:Farbe.Text })

  $s = $a.Schaden
  $ssdName = $(if ($a.Ssd -and $a.Ssd.Modell) { [string]$a.Ssd.Modell } else { (Get-FixText 'Message53') })
  $d = New-Object System.Collections.ArrayList
  if (-not $s) {
    [void]$d.Add((Get-FixText 'Message54'))
    if ($a.Ssd -and $a.Ssd.Wear) { [void]$d.Add(((Get-FixText 'Message55') -f $a.Ssd.Wear)) }
  } else {
    $bis = $(if ($s.Aktiv) { (Get-FixText 'Message56') } else { $s.Ende.ToString('d', $script:FixCulture) })
    $woher = $(if ($s.StundenQuelle -eq 'SSD') { (Get-FixText 'Message57') } else { (Get-FixText 'Message58') })
    [void]$d.Add(((Get-FixText 'Message59') -f $s.Seit.ToString('d', $script:FixCulture), $bis, $s.Tage, $s.StundenProTag, $woher))
    [void]$d.Add(((Get-FixText 'Message60') -f (Format-Menge $s.Bytes), $ssdName))
    if ($s.ProzentTbw) { [void]$d.Add(((Get-FixText 'Message61') -f $s.ProzentTbw, $s.TbwTB)) }
    if ($s.Wear) { [void]$d.Add(((Get-FixText 'Message55') -f $s.Wear)) }
    if ($s.Aktiv) { [void]$d.Add(((Get-FixText 'Message62') -f $s.GbProTag)) }
    else { [void]$d.Add((Get-FixText 'Message63')) }
    if ($s.Basis -eq 'Annahme') { [void]$d.Add((Get-FixText 'Message64')) }
    [void]$d.Add((Get-FixText 'Message65'))
  }
  $c.Schaden.Text = ($d -join $script:NL)

  $c.Fuss.Text = (Get-FixText 'Message66') + (Get-DienstText $a.Dienst) + (Get-FixText 'Message67') + $(if ($a.Schutz) { (Get-FixText 'Message68') } else { (Get-FixText 'Message69') }) + (Get-FixText 'Message70') + $(if ($a.Aufgabe) { (Get-FixText 'Message71') } else { (Get-FixText 'Message69') }) + '   |   ' + $ssdName
  Setze-Knoepfe $a
}

# ------------------------------------------------------------------ Hintergrundarbeit
function Start-Hintergrund([string]$Aktion) {
  if ($script:Async) { return }
  $c = $script:Ctrl
  Set-Bedienbar $false
  $titel = @{ Analyse = (Get-FixText 'Message7'); Schutz = (Get-FixText 'Message73'); Dienst = (Get-FixText 'Message74'); Zurueck = (Get-FixText 'Message75') }[$Aktion]
  $c.Kopf.Text = $titel
  $c.Kopf.ForeColor = $script:Farbe.Grau
  $c.Unter.Text = (Get-FixText 'Message8')
  $script:Sync.Phase = ''
  $script:Sync.Ende = [datetime]::MinValue
  $rateVorher = $(if ($script:Letzte) { [double]$script:Letzte.Rate } else { -1.0 })
  $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
  $iss.ExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::Bypass
  $rs = [runspacefactory]::CreateRunspace($iss)
  $rs.Open()
  $ps = [powershell]::Create()
  $ps.Runspace = $rs
  [void]$ps.AddScript($script:HintergrundSkript.ToString()).AddArgument($script:KernDatei).AddArgument($Aktion).AddArgument($script:SkriptDir).AddArgument($rateVorher).AddArgument($script:Sync)
  $script:Async = @{ PS = $ps; RS = $rs; Aktion = $Aktion; Handle = $ps.BeginInvoke() }
  $script:Timer.Start()
}
function Tick-Hintergrund {
  try {
    $a = $script:Async
    if (-not $a) { $script:Timer.Stop(); return }
    if (-not $a.Handle.IsCompleted) {
      try {
        $ph = [string]$script:Sync.Phase
        if ($ph) {
          $ende = [datetime]$script:Sync.Ende
          $text = $ph + ' ...'
          if ($ende -gt [datetime]::MinValue) {
            $sek = ($ende - (Get-Date)).TotalSeconds
            if ($sek -gt 0 -and $sek -lt 3600) { $text = (Get-FixText 'Message156') -f $ph, [math]::Ceiling($sek) }
          }
          $script:Ctrl.Unter.Text = $text
        }
      } catch {}   # eine fehlerhafte Fortschrittsanzeige darf die laufende Arbeit nie abbrechen
      return
    }
    $script:Timer.Stop()
    $res = @(); $fehler = ''
    try { $res = @($a.PS.EndInvoke($a.Handle)) } catch { $fehler = $_.Exception.Message }
    if (-not $fehler -and $a.PS.Streams.Error.Count) { $fehler = [string]$a.PS.Streams.Error[0] }
    try { $a.PS.Dispose(); $a.RS.Close(); $a.RS.Dispose() } catch {}
    $script:Async = $null
    if ($script:Beenden -or $script:Ctrl.Form.IsDisposed) { return }
    $paket = $res | Where-Object { $_ -and $_.PSObject.Properties['Analyse'] } | Select-Object -Last 1
    if (-not $paket -or -not $paket.Analyse) {
      $script:Ctrl.Kopf.Text = (Get-FixText 'Message76')
      $script:Ctrl.Kopf.ForeColor = $script:Farbe.Orange
      $script:Ctrl.Unter.Text = (Get-FixText 'Message77')
      Set-Bedienbar $true
      Zeige-Nachricht ((Get-FixText 'Message78') + $script:NL + $fehler) 'OK' 'Warning' | Out-Null
      return
    }
    $script:Letzte = $paket.Analyse
    Refresh-Ansicht $paket.Analyse
    Melde-Aktion $paket
  } catch {
    # Läuft die Hintergrundarbeit noch, weiter abwarten statt sie zu verlieren
    # (sonst könnten sich zwei Aktionen überschneiden).
    $a = $script:Async
    if ($a -and -not $a.Handle.IsCompleted) { return }
    try { $script:Timer.Stop() } catch {}
    if ($a) { try { $a.PS.Dispose(); $a.RS.Close(); $a.RS.Dispose() } catch {} }
    $script:Async = $null
    Set-Bedienbar $true
    Zeige-Nachricht ((Get-FixText 'Message79') + $_.Exception.Message) 'OK' 'Error' | Out-Null
  }
}
function Stop-Hintergrund {
  try { if ($script:Timer) { $script:Timer.Stop() } } catch {}
  $a = $script:Async
  $script:Async = $null
  if ($a) {
    try { $a.PS.Stop() } catch {}
    try { $a.PS.Dispose(); $a.RS.Close(); $a.RS.Dispose() } catch {}
  }
  & logman stop $script:TraceName -ets *> $null   # falls eine Aufzeichnung lief
}
function Melde-Aktion($p) {
  $e = $p.Ergebnis
  switch ([string]$p.Aktion) {
    'Schutz' {
      if ($e.Ok) {
        $auto = $(if ($e.Aufgabe) { (Get-FixText 'Message80') }
                  else { (Get-FixText 'Message81') })
        Zeige-Nachricht ((Get-FixText 'Message82') + $script:NL + $script:NL + $auto) 'OK' 'Information' | Out-Null
      } else {
        Zeige-Nachricht (Get-FixText 'Message83') 'OK' 'Warning' | Out-Null
      }
    }
    'Dienst' {
      $t = switch ([string]$e.Ergebnis) {
        'OK'         { (Get-FixText 'Message84') }
        'LaeuftNoch' { (Get-FixText 'Message85') }
        'KeinDienst' { (Get-FixText 'Message86') }
        default      { (Get-FixText 'Message87') }
      }
      Zeige-Nachricht $t 'OK' $(if ([string]$e.Ergebnis -eq 'OK') { 'Information' } else { 'Warning' }) | Out-Null
    }
    'Zurueck' { Zeige-Nachricht ((Get-FixText 'Message88') + $script:NL + (Get-FixText 'Message89')) 'OK' 'Information' | Out-Null }
  }
}

# ------------------------------------------------------------------ Knöpfe
function Fehler-Anzeigen($Fehler) { Set-Bedienbar $true; Zeige-Nachricht ((Get-FixText 'Message79') + $Fehler.Exception.Message) 'OK' 'Error' | Out-Null }
function Klick-Pruefen { try { Start-Hintergrund 'Analyse' } catch { Fehler-Anzeigen $_ } }
function Klick-Schutz { try { Start-Hintergrund 'Schutz' } catch { Fehler-Anzeigen $_ } }
function Klick-Dienst {
  try {
    $r = Zeige-Nachricht ((Get-FixText 'Message90') + $script:NL + $script:NL +
      (Get-FixText 'Message91')) 'YesNo' 'Warning'
    if ($r -eq 'Yes') { Start-Hintergrund 'Dienst' }
  } catch { Fehler-Anzeigen $_ }
}
function Klick-Zurueck {
  try {
    $r = Zeige-Nachricht (Get-FixText 'Message92') 'YesNo' 'Question'
    if ($r -eq 'Yes') { Start-Hintergrund 'Zurueck' }
  } catch { Fehler-Anzeigen $_ }
}
function Klick-ReBar {
  Zeige-Nachricht ((Get-FixText 'Message93') + $script:NL + $script:NL +
    (Get-FixText 'Message94') + $script:NL + $script:NL +
    (Get-FixText 'Message95')) 'OK' 'Information' (Get-FixText 'Message19') | Out-Null
}
function Klick-Protokoll {
  if (Test-Path -LiteralPath $script:ProtokollDatei) { Start-Process notepad.exe -ArgumentList ('"' + $script:ProtokollDatei + '"') }
  else { Zeige-Nachricht (Get-FixText 'Message96') | Out-Null }
}
function Klick-Hilfe {
  $name = if ($script:FixLanguage -eq 'de') { 'LIESMICH.txt' } else { "HELP.$script:FixLanguage.txt" }
  $datei = Join-Path (Split-Path -Parent $script:SkriptDir) $name
  if (-not (Test-Path -LiteralPath $datei)) { $datei = Join-Path $script:InstallDir $name }
  if (Test-Path -LiteralPath $datei) { Start-Process notepad.exe -ArgumentList ('"' + $datei + '"') }
  else { Zeige-Nachricht (Get-FixText 'Message97') | Out-Null }
}
function Beim-Schliessen($e) {
  if ($script:Async -and $script:Async.Aktion -ne 'Analyse') {
    Zeige-Nachricht (Get-FixText 'Message98') | Out-Null
    $e.Cancel = $true
    return
  }
  $script:Beenden = $true
  Stop-Hintergrund
}

# ------------------------------------------------------------------ Start
if (-not $Global:AMDFIX_NOSHOW) {
  try {
    if (-not (Test-IstAdmin)) {
      # Mit Administratorrechten neu starten (gleiche PowerShell-Version).
      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = (Get-Process -Id $PID).Path
      $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $PSCommandPath + '"'
      $psi.Verb = 'runas'
      $psi.UseShellExecute = $true
      try { [void][System.Diagnostics.Process]::Start($psi) } catch {}   # Windows-Abfrage abgelehnt
      return
    }
    $neu = $false
    $script:Mutex = New-Object System.Threading.Mutex($true, 'Global\Radeon-atieclxx-SSD-Fix-Oberflaeche', [ref]$neu)
    if (-not $neu) {
      [void][System.Windows.Forms.MessageBox]::Show((Get-FixText 'Message99'), 'Radeon-atieclxx-SSD-Fix', 'OK', 'Information')
      $script:Mutex.Dispose()
      $script:Mutex = $null
      return
    }
    & logman stop $script:TraceName -ets *> $null    # Reste einer abgebrochenen Aufzeichnung beenden
    $form = Build-Form
    $form.Add_Shown({ $this.Activate(); Start-Hintergrund 'Analyse' })
    [void]$form.ShowDialog()
  } catch {
    $text = (Get-FixText 'Message100') + $script:NL + $_.Exception.Message
    try { Add-Content -LiteralPath (Join-Path $env:TEMP 'Radeon-atieclxx-SSD-Fix-Fehler.txt') -Value ((Get-Date -Format s) + '  ' + $_.Exception.ToString()) -Encoding UTF8 } catch {}
    try { [void][System.Windows.Forms.MessageBox]::Show($text, 'Radeon-atieclxx-SSD-Fix', 'OK', 'Error') } catch {}
  } finally {
    if (Test-IstAdmin) { Stop-Hintergrund }
    if ($script:Timer) { try { $script:Timer.Dispose() } catch {} }
    if ($script:Mutex) { try { $script:Mutex.ReleaseMutex() } catch {}; try { $script:Mutex.Dispose() } catch {} }
  }
}
