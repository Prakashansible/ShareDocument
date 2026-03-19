#!/bin/bash
###############################################################################
# pg_replication_slot_monitor.sh
# PostgreSQL Replication Slot Health Monitor
#
# Environment:
#   PostgreSQL Version : 17
#   OS                 : AlmaLinux 9
#   Data Directory     : /apps/pgsql_data/17
#   Log Directory      : /apps/logs
#   Replication Slot   : ssncpri
#   pg_wal Location    : /apps/pgsql_data/17/pg_wal
#
# Usage:
#   ./pg_replication_slot_monitor.sh [--config /path/to/config]
#
# Scheduling (crontab):
#   */5 * * * * postgres /opt/scripts/pg_replication_slot_monitor.sh \
#       >> /apps/logs/pg_repl_monitor.log 2>&1
#
# Author : DBA Team
# Version: 1.0
# Date   : 2026-03-19
###############################################################################

set -euo pipefail

# ===========================================================================
#  CONFIGURATION — Customized for your environment
# ===========================================================================

# PostgreSQL connection
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
PGDATABASE="${PGDATABASE:-postgres}"

# Environment-specific paths
PGDATA="/apps/pgsql_data/17"
PG_WAL_DIR="${PGDATA}/pg_wal"
PG_LOG_DIR="/apps/logs"
PG_CONF="${PGDATA}/postgresql.conf"
PG_HBA="${PGDATA}/pg_hba.conf"
PG_AUTO_CONF="${PGDATA}/postgresql.auto.conf"

# Replication slot name
REPL_SLOT_NAME="ssncpri"

# Alerting
ALERT_EMAIL="${ALERT_EMAIL:-dba-team@example.com}"
ENABLE_EMAIL_ALERTS="${ENABLE_EMAIL_ALERTS:-false}"         # true / false
ENABLE_SLACK_ALERTS="${ENABLE_SLACK_ALERTS:-false}"          # true / false
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

# Thresholds — WAL lag
WAL_LAG_WARNING_MB="${WAL_LAG_WARNING_MB:-1024}"            # 1 GB
WAL_LAG_CRITICAL_MB="${WAL_LAG_CRITICAL_MB:-5120}"          # 5 GB

# Thresholds — Replay time lag
REPLAY_LAG_WARNING_SEC="${REPLAY_LAG_WARNING_SEC:-60}"      # 1 minute
REPLAY_LAG_CRITICAL_SEC="${REPLAY_LAG_CRITICAL_SEC:-300}"   # 5 minutes

# Thresholds — pg_wal directory
WAL_DIR_WARNING_GB="${WAL_DIR_WARNING_GB:-10}"              # 10 GB
WAL_DIR_CRITICAL_GB="${WAL_DIR_CRITICAL_GB:-30}"            # 30 GB

# Thresholds — safe_wal_size (slot invalidation proximity)
SAFE_WAL_WARN_BYTES="${SAFE_WAL_WARN_BYTES:-1073741824}"    # 1 GB remaining budget

# Thresholds — Disk
DISK_WARNING_PCT="${DISK_WARNING_PCT:-80}"                   # 80% used
DISK_CRITICAL_PCT="${DISK_CRITICAL_PCT:-90}"                 # 90% used

# Log file for this script
LOG_FILE="${PG_LOG_DIR}/pg_replication_slot_monitor.log"

# Prometheus textfile collector (optional)
METRICS_FILE="${METRICS_FILE:-/tmp/pg_repl_slot_metrics.prom}"

# State file to avoid alert flooding (only alert once per issue)
STATE_DIR="/tmp/pg_repl_monitor_state"
mkdir -p "$STATE_DIR"

# Load external config if provided
if [[ "${1:-}" == "--config" && -f "${2:-}" ]]; then
    # shellcheck disable=SC1090
    source "$2"
fi

# ===========================================================================
#  HELPER FUNCTIONS
# ===========================================================================

TIMESTAMP() {
    date '+%Y-%m-%d %H:%M:%S %Z'
}

log_info() {
    echo "[$(TIMESTAMP)] [INFO]     $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo "[$(TIMESTAMP)] [WARNING]  $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(TIMESTAMP)] [ERROR]    $*" | tee -a "$LOG_FILE"
}

log_critical() {
    echo "[$(TIMESTAMP)] [CRITICAL] $*" | tee -a "$LOG_FILE"
}

run_sql() {
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
         -X -A -t --no-psqlrc -c "$1" 2>/dev/null
}

run_sql_formatted() {
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" \
         -X --no-psqlrc -c "$1" 2>/dev/null
}

# Alert deduplication: only fire once per state_key until issue clears
should_alert() {
    local state_key="$1"
    local state_file="${STATE_DIR}/${state_key}"
    if [[ -f "$state_file" ]]; then
        local age_sec
        age_sec=$(( $(date +%s) - $(stat -c %Y "$state_file" 2>/dev/null || echo 0) ))
        if [[ "$age_sec" -lt 14400 ]]; then
            return 1  # suppress — re-alert after 4 hours
        fi
    fi
    touch "$state_file"
    return 0
}

clear_alert_state() {
    local state_key="$1"
    rm -f "${STATE_DIR}/${state_key}" 2>/dev/null
}

send_email_alert() {
    local subject="$1"
    local body="$2"
    if [[ "$ENABLE_EMAIL_ALERTS" == "true" ]]; then
        echo "$body" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || \
            log_error "Failed to send email alert to ${ALERT_EMAIL}"
    fi
}

send_slack_alert() {
    local message="$1"
    if [[ "$ENABLE_SLACK_ALERTS" == "true" && -n "$SLACK_WEBHOOK_URL" ]]; then
        curl -s -X POST -H 'Content-type: application/json' \
             --data "{\"text\": \"$message\"}" \
             "$SLACK_WEBHOOK_URL" >/dev/null 2>&1 || \
            log_error "Failed to send Slack alert"
    fi
}

send_alert() {
    local severity="$1"
    local subject="$2"
    local body="$3"
    local state_key="${4:-$(echo "$subject" | tr ' ' '_' | tr -cd '[:alnum:]_')}"

    if ! should_alert "$state_key"; then
        log_info "(Alert suppressed — already sent recently) $subject"
        return
    fi

    local hostname
    hostname=$(hostname -f 2>/dev/null || hostname)
    local full_subject="[PG-REPL-${severity}] ${hostname}: ${subject}"
    local full_body
    full_body=$(cat <<EOF
===============================================================
  PostgreSQL Replication Slot Alert
===============================================================
Host          : ${hostname}
Severity      : ${severity}
Time          : $(TIMESTAMP)
PG Port       : ${PGPORT}
Data Directory: ${PGDATA}
Log Directory : ${PG_LOG_DIR}
Slot Name     : ${REPL_SLOT_NAME}
---------------------------------------------------------------
${body}
---------------------------------------------------------------
Action Required: See runbook section corresponding to this alert.
Sent by pg_replication_slot_monitor.sh
EOF
    )

    send_email_alert "$full_subject" "$full_body"
    send_slack_alert ":rotating_light: *${full_subject}*\n\`\`\`\n${body}\n\`\`\`"

    if [[ "$severity" == "CRITICAL" ]]; then
        log_critical "$subject"
    else
        log_warn "$subject"
    fi
}

# ===========================================================================
#  PRE-FLIGHT CHECKS
# ===========================================================================

preflight() {
    log_info "================================================================"
    log_info " PRE-FLIGHT CHECKS"
    log_info "================================================================"

    # Check PGDATA exists
    if [[ ! -d "$PGDATA" ]]; then
        log_error "Data directory does not exist: ${PGDATA}"
        send_alert "CRITICAL" "Data directory missing" \
            "PGDATA=${PGDATA} does not exist or is not accessible." "preflight_pgdata"
        exit 1
    fi
    log_info "PGDATA verified: ${PGDATA}"

    # Check pg_wal directory
    if [[ ! -d "$PG_WAL_DIR" ]]; then
        log_error "pg_wal directory does not exist: ${PG_WAL_DIR}"
        send_alert "CRITICAL" "pg_wal directory missing" \
            "pg_wal not found at ${PG_WAL_DIR}. Check if it is a symlink." "preflight_pgwal"
        exit 1
    fi
    log_info "pg_wal verified: ${PG_WAL_DIR}"

    # Ensure log directory exists
    if [[ ! -d "$PG_LOG_DIR" ]]; then
        mkdir -p "$PG_LOG_DIR" 2>/dev/null || true
    fi

    # Test PostgreSQL connection
    if ! run_sql "SELECT 1;" >/dev/null 2>&1; then
        log_error "Cannot connect to PostgreSQL at ${PGHOST}:${PGPORT}"
        send_alert "CRITICAL" "PostgreSQL connection failure" \
            "Cannot connect to PostgreSQL at ${PGHOST}:${PGPORT}\n\nCheck:\n  systemctl status postgresql-17\n  tail -50 ${PG_LOG_DIR}/postgresql-*.log" \
            "preflight_connect"
        exit 1
    fi
    log_info "PostgreSQL connection: OK"

    # Verify PRIMARY role
    local is_recovery
    is_recovery=$(run_sql "SELECT pg_is_in_recovery();")
    if [[ "$is_recovery" == "t" ]]; then
        log_info "This server is a STANDBY (recovery mode). Monitoring skipped."
        exit 0
    fi
    log_info "Server role: PRIMARY"

    # PostgreSQL version
    PG_VERSION=$(run_sql "SHOW server_version_num;")
    PG_MAJOR=$(( PG_VERSION / 10000 ))
    PG_VERSION_STR=$(run_sql "SHOW server_version;")
    log_info "PostgreSQL version: ${PG_VERSION_STR} (major=${PG_MAJOR})"

    # Verify PGDATA consistency
    local reported_pgdata
    reported_pgdata=$(run_sql "SHOW data_directory;")
    if [[ "$reported_pgdata" != "$PGDATA" ]]; then
        log_warn "PGDATA mismatch! Script: ${PGDATA} vs PostgreSQL reports: ${reported_pgdata}"
    fi

    clear_alert_state "preflight_connect"
    clear_alert_state "preflight_pgdata"
    clear_alert_state "preflight_pgwal"
}

# ===========================================================================
#  CHECK 1: REPLICATION SLOT STATUS (focused on ssncpri)
# ===========================================================================

check_slot_status() {
    log_info "================================================================"
    log_info " CHECK 1: Replication Slot Status [${REPL_SLOT_NAME}]"
    log_info "================================================================"

    # Does the slot exist?
    local slot_exists
    slot_exists=$(run_sql "SELECT count(*) FROM pg_replication_slots WHERE slot_name = '${REPL_SLOT_NAME}';")

    if [[ "$slot_exists" -eq 0 ]]; then
        log_critical "Replication slot '${REPL_SLOT_NAME}' DOES NOT EXIST!"
        send_alert "CRITICAL" "Slot ${REPL_SLOT_NAME} MISSING" \
            "The replication slot '${REPL_SLOT_NAME}' does not exist on this Primary.\n\nStandby cannot connect. WAL retention is NOT guaranteed.\n\nRecreate:\n  SELECT pg_create_physical_replication_slot('${REPL_SLOT_NAME}');\n\nIf WAL was recycled, full standby rebuild is needed." \
            "slot_missing"
        return
    fi
    clear_alert_state "slot_missing"

    # Full slot details
    local slot_info
    slot_info=$(run_sql "
        SELECT slot_name,
               slot_type,
               active,
               COALESCE(active_pid::text, 'NULL'),
               COALESCE(restart_lsn::text, 'NULL'),
               COALESCE(confirmed_flush_lsn::text, 'NULL'),
               wal_status,
               COALESCE(safe_wal_size::text, 'NULL'),
               COALESCE(conflicting::text, 'false'),
               COALESCE(invalidation_reason, 'none'),
               pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn),
               pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn))
        FROM pg_replication_slots
        WHERE slot_name = '${REPL_SLOT_NAME}';
    ")

    IFS='|' read -r s_name s_type s_active s_pid s_restart s_flush s_wal_status \
                    s_safe_wal s_conflicting s_inv_reason s_lag_bytes s_lag_pretty <<< "$slot_info"

    log_info "  Slot Name         : ${s_name}"
    log_info "  Slot Type         : ${s_type}"
    log_info "  Active            : ${s_active}"
    log_info "  Active PID        : ${s_pid}"
    log_info "  Restart LSN       : ${s_restart}"
    log_info "  Confirmed Flush   : ${s_flush}"
    log_info "  WAL Status        : ${s_wal_status}"
    log_info "  Safe WAL Size     : ${s_safe_wal}"
    log_info "  Conflicting       : ${s_conflicting}"
    log_info "  Invalidation      : ${s_inv_reason}"
    log_info "  Current Lag       : ${s_lag_pretty} (${s_lag_bytes} bytes)"

    # INVALIDATED?
    if [[ "$s_conflicting" == "true" ]]; then
        log_critical "Slot '${REPL_SLOT_NAME}' is PERMANENTLY INVALIDATED!"
        send_alert "CRITICAL" "Slot ${REPL_SLOT_NAME} INVALIDATED" \
            "Slot '${REPL_SLOT_NAME}' permanently invalidated.\n  Reason   : ${s_inv_reason}\n  WAL Status: ${s_wal_status}\n\nThis slot is UNRECOVERABLE.\n\nRequired:\n  1. pg_drop_replication_slot('${REPL_SLOT_NAME}');\n  2. pg_create_physical_replication_slot('${REPL_SLOT_NAME}');\n  3. Rebuild standby:\n     pg_basebackup -h <primary_ip> -U replicator \\\\\n       -D /apps/pgsql_data/17 -S ${REPL_SLOT_NAME} -X stream -P -R" \
            "slot_invalidated"
        return
    fi
    clear_alert_state "slot_invalidated"

    # INACTIVE?
    if [[ "$s_active" == "f" ]]; then
        log_warn "Slot '${REPL_SLOT_NAME}' is INACTIVE — no standby connected."
        send_alert "WARNING" "Slot ${REPL_SLOT_NAME} INACTIVE" \
            "Slot '${REPL_SLOT_NAME}' not consumed.\n  Active PID : NULL\n  WAL Status : ${s_wal_status}\n  Lag        : ${s_lag_pretty}\n\nWAL accumulating at: ${PG_WAL_DIR}\n\nPossible causes:\n  - Standby postgresql-17 service down\n  - Network failure between Primary and Standby\n  - pg_hba.conf rejecting replication connection\n  - primary_conninfo misconfigured on Standby\n  - SSL certificate expired\n  - walsender killed (OOM or manual)\n\nCheck standby: ${PG_LOG_DIR}/postgresql-*.log" \
            "slot_inactive"
    else
        log_info "Slot '${REPL_SLOT_NAME}' is ACTIVE (PID: ${s_pid}). OK."
        clear_alert_state "slot_inactive"
    fi

    # WAL status progression
    case "$s_wal_status" in
        reserved)
            log_info "  WAL Status 'reserved' — fully safe."
            clear_alert_state "slot_wal_danger"
            ;;
        extended)
            log_info "  WAL Status 'extended' — retaining WAL beyond wal_keep_size."
            ;;
        unreserved)
            log_warn "  WAL Status 'unreserved' — WAL may be removed at next checkpoint!"
            send_alert "WARNING" "Slot ${REPL_SLOT_NAME} WAL UNRESERVED" \
                "WAL for '${REPL_SLOT_NAME}' is 'unreserved' — may be removed at next checkpoint.\n  Lag      : ${s_lag_pretty}\n  Safe WAL : ${s_safe_wal}" \
                "slot_wal_danger"
            ;;
        lost)
            log_critical "  WAL Status 'lost' — required WAL REMOVED!"
            send_alert "CRITICAL" "Slot ${REPL_SLOT_NAME} WAL LOST" \
                "Required WAL for '${REPL_SLOT_NAME}' has been removed.\n  WAL Status: lost\n  Lag       : ${s_lag_pretty}\n\nStandby CANNOT recover. Full rebuild required." \
                "slot_wal_danger"
            ;;
    esac

    # Safe WAL budget check
    if [[ "$s_safe_wal" != "NULL" && "$s_safe_wal" =~ ^[0-9]+$ ]]; then
        if [[ "$s_safe_wal" -lt "$SAFE_WAL_WARN_BYTES" ]]; then
            local safe_pretty
            safe_pretty=$(run_sql "SELECT pg_size_pretty(${s_safe_wal}::bigint);")
            send_alert "WARNING" "Slot ${REPL_SLOT_NAME} near invalidation" \
                "Safe WAL remaining: ${safe_pretty}\nSlot approaching max_slot_wal_keep_size limit.\n  Lag: ${s_lag_pretty}" \
                "slot_near_limit"
        else
            clear_alert_state "slot_near_limit"
        fi
    fi

    # Report other slots
    local other_slots
    other_slots=$(run_sql "
        SELECT slot_name || ' | active=' || active || ' | wal_status=' || wal_status
        FROM pg_replication_slots WHERE slot_name != '${REPL_SLOT_NAME}';
    ")
    if [[ -n "$other_slots" ]]; then
        log_info "  Other slots:"
        while IFS= read -r line; do log_info "    ${line}"; done <<< "$other_slots"
    fi
}

# ===========================================================================
#  CHECK 2: REPLICATION LAG
# ===========================================================================

check_replication_lag() {
    log_info "================================================================"
    log_info " CHECK 2: Replication Lag"
    log_info "================================================================"

    local standby_count
    standby_count=$(run_sql "SELECT count(*) FROM pg_stat_replication;")

    if [[ "$standby_count" -eq 0 ]]; then
        log_warn "No streaming replication connections."
        send_alert "WARNING" "No streaming replication" \
            "pg_stat_replication is EMPTY.\n\nDiagnostics:\n  ssh standby 'systemctl status postgresql-17'\n  ssh standby 'tail -50 ${PG_LOG_DIR}/postgresql-*.log'\n  ssh standby 'grep primary_conninfo ${PG_AUTO_CONF}'\n  grep replication ${PG_HBA}" \
            "no_replication"
        return
    fi
    clear_alert_state "no_replication"

    log_info "Active streaming connections: ${standby_count}"

    local lag_data
    lag_data=$(run_sql "
        SELECT client_addr,
               application_name,
               state,
               sync_state,
               COALESCE(pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn), 0),
               COALESCE(pg_wal_lsn_diff(pg_current_wal_lsn(), write_lsn), 0),
               COALESCE(pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn), 0),
               COALESCE(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn), 0),
               COALESCE(EXTRACT(EPOCH FROM replay_lag), 0),
               COALESCE(EXTRACT(EPOCH FROM write_lag), 0),
               COALESCE(EXTRACT(EPOCH FROM flush_lag), 0),
               sent_lsn, write_lsn, flush_lsn, replay_lsn
        FROM pg_stat_replication;
    ")

    while IFS='|' read -r addr app_name state sync_state send_lag write_lag flush_lag \
                         replay_lag replay_sec write_sec flush_sec \
                         sent_lsn write_lsn flush_lsn replay_lsn; do
        addr=$(echo "$addr" | xargs)
        app_name=$(echo "$app_name" | xargs)
        state=$(echo "$state" | xargs)

        local replay_lag_mb
        replay_lag_mb=$(echo "scale=2; ${replay_lag:-0} / 1048576" | bc 2>/dev/null || echo "0")
        local replay_sec_int
        replay_sec_int=$(printf "%.0f" "${replay_sec:-0}" 2>/dev/null || echo "0")

        log_info "  Standby: ${addr} (${app_name})"
        log_info "    State      : ${state} | Sync: ${sync_state}"
        log_info "    Sent LSN   : ${sent_lsn}"
        log_info "    Write LSN  : ${write_lsn}"
        log_info "    Flush LSN  : ${flush_lsn}"
        log_info "    Replay LSN : ${replay_lsn}"
        log_info "    Replay Lag : ${replay_lag_mb} MB (${replay_sec_int}s)"

        local ak
        ak=$(echo "${addr}_${app_name}" | tr '.' '_' | tr ' ' '_')

        if (( $(echo "$replay_lag_mb > $WAL_LAG_CRITICAL_MB" | bc -l 2>/dev/null || echo 0) )); then
            send_alert "CRITICAL" "WAL lag CRITICAL: ${addr}" \
                "Replay lag: ${replay_lag_mb} MB (threshold: ${WAL_LAG_CRITICAL_MB} MB)\nTime lag: ${replay_sec_int}s" "wal_lag_${ak}"
        elif (( $(echo "$replay_lag_mb > $WAL_LAG_WARNING_MB" | bc -l 2>/dev/null || echo 0) )); then
            send_alert "WARNING" "WAL lag WARNING: ${addr}" \
                "Replay lag: ${replay_lag_mb} MB (threshold: ${WAL_LAG_WARNING_MB} MB)\nTime lag: ${replay_sec_int}s" "wal_lag_${ak}"
        else
            clear_alert_state "wal_lag_${ak}"
        fi

        if [[ "$replay_sec_int" -gt "$REPLAY_LAG_CRITICAL_SEC" ]]; then
            send_alert "CRITICAL" "Replay time CRITICAL: ${addr}" \
                "${replay_sec_int}s behind (threshold: ${REPLAY_LAG_CRITICAL_SEC}s)" "time_lag_${ak}"
        elif [[ "$replay_sec_int" -gt "$REPLAY_LAG_WARNING_SEC" ]]; then
            send_alert "WARNING" "Replay time WARNING: ${addr}" \
                "${replay_sec_int}s behind (threshold: ${REPLAY_LAG_WARNING_SEC}s)" "time_lag_${ak}"
        else
            clear_alert_state "time_lag_${ak}"
        fi
    done <<< "$lag_data"
}

# ===========================================================================
#  CHECK 3: pg_wal DIRECTORY + DISK
# ===========================================================================

check_wal_directory_and_disk() {
    log_info "================================================================"
    log_info " CHECK 3: pg_wal Directory & Disk Usage"
    log_info "================================================================"

    if [[ -d "$PG_WAL_DIR" ]]; then
        local wal_size_bytes wal_size_gb wal_file_count
        wal_size_bytes=$(du -sb "$PG_WAL_DIR" 2>/dev/null | awk '{print $1}')
        wal_size_gb=$(echo "scale=2; ${wal_size_bytes:-0} / 1073741824" | bc 2>/dev/null || echo "0")
        wal_file_count=$(find "$PG_WAL_DIR" -maxdepth 1 -type f -name '0000*' 2>/dev/null | wc -l)

        log_info "  pg_wal path    : ${PG_WAL_DIR}"
        log_info "  pg_wal size    : ${wal_size_gb} GB"
        log_info "  Segment count  : ${wal_file_count}"

        if (( $(echo "$wal_size_gb > $WAL_DIR_CRITICAL_GB" | bc -l 2>/dev/null || echo 0) )); then
            send_alert "CRITICAL" "pg_wal CRITICAL: ${wal_size_gb} GB" \
                "Path: ${PG_WAL_DIR}\nSize: ${wal_size_gb} GB (${wal_file_count} segments)\nThreshold: ${WAL_DIR_CRITICAL_GB} GB\n\nLikely: slot '${REPL_SLOT_NAME}' inactive.\n\nEmergency if disk > 90%:\n  SELECT pg_drop_replication_slot('${REPL_SLOT_NAME}');\n  CHECKPOINT;" \
                "wal_dir_size"
        elif (( $(echo "$wal_size_gb > $WAL_DIR_WARNING_GB" | bc -l 2>/dev/null || echo 0) )); then
            send_alert "WARNING" "pg_wal WARNING: ${wal_size_gb} GB" \
                "Path: ${PG_WAL_DIR}\nSize: ${wal_size_gb} GB (${wal_file_count} segments)" "wal_dir_size"
        else
            clear_alert_state "wal_dir_size"
        fi
    fi

    # Disk usage
    local disk_pct disk_avail disk_total
    disk_pct=$(df "$PGDATA" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
    disk_avail=$(df -h "$PGDATA" 2>/dev/null | awk 'NR==2 {print $4}')
    disk_total=$(df -h "$PGDATA" 2>/dev/null | awk 'NR==2 {print $2}')

    log_info "  Disk usage     : ${disk_pct}% (${disk_avail} free of ${disk_total})"

    if [[ -n "$disk_pct" ]]; then
        if [[ "$disk_pct" -ge "$DISK_CRITICAL_PCT" ]]; then
            send_alert "CRITICAL" "PGDATA disk ${disk_pct}% FULL" \
                "${PGDATA} is ${disk_pct}% full (${disk_avail} free).\n\nPG will PANIC at 100%.\n\nEmergency:\n  1. pg_drop_replication_slot('${REPL_SLOT_NAME}');\n  2. CHECKPOINT;\n  3. Extend volume" \
                "disk_usage"
        elif [[ "$disk_pct" -ge "$DISK_WARNING_PCT" ]]; then
            send_alert "WARNING" "PGDATA disk ${disk_pct}%" \
                "${PGDATA} is ${disk_pct}% full (${disk_avail} free)." "disk_usage"
        else
            clear_alert_state "disk_usage"
        fi
    fi
}

# ===========================================================================
#  CHECK 4: KEY PARAMETERS
# ===========================================================================

check_parameters() {
    log_info "================================================================"
    log_info " CHECK 4: Key Replication Parameters"
    log_info "================================================================"

    local params
    params=$(run_sql "
        SELECT name || ' = ' || setting || COALESCE(' (' || unit || ')','')
        FROM pg_settings
        WHERE name IN (
            'max_replication_slots','max_wal_senders','wal_level',
            'wal_keep_size','max_slot_wal_keep_size','wal_sender_timeout',
            'hot_standby_feedback','synchronous_standby_names',
            'synchronous_commit','archive_mode','archive_command'
        ) ORDER BY name;
    ")
    while IFS= read -r line; do log_info "  ${line}"; done <<< "$params"

    local wal_level
    wal_level=$(run_sql "SHOW wal_level;")
    if [[ "$wal_level" == "minimal" ]]; then
        send_alert "CRITICAL" "wal_level is minimal" \
            "Streaming replication WILL NOT WORK.\nFix: ALTER SYSTEM SET wal_level = 'replica';\nsystemctl restart postgresql-17" "param_wal_level"
    else
        clear_alert_state "param_wal_level"
    fi

    local max_senders
    max_senders=$(run_sql "SHOW max_wal_senders;")
    if [[ "$max_senders" -eq 0 ]]; then
        send_alert "CRITICAL" "max_wal_senders is 0" \
            "Replication disabled.\nFix: ALTER SYSTEM SET max_wal_senders = 10;\nsystemctl restart postgresql-17" "param_senders"
    else
        clear_alert_state "param_senders"
    fi

    local max_slot_wal
    max_slot_wal=$(run_sql "SHOW max_slot_wal_keep_size;")
    if [[ "$max_slot_wal" == "-1" ]]; then
        log_warn "  max_slot_wal_keep_size = -1 (UNLIMITED). Inactive slots can fill disk."
    fi
}

# ===========================================================================
#  CHECK 5: WALSENDER PROCESSES
# ===========================================================================

check_walsender_processes() {
    log_info "================================================================"
    log_info " CHECK 5: WAL Sender Processes"
    log_info "================================================================"

    local pids
    pids=$(pgrep -fa 'walsender' 2>/dev/null || true)
    if [[ -z "$pids" ]]; then
        log_warn "  No walsender processes at OS level."
    else
        while IFS= read -r line; do log_info "  ${line}"; done <<< "$pids"
    fi

    # OOM check
    local oom
    oom=$(dmesg -T 2>/dev/null | grep -i 'oom\|killed process' | tail -5 || true)
    if [[ -n "$oom" ]] && echo "$oom" | grep -qi 'postgres'; then
        log_warn "  OOM killer affected PostgreSQL!"
        send_alert "WARNING" "OOM killer hit PostgreSQL" \
            "Recent events:\n${oom}\n\nConsider OOMScoreAdjust=-1000 in systemd unit." "oom_postgres"
    fi

    local repl_details
    repl_details=$(run_sql "
        SELECT pid, client_addr, application_name, state, sync_state, backend_start::text,
               pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn)) AS lag
        FROM pg_stat_replication ORDER BY client_addr;
    ")
    if [[ -n "$repl_details" ]]; then
        log_info "  pg_stat_replication:"
        while IFS='|' read -r pid addr app state sync start lag; do
            log_info "    PID=${pid} addr=$(echo $addr|xargs) app=$(echo $app|xargs) state=$(echo $state|xargs) lag=$(echo $lag|xargs)"
        done <<< "$repl_details"
    fi
}

# ===========================================================================
#  CHECK 6: POSTGRESQL LOG INSPECTION
# ===========================================================================

check_pg_logs() {
    log_info "================================================================"
    log_info " CHECK 6: Recent PostgreSQL Log Errors"
    log_info "================================================================"

    local latest_log
    latest_log=$(ls -t "${PG_LOG_DIR}"/postgresql-*.log 2>/dev/null | head -1)
    if [[ -z "$latest_log" ]]; then
        log_warn "  No log files in ${PG_LOG_DIR}"
        return
    fi
    log_info "  Scanning: ${latest_log}"

    local repl_errors
    repl_errors=$(tail -1000 "$latest_log" 2>/dev/null | grep -iE 'replication|walsender|walreceiver|slot.*ssncpri|FATAL|PANIC' | tail -20 || true)

    if [[ -n "$repl_errors" ]]; then
        log_warn "  Replication-related entries:"
        while IFS= read -r line; do log_warn "    ${line}"; done <<< "$repl_errors"
        if echo "$repl_errors" | grep -qiE 'PANIC|FATAL.*replication|FATAL.*slot'; then
            send_alert "WARNING" "FATAL/PANIC in logs (replication)" \
                "File: ${latest_log}\n$(echo "$repl_errors" | grep -iE 'PANIC|FATAL' | tail -5)" "log_fatal"
        fi
    else
        log_info "  No replication errors in recent logs."
        clear_alert_state "log_fatal"
    fi
}

# ===========================================================================
#  PROMETHEUS METRICS
# ===========================================================================

export_prometheus_metrics() {
    [[ -z "${METRICS_FILE:-}" ]] && return
    log_info "Writing Prometheus metrics to ${METRICS_FILE}"
    local tmp; tmp=$(mktemp)
    cat > "$tmp" <<'H'
# HELP pg_replication_slot_active Slot active (1) or not (0)
# TYPE pg_replication_slot_active gauge
# HELP pg_replication_slot_wal_lag_bytes WAL lag bytes
# TYPE pg_replication_slot_wal_lag_bytes gauge
# HELP pg_replication_slot_conflicting Slot invalidated (1) or not (0)
# TYPE pg_replication_slot_conflicting gauge
# HELP pg_replication_replay_lag_seconds Replay lag seconds
# TYPE pg_replication_replay_lag_seconds gauge
# HELP pg_wal_directory_size_bytes pg_wal size
# TYPE pg_wal_directory_size_bytes gauge
# HELP pg_data_disk_usage_percent Disk usage pct
# TYPE pg_data_disk_usage_percent gauge
H
    run_sql "SELECT 'pg_replication_slot_active{slot=\"'||slot_name||'\"} '||CASE WHEN active THEN '1' ELSE '0' END FROM pg_replication_slots;" >> "$tmp"
    run_sql "SELECT 'pg_replication_slot_wal_lag_bytes{slot=\"'||slot_name||'\"} '||COALESCE(pg_wal_lsn_diff(pg_current_wal_lsn(),restart_lsn),0) FROM pg_replication_slots;" >> "$tmp"
    run_sql "SELECT 'pg_replication_slot_conflicting{slot=\"'||slot_name||'\"} '||CASE WHEN conflicting THEN '1' ELSE '0' END FROM pg_replication_slots;" >> "$tmp"
    run_sql "SELECT 'pg_replication_replay_lag_seconds{addr=\"'||client_addr||'\"} '||COALESCE(EXTRACT(EPOCH FROM replay_lag)::text,'0') FROM pg_stat_replication;" >> "$tmp"
    echo "pg_wal_directory_size_bytes $(du -sb "$PG_WAL_DIR" 2>/dev/null | awk '{print $1}')" >> "$tmp"
    echo "pg_data_disk_usage_percent $(df "$PGDATA" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5);print $5}')" >> "$tmp"
    mv "$tmp" "$METRICS_FILE"
}

# ===========================================================================
#  SUMMARY
# ===========================================================================

generate_summary() {
    log_info "================================================================"
    log_info " SUMMARY"
    log_info "================================================================"
    run_sql_formatted "
        SELECT slot_name AS \"Slot\", active AS \"Active\", wal_status AS \"WAL\",
               conflicting AS \"Invalid\", COALESCE(invalidation_reason,'-') AS \"Reason\",
               pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(),restart_lsn)) AS \"Lag\",
               COALESCE(pg_size_pretty(safe_wal_size),'unlimited') AS \"Safe WAL\"
        FROM pg_replication_slots ORDER BY slot_name;
    " >> "$LOG_FILE" 2>&1
    run_sql_formatted "
        SELECT client_addr AS \"Standby\", state AS \"State\",
               pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(),replay_lsn)) AS \"Lag\",
               EXTRACT(EPOCH FROM replay_lag)::int AS \"Lag(s)\"
        FROM pg_stat_replication ORDER BY client_addr;
    " >> "$LOG_FILE" 2>&1
    log_info "================================================================"
    log_info " RUN COMPLETE — next at cron interval"
    log_info "================================================================"
}

# ===========================================================================
#  MAIN
# ===========================================================================

main() {
    log_info ""
    log_info "################################################################"
    log_info "#  PostgreSQL Replication Slot Monitor"
    log_info "#  Slot: ${REPL_SLOT_NAME} | PGDATA: ${PGDATA}"
    log_info "#  $(TIMESTAMP)"
    log_info "################################################################"
    preflight
    check_slot_status
    check_replication_lag
    check_wal_directory_and_disk
    check_parameters
    check_walsender_processes
    check_pg_logs
    export_prometheus_metrics
    generate_summary
}

main "$@"
