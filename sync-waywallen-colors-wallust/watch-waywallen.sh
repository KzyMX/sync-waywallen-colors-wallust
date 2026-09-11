#!/usr/bin/env bash
# watch-waywallen.sh — reactivo con coalescencia de eventos
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
WAYWALLEN_LOG_DIR="$HOME/.var/app/org.waywallen.waywallen/.local/state/waywallen/logs/daemon"
SYNC_SCRIPT="$HOME/.local/bin/sync-waywallen-colors"
LOCK=/tmp/waywallen_sync.lock
PENDING=/tmp/waywallen_sync.pending
log() { echo "[watch $(date '+%F %T')] $*"; }
mkdir -p "$WAYWALLEN_LOG_DIR"
rm -f "$LOCK" "$PENDING"

if ! command -v inotifywait &> /dev/null; then
    log "inotifywait no está instalado (paquete 'inotifytools'). El watch queda inactivo."
    exec sleep infinity
fi
[ -x "$SYNC_SCRIPT" ] || log "Advertencia: $SYNC_SCRIPT no existe o no es ejecutable."

inotifywait -m -e close_write,modify --format '%w%f' "$WAYWALLEN_LOG_DIR" | \
while read -r _; do
    # Debounce: colecciona el burst de eventos del mismo cambio
    sleep 0.6
    while read -t 0.2 -r _; do :; done

    # Si ya hay un sync corriendo, NO encolar: solo marcar pendiente
    if [ -e "$LOCK" ]; then
        touch "$PENDING"
        log "Sync en curso; se aplicará el último fondo al terminar."
        continue
    fi

    # Corre sync; si llegaron cambios durante él, hace UNA pasada final más
    while :; do
        touch "$LOCK"
        log "Evento detectado. Ejecutando sync."
        "$SYNC_SCRIPT"
        rc=$?
        rm -f "$LOCK"
        if [ "$rc" -eq 0 ]; then
            log "Sync finalizado correctamente."
        else
            log "Sync terminó con código $rc."
        fi
        [ -e "$PENDING" ] || break
        rm -f "$PENDING"
        log "Hubo cambios durante el sync; re-ejecutando con el fondo más reciente."
    done
done
