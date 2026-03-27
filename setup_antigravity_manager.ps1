# =============================================================================
# setup_antigravity_manager.ps1
# Instala y configura Antigravity-Manager en Windows
# Compatible con Antigravity IDE y VS Code (Continue / Kilo Code)
# =============================================================================

param(
    [string]$ApiKey = "sk-antigravity",
    [string]$WebPassword = "",
    [ValidateRange(1, 65535)]
    [int]$Port = 8045,
    [string]$Image = "antigravity-manager-local:4.1.31-es",
    [string]$SourceDir = "",
    [switch]$RebuildImage,
    [switch]$AllowLanAccess
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n[+] $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "    OK: $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "    !! $Message" -ForegroundColor Yellow
}

function New-RandomPassword {
    param([int]$Length = 20)

    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*_-"
    $bytes = New-Object byte[] ($Length)
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $result = for ($i = 0; $i -lt $Length; $i++) {
        $chars[$bytes[$i] % $chars.Length]
    }
    -join $result
}

function Wait-ServiceHealthy {
    param(
        [int]$HealthPort,
        [int]$Attempts = 20,
        [int]$DelaySeconds = 2
    )

    for ($i = 0; $i -lt $Attempts; $i++) {
        Start-Sleep -Seconds $DelaySeconds
        try {
            $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$HealthPort/health" -TimeoutSec 3 -UseBasicParsing
            if ($resp.StatusCode -eq 200) {
                return $true
            }
        } catch {
        }
    }

    return $false
}

function Update-UiConfig {
    param(
        [string]$ConfigPath,
        [string]$Language,
        [bool]$LanEnabled,
        [int]$ListenPort
    )

    if (-not (Test-Path $ConfigPath)) {
        Write-Warn "No se encontro gui_config.json para ajustar el idioma."
        return $false
    }

    try {
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        $config.language = $Language

        if ($null -ne $config.proxy) {
            $config.proxy.allow_lan_access = $LanEnabled
            $config.proxy.port = $ListenPort
        }

        $json = $config | ConvertTo-Json -Depth 12
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ConfigPath, $json, $utf8NoBom)
        Write-Ok "Interfaz configurada en espanol."
        return $true
    } catch {
        Write-Warn "No se pudo actualizar gui_config.json: $($_.Exception.Message)"
        return $false
    }
}

function Resolve-SourceDir {
    param([string]$ConfiguredSourceDir)

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredSourceDir)) {
        return $ConfiguredSourceDir
    }

    if ($PSScriptRoot) {
        $siblingDir = Join-Path (Split-Path $PSScriptRoot -Parent) "antigravity-manager-src"
        if (Test-Path $siblingDir) {
            return $siblingDir
        }
    }

    return (Join-Path $env:USERPROFILE "Documents\Antigravity\antigravity-manager-src")
}

function Test-DockerImageExists {
    param([string]$ImageName)

    docker image inspect $ImageName *> $null
    return ($LASTEXITCODE -eq 0)
}

if ([string]::IsNullOrWhiteSpace($WebPassword)) {
    $WebPassword = New-RandomPassword
    Write-Warn "No se recibio WebPassword. Se genero una clave aleatoria segura."
} elseif ($WebPassword -eq "admin1234") {
    Write-Warn "La clave 'admin1234' es debil. Se reemplazara por una clave aleatoria segura."
    $WebPassword = New-RandomPassword
}

$publishSpec = if ($AllowLanAccess) { "${Port}:8045" } else { "127.0.0.1:${Port}:8045" }
$dataDir = Join-Path $env:USERPROFILE ".antigravity_tools"
$continueDir = Join-Path $env:USERPROFILE ".continue"
$continueConfigPath = Join-Path $continueDir "config.json"
$kiloSettingsPath = Join-Path $env:USERPROFILE "antigravity_manager_kilo_settings.json"
$resolvedSourceDir = Resolve-SourceDir -ConfiguredSourceDir $SourceDir

Write-Step "Verificando Docker Desktop..."
try {
    $dockerVersion = docker --version 2>&1
    Write-Ok "Docker encontrado: $dockerVersion"
} catch {
    Write-Host @"

[ERROR] Docker Desktop no esta instalado o no esta corriendo.

Instalalo desde:
https://www.docker.com/products/docker-desktop/

Luego vuelve a ejecutar este script.
"@ -ForegroundColor Red
    exit 1
}

try {
    docker info | Out-Null
    Write-Ok "Docker daemon activo."
} catch {
    Write-Host "[ERROR] Docker esta instalado pero no esta corriendo. Abre Docker Desktop y espera a que inicie." -ForegroundColor Red
    exit 1
}

Write-Step "Limpiando instalacion previa si existe..."
$existing = docker ps -a --filter "name=antigravity-manager" --format "{{.Names}}" 2>&1
if ($existing -match "^antigravity-manager$") {
    docker stop antigravity-manager | Out-Null
    docker rm antigravity-manager | Out-Null
    Write-Ok "Contenedor previo eliminado."
} else {
    Write-Ok "No habia contenedor previo."
}

Write-Step "Preparando directorios locales..."
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir | Out-Null
}
if (-not (Test-Path $continueDir)) {
    New-Item -ItemType Directory -Path $continueDir | Out-Null
}
Write-Ok "Datos en: $dataDir"
Write-Ok "Continue en: $continueDir"

if ($Image -like "antigravity-manager-local:*") {
    Write-Ok "Instalacion configurada para usar imagen local: $Image"
} elseif ($Image -like "*:latest") {
    Write-Warn "La imagen usa el tag 'latest'. Funciona, pero es menos predecible que fijar una version."
} elseif ($Image -match "@sha256:") {
    Write-Ok "Imagen fijada por digest para instalaciones reproducibles."
}

Write-Step "Preparando imagen del contenedor..."
if ((-not $RebuildImage) -and (Test-DockerImageExists -ImageName $Image)) {
    Write-Ok "Imagen encontrada localmente: $Image"
} else {
    $dockerfilePath = Join-Path $resolvedSourceDir "docker\\Dockerfile"
    if (-not (Test-Path $dockerfilePath)) {
        Write-Host @" 

[ERROR] No se encontro una imagen local ni un Dockerfile util para construirla.

Ruta esperada del codigo fuente:
$resolvedSourceDir

Se esperaba encontrar:
$dockerfilePath

Clona o prepara primero el fuente local de Antigravity-Manager y vuelve a ejecutar este script.
"@ -ForegroundColor Red
        exit 1
    }

    Write-Ok "Fuente local detectada en: $resolvedSourceDir"
    if ($RebuildImage -and (Test-DockerImageExists -ImageName $Image)) {
        Write-Warn "Se reconstruira la imagen local existente: $Image"
    }
    Write-Step "Construyendo imagen local desde codigo fuente..."
    docker build -t $Image -f $dockerfilePath $resolvedSourceDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Fallo la construccion de la imagen local." -ForegroundColor Red
        exit 1
    }
    Write-Ok "Imagen local construida: $Image"
}

Write-Step "Iniciando Antigravity-Manager..."
docker run -d `
    --name antigravity-manager `
    --restart unless-stopped `
    -p $publishSpec `
    -e "API_KEY=$ApiKey" `
    -e "WEB_PASSWORD=$WebPassword" `
    -e "ABV_MAX_BODY_SIZE=104857600" `
    -v "${dataDir}:/root/.antigravity_tools" `
    $Image | Out-Null
Write-Ok "Contenedor iniciado."

Write-Step "Esperando health check..."
$ready = Wait-ServiceHealthy -HealthPort $Port

if ($ready) {
    Write-Ok "Servicio disponible en http://127.0.0.1:$Port"
} else {
    Write-Warn "El servicio no respondio a tiempo. Revisa: docker logs antigravity-manager"
}

$guiConfigPath = Join-Path $dataDir "gui_config.json"

Write-Step "Ajustando idioma y preferencias de interfaz..."
if (Update-UiConfig -ConfigPath $guiConfigPath -Language "es" -LanEnabled ([bool]$AllowLanAccess) -ListenPort $Port) {
    docker restart antigravity-manager | Out-Null
    Write-Ok "Contenedor reiniciado para aplicar el idioma."

    if (Wait-ServiceHealthy -HealthPort $Port) {
        Write-Ok "Servicio verificado despues de aplicar la configuracion."
    } else {
        Write-Warn "La interfaz se actualizo, pero el health check no respondio tras reiniciar."
    }
}

Write-Step "Generando configuracion para Continue..."
$continueConfig = [ordered]@{
    models = @(
        [ordered]@{
            title = "Gemini 3.1 Pro - Antigravity-Manager"
            provider = "openai"
            model = "gemini-3.1-pro-high"
            apiBase = "http://127.0.0.1:$Port/v1"
            apiKey = $ApiKey
        },
        [ordered]@{
            title = "Gemini 3.1 Flash - Antigravity-Manager"
            provider = "openai"
            model = "gemini-3.1-flash"
            apiBase = "http://127.0.0.1:$Port/v1"
            apiKey = $ApiKey
        },
        [ordered]@{
            title = "Claude Sonnet 4.6 - Antigravity-Manager"
            provider = "openai"
            model = "claude-sonnet-4-6"
            apiBase = "http://127.0.0.1:$Port/v1"
            apiKey = $ApiKey
        },
        [ordered]@{
            title = "Claude Opus 4.6 - Antigravity-Manager"
            provider = "openai"
            model = "claude-opus-4-6"
            apiBase = "http://127.0.0.1:$Port/v1"
            apiKey = $ApiKey
        }
    )
    tabAutocompleteModel = [ordered]@{
        title = "Gemini Flash Autocomplete"
        provider = "openai"
        model = "gemini-3.1-flash"
        apiBase = "http://127.0.0.1:$Port/v1"
        apiKey = $ApiKey
    }
    slashCommands = @(
        [ordered]@{ name = "share"; description = "Exportar conversacion como Markdown" },
        [ordered]@{ name = "commit"; description = "Generar mensaje de commit Git" },
        [ordered]@{ name = "edit"; description = "Editar codigo seleccionado" }
    )
    allowAnonymousTelemetry = $false
}
$continueConfig | ConvertTo-Json -Depth 6 | Set-Content -Path $continueConfigPath -Encoding utf8
Write-Ok "Continue config -> $continueConfigPath"

Write-Step "Generando configuracion para Kilo Code..."
$kiloSettings = [ordered]@{
    "// INSTRUCCIONES" = "Fusiona estas claves en tu settings.json de VS Code"
    "kilocode.openAiCompatModelId" = "gemini-3.1-pro-high"
    "kilocode.openAiCompatBaseUrl" = "http://127.0.0.1:$Port/v1"
    "kilocode.openAiCompatApiKey" = $ApiKey
    "kilocode.openAiCompatModelInfo" = [ordered]@{
        maxTokens = 65536
        contextWindow = 1000000
        supportsPromptCache = $false
        supportsImages = $true
    }
}
$kiloSettings | ConvertTo-Json -Depth 5 | Set-Content -Path $kiloSettingsPath -Encoding utf8
Write-Ok "Kilo Code config -> $kiloSettingsPath"

Write-Host ""
Write-Host "===================================================================" -ForegroundColor White
Write-Host " ANTIGRAVITY-MANAGER - INSTALACION COMPLETA" -ForegroundColor White
Write-Host "===================================================================" -ForegroundColor White
Write-Host " Panel web:          http://127.0.0.1:$Port" -ForegroundColor White
Write-Host " API base URL:       http://127.0.0.1:$Port/v1" -ForegroundColor White
Write-Host " API key:            $ApiKey" -ForegroundColor White
Write-Host " Password panel:     $WebPassword" -ForegroundColor White
Write-Host " Puerto publicado:   $publishSpec" -ForegroundColor White
Write-Host "===================================================================" -ForegroundColor White
Write-Host " Siguientes pasos:" -ForegroundColor White
Write-Host " 1. Abre http://127.0.0.1:$Port y agrega cuentas en Accounts." -ForegroundColor White
Write-Host " 2. Usa $continueConfigPath para Continue." -ForegroundColor White
Write-Host " 3. Fusiona $kiloSettingsPath en settings.json para Kilo Code." -ForegroundColor White
Write-Host " 4. Si algo falla, revisa: docker logs antigravity-manager" -ForegroundColor White
Write-Host "===================================================================" -ForegroundColor White
