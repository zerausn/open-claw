# open-claw

Repositorio de trabajo para dejar Antigravity-Manager instalable de forma local, en espanol y sin depender de la imagen publicada por terceros en tiempo de ejecucion.

## Archivos principales

- `AGENTS.md`
- `continue_config.json`
- `setup_antigravity_manager.ps1`

## Estado actual

- Este repo vive en `C:\Users\ZN-\Documents\Antigravity\open-claw`.
- `origin` apunta a `https://github.com/zerausn/open-claw`.
- La rama `main` ya esta publicada en GitHub.
- La instalacion actual corre con la imagen local `antigravity-manager-local:4.1.31-es`.

## Fuente local usada para construir la imagen

El instalador ya no hace `docker pull` de `lbjlaq/antigravity-manager` por defecto.

Ahora hace esto:

1. Busca la imagen local `antigravity-manager-local:4.1.31-es`.
2. Si no existe, intenta construirla desde una copia local del codigo fuente.
3. Por defecto busca el fuente en una carpeta hermana:
   `C:\Users\ZN-\Documents\Antigravity\antigravity-manager-src`
4. Tambien puedes pasar una ruta explicita con `-SourceDir`.
5. Si cambias el fuente y quieres regenerar la imagen, usa `-RebuildImage`.

Ejemplo:

```powershell
.\setup_antigravity_manager.ps1 `
  -SourceDir "C:\Users\ZN-\Documents\Antigravity\antigravity-manager-src" `
  -RebuildImage
```

## Garantias que deja el instalador

- Publicacion de Docker en `127.0.0.1` por defecto.
- Interfaz web forzada a espanol en `gui_config.json`.
- Password del panel generada automaticamente si no se pasa una segura.
- Configuracion de Continue sin embeddings no soportados en esta instalacion.

Nota tecnica:
en Docker para Windows, publicar `127.0.0.1:8045:8045` en el host ya deja el panel solo local.
No conviene forzar `127.0.0.1` dentro del contenedor porque eso rompe el acceso desde el host.

## Nota sobre el fuente local

La copia local del proyecto upstream fue ajustada para:

- arrancar en espanol por defecto
- usar `es` como fallback de i18n
- preferir formato y fechas en espanol

La idea es que el runtime dependa de una imagen que tu mismo puedes reconstruir desde fuente local, no de una imagen remota de tercero.
