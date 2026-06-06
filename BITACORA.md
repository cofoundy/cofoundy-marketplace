# Bitácora: cofoundy-marketplace

**Creada:** 2026-06-04
**Tipo:** general
**Contexto:** Meta-development log del catálogo de plugins de Cofoundy — portabilidad, manifests, setups multi-harness (Claude Code, Codex, Antigravity) y estrategia de distribución de plugins.

---

## Estado Actual

*   **Soporte Multiharness Completo:** Integrado E2E para Claude Code, Codex y Antigravity en desarrollo local.
*   **Directorio .agents/plugins/:** Populado con symlinks relativos correctos hacia los 8 repositorios hermanos.
*   **AGENTS.md:** Enlace simbólico en el root del marketplace apuntando a `README.md` (`AGENTS.md -> README.md`).
*   **Harness Activo:** `scripts/antigravity-harness.py` lee y valida la estructura de `.agents/plugins/` sin problemas.
*   **Codex Context Gap:** Codex instala y lista los plugins, y carga `AGENTS.md` del cwd/repo activo. Ya existe bridge local `~/cofoundy/AGENTS.md -> CLAUDE.md` y `AGENTS.md -> CLAUDE.md` en plugin source repos, pero Codex no carga automáticamente el workspace parent cuando el cwd está dentro de un repo Git anidado.
*   **Manifest SSOT:** `plugin.meta.json` en cada plugin source genera manifests Claude/Codex y marketplace Claude vía `scripts/plugin-manifests.py`.
*   **Plugin Update Command:** Después de editar/crear/borrar skills, commands, agents o hooks, correr `scripts/update-plugin.sh <plugin>` para bumpear `plugin.meta.json`, regenerar manifests y refrescar caches Claude+Codex.

---

## Reglas Extraídas

*   **Rutas de Symlinks en .agents/plugins/:** Requieren exactamente 4 niveles de directorio padre (`../../../../`) para apuntar correctamente a los repositorios hermanos locales.
*   **AGENTS.md como SSOT:** Symlinkar `AGENTS.md -> CLAUDE.md` permite portabilidad transparente sin duplicar archivos de instrucciones del agente.
*   **Mantenimiento No Invasivo:** Para conservar los repositorios hermanos limpios, la estructura de compatibilidad del runtime (ej: plugin.json y AGENTS.md expuestos en el root del plugin) debe orquestarse en la carpeta de distribución del marketplace local via symlinks.

---

## Entries

| Fecha | Título | Resumen |
|-------|--------|---------|
| 2026-06-05 | [Plugin Update Command](bitacora/2026-06-05-plugin-update-command.md) | Se crea `scripts/update-plugin.sh` como comando único post-edición de capacidades para regenerar manifests y refrescar caches Claude+Codex. |
| 2026-06-05 | [Manifest Generator SSOT](bitacora/2026-06-05-manifest-generator-ssot.md) | Se crea `plugin.meta.json` por plugin y generador para evitar drift de versiones/metadata entre Claude, Codex y marketplace. |
| 2026-06-05 | [Codex Compatibility Validation](bitacora/2026-06-05-codex-compatibility-validation.md) | Validación con `codex plugin list`, `codex debug prompt-input` y harness Antigravity; identifica gaps de identidad, workspace rules, commands y version drift. |
| 2026-06-04/05 | [Antigravity Portability Integration & Agent Instruction Unification](bitacora/2026-06-04-antigravity-portability-integration.md) | Mappings de symlinks corregidos en `.agents/plugins/`, unificación de `AGENTS.md`, actualización de harness y documentación de estrategia. |
| 2026-06-01 | [Claude + Codex Marketplace Migration Plan](bitacora/2026-06-01-codex-claude-marketplace-migration.md) | Plan de unificación SSOT de manifests para Claude Code y Codex. |
