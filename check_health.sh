#!/bin/bash

LOG_FILE="/var/log/birdkingdom_health.log"

# Keep log file size under control (truncate if over 1000 lines)
if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 1000 ]; then
    tail -n 100 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

echo "[$(date)] Health check started..." >> $LOG_FILE

# 1. Check if containers are running
SWIFT_RUNNING=$(docker inspect -f '{{.State.Running}}' birdkingdom-swift 2>/dev/null)
SMS_RUNNING=$(docker inspect -f '{{.State.Running}}' birdkingdom-sms-proxy 2>/dev/null)

if [ "$SWIFT_RUNNING" != "true" ]; then
    echo "[$(date)] Warning: birdkingdom-swift is not running. Starting it..." >> $LOG_FILE
    docker start birdkingdom-swift >> $LOG_FILE 2>&1
fi

if [ "$SMS_RUNNING" != "true" ]; then
    echo "[$(date)] Warning: birdkingdom-sms-proxy is not running. Starting it..." >> $LOG_FILE
    docker start birdkingdom-sms-proxy >> $LOG_FILE 2>&1
fi

# 2. Check HTTP responsiveness of Swift backend (Port 8080)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost:8080/api/encyclopedia/birds)

# Standard alive codes: 200 (OK), 403 (Forbidden/Auth needed), 401 (Unauthorized)
if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 403 ] && [ "$HTTP_CODE" -ne 401 ]; then
    echo "[$(date)] Error: API is unresponsive (HTTP $HTTP_CODE). Restarting containers..." >> $LOG_FILE
    docker restart birdkingdom-swift >> $LOG_FILE 2>&1
    docker restart birdkingdom-sms-proxy >> $LOG_FILE 2>&1
else
    echo "[$(date)] All services are healthy (HTTP $HTTP_CODE)." >> $LOG_FILE
fi
