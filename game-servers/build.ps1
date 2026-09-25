# ArcadeNode Game Server Image Builder
# PowerShell script for building game server cartridge images

param(
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$Images,
    
    [Alias("v")]
    [string]$Version = "latest",
    
    [Alias("r")]
    [string]$Registry = "",
    
    [Alias("p")]
    [switch]$Push,
    
    [Alias("P")]
    [switch]$Parallel,
    
    [Alias("l")]
    [switch]$List,
    
    [Alias("c")]
    [switch]$Clean,
    
    [Alias("h")]
    [switch]$Help,
    
    [string]$RemoteHost = ""
)

# Image definitions
$ImageDefinitions = @{
    "minecraft"         = "Minecraft Java Edition"
    "minecraft-bedrock" = "Minecraft Bedrock Edition"
    "project-zomboid"   = "Project Zomboid"
    "arma-reforger"     = "Arma Reforger"
}

function Write-Banner {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         ArcadeNode Game Server Image Builder              ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Show-Usage {
    Write-Host @"
Usage: .\build.ps1 [OPTIONS] [IMAGE...]

Build ArcadeNode game server Docker images

Options:
  -Help, -h              Show this help message
  -Version, -v TAG       Set version tag (default: latest)
  -Registry, -r URL      Set registry URL for tagging
  -Push, -p              Push images after building
  -Parallel, -P          Build images in parallel
  -List, -l              List available images
  -Clean, -c             Remove all arcadenode images
  -RemoteHost HOST       Build on remote host via SSH (e.g., user@host)

Images:
  minecraft              Minecraft Java Edition (Paper/Vanilla)
  minecraft-bedrock      Minecraft Bedrock Edition
  project-zomboid        Project Zomboid Dedicated Server
  arma-reforger          Arma Reforger Dedicated Server
  all                    Build all images (default)

Examples:
  .\build.ps1                                    # Build all images locally
  .\build.ps1 minecraft                          # Build only Minecraft Java
  .\build.ps1 -Version 1.0.0 -Push               # Build all with version tag and push
  .\build.ps1 -RemoteHost user@192.168.1.100     # Build on remote host
  .\build.ps1 -Registry ghcr.io/user -Push       # Build, tag for registry, and push
"@
}

function Show-ImageList {
    Write-Host "Available game server images:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($key in $ImageDefinitions.Keys) {
        Write-Host "  - $key" -ForegroundColor White -NoNewline
        Write-Host ": $($ImageDefinitions[$key])" -ForegroundColor Gray
    }
}

function Invoke-DockerCommand {
    param([string]$Command)
    
    if ($RemoteHost) {
        $result = ssh $RemoteHost $Command 2>&1
        return $result
    } else {
        $result = Invoke-Expression $Command 2>&1
        return $result
    }
}

function Remove-ArcadeNodeImages {
    Write-Status "Removing all ArcadeNode game server images..."
    
    $images = Invoke-DockerCommand "docker images --filter 'reference=arcadenode/*' -q"
    
    if ($images) {
        Invoke-DockerCommand "docker rmi -f $($images -join ' ')"
        Write-Success "All ArcadeNode images removed"
    } else {
        Write-Warning "No ArcadeNode images found"
    }
}

function Build-Image {
    param(
        [string]$Name,
        [string]$BuildPath
    )
    
    $description = $ImageDefinitions[$Name]
    $imageName = "arcadenode/${Name}"
    
    Write-Status "Building ${description} (${imageName}:${Version})..."
    
    $startTime = Get-Date
    
    try {
        if ($RemoteHost) {
            $buildCmd = "cd $BuildPath && docker build -t ${imageName}:${Version} ."
            $result = ssh $RemoteHost $buildCmd
            if ($LASTEXITCODE -ne 0) { throw "Build failed" }
        } else {
            $result = docker build -t "${imageName}:${Version}" $BuildPath 2>&1
            if ($LASTEXITCODE -ne 0) { throw "Build failed" }
        }
        
        $duration = ((Get-Date) - $startTime).TotalSeconds
        Write-Success "${description} built successfully ($([math]::Round($duration, 1))s)"
        
        # Tag as latest if version is not latest
        if ($Version -ne "latest") {
            Invoke-DockerCommand "docker tag ${imageName}:${Version} ${imageName}:latest"
        }
        
        # Tag for registry if specified
        if ($Registry) {
            $registryTag = "${Registry}/${Name}:${Version}"
            Invoke-DockerCommand "docker tag ${imageName}:${Version} $registryTag"
            Write-Status "Tagged as ${registryTag}"
            
            if ($Push) {
                Write-Status "Pushing ${registryTag}..."
                Invoke-DockerCommand "docker push $registryTag"
                Write-Success "Pushed ${registryTag}"
            }
        } elseif ($Push) {
            Write-Status "Pushing ${imageName}:${Version}..."
            Invoke-DockerCommand "docker push ${imageName}:${Version}"
            Write-Success "Pushed ${imageName}:${Version}"
        }
        
        return $true
    } catch {
        Write-Error "Failed to build ${description}: $_"
        return $false
    }
}

function Build-AllImages {
    param([string[]]$ImagesToBuild)
    
    $scriptDir = $PSScriptRoot
    if ($RemoteHost) {
        # Assume remote path
        $scriptDir = "~/ArcadeNode/game-servers"
    }
    
    $succeeded = @()
    $failed = @()
    
    if ($Parallel -and -not $RemoteHost) {
        Write-Status "Building images in parallel..."
        
        $jobs = @()
        foreach ($name in $ImagesToBuild) {
            $buildPath = Join-Path $scriptDir $name
            $jobs += Start-Job -ScriptBlock {
                param($Name, $BuildPath, $Version, $Registry, $Push)
                docker build -t "arcadenode/${Name}:${Version}" $BuildPath
                return $LASTEXITCODE -eq 0
            } -ArgumentList $name, $buildPath, $Version, $Registry, $Push
        }
        
        $jobs | Wait-Job | ForEach-Object {
            $result = Receive-Job $_
            $name = $ImagesToBuild[$jobs.IndexOf($_)]
            if ($result) {
                $succeeded += $name
            } else {
                $failed += $name
            }
            Remove-Job $_
        }
    } else {
        foreach ($name in $ImagesToBuild) {
            $buildPath = if ($RemoteHost) { "${scriptDir}/${name}" } else { Join-Path $scriptDir $name }
            
            if (Build-Image -Name $name -BuildPath $buildPath) {
                $succeeded += $name
            } else {
                $failed += $name
            }
        }
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                      Build Summary                         " -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    if ($succeeded.Count -gt 0) {
        Write-Success "Built: $($succeeded -join ', ')"
    }
    
    if ($failed.Count -gt 0) {
        Write-Error "Failed: $($failed -join ', ')"
        return $false
    }
    
    Write-Host ""
    Write-Success "All images built successfully!"
    
    # Show image sizes
    Write-Host ""
    Write-Status "Image sizes:"
    Invoke-DockerCommand "docker images --filter 'reference=arcadenode/*' --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}'"
    
    return $true
}

# Main execution
if ($Help) {
    Show-Usage
    exit 0
}

if ($List) {
    Show-ImageList
    exit 0
}

if ($Clean) {
    Remove-ArcadeNodeImages
    exit 0
}

# Determine which images to build
$imagesToBuild = @()

if ($Images -contains "all" -or $Images.Count -eq 0) {
    $imagesToBuild = $ImageDefinitions.Keys
} else {
    foreach ($img in $Images) {
        if ($ImageDefinitions.ContainsKey($img)) {
            $imagesToBuild += $img
        } else {
            Write-Error "Unknown image: $img"
            Write-Host "Use -List to see available images"
            exit 1
        }
    }
}

Write-Banner
Write-Status "Version: $Version"
Write-Status "Registry: $(if ($Registry) { $Registry } else { 'none' })"
Write-Status "Push: $Push"
Write-Status "Parallel: $Parallel"
Write-Status "Remote Host: $(if ($RemoteHost) { $RemoteHost } else { 'local' })"
Write-Status "Images: $($imagesToBuild -join ', ')"
Write-Host ""

$result = Build-AllImages -ImagesToBuild $imagesToBuild

if (-not $result) {
    exit 1
}
