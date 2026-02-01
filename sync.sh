#!/bin/bash
# Task Dashboard Sync Script

RENDER_URL="https://genie-dashboard.onrender.com/api/tasks"
LOCAL_FILE="$HOME/clawd/dashboard/tasks.json"
BACKUP_DIR="$HOME/clawd/dashboard/backups"
GIST_ID="efa1580eefda602e38d5517799c7e84e"

mkdir -p "$BACKUP_DIR"

case "$1" in
  pull)
    curl -s "$RENDER_URL" > "$LOCAL_FILE"
    echo "✓ Pulled $(jq '.tasks | length' "$LOCAL_FILE") tasks from Render"
    ;;
  push)
    curl -s -X POST "$RENDER_URL" -H "Content-Type: application/json" -d @"$LOCAL_FILE" | jq -r 'if .ok then "✓ Pushed to Render" else "✗ Push failed" end'
    ;;
  backup)
    BACKUP_FILE="$BACKUP_DIR/tasks-$(date +%Y%m%d-%H%M%S).json"
    cp "$LOCAL_FILE" "$BACKUP_FILE"
    echo "✓ Local backup: $BACKUP_FILE"
    ;;
  cloud)
    # Backup to GitHub Gist
    gh gist edit "$GIST_ID" "$LOCAL_FILE" 2>/dev/null && echo "✓ Backed up to Gist" || echo "✗ Gist backup failed"
    ;;
  restore-cloud)
    # Restore from Gist
    curl -sL "https://gist.githubusercontent.com/michael-matias-clarity/$GIST_ID/raw/tasks.json" > "$LOCAL_FILE"
    echo "✓ Restored from Gist"
    ;;
  full-backup)
    # Full backup: local + cloud + push to Render
    $0 backup
    $0 cloud
    $0 push
    ;;
  *)
    echo "Usage: sync.sh [pull|push|backup|cloud|restore-cloud|full-backup]"
    ;;
esac
