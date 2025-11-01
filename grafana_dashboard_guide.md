# Complete Guide: Viewing Custom Queries in PMM3 Grafana

## Table of Contents
1. [Quick Start - View Existing Metrics](#quick-start---view-existing-metrics)
2. [Method 1: Using Explore Feature](#method-1-using-explore-feature)
3. [Method 2: Creating Custom Dashboard from Scratch](#method-2-creating-custom-dashboard-from-scratch)
4. [Method 3: Import Pre-built Dashboard JSON](#method-3-import-pre-built-dashboard-json)
5. [Method 4: Add Panels to Existing Dashboards](#method-4-add-panels-to-existing-dashboards)
6. [Complete Dashboard Examples](#complete-dashboard-examples)
7. [Troubleshooting Visualization Issues](#troubleshooting-visualization-issues)

---

## Quick Start - View Existing Metrics

### Step 1: Access PMM Server Grafana

```bash
# Open browser and navigate to:
https://your-pmm-server-ip

# OR
https://your-pmm-server-ip:443

# Default credentials:
# Username: admin
# Password: admin (change on first login)
```

### Step 2: Verify Custom Metrics Are Being Collected

**Option A: Check Metrics Explorer**

1. Click on **Explore** (compass icon) in left sidebar
2. Select **VictoriaMetrics** as data source
3. In the **Metrics browser**, start typing: `pg_`
4. You should see all your custom metrics:
   ```
   pg_long_running_queries_duration_seconds
   pg_table_bloat_bloat_percentage
   pg_replication_lag_replay_lag_seconds
   pg_connection_saturation_usage_percentage
   ... (and 16 more)
   ```

**Option B: Use Browser Developer Tools**

1. Open browser DevTools (F12)
2. Go to **Network** tab
3. In Grafana, navigate to any dashboard
4. Filter network requests by: `api/datasources/proxy`
5. Check if custom metrics appear in responses

**Option C: Direct API Query**

```bash
# Query VictoriaMetrics directly
curl -k "https://admin:admin@your-pmm-server-ip/prometheus/api/v1/label/__name__/values" | jq '.data[] | select(startswith("pg_"))'

# Expected output:
# "pg_long_running_queries_duration_seconds"
# "pg_table_bloat_bloat_percentage"
# "pg_replication_lag_replay_lag_seconds"
# ... etc
```

---

## Method 1: Using Explore Feature

The **Explore** feature is the fastest way to view and test your custom metrics.

### Step-by-Step: Viewing Long Running Queries

1. **Open Explore**
   - Click **Explore** icon (compass) in left sidebar
   - Or press `Ctrl+Shift+E` (Windows/Linux) or `Cmd+Shift+E` (Mac)

2. **Select Data Source**
   - Ensure **VictoriaMetrics** is selected in top dropdown

3. **Build Query**
   - Click **Metrics browser** button
   - Start typing: `pg_long_running_queries`
   - Select: `pg_long_running_queries_duration_seconds`
   - Click **Use query**

4. **Add Filters (Optional)**
   - Click `+ Operations` → `Label filters`
   - Add filter: `database = "your_database"`
   - Or: `state = "active"`

5. **View Results**
   - Click **Run query** (or press `Shift+Enter`)
   - Switch between **Table** and **Graph** views
   - View in **Table** format for better readability

### Example Queries in Explore

**Query 1: View All Long Running Queries**
```promql
pg_long_running_queries_duration_seconds > 300
```

**Query 2: View Table Bloat Top 10**
```promql
topk(10, pg_table_bloat_bloat_percentage)
```

**Query 3: Check Replication Lag**
```promql
pg_replication_lag_replay_lag_seconds{application_name=~".*"}
```

**Query 4: Connection Pool Usage**
```promql
pg_connection_saturation_usage_percentage{state="total"}
```

**Query 5: Cache Hit Ratio by Database**
```promql
pg_cache_hit_ratio_cache_hit_ratio
```

### Using Table Format in Explore

For better viewing of custom queries:

1. After running query, click **Table** tab
2. Click **Transform data** → **Organize fields**
3. Select columns to display:
   - For long running queries: `database`, `username`, `pid`, `query_snippet`, `Value`
   - For table bloat: `schemaname`, `tablename`, `Value`
4. Click **Apply**

---

## Method 2: Creating Custom Dashboard from Scratch

### Step 1: Create New Dashboard

1. Click **Dashboards** (four squares icon) in left sidebar
2. Click **New** → **New Dashboard**
3. Click **Add visualization**

### Step 2: Configure Your First Panel - Long Running Queries

**Panel Title: Active Long Running Queries**

1. **Select Data Source**: VictoriaMetrics

2. **Enter Query** (Code mode):
   ```promql
   pg_long_running_queries_duration_seconds > 300
   ```

3. **Panel Type**: Change to **Table**

4. **Configure Transformations**:
   - Click **Transform data** tab
   - Add transformation: **Organize fields**
   - Reorder and select fields:
     - ✅ database
     - ✅ username
     - ✅ pid
     - ✅ application_name
     - ✅ state
     - ✅ query_snippet
     - ✅ Value (rename to "Duration (seconds)")
     - ❌ Time (hide)
     - ❌ __name__ (hide)
     - ❌ instance (hide if not needed)

5. **Format Value Column**:
   - Click **Value** column → **Field options**
   - Unit: `seconds (s)`
   - Decimals: `0`

6. **Add Conditional Formatting**:
   - Click **Value** → **Thresholds**
   - Add steps:
     - Base: Green
     - 600: Yellow
     - 1800: Orange
     - 3600: Red
   - Color mode: **Cell background**

7. **Panel Settings**:
   - Title: `Active Long Running Queries (>5 min)`
   - Description: `Queries running longer than 5 minutes. Investigate queries over 30 minutes.`

8. Click **Apply** to save panel

### Step 3: Add More Panels to Same Dashboard

**Panel 2: Table Bloat**

1. Click **Add** → **Visualization**
2. Query:
   ```promql
   topk(10, pg_table_bloat_bloat_percentage)
   ```
3. Visualization: **Bar gauge**
4. Orientation: **Horizontal**
5. Display mode: **Gradient**
6. Value: 
   - Unit: `Percent (0-100)`
   - Thresholds: 0=Green, 20=Yellow, 30=Red
7. Legend: `{{ schemaname }}.{{ tablename }}`
8. Title: `Top 10 Tables by Bloat Percentage`

**Panel 3: Replication Lag**

1. Add new visualization
2. Query:
   ```promql
   pg_replication_lag_replay_lag_seconds
   ```
3. Visualization: **Time series**
4. Legend: `{{ application_name }} ({{ slot_name }})`
5. Y-axis:
   - Unit: `seconds (s)`
   - Min: 0
6. Thresholds:
   - Add threshold line at 300 (5 min) - Yellow
   - Add threshold line at 600 (10 min) - Red
7. Title: `Replication Lag Timeline`

**Panel 4: Connection Pool Status**

1. Add new visualization
2. Query:
   ```promql
   pg_connection_saturation_usage_percentage{state="total"}
   ```
3. Visualization: **Gauge**
4. Options:
   - Min: 0
   - Max: 100
   - Unit: `Percent (0-100)`
5. Thresholds:
   - 0-70: Green
   - 70-85: Yellow
   - 85-95: Orange
   - 95-100: Red
6. Title: `Connection Pool Utilization`

**Panel 5: Cache Hit Ratio**

1. Add new visualization
2. Query:
   ```promql
   pg_cache_hit_ratio_cache_hit_ratio
   ```
3. Visualization: **Stat**
4. Graph mode: **None**
5. Text mode: **Value and name**
6. Color mode: **Background**
7. Unit: `Percent (0-100)`
8. Thresholds:
   - 0-85: Red
   - 85-95: Yellow
   - 95-100: Green
9. Repeat: Select variable `database` (after creating it)
10. Title: `Cache Hit Ratio - {{ database }}`

### Step 4: Organize Dashboard Layout

1. **Resize Panels**: Drag corners to resize
2. **Move Panels**: Drag from title bar
3. **Add Rows**: Click **Add** → **Row**
   - Row 1: "Overview Metrics"
   - Row 2: "Query Performance"
   - Row 3: "Replication & WAL"
   - Row 4: "Maintenance & Bloat"

4. **Suggested Layout**:
   ```
   Row 1: Overview (4 panels across)
   ├─ Connection Pool (6w x 8h)
   ├─ Cache Hit Ratio (6w x 8h)
   ├─ Database Size (6w x 8h)
   └─ Replication Lag (6w x 8h)

   Row 2: Query Performance
   ├─ Long Running Queries (24w x 10h) - Full width table
   └─ Top Queries by Time (24w x 10h) - Full width table

   Row 3: Replication & WAL
   ├─ Replication Lag Graph (12w x 8h)
   ├─ WAL Generation (12w x 8h)

   Row 4: Maintenance
   ├─ Table Bloat (12w x 10h)
   ├─ Vacuum Progress (12w x 10h)
   ```

### Step 5: Add Dashboard Variables

Variables allow filtering across all panels.

1. Click **Dashboard settings** (gear icon) at top
2. Select **Variables** tab
3. Click **Add variable**

**Variable 1: Instance**
```yaml
Name: instance
Type: Query
Label: PostgreSQL Instance
Data source: VictoriaMetrics
Query: label_values(pg_database_size_size_bytes, instance)
Regex: .*
Multi-value: ✅ Enabled
Include All option: ✅ Enabled
```

**Variable 2: Database**
```yaml
Name: database
Type: Query
Label: Database
Data source: VictoriaMetrics
Query: label_values(pg_database_size_size_bytes{instance="$instance"}, database)
Multi-value: ✅ Enabled
Include All option: ✅ Enabled
```

**Variable 3: Schema**
```yaml
Name: schema
Type: Query
Label: Schema
Data source: VictoriaMetrics
Query: label_values(pg_table_bloat_bloat_percentage{database="$database"}, schemaname)
Multi-value: ✅ Enabled
Include All option: ✅ Enabled
```

4. Click **Apply** and **Save dashboard**

### Step 6: Use Variables in Queries

Update your queries to use variables:

**Long Running Queries with filter:**
```promql
pg_long_running_queries_duration_seconds{instance=~"$instance", database=~"$database"} > 300
```

**Table Bloat with filter:**
```promql
topk(10, pg_table_bloat_bloat_percentage{instance=~"$instance", database=~"$database", schemaname=~"$schema"})
```

### Step 7: Save Dashboard

1. Click **Save dashboard** (disk icon) at top right
2. Enter name: `PostgreSQL 17 - Custom Monitoring`
3. Add description
4. Select folder (or create new)
5. Click **Save**

---

## Method 3: Import Pre-built Dashboard JSON

### Step 1: Create Complete Dashboard JSON

Save this as `pg17_custom_dashboard.json`:

```json
{
  "dashboard": {
    "title": "PostgreSQL 17 - Custom Queries Dashboard",
    "uid": "pg17-custom-queries",
    "tags": ["postgresql", "postgresql17", "custom"],
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
          "datasource": {
            "type": "prometheus",
            "uid": "victoria-metrics-uid"
          },
          "query": "label_values(pg_database_size_size_bytes, instance)",
          "multi": true,
          "includeAll": true,
          "current": {
            "selected": true,
            "text": "All",
            "value": "$__all"
          }
        },
        {
          "name": "database",
          "type": "query",
          "datasource": {
            "type": "prometheus",
            "uid": "victoria-metrics-uid"
          },
          "query": "label_values(pg_database_size_size_bytes{instance=~\"$instance\"}, database)",
          "multi": true,
          "includeAll": true
        }
      ]
    },
    "panels": [
      {
        "id": 1,
        "title": "Connection Pool Utilization",
        "type": "gauge",
        "datasource": {
          "type": "prometheus",
          "uid": "victoria-metrics-uid"
        },
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
        "targets": [
          {
            "expr": "pg_connection_saturation_usage_percentage{instance=~\"$instance\", state=\"total\"}",
            "refId": "A"
          }
        ],
        "options": {
          "orientation": "auto",
          "showThresholdLabels": false,
          "showThresholdMarkers": true
        },
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 70, "color": "yellow"},
                {"value": 85, "color": "orange"},
                {"value": 95, "color": "red"}
              ]
            }
          }
        }
      },
      {
        "id": 2,
        "title": "Cache Hit Ratio by Database",
        "type": "stat",
        "datasource": {
          "type": "prometheus",
          "uid": "victoria-metrics-uid"
        },
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
        "targets": [
          {
            "expr": "pg_cache_hit_ratio_cache_hit_ratio{instance=~\"$instance\", database=~\"$database\"}",
            "refId": "A",
            "legendFormat": "{{ database }}"
          }
        ],
        "options": {
          "colorMode": "background",
          "graphMode": "none",
          "textMode": "value_and_name"
        },
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": 0, "color": "red"},
                {"value": 85, "color": "yellow"},
                {"value": 95, "color": "green"}
              ]
            }
          }
        }
      },
      {
        "id": 3,
        "title": "Database Size",
        "type": "stat",
        "datasource": {
          "type": "prometheus",
          "uid": "victoria-metrics-uid"
        },
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
        "targets": [
          {
            "expr": "pg_database_size_size_gb{instance=~\"$instance\", database=~\"$database\"}",
            "refId": "A",
            "legendFormat": "{{ database }}"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "decgbytes",
            "color": {"mode": "thresholds"},
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 500, "color": "yellow"},
                {"value": 1000, "color": "orange"}
              ]
            }
          }
        }
      },
      {
        "id": 4,
        "title": "Replication Lag",
        "type": "stat",
        "datasource": {
          "type": "prometheus",
          "uid": "victoria-metrics-uid"
        },
        "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
        "targets": [
          {
            "expr": "max(pg_replication_lag_replay_lag_seconds{instance=~\"$instance\"})",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "color": {"mode": "thresholds"},
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 60, "color": "yellow"},
                {"value": 300, "color": "red"}
              ]
            }
          }
        }
      },
      {
        "id": 5,
        "title": "Long Running Queries (>5 minutes)",
        "type": "table",
        "datasource": {
          "type": "prometheus",
          "uid": "victoria-metrics-uid"
        },
        "gridPos": {"h": 12, "w": 24, "x": 0, "y": 8},
        "targets": [
          {
            "expr": "pg_long_running_queries_duration_seconds{instance=~\"$instance\", database=~\"$database\"} > 300",
            "refId": "A",
            "format": "table",
            "instant": true
          }
        ],
        "transformations": [
          {
            "id": "organize",
            "options": {
              "excludeByName": {
                "Time": true,
                "__name__": true,
                "backend_type": true,
                "instance": true,
                "job": true
              },
              "indexByName": {
                "database": 0,
                "username": 1,
                "pid": 2,
                "application_name": 3,
                "state": 4,
                "query_snippet": 5,
                "Value": 6
              },
              "renameByName": {
                "Value": "Duration (seconds)"
              }
            }
          }
        ],
        "fieldConfig": {
          "defaults": {
            "custom": {
              "align": "auto",
              "displayMode": "auto"
            }
          },
          "overrides": [
            {
              "matcher": {"id": "byName", "options": "Duration (seconds)"},
              "properties": [
                {
                  "id": "unit",
                  "value": "s"
                },
                {
                  "id": "custom.displayMode",
                  "value": "color-background"
                },
                {
                  "id": "thresholds",
                  "value": {
                    "mode": "absolute",
                    "steps": [
                      {"value": 0, "color": "green"},
                      {"value": 600, "color": "yellow"},
                      {"value": 1800, "color": "orange"},
                      {"value": 3600, "color": "red"}
                    ]
                  }
                }
              ]
            }
          ]
        }
      },
      {
        "id": 6,
        "title": "Table Bloat - Top 10",
        "type": "bargauge",
        "datasource": {
          "type": "prometheus",
          "uid": "victoria-metrics-uid"
        },
        "gridPos": {"h": 10, "w": 12, "x": 0, "y": 20},
        "targets": [
          {
            "expr": "topk(10, pg_table_bloat_bloat_percentage{instance=~\"$instance\", database=~\"$database\"})",
            "refId": "A",
            "legendFormat": "{{ schemaname }}.{{ tablename }}"
          }
        ],
        "options": {
          "orientation": "horizontal",
          "displayMode": "gradient",
          "showUnfilled": true
        },
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "min": 0,
            "max": 100,
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": 0, "color": "green"},
                {"value": 20, "color": "yellow"},
                {"value": 30, "color": "red"}
              ]
            }
          }
        }
      },
      {
        "id": 7,
        "title": "Replication Lag Timeline",
        "type": "timeseries",
        "datasource": {
          "type": "prometheus",
          "uid": "victoria-metrics-uid"
        },
        "gridPos": {"h": 10, "w": 12, "x": 12, "y": 20},
        "targets": [
          {
            "expr": "pg_replication_lag_replay_lag_seconds{instance=~\"$instance\"}",
            "refId": "A",
            "legendFormat": "{{ application_name }} ({{ slot_name }})"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "s",
            "min": 0,
            "color": {"mode": "palette-classic"},
            "custom": {
              "axisPlacement": "auto",
              "drawStyle": "line",
              "fillOpacity": 10,
              "pointSize": 5,
              "showPoints": "auto",
              "thresholdsStyle": {"mode": "line"}
            },
            "thresholds": {
              "mode": "absolute",
              "steps": [
                {"value": 0, "color": "transparent"},
                {"value": 300, "color": "red"}
              ]
            }
          }
        }
      }
    ]
  }
}
```

### Step 2: Import Dashboard

1. **Via Grafana UI**:
   - Go to **Dashboards** → **New** → **Import**
   - Click **Upload JSON file**
   - Select your `pg17_custom_dashboard.json`
   - Click **Load**
   - Select data source: **VictoriaMetrics**
   - Click **Import**

2. **Via API**:
   ```bash
   # Get API key first
   # In Grafana: Profile → API Keys → Add API key
   
   curl -X POST \
     -H "Authorization: Bearer YOUR_API_KEY" \
     -H "Content-Type: application/json" \
     -d @pg17_custom_dashboard.json \
     https://your-pmm-server-ip/api/dashboards/db
   ```

3. **Via PMM Server Container**:
   ```bash
   # Copy JSON to container
   docker cp pg17_custom_dashboard.json pmm-server:/tmp/

   # Import via provisioning
   docker exec -it pmm-server bash
   cp /tmp/pg17_custom_dashboard.json /etc/grafana/provisioning/dashboards/
   supervisorctl restart grafana
   ```

---

## Method 4: Add Panels to Existing Dashboards

### Add Custom Query Panel to PostgreSQL Instance Summary

1. Navigate to existing dashboard:
   - **Dashboards** → **PMM** → **PostgreSQL Instance Summary**

2. Click **Edit** (pencil icon) at top right

3. Click **Add** → **Visualization**

4. Create your panel (e.g., Long Running Queries)

5. Click **Apply**

6. Click **Save dashboard**
   - Check **Save current time range**
   - Add note: "Added custom long running queries panel"
   - Click **Save**

---

## Complete Dashboard Examples

### Dashboard 1: Query Performance Monitoring

**Purpose**: Monitor query execution and performance

**Panels**:
1. Long Running Queries (Table)
2. Top 20 Queries by Total Time (Table)
3. Query Execution Time Trend (Graph)
4. Queries Writing Temp Files (Table)
5. Sequential Scans on Large Tables (Table)

**PromQL Queries**:
```promql
# Panel 1
pg_long_running_queries_duration_seconds{instance=~"$instance"} > 300

# Panel 2
topk(20, pg_top_queries_total_time_ms{instance=~"$instance", database=~"$database"})

# Panel 3
avg(pg_top_queries_mean_time_ms{instance=~"$instance"}) by (database)

# Panel 4
pg_top_queries_temp_blks_written{instance=~"$instance"} > 0

# Panel 5
pg_sequential_scans_seq_scan{instance=~"$instance", database=~"$database"} > 100
```

### Dashboard 2: Maintenance & Health

**Purpose**: Monitor vacuum, bloat, and maintenance tasks

**Panels**:
1. Table Bloat Top 10 (Bar Gauge)
2. Vacuum Progress (Table)
3. Autovacuum Activity (Graph)
4. Tables Not Vacuumed (Table)
5. Transaction Wraparound Risk (Gauge)

**PromQL Queries**:
```promql
# Panel 1
topk(10, pg_table_bloat_bloat_percentage{instance=~"$instance"})

# Panel 2
pg_vacuum_progress_progress_percentage{instance=~"$instance"}

# Panel 3
rate(pg_autovacuum_activity_autovacuum_count{instance=~"$instance"}[1h])

# Panel 4
pg_autovacuum_activity_seconds_since_last_vacuum{instance=~"$instance"} > 86400

# Panel 5
max(pg_transaction_wraparound_wraparound_risk_percentage{instance=~"$instance"})
```

### Dashboard 3: Replication Monitoring

**Purpose**: Monitor replication lag and WAL

**Panels**:
1. Replication Lag (seconds) - Time Series
2. Replication Lag (MB) - Time Series
3. WAL Generation Rate (Graph)
4. WAL File Count (Stat)
5. Archive Status (Table)

**PromQL Queries**:
```promql
# Panel 1
pg_replication_lag_replay_lag_seconds{instance=~"$instance"}

# Panel 2
pg_replication_lag_replay_lag_mb{instance=~"$instance"}

# Panel 3
rate(pg_wal_generation_total_wal_size_mb{instance=~"$instance"}[5m])

# Panel 4
pg_wal_generation_wal_file_count{instance=~"$instance"}

# Panel 5
pg_archive_status_wal_files_ready{instance=~"$instance"}
```

---

## Troubleshooting Visualization Issues

### Issue 1: "No Data" in Panels

**Symptoms**: Panels show "No data" even though metrics exist

**Solutions**:

1. **Check Time Range**:
   ```
   - Click time range picker (top right)
   - Try "Last 5 minutes" or "Last 15 minutes"
   - Click "Refresh dashboard" icon
   ```

2. **Verify Query Syntax**:
   ```promql
   # Test in Explore first
   # Remove instance/database filters temporarily
   pg_long_running_queries_duration_seconds
   ```

3. **Check Data Source**:
   ```
   - Panel Edit → Query tab
   - Verify "VictoriaMetrics" is selected
   - Try switching to "Prometheus" if available
   ```

4. **Verify Metrics Exist**:
   ```bash
   # Via API
   curl -k "https://admin:admin@your-pmm-server-ip/prometheus/api/v1/query?query=pg_long_running_queries_duration_seconds" | jq

   # Should return data, not empty array
   ```

### Issue 2: Incorrect Values or Labels

**Symptoms**: Values don't match what's in database

**Solutions**:

1. **Check Label Filters**:
   ```promql
   # Make sure labels match your setup
   pg_cache_hit_ratio_cache_hit_ratio{instance="your-instance-name"}
   
   # Find available labels
   {__name__=~"pg_cache_hit_ratio.*"}
   ```

2. **Use `instant` for Current Values**:
   ```
   In Query Options:
   - Type: Instant (for current values)
   - Type: Range (for time series)
   ```

3. **Verify Units**:
   ```
   Field Config → Standard Options → Unit
   - Duration in seconds: "seconds (s)"
   - Percentages: "percent (0-100)"
   - Bytes: "bytes (IEC)" or "decbytes"
   ```

### Issue 3: Variables Not Working

**Symptoms**: Dashboard variables show "No options found"

**Solutions**:

1. **Fix Query Syntax**:
   ```promql
   # Wrong
   label_values(database)
   
   # Correct
   label_values(pg_database_size_size_bytes, database)
   ```

2. **Check Data Source in Variable**:
   ```
   Dashboard Settings → Variables → [variable name]
   - Data source: Must be "VictoriaMetrics"
   ```

3. **Test Variable Query in Explore**:
   ```promql
   # Test this query in Explore
   label_values(pg_database_size_size_bytes, database)
   ```

### Issue 4: Table Shows Too Many Columns

**Solution**: Use Transformations

1. Click panel **Edit**
2. Go to **Transform data** tab
3. Add transformation: **Organize fields**
4. Hide unwanted fields:
   - Time
   - __name__
   - instance (if not needed)
   - job
5. Rename fields as needed
6. Click **Apply**

### Issue 5: Performance Issues (Dashboard Slow)

**Solutions**:

1. **Limit Query Results**:
   ```promql
   # Use topk/bottomk
   topk(20, pg_top_queries_total_time_ms)
   
   # Add thresholds
   pg_long_running_queries_duration_seconds > 300
   ```

2. **Increase Refresh