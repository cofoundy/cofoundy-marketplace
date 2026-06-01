# 2026-06-01 — Claude + Codex Marketplace Migration Plan

**Operador:** Andre Pacheco + Codex

---

## Contexto

El marketplace de Cofoundy nació para Claude Code. El repo `cofoundy-marketplace`
exponía solo `.claude-plugin/marketplace.json`, mientras que Codex espera
`.agents/plugins/marketplace.json` y plugins con `.codex-plugin/plugin.json`.

Durante la sesión se confirmó que Codex podía registrar el marketplace remoto
`cofoundy`, pero no podía listar ni instalar sus plugins mientras el repo solo
tuviera el contrato de Claude.

## Objetivo

Convertir `cofoundy-marketplace` en el marketplace SSOT de Cofoundy para ambos
runtimes:

- Claude Code lee `.claude-plugin/marketplace.json`.
- Codex lee `.agents/plugins/marketplace.json`.
- Los plugins viven en `plugins/cofoundy-*`.
- Cada plugin mantiene su contenido operativo una sola vez: `skills/`, `agents/`,
  `commands/`, `hooks/`, `scripts/`, `docs/`.
- Cada plugin expone metadata por runtime:
  - `.claude-plugin/plugin.json`
  - `.codex-plugin/plugin.json`

La meta es DRY en contenido y bidireccional en runtime, aceptando metadata mínima
por plataforma cuando los contratos de instalación no son iguales.

## Estado de Hoy

Se creó la forma local esperada:

```text
plugins/
  cofoundy-marketplace/
    .claude-plugin/marketplace.json
    .agents/plugins/marketplace.json
    plugins/cofoundy-toolkit -> ../../cofoundy-toolkit
    plugins/cofoundy-business -> ../../cofoundy-business
    plugins/cofoundy-docs -> ../../cofoundy-docs
    plugins/cofoundy-finance -> ../../cofoundy-finance
    plugins/cofoundy-founders -> ../../cofoundy-founders
    plugins/cofoundy-meta -> ../../cofoundy-meta
    plugins/cofoundy-pms -> ../../cofoundy-pms
    plugins/cofoundy-orchestrator -> ../../cofoundy-orchestrator
```

Codex quedó apuntando al marketplace local `cofoundy`:

```text
[marketplaces.cofoundy]
source_type = "local"
source = "/home/andre/cofoundy/plugins/cofoundy-marketplace"
```

Los 8 plugins quedaron instalados y enabled en Codex bajo `cofoundy`:

- `cofoundy-toolkit`
- `cofoundy-business`
- `cofoundy-docs`
- `cofoundy-founders`
- `cofoundy-finance`
- `cofoundy-meta`
- `cofoundy-pms`
- `cofoundy-orchestrator`

## Diseño Propuesto

El repo `cofoundy-marketplace` debe ser el punto de entrada compartido.

Para desarrollo local:

- `plugins/cofoundy-marketplace/plugins/<name>` puede ser symlink al repo fuente
  vecino en `plugins/<name>`.
- Codex instala desde el marketplace local y cachea normalmente en
  `~/.codex/plugins/cache/cofoundy/...`.
- Claude mantiene su flujo actual de marketplace e install cache.

Para portabilidad remota hay que decidir si los enlaces serán:

1. symlinks versionados, si el checkout del workspace siempre clona todos los
   plugins vecinos;
2. git submodules, si el marketplace remoto debe traer punteros explícitos a cada
   plugin;
3. snapshots vendorizados, si se prioriza instalación offline/portable sobre DRY;
4. entries remotas por repo, si Codex soporta esa forma de `source` en
   `.agents/plugins/marketplace.json`.

La decisión final debe preservar que el contenido de cada skill vive en un solo
repo fuente.

## Next Steps

### 1. Portabilidad a Antigravity

Verificar qué contrato usa Antigravity para plugins, skills, commands, hooks y
MCP. Resultado esperado: una matriz `Claude / Codex / Antigravity` con:

- manifest de marketplace;
- manifest de plugin;
- soporte de skills;
- soporte de commands;
- soporte de hooks;
- soporte de MCP;
- mecanismo de install/cache;
- mecanismo de update/cachebuster.

Objetivo: que `cofoundy-marketplace` no quede hardcodeado solo a Claude + Codex.

### 2. Revisión completa de hooks

Auditar todos los hooks de plugins Cofoundy y clasificar si deben seguir siendo
hooks del runtime o migrar a hooks estándar de Git/shell.

Ejemplo detectado:

```text
Command
bash /home/andre/.codex/plugins/cache/cofoundy-local/cofoundy-meta/0.3.12/hooks/scripts/enforce-version-bump.sh
Bash
```

Ese hook probablemente no debería depender del cache de Codex ni del runtime. Es
candidato a convertirse en `pre-commit` o `pre-push` del repo correspondiente,
porque su responsabilidad parece ser control de versión antes de publicar.

Regla de refactor:

- Si protege integridad del repo: git hook o CI.
- Si protege comportamiento del agente durante una sesión: runtime hook.
- Si sincroniza estado compartido: revisar si debe ser manual, CI, o job
  controlado, no hook silencioso.

### 3. Repensar `sync-pattern-library.sh`

El hook/script `sync-pattern-library.sh` en modo push es sospechoso. Puede ser
perjudicial si se ejecuta desde cache de plugin o desde una sesión de agente,
porque puede escribir/sobrescribir estado compartido sin que el operador entienda
qué fuente ganó.

Hipótesis: el flujo actual "se carga el cache" o hace que el cache instalado
participe como si fuera fuente de verdad.

Pendiente:

- identificar todos los callsites;
- separar source repo vs installed cache;
- definir dirección de sync;
- evitar writes desde cache;
- exigir dry-run/diff antes de push;
- mover el push a comando explícito o CI con logs.

### 4. Workspace setup + workspace map RBAC compliant

Actualizar el `workspace-map.yaml` usado por `/workspace-setup` en
`cofoundy-toolkit` para incluir todos los repos necesarios del sistema de plugins:

- `cofoundy-marketplace`
- `cofoundy-toolkit`
- `cofoundy-business`
- `cofoundy-docs`
- `cofoundy-finance`
- `cofoundy-founders`
- `cofoundy-meta`
- `cofoundy-pms`
- `cofoundy-orchestrator`

Pero no basta con agregarlos al map. Debe ser RBAC compliant:

- GitHub sigue siendo el SSOT de acceso.
- El workspace setup solo clona repos accesibles para el usuario autenticado.
- Tiers restringidos no deben recibir repos founder-only por accidente.
- Contractors y T0-Shadow deben seguir filtrados por scope.
- La existencia de un plugin en marketplace no implica permiso de clonar su repo
  fuente.

### 5. Protocolo de creación/update de plugins

Actualizar el protocolo de crear skills/plugins para que desde ahora todo plugin
Cofoundy nuevo nazca con:

```text
.claude-plugin/plugin.json
.codex-plugin/plugin.json
skills/
```

Y el marketplace se actualice en ambos manifests:

```text
cofoundy-marketplace/.claude-plugin/marketplace.json
cofoundy-marketplace/.agents/plugins/marketplace.json
```

Idealmente, introducir un `plugin.meta.json` o script generador que derive ambos
manifests y reduzca drift.

### 6. Versionamiento, cachebusters y bump policy

Definir una política única de versionamiento para plugins Cofoundy que funcione
en Claude, Codex y futuros runtimes.

Problema actual:

- Claude y Codex cachean instalaciones.
- Codex necesita que el plugin instalado cambie de versión/cachebuster para
  forzar reinstalación limpia.
- Algunos hooks, como `enforce-version-bump.sh`, intentan proteger esto desde el
  runtime/cache, pero esa responsabilidad probablemente pertenece al repo, a CI,
  o a un flujo explícito de release.
- Si el version bump se olvida, una skill puede estar editada en source pero el
  runtime seguirá usando una copia vieja en cache.

Pendiente:

- definir si el SSOT de versión vive en `.claude-plugin/plugin.json`,
  `.codex-plugin/plugin.json`, o en un nuevo `plugin.meta.json`;
- decidir si Claude y Codex comparten exactamente el mismo semver o si Codex usa
  build metadata tipo `+codex.<cachebuster>`;
- crear un comando/script único para bump de plugin;
- actualizar ambos manifests desde una sola fuente;
- validar que marketplace entries y plugin manifests no diverjan;
- decidir cuándo usar bump semver real vs cachebuster local;
- mover enforcement a `pre-commit`, `pre-push`, CI, o release command, no a paths
  de cache instalados;
- documentar el flujo de update:

```text
edit skill -> validate plugin -> bump/cachebuster -> reinstall runtime -> new session
```

Resultado esperado: ningún agente tiene que adivinar cuándo bumppear versión ni
editar manifests a mano.

### 7. Publicación remota

Cuando el diseño local esté validado:

- commitear `.agents/plugins/marketplace.json` en `cofoundy-marketplace`;
- commitear `.codex-plugin/plugin.json` en cada plugin;
- decidir symlink/submodule/snapshot/remote-source para portabilidad;
- probar fresh install en máquina limpia;
- reemplazar el marketplace Codex local por el link remoto:

```text
https://github.com/cofoundy/cofoundy-marketplace
```

### 8. Unificar instrucciones de agentes (`CLAUDE.md`, `AGENTS.md`, etc.)

Revisar en la siguiente sesión cómo hacer que las instrucciones base para
agentes no diverjan por runtime.

Problema actual:

- Claude usa `CLAUDE.md`.
- Codex usa `AGENTS.md` en varios repos.
- Otros runtimes pueden necesitar otros nombres o formatos.
- Si cada archivo se edita a mano, las reglas operativas de Cofoundy van a
  divergir.

Pendiente:

- inventariar todos los `CLAUDE.md`, `AGENTS.md` y equivalentes en el workspace;
- decidir cuál es el SSOT por repo o por plugin;
- evaluar symlinks cuando el contenido pueda ser idéntico;
- cuando no pueda ser idéntico, usar un generador/templating desde una fuente
  común;
- documentar qué instrucciones son universales y cuáles son runtime-specific.

Objetivo: que Claude, Codex y futuros runtimes lean la misma intención operativa,
sin mantener copias divergentes.

## Riesgos

- Codex y Claude tienen contratos de marketplace distintos; forzar un solo JSON
  sería brittle.
- Runtime hooks ejecutados desde cache pueden escribir al lugar equivocado.
- Symlinks son limpios para desarrollo local, pero pueden no ser suficientes para
  instalación remota portable.
- RBAC no puede inferirse del marketplace; debe seguir viniendo de GitHub/org/team
  access y del workspace setup.

## Criterio de Éxito

- Un usuario con acceso correcto puede instalar Cofoundy en Claude, Codex y
  eventualmente Antigravity desde el mismo repo marketplace.
- No hay duplicación de skills.
- Los hooks no dependen de paths de cache.
- `/workspace-setup` clona solo lo permitido por RBAC y deja el sistema listo para
  editar plugins fuente.
- El flujo de update de skill/plugin es documentado y repetible.
