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
    [string]$Image = "lbjlaq/antigravity-manager:latest",
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

if ($Image -like "*:latest") {
    Write-Warn "La imagen usa el tag 'latest'. Funciona, pero es menos predecible que fijar una version."
}

Write-Step "Descargando imagen del contenedor..."
docker pull $Image | Out-Null
Write-Ok "Imagen lista: $Image"

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
$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 2
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 3 -UseBasicParsing
        if ($resp.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {
    }
}

if ($ready) {
    Write-Ok "Servicio disponible en http://127.0.0.1:$Port"
} else {
    Write-Warn "El servicio no respondio a tiempo. Revisa: docker logs antigravity-manager"
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
    embeddingsProvider = [ordered]@{
        provider = "openai"
        model = "text-embedding-3-small"
        apiBase = "http://127.0.0.1:$Port/v1"
        apiKey = $ApiKey
    }
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
