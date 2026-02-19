#!/bin/bash
# =============================================================
#  Site Monitor — GitHub Actions
#  Checks all sites every 10 min, sends Telegram alerts only
#  on state changes (DOWN / RECOVERY).
# =============================================================

# Sites loaded from GitHub Secret SITES_LIST (comma-separated)
IFS=',' read -ra SITES <<< "$SITES_LIST"

STATE_DIR=".monitor-state"
mkdir -p "$STATE_DIR"

# ── Telegram ─────────────────────────────────────────────────
send_tg() {
  curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TG_CHAT}" \
    --data-urlencode "text=$1" \
    --data-urlencode "parse_mode=HTML" \
    > /dev/null 2>&1
}

# ── Check each site ───────────────────────────────────────────
ISSUES=()
RECOVERED=()
TIMESTAMP=$(date '+%d.%m.%Y %H:%M UTC')

for SITE in "${SITES[@]}"; do
  STATE_FILE="$STATE_DIR/${SITE//[^a-zA-Z0-9]/_}"
  PREV=$(cat "$STATE_FILE" 2>/dev/null || echo "unknown")

  # HEAD first (fast), fallback to GET
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 10 --max-time 15 \
    -L --head "https://$SITE" 2>/dev/null)

  # Some servers reject HEAD — retry with GET
  if [[ "$HTTP" == "000" || "$HTTP" == "405" ]]; then
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
      --connect-timeout 10 --max-time 15 \
      -L "https://$SITE" 2>/dev/null)
  fi

  if [[ "$HTTP" -ge 200 && "$HTTP" -lt 400 ]]; then
    CURR="up"
    if [[ "$PREV" == "down" ]]; then
      RECOVERED+=("✅ <b>${SITE}</b> — восстановлен")
    fi
  else
    CURR="down"
    ERR=$( [[ "$HTTP" == "000" ]] && echo "нет ответа / таймаут" || echo "HTTP ${HTTP}" )
    if [[ "$PREV" != "down" ]]; then
      ISSUES+=("💀 <b>${SITE}</b> — ${ERR}")
    fi
  fi

  echo "$CURR" > "$STATE_FILE"
  echo "$([ "$CURR" = "up" ] && echo "✓" || echo "✗") $SITE — HTTP $HTTP"
done

# ── Send notifications ────────────────────────────────────────
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  MSG="🚨 <b>САЙТ УПАЛ</b>
🕐 ${TIMESTAMP}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$(printf '%s\n' "${ISSUES[@]}")"
  send_tg "$MSG"
  echo "⚠ Alert sent: ${#ISSUES[@]} site(s) down"
fi

if [[ ${#RECOVERED[@]} -gt 0 ]]; then
  MSG="🎉 <b>ВОССТАНОВЛЕН</b>
🕐 ${TIMESTAMP}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$(printf '%s\n' "${RECOVERED[@]}")"
  send_tg "$MSG"
  echo "✓ Recovery sent: ${#RECOVERED[@]} site(s) back"
fi

echo "Done at $TIMESTAMP"
