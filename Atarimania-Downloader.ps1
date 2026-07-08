Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------
# Persistent Settings File
# ------------------------------------------------------------
$ConfigPath = Join-Path $PSScriptRoot "Atarimania-GUI.config"

# Default window settings
$DefaultWidth  = 640
$DefaultHeight = 480

# ------------------------------------------------------------
# Load Saved Window Settings
# ------------------------------------------------------------
$FormX = $null
$FormY = $null
$FormW = $DefaultWidth
$FormH = $DefaultHeight

if (Test-Path $ConfigPath) {
    try {
        $cfg = Get-Content $ConfigPath | ConvertFrom-Json
        $FormX = $cfg.X
        $FormY = $cfg.Y
        $FormW = $cfg.Width
        $FormH = $cfg.Height
        $Url = $cfg.Url
        $File = $cfg.File
        $Iterations = $cfg.Iterations
    } catch {
        # Ignore malformed config
    }
}

# ------------------------------------------------------------
# Load Icon from Local Directory
# ------------------------------------------------------------
$iconPath = Join-Path $PSScriptRoot "favicon.ico"

function Get-LocalIcon {
    if (Test-Path $iconPath) {
        try {
            return New-Object System.Drawing.Icon($iconPath)
        } catch {
            Write-Host "Failed to load icon from $iconPath"
            return $null
        }
    } else {
        Write-Host "Icon file not found: $iconPath"
        return $null
    }
}

# ------------------------------------------------------------
# Create Form
# ------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Atarimania - Manual Downloader"
$form.TopMost = $true
$form.StartPosition = "Manual"
$form.FormBorderStyle = "Sizable"
$form.Icon = Get-LocalIcon

# Apply saved size
$form.Width  = $FormW
$form.Height = $FormH

# Center or restore location
if ($FormX -and $FormY) {
    $form.Location = New-Object System.Drawing.Point($FormX, $FormY)
} else {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Location = New-Object System.Drawing.Point(
        ($screen.Width  - $FormW) / 2,
        ($screen.Height - $FormH) / 2
    )
}

# ------------------------------------------------------------
# Label: URL + Mask
# ------------------------------------------------------------
$labelUrlMask = New-Object System.Windows.Forms.Label
$labelUrlMask.Text = "URL + Mask"
$labelUrlMask.AutoSize = $true
$labelUrlMask.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$labelUrlMask.Location = New-Object System.Drawing.Point(10, 10)
$form.Controls.Add($labelUrlMask)

# ------------------------------------------------------------
# Textbox: URL + Mask Input
# ------------------------------------------------------------
$textUrlMask = New-Object System.Windows.Forms.TextBox
$textUrlMask.Location = New-Object System.Drawing.Point(10, 30)
$textUrlMask.Width = $form.ClientSize.Width - 20
$textUrlMask.Anchor = "Top, Left, Right"
$textUrlMask.Text = $Url #"https://www.atarimania.com/2600/boxes/hi_res/Alien_i{0}.jpg"
$form.Controls.Add($textUrlMask)

# ------------------------------------------------------------
# Label: Filename Mask
# ------------------------------------------------------------
$labelFilenameMask = New-Object System.Windows.Forms.Label
$labelFilenameMask.Text = "Filename Mask"
$labelFilenameMask.AutoSize = $true
$labelFilenameMask.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$labelFilenameMask.Location = New-Object System.Drawing.Point(10, 65)
$form.Controls.Add($labelFilenameMask)

# ------------------------------------------------------------
# Textbox: Filename Mask Input
# ------------------------------------------------------------
$textFilenameMask = New-Object System.Windows.Forms.TextBox
$textFilenameMask.Location = New-Object System.Drawing.Point(10, 85)
$textFilenameMask.Width = $form.ClientSize.Width - 20
$textFilenameMask.Anchor = "Top, Left, Right"
$textFilenameMask.Text = $File #"Alien_{0}.jpg"
$form.Controls.Add($textFilenameMask)

# ------------------------------------------------------------
# Label: Iterations
# ------------------------------------------------------------
$labelIterations = New-Object System.Windows.Forms.Label
$labelIterations.Text = "Iterations"
$labelIterations.AutoSize = $true
$labelIterations.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$labelIterations.Location = New-Object System.Drawing.Point(10, 118)
$form.Controls.Add($labelIterations)

# ------------------------------------------------------------
# NumericUpDown: Iterations Spinner
# ------------------------------------------------------------
$spinnerIterations = New-Object System.Windows.Forms.NumericUpDown
$spinnerIterations.Location = New-Object System.Drawing.Point(10, 140)
$spinnerIterations.Width = 80
$spinnerIterations.Minimum = 1
$spinnerIterations.Maximum = 9999
$spinnerIterations.Value = [int]$Iterations
$form.Controls.Add($spinnerIterations)

# ------------------------------------------------------------
# Download Button
# ------------------------------------------------------------
$buttonDownload = New-Object System.Windows.Forms.Button
$buttonDownload.Text = "Download"
$buttonDownload.Location = New-Object System.Drawing.Point(10, 180)
$buttonDownload.Width = 120
$buttonDownload.Height = 30
$form.Controls.Add($buttonDownload)

# ------------------------------------------------------------
# Download Button Click Event
# ------------------------------------------------------------
$buttonDownload.Add_Click({
    $iterations = [int]$spinnerIterations.Value
    $urlMask    = $textUrlMask.Text
    $fileMask   = $textFilenameMask.Text

    # Extract cartridge name from mask
    $cartridge = ($fileMask -replace "_\{0\}.jpg","")
    $bar = ""
    $mask = ""

    for ($i = 1; $i -le $iterations; $i++) {

        if($i -eq 1) {
            $bar = ""
            $mask = "00_c"
        } else {
            $bar = "_" + $i.ToString()
            $mask = ($i - 1).ToString().PadLeft(2, '0')
        }

        # Build URL and filename
        $url  = $urlMask -f $bar
        $file = $fileMask -f $mask

        $outputPath = Join-Path (Get-Location) $file

        try {
            Write-Host "Downloading $url -> $outputPath"
            Invoke-WebRequest -Uri $url -OutFile $outputPath -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to download $url"
        }
    }

    # ------------------------------------------------------------
    # Copy IC file to <cartridge>_00_ic.jpg
    # ------------------------------------------------------------
    $sourceIC = Join-Path (Get-Location) "inside_cover.jpg"   # <-- adjust if needed
    $destIC   = Join-Path (Get-Location) ("{0}_00_ic.jpg" -f $cartridge)

    if (Test-Path $sourceIC) {
        Copy-Item $sourceIC $destIC -Force
        Write-Host "Copied IC file -> $destIC"
    } else {
        Write-Host "IC source file not found: $sourceIC"
    }
})

# ------------------------------------------------------------
# Save Window Settings on Close
# ------------------------------------------------------------
$form.Add_FormClosing({
    $out = [PSCustomObject]@{
        X      = $form.Location.X
        Y      = $form.Location.Y
        Width  = $form.Width
        Height = $form.Height
        Url    = $textUrlMask.Text
        File   = $textFilenameMask.Text
        Iterations = $spinnerIterations.Value.ToString()

    }
    $out | ConvertTo-Json | Set-Content $ConfigPath
})

# ------------------------------------------------------------
# Show GUI
# ------------------------------------------------------------
[System.Windows.Forms.Application]::EnableVisualStyles()
$form.ShowDialog()