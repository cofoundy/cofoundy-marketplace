# 2026-06-04/05 — Antigravity Portability Integration & Agent Instruction Unification

**Operador:** Antigravity + Andre Pacheco

---

## Contexto

El catálogo de plugins `cofoundy-marketplace` se está convirtiendo en el Single Source of Truth (SSOT) para múltiples runtimes. Claude Code y Codex ya contaban con mappings establecidos, pero faltaba integrar de manera nativa y formal el soporte para el runtime **Google Antigravity** (correspondiente a los Pasos 1 y 8 de nuestro plan de migración).

---

## Objetivo

Hacer que todas las habilidades (skills), personas de agentes y directivas de prompts del ecosistema Cofoundy estén disponibles de forma nativa para Antigravity en la sesión del workspace actual, sin modificar ni comprometer los archivos origen de los repositorios hermanos (garantizando compatibilidad total con Claude Code y Codex).

---

## Qué se hizo

1.  **Investigación y Especificaciones de Antigravity:**
    *   Confirmamos que el runtime busca archivos `AGENTS.md` o `GEMINI.md` en el root del workspace al iniciar sesión.
    *   Confirmamos el directorio estándar de plugins del workspace: `.agents/plugins/` (o `_agents/plugins/`).
    *   Confirmamos la estructura nativa para plugins de Antigravity: `plugin.json` (obligatorio), `hooks.json` (hooks de ciclo de vida en fases `Inspect`, `Decide` o `Transform`), y subdirectorios `skills/` y `agents/`.

2.  **Configuración de Mappings No Invasivos (Symlinks):**
    *   Limpiamos referencias directas antiguas y creamos directorios reales individuales bajo `.agents/plugins/` para cada uno de los 8 plugins.
    *   Dentro de cada directorio de plugin, creamos symlinks apuntando a los recursos correspondientes en los repositorios hermanos, resolviendo rutas relativas con el nivel correcto de directorios padres (`../../../../$plugin`):
        *   `plugin.json` -> `.codex-plugin/plugin.json` (Exponiendo el manifest al root del plugin para Antigravity).
        *   `AGENTS.md` -> `CLAUDE.md` (Exponiendo el rulebook de instrucciones de cada plugin).
        *   `skills/` -> `skills/`
        *   `agents/` -> `agents/`
    *   Creamos un symlink `AGENTS.md` en el root del marketplace apuntando a `README.md` (`AGENTS.md -> README.md`).

3.  **Actualización de Herramientas y Documentación:**
    *   Modificamos el script de utilidad `scripts/antigravity-harness.py` para leer directamente desde el directorio estándar `.agents/plugins/` en lugar del root `plugins/`.
    *   Actualizamos la matriz de portabilidad y compatibilidad en [docs/portable-marketplace-strategy.md](file:///home/andre/cofoundy/plugins/cofoundy-marketplace/docs/portable-marketplace-strategy.md).
    *   Actualizamos el `.gitignore` del root para excluir los symlinks locales de plugins (`/.agents/plugins/cofoundy-*/`), el symlink de reglas local (`/AGENTS.md`) y la configuración de terminal/IDE (`/.antigravitycli/`), evitando leaks de rutas rotas al remoto.

---

## Decisiones tomadas

*   **Enfoque no invasivo para repositorios hermanos:** No renombramos los archivos `CLAUDE.md` originales ni modificamos la estructura de los plugins origen. Toda la compatibilidad se orquesta a través de enlaces simbólicos creados de forma local en la carpeta `.agents/plugins/` del catálogo, manteniendo el desarrollo local DRY y limpio.
*   **AGENTS.md como SSOT virtual:** Antigravity y Codex cargan `AGENTS.md`. Mediante el enlace simbólico `AGENTS.md -> CLAUDE.md`, garantizamos que carguen el contenido exacto de `CLAUDE.md` sin duplicación de archivos.
*   **Higiene del Repositorio:** Excluir explícitamente los symlinks locales y archivos de sesión (`AGENTS.md`) en `.gitignore` para asegurar que las referencias relativas a rutas locales no se commiteen al remoto por accidente, dejando solo los scripts portables (`scripts/`) y el manifest general de Codex (`marketplace.json`).


---

## Learnings (Aprendizajes)

*   **Rutas de Symlinks Relativos:** Al crear symlinks que están anidados a nivel de `.agents/plugins/<plugin-name>/`, se requieren 4 niveles de directorio padre (`../../../../`) para alcanzar de forma relativa a un repositorio hermano ubicado a nivel de sibling (en `/home/andre/cofoundy/plugins/`). Si se usan 3 niveles, el enlace se rompe y el loader no descubre los subdirectorios.
*   **Startup del Runtime:** Antigravity lee el `AGENTS.md` del root del proyecto al inicializarse, sirviendo como la constitución de comportamiento del agente durante toda la sesión.

---

## Validación

*   Ejecutamos el comando `uv run scripts/antigravity-harness.py list`, que parseó exitosamente el directorio `.agents/plugins/`, listando correctamente todas las skills y personas de agentes registradas.
*   Corrimos exitosamente `uv run scripts/antigravity-harness.py skill handoff` para comprobar que la lectura de las instrucciones de las habilidades funciona perfectamente a través de las rutas resueltas por los enlaces simbólicos.
