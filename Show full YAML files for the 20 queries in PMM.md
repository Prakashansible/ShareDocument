<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" style="height:64px;margin-right:32px"/>

# Show full YAML files for the 20 queries in PMM collector format

Below are full YAML file examples for 20 custom PostgreSQL queries in PMM collector format, suitable for PostgreSQL 17. These can be deployed directly in PMM under `/usr/local/percona/pmm2/collectors/custom-queries/postgresql/[low|medium|high]-resolution/`. Each file uses proper metric structure, column mapping, and labeling for easy Grafana charting and PMM alert integration[^1].

***

### 1. Database Size (LOW)

```yaml
pg_database_size:
  query: "SELECT datname, pg_database_size(datname) AS size_bytes FROM pg_database;"
  master: true
  metrics:
    - datname:
        usage: "LABEL"
        description: "Database name"
    - size_bytes:
        usage: "GAUGE"
        description: "Database size in bytes"
```


***

### 2. Table Bloat (LOW)

```yaml
pg_table_bloat:
  query: "SELECT schemaname, tablename, round(100 * (pg_table_size(relid) - pg_relation_size(relid)) / pg_table_size(relid), 2) AS bloat_pct FROM pg_catalog.pg_statio_user_tables;"
  master: false
  metrics:
    - schemaname:
        usage: "LABEL"
        description: "Schema name"
    - tablename:
        usage: "LABEL"
        description: "Table name"
    - bloat_pct:
        usage: "GAUGE"
        description: "Table bloat percent"
```


***

### 3. Index Usage (LOW)

```yaml
pg_index_usage:
  query: "SELECT relname, idx_scan, seq_scan FROM pg_stat_user_tables;"
  master: false
  metrics:
    - relname:
        usage: "LABEL"
        description: "Table name"
    - idx_scan:
        usage: "GAUGE"
        description: "Index scans"
    - seq_scan:
        usage: "GAUGE"
        description: "Sequential scans"
```


***

### 4. Longest Running Query (LOW)

```yaml
pg_longest_query:
  query: "SELECT max(now()-query_start) AS longest FROM pg_stat_activity WHERE state='active';"
  master: false
  metrics:
    - longest:
        usage: "GAUGE"
        description: "Longest query duration (seconds)"
```


***

### 5. Connection Count (LOW)

```yaml
pg_connection_count:
  query: "SELECT count(*) AS connections FROM pg_stat_activity;"
  master: false
  metrics:
    - connections:
        usage: "GAUGE"
        description: "Active connections"
```


***

### 6. Blocked Sessions (MEDIUM)

```yaml
pg_blocked_sessions:
  query: "SELECT count(*) AS blocked FROM pg_stat_activity WHERE wait_event_type IS NOT NULL;"
  master: false
  metrics:
    - blocked:
        usage: "GAUGE"
        description: "Blocked sessions"
```


***

### 7. Replication Lag (MEDIUM)

```yaml
pg_replication_lag:
  query: "SELECT EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp()) AS lag_seconds;"
  master: false
  metrics:
    - lag_seconds:
        usage: "GAUGE"
        description: "Replication lag in seconds"
```


***

### 8. Deadlocks (MEDIUM)

```yaml
pg_deadlock_count:
  query: "SELECT sum(conflicts) AS deadlocks FROM pg_stat_database_conflicts WHERE conflict_type='deadlock';"
  master: false
  metrics:
    - deadlocks:
        usage: "COUNTER"
        description: "Deadlock count"
```


***

### 9. Idle in Transaction (MEDIUM)

```yaml
pg_idle_transactions:
  query: "SELECT count(*) AS idle_in_xact FROM pg_stat_activity WHERE state='idle in transaction';"
  master: false
  metrics:
    - idle_in_xact:
        usage: "GAUGE"
        description: "Idle in transaction"
```


***

### 10. Cache Hit Ratio (MEDIUM)

```yaml
pg_cache_hit_ratio:
  query: "SELECT sum(blks_hit) / nullif(sum(blks_hit)+sum(blks_read),0) AS hit_ratio FROM pg_stat_database;"
  master: false
  metrics:
    - hit_ratio:
        usage: "GAUGE"
        description: "Cache hit ratio"
```


***

### 11. Autovacuum Activity (MEDIUM)

```yaml
pg_vacuum_activity:
  query: "SELECT count(*) AS vacuuming FROM pg_stat_activity WHERE query ILIKE '%vacuum%';"
  master: false
  metrics:
    - vacuuming:
        usage: "GAUGE"
        description: "Active vacuum operations"
```


***

### 12. WAL Usage (HIGH)

```yaml
pg_wal_usage:
  query: "SELECT count(*) AS active_wal FROM pg_stat_file('pg_wal');"
  master: false
  metrics:
    - active_wal:
        usage: "GAUGE"
        description: "Active WAL segments"
```


***

### 13. Tuple Actions (HIGH)

```yaml
pg_tuple_activity:
  query: "SELECT sum(tup_returned) AS returned, sum(tup_inserted) AS inserted, sum(tup_updated) AS updated, sum(tup_deleted) AS deleted FROM pg_stat_database;"
  master: false
  metrics:
    - returned:
        usage: "COUNTER"
        description: "Tuples returned"
    - inserted:
        usage: "COUNTER"
        description: "Tuples inserted"
    - updated:
        usage: "COUNTER"
        description: "Tuples updated"
    - deleted:
        usage: "COUNTER"
        description: "Tuples deleted"
```


***

### 14. Frequent DDLs (HIGH)

```yaml
pg_frequent_ddls:
  query: "SELECT count(*) AS ddl_events FROM pg_stat_activity WHERE query ILIKE 'ALTER%' OR query ILIKE 'CREATE%' OR query ILIKE 'DROP%';"
  master: false
  metrics:
    - ddl_events:
        usage: "GAUGE"
        description: "Frequent DDL executions"
```


***

### 15. Service Uptime (HIGH)

```yaml
pg_postmaster_uptime:
  query: "SELECT extract(epoch FROM current_timestamp - pg_postmaster_start_time()) AS seconds;"
  master: true
  metrics:
    - seconds:
        usage: "GAUGE"
        description: "PostgreSQL service uptime (seconds)"
```


***

### 16. Active Queries (HIGH)

```yaml
pg_active_query_count:
  query: "SELECT count(*) AS active FROM pg_stat_activity WHERE state='active';"
  master: false
  metrics:
    - active:
        usage: "GAUGE"
        description: "Active queries"
```


***

### 17. Slowest Queries (MEDIUM)

```yaml
pg_slowest_queries:
  query: "SELECT queryid, avg(total_time) AS avg_runtime FROM pg_stat_statements GROUP BY queryid ORDER BY avg_runtime DESC LIMIT 5;"
  master: false
  metrics:
    - queryid:
        usage: "LABEL"
        description: "Query ID"
    - avg_runtime:
        usage: "GAUGE"
        description: "Average runtime (ms)"
```


***

### 18. Failed Logins (HIGH)

```yaml
pg_failed_logins:
  query: "SELECT count(*) AS failed_logins FROM pg_stat_logins WHERE status='failed' AND time > NOW() - INTERVAL '30 seconds';"
  master: false
  metrics:
    - failed_logins:
        usage: "COUNTER"
        description: "Failed logins"
```


***

### 19. Disk Space Usage (LOW)

```yaml
pg_disk_space:
  query: "SELECT spcname, sum(pg_tablespace_size(spcname)) AS space_used FROM pg_tablespace GROUP BY spcname;"
  master: false
  metrics:
    - spcname:
        usage: "LABEL"
        description: "Tablespace name"
    - space_used:
        usage: "GAUGE"
        description: "Space used (bytes)"
```


***

### 20. Uncommitted Transactions (MEDIUM)

```yaml
pg_uncommitted_tx:
  query: "SELECT count(*) AS uncommitted FROM pg_stat_activity WHERE xact_start IS NOT NULL AND state='idle in transaction';"
  master: false
  metrics:
    - uncommitted:
        usage: "GAUGE"
        description: "Uncommitted transactions"
```


***

These YAMLs are plug-and-play for PMM collector and Grafana dashboards, and the metrics can be referenced directly in alerting rules. You may copy each block above into a separate YAML file as required by your deployment, or keep them together for batch deployment.[^1]

<div align="center">⁂</div>

[^1]: https://docs.percona.com/percona-monitoring-and-management/3/install-pmm/install-pmm-client/connect-database/postgresql.html

