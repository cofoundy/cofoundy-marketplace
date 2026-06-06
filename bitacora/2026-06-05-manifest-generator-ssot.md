# 2026-06-05 — Manifest Generator SSOT

**Operador:** Codex + Andre Pacheco

---

## Contexto

Andre preguntó por qué había drift si el marketplace usa symlinks. La validación mostró que los symlinks sincronizan rutas de contenido (`skills/`, plugin source paths), pero no sincronizan metadata runtime: `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json` y `.claude-plugin/marketplace.json` seguían siendo archivos separados.

---

## Qué se hizo

1. Se agregó `scripts/plugin-manifests.py` en `cofoundy-marketplace`.
2. Se bootstrappeó `plugin.meta.json` en los 8 plugin source repos.
3. Se regeneraron:
   - `<plugin>/.claude-plugin/plugin.json`;
   - `<plugin>/.codex-plugin/plugin.json`;
   - `cofoundy-marketplace/.claude-plugin/marketplace.json`.
4. Se documentó el flujo en `README.md`.
5. Se validó idempotencia con `python3 scripts/plugin-manifests.py check`.

---

## Decisión

`plugin.meta.json` es el SSOT para metadata de plugin. Los manifests runtime son generated outputs.

No se usa symlink entre manifests porque Claude Code y Codex tienen schemas distintos. El contenido operativo puede ser symlink (`skills/`, `agents/`, rulebooks), pero la metadata runtime debe derivarse de una fuente común.

---

## Comandos

```bash
python3 scripts/plugin-manifests.py init-meta <plugin>
python3 scripts/plugin-manifests.py generate
python3 scripts/plugin-manifests.py check
```

---

## Pendientes

* Integrar el check en CI o pre-commit.
* Definir si `.agents/plugins/marketplace.json` debe seguir path-only o recibir metadata generada cuando Codex soporte versiones en marketplace entries.
* Decidir si el release script debe correr `codex plugin remove/add` o solo avisar que el cache instalado sigue en versión anterior hasta refresh.
