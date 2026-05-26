# VPS Rig Universal 1Password Sync (PowerShell 7)
# Mapping: 1 File <-> 1 Item (Named: "SERVER - filename")

param (
    [switch]$Pull,
    [switch]$Push,
    [switch]$PushExample,
    [string]$Server = "",
    [string]$Vault = "",
    [string]$Tags = ""
)

# --- HELPERS ---

function Show-Usage {
    Write-Host @"
Usage: 
  ./op-sync.ps1 -Pull [-Server <name>] [-Vault <name>]
  ./op-sync.ps1 -Push [-Server <name>] [-Vault <name>] [-Tags <list>]
  ./op-sync.ps1 -PushExample [-Server <name>] [-Vault <name>] [-Tags <list>]

Arguments:
  -Server : The hostname prefix for 1Password items (e.g. "web01.example.com").
            Can also be set via VPS_HOSTNAME in .env.
  -Vault  : The 1Password vault name to sync with (e.g. "Private").
            Can also be set via VPS_VAULT in .env.
  -Tags   : Comma-separated list of tags to apply to items during push.

Current Runtime Config:
  Server : $(if ($Server) { $Server } else { '<MISSING>' })
  Vault  : $(if ($Vault) { $Vault } else { '<MISSING>' })
  Tags   : $(if ($Tags) { $Tags } else { '<none>' })
"@ -ForegroundColor Cyan
}

# --- CONFIGURATION AUTO-LOAD ---
# If Server or Vault are not provided, try to load them from .env
if (-not $Server -or -not $Vault) {
    if (Test-Path .env) {
        Get-Content .env | ForEach-Object {
            $line = $_.Trim()
            if ($line -notmatch '^#' -and $line -match '=') {
                $parts = $line -split '=', 2
                $key = $parts[0].Trim()
                $val = $parts[1].Trim()
                if (-not $Server -and $key -eq 'VPS_HOSTNAME') { $Server = $val }
                if (-not $Vault -and $key -eq 'VPS_VAULT') { $Vault = $val }
            }
        }
    }
}

# Validate required configuration
if (-not $Server -or -not $Vault) {
    Show-Usage
    Write-Error "Required configuration missing (Server or Vault). Provide via arguments or .env"
    exit 1 
}

function Check-Field {
    param($Data, $Section, $Key, $Value)
    
    $OpSection = if ($Section) { $Section } else { "__root__" }
    $fieldRef = "${OpSection}.${Key}"
    
    $match = $null
    if ($Data -and $Data.fields) {
        $match = $Data.fields | Where-Object {
            $secMatch = $_.section -and ($_.section.label -eq $OpSection)
            $secMatch -and ($_.label -eq $Key)
        }
    }
    
    if (-not $match) {
        Write-Host "  [NEW] $fieldRef" -ForegroundColor Cyan
        $choice = Read-Host "    Field does not exist. Add it? (Y/n)"
        if ($choice -notmatch '^n|^N') { return "${fieldRef}[password]=$Value" }
    } else {
        $existingVal = $match[0].value
        if ($existingVal -ne $Value) {
            Write-Host "  [DIFF] $fieldRef" -ForegroundColor Yellow
            Write-Host "    Local : $Value" -ForegroundColor Gray
            Write-Host "    Vault : $existingVal" -ForegroundColor DarkGray
            $choice = Read-Host "    Overwrite vault? (y/N)"
            if ($choice -match '^y|^Y') { return "${fieldRef}[password]=$Value" }
        } else {
            Write-Host "  [OK] $fieldRef (No change)" -ForegroundColor DarkGreen
        }
    }
    return $null
}

function Push-FileToOp {
    param($Path, $OverrideFilename)
    
    $Filename = if ($OverrideFilename) { $OverrideFilename } else { Split-Path $Path -Leaf }
    $ItemFilename = $Filename.Replace(".example", "")
    $Item = "$Server - $ItemFilename"
    
    $existingJson = op item get $Item --vault $Vault --format json 2>$null
    if (-not $existingJson) {
        Write-Host "  !! Creating item: $Item" -ForegroundColor Cyan
        $template = op item template get Server --format json | ConvertFrom-Json
        $template.title = $Item
        $template.fields = @()
        $template.sections = @()
        $template | ConvertTo-Json -Depth 10 | op item create - --vault $Vault | Out-Null
        
        $existingJson = op item get $Item --vault $Vault --format json 2>$null
    }
    
    $existingData = $existingJson | ConvertFrom-Json
    Write-Host "`nPushing $Filename -> $Item..." -ForegroundColor Magenta
    $Updates = @()

    if ($Filename -like "*.ini*" -or $Filename -eq "backup.ini.example") {
        $Section = ""
        Get-Content $Path | ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^\[(.*)\]$') {
                $Section = $Matches[1]
            } elseif ($line -and -not $line.StartsWith("#") -and $line -match '=') {
                $parts = $line -split '=', 2
                $key = $parts[0].Trim()
                $val = $parts[1].Trim()
                $update = Check-Field -Data $existingData -Section $Section -Key $key -Value $val
                if ($update) { $Updates += $update }
            }
        }
    } elseif ($Filename -eq ".env" -or $Filename -eq ".env.example") {
        Get-Content $Path | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line -match '=') {
                $parts = $line -split '=', 2
                $update = Check-Field -Data $existingData -Section "" -Key $parts[0].Trim() -Value $parts[1].Trim()
                if ($update) { $Updates += $update }
            }
        }
    } else {
        $content = Get-Content $Path -Raw
        $update = Check-Field -Data $existingData -Section "" -Key "password" -Value $content
        if ($update) { $Updates += $update }
    }

    if ($Updates.Count -gt 0 -or $Tags) {
        try {
            $editArgs = @($Item)
            if ($Updates.Count -gt 0) {
                Write-Host "  Applying $($Updates.Count) field update(s)..." -ForegroundColor Yellow
                $editArgs += $Updates
            }
            if ($Tags) {
                Write-Host "  Applying tags: $Tags" -ForegroundColor Yellow
                $editArgs += "--tags"
                $editArgs += $Tags
            }
            $editArgs += "--vault"
            $editArgs += $Vault
            
            op item edit @editArgs | Out-Null
        } catch {
            Write-Error "Failed to push $Item. Error: $_"
        }
    } else {
        Write-Host "  No updates required for $Item." -ForegroundColor DarkGreen
    }
}

function Pull-ItemFromOp {
    param($Title)
    $Filename = $Title.Replace("$Server - ", "")
    $Path = if ($Filename -eq ".env") { ".env" } else { "secrets/$Filename" }

    if (Test-Path $Path) {
        Write-Host "`n  [CONFLICT] $Path already exists locally." -ForegroundColor Yellow
        $choice = Read-Host "    Overwrite local file? (y/N)"
        if ($choice -notmatch '^y|^Y') {
            Write-Host "  Skipping $Path." -ForegroundColor DarkGray
            return
        }
    }

    Write-Host "`nPulling $Title -> $Path..." -ForegroundColor Green
    $json = op item get $Title --format json | ConvertFrom-Json

    $Content = @()
    
    $ValidFields = $json.fields | Where-Object { 
        $_.id -ne "notesPlain" -and 
        $_.label -ne "notesPlain"
    }
    
    if ($Filename -like "*.ini") {
        $Groups = $ValidFields | Group-Object { if ($_.section) { $_.section.label } else { "" } }
        foreach ($group in $Groups) {
            if ($group.Name -and $group.Name -ne "__root__") { 
                $Content += ""
                $Content += "[$($group.Name)]" 
            }
            foreach ($field in $group.Group) {
                $Content += "$($field.label) = $($field.value)"
            }
        }
    } elseif ($Filename -eq ".env") {
        foreach ($field in $ValidFields) {
            $Content += "$($field.label)=$($field.value)"
        }
    } else {
        $val = ($ValidFields | Where-Object { $_.section.label -eq "__root__" -and $_.label -eq "password" }).value
        if (-not $val) { $val = $ValidFields[0].value }
        $Content = @($val)
    }

    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

    # Force LF (Linux) line endings and UTF-8 without BOM for VPS compatibility
    $text = ($Content -join "`n") + "`n"
    $fullPath = Join-Path $PWD $Path
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($fullPath, $text, $utf8NoBom)
}

# --- MAIN ---

if (-not (Get-Command op -ErrorAction SilentlyContinue)) { 
    Write-Error "1Password CLI (op.exe) not found."
    exit 1 
}

# Ensure exactly one command is provided
$commandCount = @($Pull, $Push, $PushExample).Where({$_}).Count
if ($commandCount -ne 1) {
    Show-Usage
    exit 0
}

# Verify authentication
if (-not (op whoami 2>$null)) { op signin | Out-Null }

if ($Push) {
    Write-Host "--- PUSH MODE: Local REAL secrets -> 1Password ($Server) ---" -ForegroundColor Yellow
    if (Test-Path .env) { Push-FileToOp ".env" }
    if (Test-Path secrets) {
        Get-ChildItem secrets/*.example | ForEach-Object {
            $real = $_.FullName.Replace(".example", "")
            if (Test-Path $real) { Push-FileToOp $real }
        }
    }
} elseif ($PushExample) {
    Write-Host "--- PUSH-EXAMPLE MODE: Local templates -> 1Password ($Server) ---" -ForegroundColor Yellow
    if (Test-Path .env.example) { Push-FileToOp ".env.example" ".env" }
    if (Test-Path secrets) {
        Get-ChildItem secrets/*.example | ForEach-Object {
            Push-FileToOp $_.FullName
        }
    }
} elseif ($Pull) {
    Write-Host "--- PULL MODE: 1Password -> Local ($Server) ---" -ForegroundColor Green
    $items = op item list --vault $Vault --format json | ConvertFrom-Json | Where-Object { $_.title -like "$Server - *" }
    if (-not $items) { Write-Host "No items found." -ForegroundColor Red }
    else { foreach ($item in $items) { Pull-ItemFromOp $item.title } }
}

Write-Host "`nDone!" -ForegroundColor Green
