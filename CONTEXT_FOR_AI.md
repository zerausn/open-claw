# OpenClaw PC - Context for AI

Lee este archivo ANTES de hacer cualquier cambio en `open-claw/`.

## ¿Qué se busca?

Configurar el entorno Windows para gestionar el proxy Antigravity-Manager (rotación de cuentas de IA) y conectar con el Note 9 vía ADB. Este es el "lado PC" del ecosistema OpenClaw.

## ¿Qué se necesita?

1. **Script de Setup Funcional**: `setup_antigravity_manager.ps1` debe configurar todo sin Docker.
2. **Configuración de Sesión**: `continue_config.json` debe reflejar los modelos disponibles actuales.
3. **Documentación Clara**: Para que cualquier IA pueda retomar el trabajo sin preguntar lo mismo.

## Fallas No Corregidas

| Falla | Severidad | Descripción |
|-------|-----------|-------------|
| Docker Legacy | MEDIA | `setup_antigravity_manager.ps1` aún referencia configuración Docker. El usuario decidió NO usar Docker. |
| Config Stale | BAJA | `continue_config.json` puede tener modelos desactualizados. |

## INSTRUCCIÓN CRÍTICA

**NO configurar ni sugerir Docker.** El usuario ha decidido conectarse directamente a las APIs oficiales sin proxy local. Lee las reglas completas en el `AGENTS.md` de la raíz del workspace.

## Arquitectura del Código

```
open-claw/
├── setup_antigravity_manager.ps1  → Script de PowerShell para configurar el entorno
├── continue_config.json           → Configuración de sesión del IDE
├── AGENTS.md                      → Instrucciones tácticas (incluye config proxy)
├── AI.md                          → Reglas de desarrollo
├── CLAUDE.md                      → Instrucciones para Claude
├── GEMINI.md                      → Instrucciones para Gemini
└── README.md                      → Resumen ejecutivo
```
