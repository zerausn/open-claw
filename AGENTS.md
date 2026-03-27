# AGENTS.md - Instrucciones para Antigravity IDE
# Configura el proxy Antigravity-Manager para rotacion multi-cuenta
# Guarda este archivo en la raiz de tu proyecto o carpeta de trabajo
# y Antigravity lo leera automaticamente como contexto del agente.

## Objetivo de este agente

Tienes acceso a un proxy local llamado **Antigravity-Manager** que corre en
`http://127.0.0.1:8045`. Este proxy convierte multiples cuentas de Google
en un endpoint OpenAI-compatible con rotacion automatica de cuota.

- **Base URL:** `http://127.0.0.1:8045/v1`
- **API Key:** `sk-antigravity`
- **Modelos disponibles:** `gemini-3.1-pro-high`, `gemini-3.1-flash`,
  `claude-sonnet-4-6`, `claude-opus-4-6`

## Configurar Antigravity IDE para usar el proxy

Cuando el usuario pida configurar el IDE o mejorar la disponibilidad de tokens,
ejecuta los siguientes pasos en orden:

### Paso 1 - Verificar que el proxy este corriendo

```bash
curl -s http://127.0.0.1:8045/health
```

Si falla, indicar al usuario que ejecute primero `setup_antigravity_manager.ps1`.

### Paso 2 - Abrir configuracion del proveedor AI en Antigravity IDE

Genera y ejecuta este comando para abrir los settings correctos:

```
Ctrl+Shift+P -> "Preferences: Open User Settings (JSON)"
```

Luego fusiona este bloque en el JSON de settings:

```json
{
  "antigravity.aiProvider": "openai-compatible",
  "antigravity.openAiCompatBaseUrl": "http://127.0.0.1:8045/v1",
  "antigravity.openAiCompatApiKey": "sk-antigravity",
  "antigravity.openAiCompatModel": "gemini-3.1-pro-high",
  "antigravity.fallbackModels": [
    "gemini-3.1-flash",
    "claude-sonnet-4-6"
  ]
}
```

### Paso 3 - Verificar modelos disponibles

```bash
curl -s http://127.0.0.1:8045/v1/models \
  -H "Authorization: Bearer sk-antigravity" | python -m json.tool
```

### Paso 4 - Anadir cuentas de Google al proxy

Abrir el panel web en `http://127.0.0.1:8045` -> Accounts -> Add Account.
Cada cuenta de Gmail gratuita agrega un pool separado de cuota.

## Reglas para este agente

- Siempre preferir `gemini-3.1-pro-high` para tareas complejas de analisis.
- Si recibes error 429 (quota exceeded), el proxy rotara automaticamente;
  no es necesario intervenir manualmente.
- Para codigo Python/R de analisis cualitativo (NLP, topic modeling, redes
  de co-ocurrencia), usar `claude-sonnet-4-6` por su mejor comprension
  de estructuras metodologicas complejas.
- Mantener los archivos de configuracion en `~/.antigravity_tools/`.

## Verificacion rapida de todo el stack

```powershell
# PowerShell - verificar estado completo
$headers = @{ Authorization = "Bearer sk-antigravity" }

# 1. Health check
Invoke-WebRequest http://127.0.0.1:8045/health -UseBasicParsing

# 2. Listar modelos
(Invoke-WebRequest http://127.0.0.1:8045/v1/models -Headers $headers |
  ConvertFrom-Json).data | Select-Object id, object

# 3. Test de completions
$body = @{
  model = "gemini-3.1-flash"
  messages = @(@{ role = "user"; content = "Responde solo: OK" })
  max_tokens = 10
} | ConvertTo-Json -Depth 3

Invoke-WebRequest http://127.0.0.1:8045/v1/chat/completions `
  -Method POST `
  -Headers ($headers + @{ "Content-Type" = "application/json" }) `
  -Body $body -UseBasicParsing |
  ConvertFrom-Json | Select-Object -ExpandProperty choices |
  Select-Object -First 1 | Select-Object -ExpandProperty message
```
