# Plugin Update Command

**Fecha:** 2026-06-05
**Contexto:** Los flujos de plugin ya tenían `plugin.meta.json` como SSOT de metadata, pero las instrucciones cargadas por agentes todavía mezclaban pasos manuales: editar `plugin.json`, editar marketplace, correr `sync-plugin.sh`, y refrescar Codex por separado.

## Cambio

Se agrega `scripts/update-plugin.sh` como comando operacional único para usar después de editar, crear o borrar una skill/command/agent/hook en cualquier plugin Cofoundy:

```bash
bash ~/cofoundy/plugins/cofoundy-marketplace/scripts/update-plugin.sh <plugin-name>
```

El script:

1. Bumpea `plugin.meta.json` (`patch` por defecto; `--bump minor|major|none` disponible).
2. Corre `scripts/plugin-manifests.py generate`.
3. Corre `scripts/plugin-manifests.py check`.
4. Refresca Claude Code vía `cofoundy-toolkit/scripts/sync-plugin.sh`.
5. Refresca Codex vía `codex plugin add <plugin>@cofoundy` si el CLI está disponible.

## Superficies actualizadas

- `README.md` del marketplace documenta el comando como workflow de mantenimiento.
- `~/cofoundy/CLAUDE.md` y `cofoundy-toolkit/templates/workspace-CLAUDE.md` reemplazan el flujo manual por `update-plugin.sh`.
- Los `CLAUDE.md` de los 8 plugins fuente apuntan al mismo comando con su plugin-name específico.

## Validación

- `bash -n scripts/update-plugin.sh`
- `python3 scripts/plugin-manifests.py check`
- `bash scripts/update-plugin.sh cofoundy-docs --bump none`

Resultado: manifests sin drift, cache Claude refrescada para `cofoundy-docs`, cache Codex refrescada vía marketplace `cofoundy`.
