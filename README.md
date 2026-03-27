# open-claw

Repositorio local preparado dentro de `Antigravity` para agrupar los archivos revisados:

- `AGENTS.md`
- `continue_config.json`
- `setup_antigravity_manager.ps1`

Origen de los archivos:

- `C:\Users\ZN-\Downloads\AGENTS.md`
- `C:\Users\ZN-\Downloads\continue_config.json`
- `C:\Users\ZN-\Downloads\setup_antigravity_manager.ps1`

Notas:

- Los archivos fueron normalizados para evitar texto roto por problemas de codificacion.
- `setup_antigravity_manager.ps1` fue revisado para reducir algunos riesgos basicos:
  - password debil por defecto
  - publicacion en localhost por defecto
  - imagen Docker fijada por digest
- Se elimino la configuracion de embeddings de Continue porque este proxy no expone `text-embedding-3-small` en esta instalacion.

Estado actual:

- Este repo local ya existe en `C:\Users\ZN-\Documents\Antigravity\open-claw`.
- El remoto `git@github.com:zerausn/open-claw.git` ya existe.
- `origin` esta configurado y la rama `main` ya fue publicada en GitHub.
