# PMM3 + PostgreSQL 17 - Complete Setup Guide

## Table of Contents
1. [PMM3 Architecture Overview](#pmm3-architecture-overview)
2. [Prerequisites and Installation](#prerequisites-and-installation)
3. [PostgreSQL 17 Configuration](#postgresql-17-configuration)
4. [Custom Queries Deployment](#custom-queries-deployment)
5. [Alert Rules Configuration](#alert-rules-configuration)
6. [Grafana Dashboard Setup](#grafana-dashboard-setup)
7. [PMM3 Best Practices](#pmm3-best-practices)
8. [Troubleshooting](#troubleshooting)

---

## PMM3 Architecture Overview

PMM3 introduces significant improvements over PMM2:

### Key Changes in PMM3:
- **VictoriaMetrics** replaces Prometheus for better performance
- **Improved pmm-agent** with enhanced custom query support
- **Better PostgreSQL 17 support** with new system catalogs
- **Enhanced alerting** with AlertManager integration
- **Improved UI** with better filtering and visualization

### Architecture Components:
```
PostgreSQL 17 Server
    ↓
pmm-agent (collects metrics)
    ↓
PMM Server (VictoriaMetrics + Grafana + AlertManager)
    ↓
Grafana Dashboards + Alerts
```

---

## Prerequisites and Installation

### System Requirements

**PMM Server:**
- CPU: 4+ cores
- RAM: 8GB minimum, 16GB recommended
- Disk: 100GB+ SSD
- OS: Docker supported platform

**PostgreSQL Server:**
- PostgreSQL 17.x
- OS: Linux (Ubuntu 22.04+ / RHEL 9+ / Rocky Linux 9+)
- Network: Port 5432 accessible from PMM Server

### Step 1: Install PMM3 Server

```bash
# Using Docker (Recommended)
docker pull percona/pmm-server:3

# Create persistent volume
docker volume create pmm-data

# Run PMM Server
docker run -d \
  --name pmm-server \
  -p 443:443 \
  -p 80:80 \
  -v pmm-data:/srv \
  -e PMM_PUBLIC_ADDRESS=your-pmm-server-ip \
  --restart always \
  percona/pmm-server:3

# Check PMM Server status
docker logs pmm-server

# Access PMM UI
# https://your-pmm-server-ip (default: admin/admin)
```

**Alternative: Using podman**
```bash
podman pull percona/pmm-server:3
podman run -d \
  --name pmm-server \
  -p 443:443 \
  -p 80:80 \
  -v pmm-data:/srv:Z \
  -e PMM_PUBLIC_ADDRESS=your-pmm-server-ip \
  --restart always \
  percona/pmm-server:3
```

### Step 2: Install pmm-agent on PostgreSQL Server

```bash
# For Ubuntu/Debian
wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb
sudo dpkg -i percona-release_latest.generic_all.deb
sudo apt-get update
sudo apt-get install pmm-client

# For RHEL/Rocky Linux/CentOS
sudo yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
sudo yum install pmm-client

# Verify installation
pmm-admin --version  # Should show PMM 3.x
```

### Step 3: Register pmm-agent with PMM Server

```bash
# Register the agent
pmm-admin config \
  --server-insecure-tls \
  --server-url=https://admin:admin@your-pmm-server-ip:443 \
  --agent-password=secure_agent_password \
  node_name

# Verify connection
pmm-admin status

# Expected output:
# Agent ID: ...
# PMM Server: your-pmm-server-ip
# Agent Version: 3.x.x
```

---

## PostgreSQL 17 Configuration

### Step 1: Enable Required Extensions

```sql
-- Connect as superuser
sudo -u postgres psql

-- Enable extensions on each monitored database
\c your_database

CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgstattuple;

-- PostgreSQL 17 new extension for advanced statistics
CREATE EXTENSION IF NOT EXISTS pg_stat_monitor;  -- Optional but recommended

-- Verify extensions
\dx

-- Expected output:
-- pg_stat_statements | 1.10
-- pgstattuple         | 1.5
```

### Step 2: Configure postgresql.conf for Optimal Monitoring

```bash
sudo nano /etc/postgresql/17/main/postgresql.conf
```

Add/modify these settings:

```ini
# ===== PMM3 Monitoring Configuration for PostgreSQL 17 =====

# Shared Preload Libraries (REQUIRES RESTART)
shared_preload_libraries = 'pg_stat_statements'

# Query Statistics
pg_stat_statements.track = all
pg_stat_statements.max = 10000
pg_stat_statements.track_utility = on
pg_stat_statements.track_planning = on  # PostgreSQL 17 feature
pg_stat_statements.save = on

# Activity Tracking
track_activities = on
track_activity_query_size = 4096
track_counts = on
track_io_timing = on
track_wal_io_timing = on  # PostgreSQL 17 feature
track_functions = all

# Autovacuum Monitoring
log_autovacuum_min_duration = 0

# Checkpoint and WAL
checkpoint_completion_target = 0.9
log_checkpoints = on
wal_compression = on  # PostgreSQL 17 enhancement

# Connection Tracking
log_connections = on
log_disconnections = on

# Slow Query Logging (Optional)
log_min_duration_statement = 1000  # Log queries > 1 second
log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h '

# Statement Timeout
statement_timeout = 0  # Set per application, not globally

# Statistics
compute_query_id = on  # PostgreSQL 17 feature for query fingerprinting
```

**Restart PostgreSQL:**
```bash
sudo systemctl restart postgresql
```

### Step 3: Create Monitoring User with Proper Permissions

```sql
-- Create monitoring user
CREATE ROLE pmm_monitor WITH LOGIN PASSWORD 'StrongPassword123!';

-- PostgreSQL 17: Grant pg_monitor role (includes all needed permissions)
GRANT pg_monitor TO pmm_monitor;

-- Grant connection permissions
GRANT CONNECT ON DATABASE your_database TO pmm_monitor;
GRANT USAGE ON SCHEMA public TO pmm_monitor;
GRANT USAGE ON SCHEMA pg_catalog TO pmm_monitor;

-- Grant permissions for custom queries
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO pmm_monitor;
GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO pmm_monitor;

-- Grant execute on specific functions
GRANT EXECUTE ON FUNCTION pgstattuple(regclass) TO pmm_monitor;
GRANT EXECUTE ON FUNCTION pg_stat_file(text) TO pmm_monitor;

-- Grant permissions for pg_stat_statements
GRANT EXECUTE ON FUNCTION pg_stat_statements_reset() TO pmm_monitor;

-- For replication monitoring (if applicable)
GRANT pg_read_all_settings TO pmm_monitor;
GRANT pg_read_all_stats TO pmm_monitor;

-- Verify permissions
\du pmm_monitor
```

### Step 4: Configure pg_hba.conf

```bash
sudo nano /etc/postgresql/17/main/pg_hba.conf
```

Add entry for PMM monitoring:

```conf
# PMM Monitoring Access
host    all             pmm_monitor     pmm-server-ip/32      scram-sha-256
host    all             pmm_monitor     127.0.0.1/32          scram-sha-256
```

**Reload configuration:**
```bash
sudo systemctl reload postgresql
```

---

## Custom Queries Deployment

### Step 1: Understand PMM3 Custom Query Structure

PMM3 stores custom queries in:
```
/usr/local/percona/pmm-agent/config/custom-queries/
```

### Step 2: Create Custom Query Directory

```bash
# Create directory structure
sudo mkdir -p /usr/local/percona/pmm-agent/config/custom-queries/postgresql

# Set ownership
sudo chown -R pmm-agent:pmm-agent /usr/local/percona/pmm-agent/config/custom-queries

# Set permissions
sudo chmod 755 /usr/local/percona/pmm-agent/config/custom-queries/postgresql
```

### Step 3: Deploy Custom Query Files

**Option 1: Single Combined File**
```bash
sudo nano /usr/local/percona/pmm-agent/config/custom-queries/postgresql/pg17_monitoring.yaml
```

Copy all 20 queries from the artifacts into this file.

**Option 2: Separate Files by Category**
```bash
# Performance queries
sudo nano /usr/local/percona/pmm-agent/config/custom-queries/postgresql/01-performance.yaml
# (Queries 1, 2, 9, 16, 18)

# Replication and WAL
sudo nano /usr/local/percona/pmm-agent/config/custom-queries/postgresql/02-replication.yaml
# (Queries 3, 13, 19)

# Maintenance
sudo nano /usr/local/percona/pmm-agent/config/custom-queries/postgresql/03-maintenance.yaml
# (Queries 10, 12)

# Capacity and Storage
sudo nano /usr/local/percona/pmm-agent/config/custom-queries/postgresql/04-capacity.yaml
# (Queries 4, 11, 15)

# Locks and Contention
sudo nano /usr/local/percona/pmm-agent/config/custom-queries/postgresql/05-locks.yaml
# (Queries 5, 14, 17)

# Indexes and Queries
sudo nano /usr/local/percona/pmm-agent/config/custom-queries/postgresql/06-indexes.yaml
# (Queries 7, 8)

# System Statistics
sudo nano /usr/local/percona/pmm-agent/config/custom-queries/postgresql/07-system.yaml
# (Queries 6, 20)
```

### Step 4: Add PostgreSQL Instance with Custom Queries

```bash
# Add PostgreSQL service with custom queries enabled
pmm-admin add postgresql \
  --username=pmm_monitor \
  --password='StrongPassword123!' \
  --host=localhost \
  --port=5432 \
  --query-source=pgstatstatements \
  --disable-queryexamples \
  --custom-queries=/usr/local/percona/pmm-agent/config/custom-queries/postgresql/*.yaml \
  --environment=production \
  --cluster=pg17-cluster \
  --replication-set=primary \
  pg17_main

# For multiple databases on same server
pmm-admin add postgresql \
  --username=pmm_monitor \
  --password='StrongPassword123!' \
  --host=localhost \
  --port=5432 \
  --database=app_database \
  --custom-queries=/usr/local/percona/pmm-agent/config/custom-queries/postgresql/*.yaml \
  app_db
```

### Step 5: Verify Custom Queries are Loaded

```bash
# Check pmm-agent status
pmm-admin status

# Check agent logs
sudo journalctl -u pmm-agent -f

# Verify metrics are being collected
pmm-admin list

# Test specific custom query
curl -s http://localhost:42001/metrics | grep pg_long_running_queries

# Expected output:
# pg_long_running_queries_duration_seconds{...} 123.45
```

### Step 6: Validate Query Execution

```bash
# Test queries manually on PostgreSQL
sudo -u postgres psql -d your_database

-- Test a query from the YAML
SELECT 
  datname as database,
  usename as username,
  pid,
  state,
  EXTRACT(EPOCH FROM (NOW() - query_start)) as duration_seconds
FROM pg_stat_activity
WHERE state != 'idle'
  AND (NOW() - query_start) > interval '5 minutes';

-- Should return results if there are long-running queries
```

---

## Alert Rules Configuration

### Method 1: Using PMM3 UI (Recommended)

#### Step 1: Access Alerting Interface

1. Login to PMM Server: `https://your-pmm-server-ip`
2. Navigate to: **Alerting** → **Alert rules**
3. Click **New alert rule**

#### Step 2: Create Alert Rule - Example 1 (Long Running Queries)

**Basic Information:**
```yaml
Rule name: PostgreSQL 17 - Long Running Queries
Folder: PostgreSQL Alerts / Performance
Evaluation group: postgresql-performance (create if doesn't exist)
```

**Query Section (Section A):**
```promql
# Query A: Get duration of long running queries
pg_long_running_queries_duration_seconds > 1800

# Click "Run queries" to test
```

**Expression Section (Section B):**
```yaml
# Expression B: Reduce
Operation: Last
Input: A
Mode: Strict

# Expression C: Threshold
Condition: IS ABOVE
Value: 1800
Input: B
```

**Alert Evaluation:**
```yaml
Evaluate every: 5m
For: 5m
Configure no data and error handling: Alerting

# Labels
severity: warning
component: postgresql
tier: database
alert_type: performance
database: {{ $labels.database }}

# Annotations
summary: Long running query detected on {{ $labels.database }}
description: |
  Query running for {{ $value }}s on database {{ $labels.database }}
  - User: {{ $labels.username }}
  - PID: {{ $labels.pid }}
  - Application: {{ $labels.application_name }}
  - Query ID: {{ $labels.query_id }}
  
  Action required: Review query performance and consider optimization.
dashboard: https://your-pmm-server-ip/graph/d/postgresql-instance-summary
runbook_url: https://wiki.company.com/runbooks/postgresql-long-queries
```

**Notification Policy:**
- Select notification channel (email, Slack, PagerDuty, etc.)
- Save the alert rule

#### Step 3: Create Additional Alert Rules

Repeat for all 20 custom queries. Here are configuration examples:

**Alert 2: High Table Bloat**
```promql
# Query
pg_table_bloat_bloat_percentage > 30

# Labels
severity: warning
maintenance: required

# Description
Table {{ $labels.schemaname }}.{{ $labels.tablename }} has {{ $value }}% bloat.
Recommend running: VACUUM FULL {{ $labels.schemaname }}.{{ $labels.tablename }};
```

**Alert 3: Replication Lag Critical**
```promql
# Query
pg_replication_lag_replay_lag_seconds > 300

# Labels  
severity: critical
component: replication

# Description
Replica {{ $labels.application_name }} (slot: {{ $labels.slot_name }}) is {{ $value }}s behind primary.
Replay lag: {{ $labels.replay_lag_mb }}MB
```

**Alert 4: Connection Pool Saturation**
```promql
# Query
pg_connection_saturation_usage_percentage{state="total"} > 80

# Labels
severity: warning
capacity: connections

# Description
Connection usage at {{ $value }}% of available connections.
Current: {{ $labels.connection_count }}
Available: {{ $labels.usable_connections }}
```

### Method 2: Using Configuration Files (Advanced)

#### Create Alert Rules YAML

```bash
# Create alerts directory
sudo mkdir -p /srv/pmm/victoriametrics-data/alerts

# Create alert rules file
sudo nano /srv/pmm/victoriametrics-data/alerts/postgresql17_alerts.yml
```

**Complete Alert Rules File:**
```yaml
groups:
  - name: postgresql17_performance
    interval: 60s
    rules:
      # Long Running Queries
      - alert: PostgreSQL17LongRunningQueries
        expr: pg_long_running_queries_duration_seconds > 1800
        for: 5m
        labels:
          severity: warning
          tier: database
          component: postgresql
        annotations:
          summary: "Long running query on {{ $labels.database }}"
          description: |
            Query (ID: {{ $labels.query_id }}) running for {{ $value }}s
            Database: {{ $labels.database }}
            User: {{ $labels.username }}
            PID: {{ $labels.pid }}
          dashboard: "https://your-pmm-server-ip/graph/d/postgresql-instance"

      # High Table Bloat
      - alert: PostgreSQL17HighTableBloat
        expr: pg_table_bloat_bloat_percentage > 30
        for: 2h
        labels:
          severity: warning
          maintenance: required
        annotations:
          summary: "High bloat in {{ $labels.tablename }}"
          description: "Table {{ $labels.schemaname }}.{{ $labels.tablename }} has {{ $value }}% bloat"
          action: "VACUUM FULL {{ $labels.schemaname }}.{{ $labels.tablename }};"

      # Replication Lag
      - alert: PostgreSQL17ReplicationLagCritical
        expr: pg_replication_lag_replay_lag_seconds > 300
        for: 5m
        labels:
          severity: critical
          component: replication
        annotations:
          summary: "Critical replication lag on {{ $labels.application_name }}"
          description: "Replica {{ $labels.application_name }} is {{ $value }}s behind"

      # Connection Saturation
      - alert: PostgreSQL17ConnectionPoolSaturation
        expr: pg_connection_saturation_usage_percentage{state="total"} > 80
        for: 5m
        labels:
          severity: warning
          capacity: connections
        annotations:
          summary: "Connection pool saturation"
          description: "Usage at {{ $value }}% of usable connections"

  - name: postgresql17_data_integrity
    interval: 120s
    rules:
      # Transaction Wraparound
      - alert: PostgreSQL17TransactionWraparoundDanger
        expr: pg_transaction_wraparound_wraparound_risk_percentage > 50
        for: 1h
        labels:
          severity: critical
          emergency: true
        annotations:
          summary: "Transaction wraparound risk in {{ $labels.database }}"
          description: "Database {{ $labels.database }} is {{ $value }}% towards wraparound"

      # MultiXact Wraparound
      - alert: PostgreSQL17MultiXactWraparound
        expr: pg_transaction_wraparound_mxid_wraparound_risk_percentage > 50
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "MultiXact wraparound risk in {{ $labels.database }}"
          description: "MultiXact age at {{ $value }}%"

      # Deadlocks
      - alert: PostgreSQL17DeadlocksDetected
        expr: rate(pg_deadlocks_deadlocks[5m]) > 0.1
        for: 3m
        labels:
          severity: warning
        annotations:
          summary: "Deadlocks in {{ $labels.database }}"
          description: "{{ $value }} deadlocks/sec detected"

  - name: postgresql17_maintenance
    interval: 300s
    rules:
      # Table Not Vacuumed
      - alert: PostgreSQL17TableNotVacuumed
        expr: |
          pg_autovacuum_activity_seconds_since_last_vacuum > 86400 
          and pg_autovacuum_activity_dead_tuples > pg_autovacuum_activity_autovacuum_threshold
        for: 2h
        labels:
          severity: warning
          maintenance: vacuum
        annotations:
          summary: "Table {{ $labels.tablename }} not vacuumed"
          description: "{{ $labels.dead_tuples }} dead tuples, not vacuumed for {{ $value }}s"

      # Vacuum Stuck
      - alert: PostgreSQL17VacuumStuck
        expr: |
          pg_vacuum_progress_vacuum_duration_seconds > 7200 
          and pg_vacuum_progress_progress_percentage < 50
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "Vacuum stuck on {{ $labels.table_name }}"
          description: "Running for {{ $value }}s, only {{ $labels.progress_percentage }}% complete"

  - name: postgresql17_storage
    interval: 180s
    rules:
      # Database Growth
      - alert: PostgreSQL17DatabaseRapidGrowth
        expr: rate(pg_database_size_size_bytes[1h]) > 1073741824
        for: 2h
        labels:
          severity: info
          capacity: storage
        annotations:
          summary: "Rapid growth in {{ $labels.database }}"
          description: "Growing at {{ $value }} bytes/sec"

      # WAL Files
      - alert: PostgreSQL17ExcessiveWALFiles
        expr: pg_wal_generation_wal_file_count > 1000
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Excessive WAL accumulation"
          description: "{{ $value }} WAL files present"

      # Temp File Usage
      - alert: PostgreSQL17HighTempFileUsage
        expr: rate(pg_temp_files_temp_bytes[5m]) > 1073741824
        for: 10m
        labels:
          severity: warning
          tuning: work_mem
        annotations:
          summary: "High temp file usage in {{ $labels.database }}"
          description: "Creating {{ $value }} bytes/sec of temp files"

  - name: postgresql17_replication
    interval: 60s
    rules:
      # Replication Slot Lag
      - alert: PostgreSQL17ReplicationSlotLag
        expr: pg_replication_lag_replay_lag_mb > 10240
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Large replication slot lag"
          description: "Slot {{ $labels.slot_name }} has {{ $value }}MB lag"

      # Archive Failing
      - alert: PostgreSQL17ArchiveFailing
        expr: rate(pg_archive_status_failed_count[5m]) > 0
        for: 10m
        labels:
          severity: critical
          component: archiving
        annotations:
          summary: "WAL archiving failures"
          description: "Archive failing at {{ $value }} failures/sec"

      # Archive Backlog
      - alert: PostgreSQL17ArchiveBacklog
        expr: pg_archive_status_wal_files_ready > 100
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "WAL archive backlog"
          description: "{{ $value }} WAL files pending archival"

  - name: postgresql17_query_performance
    interval: 120s
    rules:
      # Cache Hit Ratio
      - alert: PostgreSQL17LowCacheHitRatio
        expr: pg_cache_hit_ratio_cache_hit_ratio < 90
        for: 15m
        labels:
          severity: warning
          tuning: memory
        annotations:
          summary: "Low cache hit ratio on {{ $labels.database }}"
          description: "Cache hit ratio is {{ $value }}%"

      # Sequential Scans
      - alert: PostgreSQL17HighSequentialScans
        expr: |
          rate(pg_sequential_scans_seq_scan[1h]) > 100 
          and pg_sequential_scans_size_bytes > 1073741824
          and pg_sequential_scans_avg_tuples_per_seq_scan > 10000
        for: 30m
        labels:
          severity: warning
          optimization: index
        annotations:
          summary: "High sequential scans on {{ $labels.tablename }}"
          description: "{{ $value }} seq scans/sec, avg {{ $labels.avg_tuples_per_seq_scan }} tuples/scan"

      # Query Dominance
      - alert: PostgreSQL17SlowQueryDominance
        expr: pg_top_queries_time_percentage > 20
        for: 15m
        labels:
          severity: warning
          optimization: query
        annotations:
          summary: "Single query consuming excessive time in {{ $labels.database }}"
          description: "Query {{ $labels.query_id }} consuming {{ $value }}% of total time"

      # Temp Spill
      - alert: PostgreSQL17QueryTempSpill
        expr: rate(pg_top_queries_temp_blks_written[5m]) > 1000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Query writing excessive temp blocks"
          description: "Query {{ $labels.query_id }} writing {{ $value }} temp blocks/sec"

  - name: postgresql17_locks_and_contention
    interval: 60s
    rules:
      # Waiting Locks
      - alert: PostgreSQL17HighWaitingLocks
        expr: pg_locks_detail_waiting_locks > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High waiting locks on {{ $labels.relation }}"
          description: "{{ $value }} locks waiting, {{ $labels.distinct_backends }} backends affected"

      # Idle in Transaction Blocking
      - alert: PostgreSQL17IdleInTransactionBlocking
        expr: |
          pg_idle_in_transaction_idle_seconds > 600 
          and pg_idle_in_transaction_blocking_others > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Idle in transaction blocking queries on {{ $labels.database }}"
          description: "Idle for {{ $value }}s, blocking {{ $labels.blocking_others }} queries"

      # Forced Checkpoints
      - alert: PostgreSQL17HighForcedCheckpoints
        expr: pg_checkpoint_stats_forced_checkpoint_ratio > 50
        for: 15m
        labels:
          severity: warning
          tuning: required
        annotations:
          summary: "High forced checkpoints"
          description: "{{ $value }}% of checkpoints are forced"

  - name: postgresql17_indexes
    interval: 3600s  # Check hourly
    rules:
      # Unused Indexes
      - alert: PostgreSQL17UnusedIndexes
        expr: |
          pg_unused_indexes_index_scans < 10 
          and pg_unused_indexes_index_bytes > 104857600
        for: 7d
        labels:
          severity: info
          optimization: index
        annotations:
          summary: "Potentially unused index {{ $labels.indexname }}"
          description: "Index {{ $labels.indexname }} ({{ $labels.index_type }}) has only {{ $value }} scans"
```

#### Apply Alert Rules

```bash
# Reload alerts in PMM Server
docker exec pmm-server supervisorctl restart victoriametrics

# Or restart PMM Server
docker restart pmm-server

# Verify alerts are loaded
curl -k https://your-pmm-server-ip/prometheus/api/v1/rules | jq '.data.groups[].rules[] | select(.name | contains("PostgreSQL17"))'
```

---

## Grafana Dashboard Setup

### Step 1: Create Custom Dashboard

1. Login to PMM Server
2. Navigate to **Dashboards** → **New** → **New Dashboard**
3. Click **Add visualization**

### Dashboard Structure

Create a comprehensive dashboard with these sections:

#### Section 1: Overview Row

**Panel 1: Database Size**
```yaml
Type: Stat
Query: pg_database_size_size_gb
Visualization:
  - Unit: Gigabytes (GB)
  - Color scheme: Single color (Blue)
  - Graph mode: None
  - Text mode: Value and name
Repeat: database (variable)
```

**Panel 2: Active Connections**
```yaml
Type: Gauge
Query: pg_connection_saturation_usage_percentage{state="total"}
Thresholds:
  - 0-70: Green
  - 70-85: Yellow
  - 85-100: Red
Unit: Percent (0-100)
```

**Panel 3: Cache Hit Ratio**
```yaml
Type: Stat
Query: pg_cache_hit_ratio_cache_hit_ratio
Thresholds:
  - 0-85: Red
  - 85-95: Yellow
  - 95-100: Green
Unit: Percent
```

**Panel 4: Replication Lag**
```yaml
Type: Stat
Query: max(pg_replication_lag_replay_lag_seconds)
Unit: Seconds
Color: Value
Thresholds:
  - 0-60: Green
  - 60-300: Yellow
  - 300+: Red
```

#### Section 2: Query Performance Row

**Panel 5: Long Running Queries**
```yaml
Type: Table
Query: pg_long_running_queries_duration_seconds > 60
Columns:
  - database
  - username
  - pid
  - application_name
  - duration_seconds (Unit: seconds)
  - query_snippet
Transform: Sort by duration_seconds DESC
```

**Panel 6: Top Queries by Time**
```yaml
Type: Table
Query: topk(20, pg_top_queries_total_time_ms)
Columns:
  - database
  - query_snippet
  - calls
  - mean_time_ms
  - time_percentage
  - cache_hit_ratio
Color mode: Cell
Thresholds:
  - time_percentage > 20: Red
  - time_percentage > 10: Yellow
```

**Panel 7: Query Execution Time Trend**
```yaml
Type: Time series
Query A: avg(pg_top_queries_mean_time_ms) by (database)
Query B: max(pg_top_queries_max_time_ms) by (database)
Legend: {{ database }} - {{ metric }}
Y-axis: Milliseconds
```

#### Section 3: Replication and WAL Row

**Panel 8: Replication Lag Timeline**
```yaml
Type: Time series
Query A: pg_replication_lag_replay_lag_seconds
Query B: pg_replication_lag_replay_lag_mb
Legend: {{ application_name }} ({{ slot_name }})
Y-axis (left): Seconds
Y-axis (right): MB
```

**Panel 9: WAL Generation Rate**
```yaml
Type: Graph
Query: rate(pg_wal_generation_total_wal_size_mb[5m])
Legend: WAL Generation Rate
Unit: MB/sec
```

**Panel 10: Archive Status**
```yaml
Type: Stat
Query A: rate(pg_archive_status_archived_count[5m])
Query B: rate(pg_archive_status_failed_count[5m])
Query C: pg_archive_status_wal_files_ready
Layout: Horizontal
Colors:
  - Failed > 0: Red
  - Ready > 50: Yellow
```

#### Section 4: Maintenance and Bloat Row

**Panel 11: Table Bloat**
```yaml
Type: Bar gauge
Query: topk(10, pg_table_bloat_bloat_percentage)
Legend: {{ schemaname }}.{{ tablename }}
Display mode: Gradient
Orientation: Horizontal
Thresholds:
  - 0-20: Green
  - 20-30: Yellow
  - 30-100: Red
```

**Panel 12: Vacuum Progress**
```yaml
Type: Table
Query: pg_vacuum_progress_progress_percentage
Columns:
  - database
  - table_name
  - phase
  - progress_percentage
  - vacuum_duration_seconds
Conditional formatting:
  - duration > 3600: Red
  - progress < 50: Yellow
```

**Panel 13: Autovacuum Activity**
```yaml
Type: Time series
Query A: rate(pg_autovacuum_activity_autovacuum_count[1h])
Query B: rate(pg_autovacuum_activity_vacuum_count[1h])
Legend: {{ tablename }} - {{ metric }}
Y-axis: Vacuums per hour
```

#### Section 5: Locks and Contention Row

**Panel 14: Lock Wait Queue**
```yaml
Type: Table
Query: pg_locks_detail_waiting_locks > 0
Columns:
  - locktype
  - database
  - relation
  - mode
  - waiting_locks
  - distinct_backends
  - longest_query_seconds
Sort: waiting_locks DESC
```

**Panel 15: Idle in Transaction**
```yaml
Type: Table
Query: pg_idle_in_transaction_idle_seconds > 300
Columns:
  - database
  - username
  - application_name
  - state
  - idle_seconds
  - locks_held
  - blocking_others
Thresholds:
  - idle_seconds > 600: Red
  - blocking_others > 0: Red
```

**Panel 16: Deadlock Rate**
```yaml
Type: Time series
Query: rate(pg_deadlocks_deadlocks[5m])
Legend: {{ database }}
Y-axis: Deadlocks per second
Alert threshold line: 0.1
```

#### Section 6: Storage and Capacity Row

**Panel 17: Database Growth Rate**
```yaml
Type: Time series
Query: rate(pg_database_size_size_bytes[1h]) / 1024 / 1024 / 1024
Legend: {{ database }}
Unit: GB/hour
Y-axis: Growth rate
```

**Panel 18: Temporary File Usage**
```yaml
Type: Graph
Query: rate(pg_temp_files_temp_bytes[5m]) / 1024 / 1024
Legend: {{ database }}
Unit: MB/sec
Thresholds:
  - > 100 MB/sec: Yellow
  - > 1000 MB/sec: Red
```

**Panel 19: Sequential Scans**
```yaml
Type: Bar chart
Query: topk(10, rate(pg_sequential_scans_seq_scan[1h]))
Legend: {{ schemaname }}.{{ tablename }}
Unit: Scans per hour
Color by value
```

#### Section 7: System Health Row

**Panel 20: Transaction ID Age**
```yaml
Type: Gauge
Query: max(pg_transaction_wraparound_wraparound_risk_percentage)
Unit: Percent (0-100)
Thresholds:
  - 0-30: Green
  - 30-50: Yellow
  - 50-100: Red
Label: XID Wraparound Risk
```

**Panel 21: Checkpoint Statistics**
```yaml
Type: Stat
Query A: rate(pg_checkpoint_stats_checkpoints_timed[5m])
Query B: rate(pg_checkpoint_stats_checkpoints_requested[5m])
Query C: pg_checkpoint_stats_forced_checkpoint_ratio
Layout: Row
Labels: Scheduled | Forced | Forced %
```

**Panel 22: Cache and I/O Performance**
```yaml
Type: Time series
Query A: pg_cache_hit_ratio_cache_hit_ratio
Query B: rate(pg_cache_hit_ratio_blk_read_time[5m])
Query C: rate(pg_cache_hit_ratio_blk_write_time[5m])
Legend: {{ database }} - {{ metric }}
Dual Y-axis:
  - Left: Cache hit ratio (%)
  - Right: I/O time (ms)
```

### Step 2: Configure Dashboard Variables

Create template variables for filtering:

**Variable 1: Instance**
```yaml
Name: instance
Type: Query
Data source: VictoriaMetrics
Query: label_values(pg_database_size_size_bytes, instance)
Multi-value: true
Include All: true
```

**Variable 2: Database**
```yaml
Name: database
Type: Query
Data source: VictoriaMetrics
Query: label_values(pg_database_size_size_bytes{instance="$instance"}, database)
Multi-value: true
Include All: true
```

**Variable 3: Schema**
```yaml
Name: schema
Type: Query
Query: label_values(pg_table_bloat_bloat_percentage{database="$database"}, schemaname)
Multi-value: true
Include All: true
```

**Variable 4: Time Range**
```yaml
Name: time_range
Type: Interval
Auto: true
Options: 5m, 15m, 30m, 1h, 6h, 12h, 1d, 7d
```

### Step 3: Export/Import Dashboard JSON

**Export Dashboard:**
```bash
# From Grafana UI
Dashboard Settings → JSON Model → Copy to clipboard

# Save to file
cat > /tmp/pg17_custom_dashboard.json << 'EOF'
{
  "dashboard": {
    "title": "PostgreSQL 17 - Custom Monitoring",
    "uid": "pg17-custom-mon",
    "tags": ["postgresql", "postgresql17", "custom"],
    "timezone": "browser",
    "refresh": "30s",
    "schemaVersion": 38,
    ...
  }
}
EOF
```

**Import Dashboard:**
```bash
# Via UI: Dashboards → Import → Upload JSON file

# Via API:
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d @/tmp/pg17_custom_dashboard.json \
  https://your-pmm-server-ip/api/dashboards/db
```

### Step 4: Create Complete Dashboard JSON Template

**Complete Dashboard Configuration:**
```json
{
  "dashboard": {
    "title": "PostgreSQL 17 - Complete Custom Monitoring",
    "uid": "pg17-complete-monitoring",
    "tags": ["postgresql", "postgresql17", "pmm3", "custom"],
    "timezone": "browser",
    "refresh": "30s",
    "time": {
      "from": "now-6h",
      "to": "now"
    },
    "templating": {
      "list": [
        {
          "name": "instance",
          "type": "query",
          "datasource": "VictoriaMetrics",
          "query": "label_values(pg_database_size_size_bytes, instance)",
          "multi": true,
          "includeAll": true
        },
        {
          "name": "database",
          "type": "query",
          "datasource": "VictoriaMetrics",
          "query": "label_values(pg_database_size_size_bytes{instance=\"$instance\"}, database)",
          "multi": true,
          "includeAll": true
        }
      ]
    },
    "panels": [
      {
        "title": "Key Metrics Overview",
        "type": "row",
        "collapsed": false,
        "gridPos": {"h": 1, "w": 24, "x": 0, "y": 0}
      },
      {
        "title": "Database Size",
        "type": "stat",
        "datasource": "VictoriaMetrics",
        "targets": [
          {
            "expr": "pg_database_size_size_gb{instance=\"$instance\",database=\"$database\"}"
          }
        ],
        "gridPos": {"h": 4, "w": 6, "x": 0, "y": 1},
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"]
          },
          "orientation": "auto",
          "textMode": "value_and_name",
          "colorMode": "value"
        },
        "fieldConfig": {
          "defaults": {
            "unit": "decgbytes",
            "thresholds": {
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 500, "color": "yellow"},
                {"value": 1000, "color": "red"}
              ]
            }
          }
        }
      }
    ]
  }
}
```

### Step 5: Setup Dashboard Annotations

Add event markers to correlate with alerts:

```yaml
Name: PostgreSQL Alerts
Data source: VictoriaMetrics
Query: ALERTS{alertname=~"PostgreSQL17.*"}
Tags: alert, postgresql
Color: Red
```

---

## PMM3 Best Practices

### 1. Metrics Collection Optimization

**Configure Collection Intervals:**
```bash
# Edit pmm-agent configuration
sudo nano /usr/local/percona/pmm-agent/config/pmm-agent.yaml
```

```yaml
# Optimize scrape intervals
postgresql:
  - service_id: "your-service-id"
    scrape_interval: 30s  # Increase for less critical metrics
    scrape_timeout: 10s
    
custom_queries:
  - scrape_interval: 60s  # Custom queries can be less frequent
    scrape_timeout: 30s
```

**Performance vs. Granularity Trade-offs:**
```yaml
High Frequency (10-30s):
  - Connection metrics
  - Replication lag
  - Active queries
  - Lock contention

Medium Frequency (60-120s):
  - Table statistics
  - Index usage
  - Cache hit ratios
  - Checkpoint stats

Low Frequency (300-600s):
  - Table bloat
  - Unused indexes
  - Extension stats
  - Transaction wraparound
```

### 2. Query Optimization Tips

**Limit Result Sets:**
```sql
-- Always use LIMIT for large result sets
SELECT ... FROM pg_stat_activity
WHERE ...
ORDER BY duration DESC
LIMIT 50;  -- Prevent excessive data collection

-- Use time-based filters
WHERE last_vacuum > NOW() - INTERVAL '7 days'
```

**Index Monitoring Queries:**
```sql
-- Ensure these indexes exist for better query performance
CREATE INDEX IF NOT EXISTS idx_pg_stat_activity_state 
ON pg_stat_activity(state) 
WHERE state != 'idle';

-- Note: pg_stat_activity is a view, actual indexes on pg_stat_activity don't work
-- But ensure pg_stat_statements is properly configured
```

**Use Materialized Views for Expensive Queries:**
```sql
-- Create materialized view for table bloat (expensive query)
CREATE MATERIALIZED VIEW mv_table_bloat AS
SELECT 
  schemaname,
  tablename,
  (pgstattuple(schemaname||'.'||tablename)).dead_tuple_percent as bloat_pct
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND pg_total_relation_size(schemaname||'.'||tablename) > 1073741824;

-- Refresh hourly via cron
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('refresh-bloat-stats', '0 * * * *', 
  'REFRESH MATERIALIZED VIEW mv_table_bloat');
```

### 3. Alert Tuning Guidelines

**Baseline Your Environment:**
```bash
# Collect baseline metrics for 7 days
# Analyze 95th percentile values
# Set thresholds at 1.5x normal values

# Example: Query for baseline cache hit ratio
SELECT 
  database,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY cache_hit_ratio) as p95_cache_hit
FROM (
  SELECT database, cache_hit_ratio 
  FROM historical_cache_metrics
  WHERE timestamp > NOW() - INTERVAL '7 days'
) AS baseline
GROUP BY database;
```

**Progressive Alert Severity:**
```yaml
# Example: Connection pool alerts
Warning:  80% utilization, 5min duration
Critical: 90% utilization, 3min duration
Emergency: 95% utilization, 1min duration

# Example: Replication lag
Info:     60s lag, 5min duration
Warning:  300s lag, 5min duration
Critical: 600s lag, 3min duration
```

**Alert Grouping and Routing:**
```yaml
# Configure in AlertManager
route:
  group_by: ['alertname', 'database', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'database-team'
  
  routes:
    # Critical alerts to PagerDuty
    - match:
        severity: critical
      receiver: 'pagerduty-critical'
      continue: true
    
    # Performance warnings to Slack
    - match:
        alert_type: performance
      receiver: 'slack-performance'
    
    # Maintenance alerts to email
    - match:
        maintenance: required
      receiver: 'email-dba'
```

### 4. Security Best Practices

**Encrypt PMM Communication:**
```bash
# Generate SSL certificates
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/pmm-agent/pmm-agent-key.pem \
  -out /etc/pmm-agent/pmm-agent-cert.pem

# Configure pmm-agent to use SSL
pmm-admin config \
  --server-url=https://admin:admin@your-pmm-server-ip:443 \
  --paths-ssl-cert-file=/etc/pmm-agent/pmm-agent-cert.pem \
  --paths-ssl-key-file=/etc/pmm-agent/pmm-agent-key.pem
```

**Restrict Monitoring User Permissions:**
```sql
-- Create read-only monitoring user with minimal privileges
CREATE ROLE pmm_monitor_readonly WITH LOGIN PASSWORD 'SecurePass123!';

-- Grant only necessary system catalog access
GRANT pg_monitor TO pmm_monitor_readonly;
GRANT CONNECT ON DATABASE your_db TO pmm_monitor_readonly;

-- Explicitly deny write operations
REVOKE CREATE ON DATABASE your_db FROM pmm_monitor_readonly;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM pmm_monitor_readonly;

-- Grant SELECT only on monitoring views
GRANT SELECT ON pg_stat_activity TO pmm_monitor_readonly;
GRANT SELECT ON pg_stat_statements TO pmm_monitor_readonly;
```

**Secure Credentials Storage:**
```bash
# Use environment variables instead of command-line passwords
export PMM_AGENT_POSTGRES_PASSWORD='SecurePassword123!'

# Add service without password in command
pmm-admin add postgresql \
  --username=pmm_monitor \
  --password="${PMM_AGENT_POSTGRES_PASSWORD}" \
  --host=localhost

# Or use PostgreSQL password file
echo "localhost:5432:*:pmm_monitor:SecurePassword123!" > ~/.pgpass
chmod 600 ~/.pgpass
```

### 5. Data Retention Configuration

**Configure VictoriaMetrics Retention:**
```bash
# Edit PMM Server configuration
docker exec -it pmm-server bash

# Edit VictoriaMetrics config
cat >> /etc/victoriametrics-promscrape.yml << EOF
global:
  scrape_interval: 30s
  external_labels:
    cluster: 'production'

# Retention settings
retention_period: 30d  # Keep 30 days of metrics
storage:
  max_disk_usage_percent: 80  # Alert when 80% full
EOF

# Restart VictoriaMetrics
supervisorctl restart victoriametrics
```

**Configure Query Analytics (QAN) Retention:**
```sql
-- In PostgreSQL, manage pg_stat_statements retention
-- Reset statistics periodically (e.g., monthly)
SELECT pg_stat_statements_reset();

-- Or automate via cron
SELECT cron.schedule('reset-pg-stat-statements', 
  '0 0 1 * *',  -- First day of each month
  'SELECT pg_stat_statements_reset()');
```

### 6. Monitoring the Monitor

**PMM Server Health Checks:**
```bash
# Check PMM Server metrics
curl -k https://your-pmm-server-ip/prometheus/api/v1/query?query=up

# Check VictoriaMetrics health
curl -k https://your-pmm-server-ip/victoriametrics/health

# Check disk usage
docker exec pmm-server df -h /srv

# Monitor PMM Server resource usage
docker stats pmm-server
```

**Create Self-Monitoring Alerts:**
```yaml
# Alert when PMM agent is down
- alert: PMM_Agent_Down
  expr: up{job="postgresql"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "PMM agent down on {{ $labels.instance }}"

# Alert when metrics collection is delayed
- alert: PMM_Scrape_Slow
  expr: scrape_duration_seconds > 30
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Slow metric scraping on {{ $labels.instance }}"

# Alert on PMM Server disk space
- alert: PMM_Server_Disk_Full
  expr: (node_filesystem_avail_bytes{mountpoint="/srv"} / 
         node_filesystem_size_bytes{mountpoint="/srv"}) * 100 < 20
  for: 10m
  labels:
    severity: critical
  annotations:
    summary: "PMM Server disk space low"
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Custom Queries Not Appearing

**Symptoms:**
- Metrics not visible in Grafana
- No errors in logs

**Diagnosis:**
```bash
# Check if queries are loaded
pmm-admin list

# Check pmm-agent logs
sudo journalctl -u pmm-agent -n 100 --no-pager

# Test metric endpoint
curl http://localhost:42001/metrics | grep pg_long_running

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('/usr/local/percona/pmm-agent/config/custom-queries/postgresql/pg17_monitoring.yaml'))"
```

**Solutions:**
```bash
# 1. Restart pmm-agent
sudo systemctl restart pmm-agent

# 2. Check file permissions
sudo chown pmm-agent:pmm-agent /usr/local/percona/pmm-agent/config/custom-queries/postgresql/*.yaml
sudo chmod 644 /usr/local/percona/pmm-agent/config/custom-queries/postgresql/*.yaml

# 3. Verify PostgreSQL connection
psql -U pmm_monitor -h localhost -d your_database -c "SELECT 1"

# 4. Check query execution manually
sudo -u postgres psql -d your_database -f /usr/local/percona/pmm-agent/config/custom-queries/postgresql/pg17_monitoring.yaml
```

#### Issue 2: High CPU Usage from Monitoring

**Symptoms:**
- pmm-agent consuming high CPU
- PostgreSQL load increased

**Diagnosis:**
```bash
# Identify expensive queries
SELECT queryid, calls, mean_exec_time, query 
FROM pg_stat_statements 
WHERE query LIKE '%pmm%' OR query LIKE '%pg_stat%'
ORDER BY mean_exec_time DESC 
LIMIT 10;

# Check scrape duration
curl http://localhost:42001/metrics | grep scrape_duration_seconds
```

**Solutions:**
```yaml
# 1. Increase scrape intervals
# Edit: /usr/local/percona/pmm-agent/config/pmm-agent.yaml
postgresql:
  scrape_interval: 60s  # Increase from 30s

custom_queries:
  scrape_interval: 120s  # Increase for expensive queries

# 2. Optimize expensive queries
# Add LIMIT clauses
# Remove unnecessary JOINs
# Use indexed columns in WHERE clauses

# 3. Disable non-critical queries temporarily
# Comment out in YAML file:
# pg_table_bloat:  # Expensive, run less frequently
#   query: |
```

#### Issue 3: Alert Not Firing

**Symptoms:**
- No notifications despite threshold breach
- Alert shows "Pending" state

**Diagnosis:**
```bash
# Check alert rule status
curl -k https://your-pmm-server-ip/prometheus/api/v1/rules | jq '.data.groups[].rules[] | select(.name | contains("PostgreSQL17"))'

# Test PromQL expression
curl -k "https://your-pmm-server-ip/prometheus/api/v1/query?query=pg_long_running_queries_duration_seconds"

# Check AlertManager
curl -k https://your-pmm-server-ip/alertmanager/api/v2/alerts

# View Grafana alert logs
docker exec pmm-server tail -f /srv/logs/grafana.log | grep -i alert
```

**Solutions:**
```bash
# 1. Verify alert evaluation interval
# Alert must breach threshold for "for" duration
# Example: for: 5m means 5 consecutive evaluations

# 2. Check notification channel
# Grafana → Alerting → Contact points
# Test notification

# 3. Review alert expression
# Ensure metric exists and has data
# Check label matchers are correct

# 4. Verify AlertManager configuration
docker exec pmm-server cat /etc/alertmanager.yml
```

#### Issue 4: Replication Lag Metrics Missing

**Symptoms:**
- No replication lag metrics
- Empty pg_stat_replication

**Diagnosis:**
```sql
-- Check replication status
SELECT * FROM pg_stat_replication;

-- Check replication slots
SELECT * FROM pg_replication_slots;

-- Verify standby is connected
SELECT client_addr, state, sync_state 
FROM pg_stat_replication;
```

**Solutions:**
```sql
-- 1. Ensure replication is configured
-- On primary, check postgresql.conf:
-- wal_level = replica
-- max_wal_senders = 10
-- max_replication_slots = 10

-- 2. Create replication slot if missing
SELECT pg_create_physical_replication_slot('replica_slot');

-- 3. Verify standby connection string
-- On standby, check recovery.conf or postgresql.auto.conf:
-- primary_conninfo = 'host=primary_host port=5432 user=repl_user'
-- primary_slot_name = 'replica_slot'

-- 4. Check network connectivity
-- From standby:
psql -h primary_host -U repl_user -c "SELECT 1"
```

#### Issue 5: VictoriaMetrics Running Out of Disk Space

**Symptoms:**
- PMM Server slow or unresponsive
- Disk usage at 90%+

**Diagnosis:**
```bash
# Check disk usage
docker exec pmm-server df -h /srv

# Check VictoriaMetrics data size
docker exec pmm-server du -sh /srv/victoriametrics

# Check oldest metrics
docker exec pmm-server ls -lht /srv/victoriametrics/data | tail
```

**Solutions:**
```bash
# 1. Reduce retention period
docker exec -it pmm-server bash
vi /etc/supervisord.d/victoriametrics.ini

# Change retention flag:
# --retentionPeriod=30d  # Reduce from default

# Restart VictoriaMetrics
supervisorctl restart victoriametrics

# 2. Manually delete old data
# Stop VictoriaMetrics first
supervisorctl stop victoriametrics

# Delete data older than 30 days
find /srv/victoriametrics/data -type f -mtime +30 -delete

# Restart
supervisorctl start victoriametrics

# 3. Increase disk space or move to larger volume
docker volume create pmm-data-large
# Migrate data and remount
```

#### Issue 6: pg_stat_statements Not Tracking Queries

**Symptoms:**
- Empty pg_stat_statements
- No query performance data

**Diagnosis:**
```sql
-- Check if extension exists
\dx pg_stat_statements

-- Check configuration
SHOW shared_preload_libraries;
SHOW pg_stat_statements.track;

-- Check if tracking
SELECT count(*) FROM pg_stat_statements;
```

**Solutions:**
```sql
-- 1. Ensure proper configuration
-- In postgresql.conf:
-- shared_preload_libraries = 'pg_stat_statements'
-- pg_stat_statements.track = all

-- 2. Restart PostgreSQL (required after config change)
-- sudo systemctl restart postgresql

-- 3. Create extension if missing
CREATE EXTENSION pg_stat_statements;

-- 4. Reset if corrupted
SELECT pg_stat_statements_reset();

-- 5. Increase max tracked queries if needed
ALTER SYSTEM SET pg_stat_statements.max = 10000;
SELECT pg_reload_conf();
```

### Debug Commands Reference

```bash
# PMM Agent Status
pmm-admin status
pmm-admin list
pmm-admin summary

# Check Metrics Endpoint
curl http://localhost:42001/metrics | grep -A 5 pg_long_running
curl http://localhost:42001/metrics | grep -c "^pg_"

# PMM Agent Logs
sudo journalctl -u pmm-agent -f
sudo journalctl -u pmm-agent --since "1 hour ago"
sudo tail -f /var/log/pmm-agent.log

# PostgreSQL Query Execution
sudo -u postgres psql -d your_database -c "SELECT * FROM pg_stat_activity WHERE state != 'idle'"

# Test Custom Query
sudo -u postgres psql -d your_database << 'EOF'
SELECT 
  datname as database,
  usename as username,
  pid,
  EXTRACT(EPOCH FROM (NOW() - query_start)) as duration_seconds
FROM pg_stat_activity
WHERE state != 'idle' AND query_start IS NOT NULL;
EOF

# VictoriaMetrics Query
curl -k "https://your-pmm-server-ip/prometheus/api/v1/query?query=pg_database_size_size_gb" | jq

# Check Alert Rules
curl -k https://your-pmm-server-ip/prometheus/api/v1/rules | jq '.data.groups[].rules[] | {name: .name, state: .state}'

# PMM Server Container Logs
docker logs pmm-server --tail 100
docker logs pmm-server -f | grep ERROR

# Restart Services
sudo systemctl restart pmm-agent
docker restart pmm-server
```

---

## Performance Benchmarking

### Baseline Collection

**Before implementing monitoring:**
```sql
-- Capture baseline performance
CREATE TABLE monitoring_baseline AS
SELECT 
  NOW() as timestamp,
  'pre_monitoring' as phase,
  (SELECT COUNT(*) FROM pg_stat_activity) as connections,
  (SELECT SUM(calls) FROM pg_stat_statements) as total_queries,
  (SELECT pg_database_size(current_database())) as db_size,
  (SELECT setting::int FROM pg_settings WHERE name = 'shared_buffers') as shared_buffers;
```

**After implementing monitoring:**
```sql
-- Compare performance impact
INSERT INTO monitoring_baseline
SELECT 
  NOW() as timestamp,
  'post_monitoring' as phase,
  (SELECT COUNT(*) FROM pg_stat_activity) as connections,
  (SELECT SUM(calls) FROM pg_stat_statements) as total_queries,
  (SELECT pg_database_size(current_database())) as db_size,
  (SELECT setting::int FROM pg_settings WHERE name = 'shared_buffers') as shared_buffers;

-- Analyze impact
SELECT 
  phase,
  connections,
  total_queries,
  pg_size_pretty(db_size) as database_size
FROM monitoring_baseline
ORDER BY timestamp;
```

---

## Summary

This comprehensive guide provides:

✅ **20 Custom Queries** optimized for PostgreSQL 17 and PMM3
✅ **Complete Alert Rules** with progressive severity levels
✅ **Grafana Dashboard** configurations with 22+ panels
✅ **Best Practices** for production deployments
✅ **Troubleshooting Guide** for common issues
✅ **Security Configurations** for enterprise environments

### Quick Start Checklist

- [ ] Install PMM3 Server
- [ ] Install pmm-agent on PostgreSQL server
- [ ] Configure PostgreSQL 17 with required extensions
- [ ] Create monitoring user with proper permissions
- [ ] Deploy custom query YAML files
- [ ] Add PostgreSQL instance to PMM
- [ ] Verify metrics collection
- [ ] Configure alert rules
- [ ] Create Grafana dashboards
- [ ] Test alerts and notifications
- [ ] Document your thresholds
- [ ] Schedule regular maintenance

### Next Steps

1. **Week 1**: Deploy monitoring and observe baseline metrics
2. **Week 2**: Fine-tune alert thresholds based on your environment
3. **Week 3**: Create custom dashboards for your specific needs
4. **Ongoing**: Review alerts weekly and adjust as needed

### Additional Resources

- **PMM3 Documentation**: https://docs.percona.com/percona-monitoring-and-management/
- **PostgreSQL 17 Release Notes**: https://www.postgresql.org/docs/17/release-17.html
- **PMM Community Forum**: https://forums.percona.com/c/percona-monitoring-and-management-pmm/
- **GitHub Issues**: https://github.com/percona/pmm

---

**Note**: Always test in a non-production environment first. Adjust configurations based on your specific workload and requirements.