#!/bin/bash
# ============================================================
#  backup.sh — Ubuntu → Pop!_OS Migration Backup
# ============================================================
# Verwendung:
#   bash backup.sh [ZIEL]
#
#   ZIEL ist optional. Standard: ~/backup_migration
#   Beispiel auf externer Platte:
#     bash backup.sh /media/luca/USB-Stick/backup
# ============================================================

set -euo pipefail

DEST="${1:-$HOME/backup_migration}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$DEST/backup_$TIMESTAMP"

# Farben
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }
section() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}"; }
skip()    { echo -e "${YELLOW}[~]${NC} Übersprungen (nicht gefunden): $1"; }

copy() {
    local src="$1"
    local dest="$2"
    if [ -e "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        rsync -a --relative "$src" "$dest" && log "$src"
    else
        skip "$src"
    fi
}

copy_dir_exclude_cache() {
    local src="$1"
    local dest="$2"
    if [ -d "$src" ]; then
        mkdir -p "$dest"
        rsync -a \
            --exclude='Cache/' \
            --exclude='cache/' \
            --exclude='Code Cache/' \
            --exclude='GPUCache/' \
            --exclude='ShaderCache/' \
            --exclude='DawnCache/' \
            --exclude='*.log' \
            "$src" "$dest" && log "$src"
    else
        skip "$src"
    fi
}

# ────────────────────────────────────────────────────────────
echo -e "\n${BOLD}Ubuntu → Pop!_OS Backup${NC}"
echo -e "Ziel: ${CYAN}$BACKUP_DIR${NC}"
echo -e "Gestartet: $(date)\n"

mkdir -p "$BACKUP_DIR"

# ────────────────────────────────────────────────────────────
section "Cache leeren"
if [ -d "$HOME/.cache" ]; then
    warn "Leere ~/.cache/ ..."
    rm -rf "${HOME:?}/.cache/"*
    log "~/.cache/ geleert"
fi

# ────────────────────────────────────────────────────────────
section "App-Configs"

copy "$HOME/.config/FEZ"               "$BACKUP_DIR/"
copy "$HOME/.config/inkscape"           "$BACKUP_DIR/"
copy "$HOME/.config/neofetch"           "$BACKUP_DIR/"
copy "$HOME/.config/rclone/rclone.conf" "$BACKUP_DIR/"
copy "$HOME/.config/StardewValley"      "$BACKUP_DIR/"
copy "$HOME/.config/Zettlr"             "$BACKUP_DIR/"
copy "$HOME/.config/sshmgr"             "$BACKUP_DIR/"
if [ -d "$HOME/.config/vesktop" ]; then
    mkdir -p "$BACKUP_DIR/.config/"
    rsync -a --no-links --exclude='Singleton*' --exclude='Cache/' --exclude='sessionData/Cache/' \
        "$HOME/.config/vesktop" "$BACKUP_DIR/.config/" \
        && log "$HOME/.config/vesktop"
else
    skip "$HOME/.config/vesktop"
fi
copy "$HOME/.config/opencode/opencode.json" "$BACKUP_DIR/"

# opencode kann auch im Home-Root liegen
copy "$HOME/.opencode.json"             "$BACKUP_DIR/"

# Brave: Cache explizit ausschließen
if [ -d "$HOME/.config/BraveSoftware" ]; then
    mkdir -p "$BACKUP_DIR/.config/"
    rsync -a --no-links \
        --exclude='Cache/' \
        --exclude='cache/' \
        --exclude='Code Cache/' \
        --exclude='GPUCache/' \
        --exclude='ShaderCache/' \
        --exclude='DawnCache/' \
        --exclude='Singleton*' \
        --exclude='*.log' \
        "$HOME/.config/BraveSoftware/" "$BACKUP_DIR/.config/BraveSoftware/" \
        && log "$HOME/.config/BraveSoftware"
else
    skip "$HOME/.config/BraveSoftware"
fi

warn "rclone.conf und opencode-Config enthalten möglicherweise API-Keys/Tokens!"

# ────────────────────────────────────────────────────────────
section ".desktop Files"

copy "$HOME/.local/share/applications"  "$BACKUP_DIR/"

# ────────────────────────────────────────────────────────────
section "Persönliche Ordner"

PERSONAL_DIRS=(
    "$HOME/Schreibtisch"
    "$HOME/Downloads"
    "$HOME/Dokumente"
    "$HOME/ROMs"
    "$HOME/Wallpapers"
    "$HOME/GOG Games"
)

for dir in "${PERSONAL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        dirname=$(basename "$dir")
        log "Kopiere: $dir"
        rsync -a "$dir" "$BACKUP_DIR/home/"
    else
        skip "$dir"
    fi
done

# ────────────────────────────────────────────────────────────
section "Sonstiges"

# SSH-Keys
copy "$HOME/.ssh"       "$BACKUP_DIR/"

# Git-Config
copy "$HOME/.gitconfig" "$BACKUP_DIR/"
copy "$HOME/.gitignore_global" "$BACKUP_DIR/"

# Shell
copy "$HOME/.bashrc"         "$BACKUP_DIR/"
copy "$HOME/.bash_aliases"   "$BACKUP_DIR/"
copy "$HOME/.bash_profile"   "$BACKUP_DIR/"

# ────────────────────────────────────────────────────────────
section "Fertig"

BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
echo -e "\n${BOLD}${GREEN}Backup abgeschlossen!${NC}"
echo -e "Ort:   ${CYAN}$BACKUP_DIR${NC}"
echo -e "Größe: ${CYAN}$BACKUP_SIZE${NC}"
echo -e "Zeit:  $(date)\n"

warn "Nicht vergessen: Installscript für Pop!_OS bereithalten"
warn "Nach Installation: update-desktop-database ~/.local/share/applications/"
