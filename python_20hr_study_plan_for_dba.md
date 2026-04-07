# Python for PostgreSQL DBAs — 20-Hour Accelerated Study Plan

**Target Audience:** Database Administrators with PostgreSQL/Infrastructure background  
**Goal:** Learn the 20% of Python that drives 80% of real-world DBA automation  
**Environment:** AlmaLinux 8/9, PostgreSQL 15/16/17/18  
**Paths:** `/apps/pgsql_data/<ver>`, `/apps/pgsql_archives/`, `/apps/logs`, `/apps/backups`

---

## Session 1 (Hours 1–2): Python Fundamentals — Variables, Data Types, and Control Flow

### Core Concept

Variables, strings, integers, floats, booleans, `if/elif/else`, `for`/`while` loops, and f-strings. These are the building blocks you will use in every single script you write.

### Free Resources

1. **Official Python Tutorial — Sections 3–5:** <https://docs.python.org/3/tutorial/>
2. **Corey Schafer YouTube — First 3 videos of "Python Programming Beginner Tutorials"**

### Key Concepts with Examples

#### Variables and Data Types

```python
# Variables — no type declaration needed (Python is dynamically typed)
pg_version = 16                        # int
pg_host = "192.168.1.10"              # str (string)
pg_port = 5432                         # int
is_primary = True                      # bool (boolean)
replication_lag_mb = 12.5              # float

# Check the type of any variable
print(type(pg_version))    # <class 'int'>
print(type(pg_host))       # <class 'str'>
print(type(is_primary))    # <class 'bool'>
```

#### Strings and f-strings (Formatted String Literals)

```python
# f-strings — the most important string feature for DBA work
# Prefix a string with 'f' and put variables inside {curly braces}

pg_version = 16
data_dir = f"/apps/pgsql_data/{pg_version}"
archive_dir = "/apps/pgsql_archives/"
log_dir = "/apps/logs"

print(f"Data Directory:    {data_dir}")
print(f"Archive Directory: {archive_dir}")
print(f"Log Directory:     {log_dir}")

# Output:
# Data Directory:    /apps/pgsql_data/16
# Archive Directory: /apps/pgsql_archives/
# Log Directory:     /apps/logs

# f-strings can contain expressions
db_size_bytes = 107374182400
print(f"Database size: {db_size_bytes / 1024 / 1024 / 1024:.2f} GB")
# Output: Database size: 100.00 GB

# Multi-line strings (triple quotes)
config_summary = f"""
PostgreSQL Configuration Summary
=================================
Version:   {pg_version}
Data Dir:  {data_dir}
Host:      {pg_host}
Port:      {pg_port}
Primary:   {is_primary}
"""
print(config_summary)
```

#### String Methods You'll Use Daily

```python
log_line = "2025-11-18 10:30:45 UTC [12345] ERROR:  relation \"important_table\" does not exist"

# Check if a string contains something
if "ERROR" in log_line:
    print("Found an error!")

# Split a string into parts
parts = log_line.split()
timestamp = f"{parts[0]} {parts[1]}"
print(f"Timestamp: {timestamp}")    # 2025-11-18 10:30:45

# Strip whitespace
user_input = "  pg16db  "
stanza = user_input.strip()        # "pg16db"

# Replace
new_line = log_line.replace("ERROR", "CRITICAL")

# startswith / endswith
wal_file = "000000010000000000000003"
if wal_file.startswith("00000001"):
    print(f"Timeline 1 WAL file: {wal_file}")

# Upper / Lower
severity = "error"
print(severity.upper())    # "ERROR"

# Join — combine a list into a string
servers = ["192.168.1.10", "192.168.1.20", "192.168.1.30"]
print(", ".join(servers))  # "192.168.1.10, 192.168.1.20, 192.168.1.30"
```

#### Comparison and Logical Operators

```python
# Comparison operators: ==, !=, <, >, <=, >=
pg_version = 16
print(pg_version == 16)    # True
print(pg_version != 15)    # True
print(pg_version >= 15)    # True

# Logical operators: and, or, not
is_primary = True
is_running = True
lag_mb = 0.5

if is_primary and is_running:
    print("Primary server is online")

if not is_primary and lag_mb > 10:
    print("WARNING: Standby has significant replication lag!")

# 'in' operator — check membership
supported_versions = [15, 16, 17, 18]
if pg_version in supported_versions:
    print(f"PG {pg_version} is supported")
```

#### if / elif / else — Conditional Logic

```python
pg_version = 16

# Basic if/elif/else
if pg_version >= 18:
    print("PG 18: Data checksums ON by default")
    print("  Streaming replication with slots recommended")
elif pg_version >= 16:
    print(f"PG {pg_version}: Streaming replication with slots")
    print("  Enable data checksums manually: pg_checksums --enable")
elif pg_version >= 13:
    print(f"PG {pg_version}: Log-shipping replication")
    print("  Set archive_timeout = 300")
else:
    print(f"PG {pg_version}: Consider upgrading — EOL version")

# Practical example: determine backup strategy
db_size_gb = 750

if db_size_gb < 50:
    backup_type = "full"
    schedule = "daily"
elif db_size_gb < 500:
    backup_type = "full + differential"
    schedule = "weekly full + daily diff"
else:
    backup_type = "full + incremental"
    schedule = "weekly full + daily incr"

print(f"Database size: {db_size_gb} GB")
print(f"Recommended: {backup_type}")
print(f"Schedule: {schedule}")
```

#### for Loops

```python
# Loop through a list
pg_versions = [15, 16, 17, 18]

for ver in pg_versions:
    data_dir = f"/apps/pgsql_data/{ver}"
    print(f"PG {ver}: {data_dir}")

# Output:
# PG 15: /apps/pgsql_data/15
# PG 16: /apps/pgsql_data/16
# PG 17: /apps/pgsql_data/17
# PG 18: /apps/pgsql_data/18

# Loop with index using enumerate()
servers = ["192.168.1.10", "192.168.1.20", "192.168.1.30"]
for i, server in enumerate(servers, start=1):
    print(f"Server {i}: {server}")

# range() — generate a sequence of numbers
for i in range(1, 6):
    print(f"Backup attempt {i}/5")

# Loop through a string
wal_file = "000000010000000000000003"
timeline = wal_file[:8]    # First 8 characters: "00000001"
print(f"Timeline: {int(timeline)}")  # Timeline: 1

# Practical: check multiple ports
ports_to_check = [5432, 5433, 6432]
for port in ports_to_check:
    print(f"Checking port {port}...")
```

#### while Loops

```python
# while loop — repeat until a condition is false
retry_count = 0
max_retries = 5

while retry_count < max_retries:
    retry_count += 1
    print(f"Connection attempt {retry_count}/{max_retries}...")

    # Simulate success on attempt 3
    if retry_count == 3:
        print("Connected successfully!")
        break   # Exit the loop immediately
else:
    # This block runs ONLY if the while loop completed without 'break'
    print("All retries exhausted — connection failed!")

# 'continue' — skip to next iteration
log_lines = [
    "LOG: checkpoint starting",
    "ERROR: relation does not exist",
    "LOG: checkpoint complete",
    "FATAL: password authentication failed",
    "LOG: connection received",
]

print("=== Errors Only ===")
for line in log_lines:
    if line.startswith("LOG:"):
        continue    # Skip non-error lines
    print(line)
# Output:
# ERROR: relation does not exist
# FATAL: password authentication failed
```

### Active Review (15 minutes)

Write a script called `pg_version_check.py` that:

```python
#!/usr/bin/env python3
"""
Session 1 Review Exercise: pg_version_check.py
"""

# 1. Define your supported PostgreSQL versions
supported = [15, 16, 17, 18]

# 2. Ask the user for a version number
user_input = input("Enter PostgreSQL version number: ")
version = int(user_input)

# 3. Check if it's supported and print the appropriate paths
if version in supported:
    print(f"\nPostgreSQL {version} is SUPPORTED")
    print(f"  Data Directory:    /apps/pgsql_data/{version}")
    print(f"  WAL Archive:       /apps/pgsql_archives/")
    print(f"  Logs:              /apps/logs")
    print(f"  Backups:           /apps/backups")

    # 4. Determine replication type
    if version >= 16:
        print(f"  Replication:       Streaming with Physical Slots")
    else:
        print(f"  Replication:       Log-Shipping (archive-based)")

    # 5. PG 18 specific note
    if version >= 18:
        print(f"  Checksums:         ON by default (PG 18+)")
    else:
        print(f"  Checksums:         Enable manually with pg_checksums --enable")
else:
    print(f"\nPostgreSQL {version} is NOT in the supported list: {supported}")
    print("Consider upgrading to a supported version.")
```

---

## Session 2 (Hours 3–4): Data Structures — Lists, Dictionaries, Tuples, and Sets

### Core Concept

Dictionaries and lists are the workhorses of Python. Every config file, JSON response, database row, and monitoring output maps to these structures. Spend 70% of your time on dicts.

### Free Resources

1. **Official Python Tutorial — Section 5 (Data Structures):** <https://docs.python.org/3/tutorial/datastructures.html>
2. **Real Python — "Dictionaries in Python":** <https://realpython.com/python-dicts/>

### Key Concepts with Examples

#### Lists — Ordered, Mutable Collections

```python
# Creating lists
servers = ["192.168.1.10", "192.168.1.20", "192.168.1.30"]
pg_versions = [15, 16, 17, 18]
empty_list = []

# Accessing elements (0-indexed)
primary = servers[0]         # "192.168.1.10"
last_server = servers[-1]    # "192.168.1.30" (negative = from end)

# Slicing — get a range of elements
first_two = servers[:2]      # ["192.168.1.10", "192.168.1.20"]
modern_pg = pg_versions[1:]  # [16, 17, 18]

# Modifying lists
servers.append("192.168.1.40")        # Add to end
servers.insert(0, "192.168.1.5")      # Insert at position 0
servers.remove("192.168.1.30")        # Remove by value
popped = servers.pop()                 # Remove and return last item

# List length
print(f"Total servers: {len(servers)}")

# Check if item exists
if "192.168.1.10" in servers:
    print("Primary server is in the list")

# Sort
servers.sort()                # Sort in place (modifies the list)
sorted_copy = sorted(servers) # Returns a NEW sorted list (original unchanged)

# List comprehension — create a new list by transforming another
# This is VERY Pythonic and you'll use it constantly
data_dirs = [f"/apps/pgsql_data/{v}" for v in pg_versions]
print(data_dirs)
# ['/apps/pgsql_data/15', '/apps/pgsql_data/16', '/apps/pgsql_data/17', '/apps/pgsql_data/18']

# Filter with list comprehension
modern_versions = [v for v in pg_versions if v >= 16]
print(modern_versions)  # [16, 17, 18]
```

#### Dictionaries — Key-Value Pairs (Most Important Data Structure)

```python
# Creating dictionaries
server_config = {
    "host": "192.168.1.10",
    "port": 5432,
    "version": 16,
    "is_primary": True,
    "data_dir": "/apps/pgsql_data/16",
}

# Accessing values
print(server_config["host"])        # "192.168.1.10"
print(server_config["port"])        # 5432

# Safe access with .get() — returns None (or default) if key doesn't exist
max_conn = server_config.get("max_connections")        # None (key missing)
max_conn = server_config.get("max_connections", 100)   # 100 (default value)

# Adding / updating values
server_config["max_connections"] = 200
server_config["archive_dir"] = "/apps/pgsql_archives/"

# Remove a key
del server_config["is_primary"]
# OR: value = server_config.pop("is_primary")  # removes and returns value

# Check if key exists
if "host" in server_config:
    print(f"Host: {server_config['host']}")

# Loop through a dictionary
print("\n=== Server Configuration ===")
for key, value in server_config.items():
    print(f"  {key}: {value}")

# Get just keys or just values
print(list(server_config.keys()))
print(list(server_config.values()))

# Nested dictionaries — extremely common for configs
cluster_config = {
    "pg16db": {
        "pg_path": "/apps/pgsql_data/16",
        "archive": "/apps/pgsql_archives/",
        "backup": "/apps/backups",
        "replication": "streaming",
        "servers": {
            "primary": "192.168.1.10",
            "standby": "192.168.1.20",
        }
    },
    "pg17db": {
        "pg_path": "/apps/pgsql_data/17",
        "archive": "/apps/pgsql_archives/",
        "backup": "/apps/backups",
        "replication": "streaming",
        "servers": {
            "primary": "192.168.1.30",
            "standby": "192.168.1.40",
        }
    },
}

# Access nested values
primary_16 = cluster_config["pg16db"]["servers"]["primary"]
print(f"PG 16 primary: {primary_16}")

# Loop through nested dicts
for stanza, config in cluster_config.items():
    print(f"\nStanza: {stanza}")
    print(f"  Path:        {config['pg_path']}")
    print(f"  Replication: {config['replication']}")
    print(f"  Primary:     {config['servers']['primary']}")
    print(f"  Standby:     {config['servers']['standby']}")

# Dictionary comprehension
versions = [15, 16, 17, 18]
version_paths = {v: f"/apps/pgsql_data/{v}" for v in versions}
print(version_paths)
# {15: '/apps/pgsql_data/15', 16: '/apps/pgsql_data/16', ...}
```

#### Tuples — Immutable Ordered Collections

```python
# Tuples cannot be changed after creation — good for fixed data
server_pair = ("192.168.1.10", "192.168.1.20")   # (primary, standby)
pg_credentials = ("replicator", "secure_password", 5432)

# Unpacking — assign multiple variables at once
primary, standby = server_pair
print(f"Primary: {primary}, Standby: {standby}")

user, password, port = pg_credentials

# Tuples are often returned by functions
# (You'll see this with database query results)
```

#### Sets — Unique Collections

```python
# Sets automatically remove duplicates
active_connections = {"app_user", "replicator", "postgres", "app_user", "app_user"}
print(active_connections)  # {'app_user', 'replicator', 'postgres'}

# Set operations — useful for comparing server lists
prod_servers = {"db1", "db2", "db3", "db4"}
monitored_servers = {"db1", "db2", "db5"}

unmonitored = prod_servers - monitored_servers
print(f"Not monitored: {unmonitored}")     # {'db3', 'db4'}

in_both = prod_servers & monitored_servers
print(f"In both: {in_both}")               # {'db1', 'db2'}

all_servers = prod_servers | monitored_servers
print(f"All known: {all_servers}")          # {'db1', 'db2', 'db3', 'db4', 'db5'}
```

### Active Review (15 minutes)

```python
#!/usr/bin/env python3
"""
Session 2 Review: Build a pgBackRest stanza configuration dictionary
"""

stanzas = {
    "pg15db": {
        "pg_path": "/apps/pgsql_data/15",
        "archive": "/apps/pgsql_archives/",
        "backup": "/apps/backups",
        "replication_type": "log-shipping",
        "retention_full": 4,
        "retention_diff": 14,
    },
    "pg16db": {
        "pg_path": "/apps/pgsql_data/16",
        "archive": "/apps/pgsql_archives/",
        "backup": "/apps/backups",
        "replication_type": "streaming",
        "retention_full": 4,
        "retention_diff": 14,
    },
    "pg18db": {
        "pg_path": "/apps/pgsql_data/18",
        "archive": "/apps/pgsql_archives/",
        "backup": "/apps/backups",
        "replication_type": "streaming",
        "retention_full": 2,
        "retention_diff": 7,
        "checksums": "on_by_default",
    },
}

# Print formatted summary
for stanza_name, config in stanzas.items():
    print(f"\n{'='*50}")
    print(f"Stanza: {stanza_name}")
    print(f"{'='*50}")
    for key, value in config.items():
        print(f"  {key:20s}: {value}")

# Find all stanzas using streaming replication
streaming = [name for name, cfg in stanzas.items() if cfg["replication_type"] == "streaming"]
print(f"\nStreaming replication stanzas: {streaming}")

# Calculate total retention days across all stanzas
total_full = sum(cfg["retention_full"] for cfg in stanzas.values())
print(f"Total full backup retention across all stanzas: {total_full}")
```

---

## Session 3 (Hours 5–6): Functions and Modules

### Core Concept

Functions let you write reusable, testable code. Modules let you organize code across files. Together they transform one-off scripts into a DBA toolkit.

### Free Resources

1. **Corey Schafer YouTube — "Functions" video** (~20 min)
2. **Official Python Tutorial — Section 4.7 (Functions) & Section 6 (Modules):** <https://docs.python.org/3/tutorial/controlflow.html#defining-functions>

### Key Concepts with Examples

#### Basic Functions

```python
def get_data_dir(pg_version):
    """Return the data directory path for a given PostgreSQL version."""
    return f"/apps/pgsql_data/{pg_version}"

# Call the function
path = get_data_dir(16)
print(path)  # /apps/pgsql_data/16

# Use in a loop
for ver in [15, 16, 17, 18]:
    print(f"PG {ver}: {get_data_dir(ver)}")
```

#### Default Parameters

```python
def pg_connection_string(host, port=5432, user="postgres", dbname="postgres"):
    """Build a PostgreSQL connection string with sensible defaults."""
    return f"host={host} port={port} user={user} dbname={dbname}"

# Use defaults
conn1 = pg_connection_string("192.168.1.10")
print(conn1)  # host=192.168.1.10 port=5432 user=postgres dbname=postgres

# Override specific defaults
conn2 = pg_connection_string("192.168.1.20", user="replicator", dbname="replication")
print(conn2)  # host=192.168.1.20 port=5432 user=replicator dbname=replication
```

#### Functions Returning Dictionaries

```python
def get_cluster_info(stanza, pg_version, primary_host, standby_host):
    """Return a dictionary with all cluster configuration details."""
    repl_type = "streaming" if pg_version >= 16 else "log-shipping"
    checksums = "on_by_default" if pg_version >= 18 else "manual"

    return {
        "stanza": stanza,
        "pg_version": pg_version,
        "data_dir": f"/apps/pgsql_data/{pg_version}",
        "archive_dir": "/apps/pgsql_archives/",
        "backup_dir": "/apps/backups",
        "log_dir": "/apps/logs",
        "primary": primary_host,
        "standby": standby_host,
        "replication": repl_type,
        "checksums": checksums,
    }

# Use it
cluster = get_cluster_info("pg16db", 16, "192.168.1.10", "192.168.1.20")
print(f"Stanza {cluster['stanza']}: {cluster['replication']} replication")
print(f"  Primary: {cluster['primary']}")
print(f"  Data:    {cluster['data_dir']}")
```

#### Functions with *args and **kwargs

```python
def log_message(level, *messages, **context):
    """
    Log with variable number of messages and context.
    *args   = any number of positional arguments (collected into a tuple)
    **kwargs = any number of keyword arguments (collected into a dict)
    """
    from datetime import datetime
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    full_message = " | ".join(messages)
    print(f"[{timestamp}] [{level}] {full_message}")

    if context:
        for key, value in context.items():
            print(f"    {key}: {value}")

# Usage
log_message("INFO", "Backup started")
log_message("ERROR", "Restore failed", "Checksum mismatch",
            stanza="pg16db", backup_set="20251118-020000F")

# Output:
# [2025-11-18 10:30:45] [INFO] Backup started
# [2025-11-18 10:30:45] [ERROR] Restore failed | Checksum mismatch
#     stanza: pg16db
#     backup_set: 20251118-020000F
```

#### Modules — Organizing Code Across Files

```python
# File: pg_utils.py (your reusable module)
# ==========================================

"""PostgreSQL DBA utility functions."""

SUPPORTED_VERSIONS = [15, 16, 17, 18]
ARCHIVE_DIR = "/apps/pgsql_archives/"
LOG_DIR = "/apps/logs"
BACKUP_DIR = "/apps/backups"

def get_data_dir(version):
    """Return data directory for a PG version."""
    if version not in SUPPORTED_VERSIONS:
        raise ValueError(f"Unsupported version: {version}")
    return f"/apps/pgsql_data/{version}"

def get_replication_type(version):
    """Determine replication type based on version."""
    if version >= 16:
        return "streaming"
    elif version >= 13:
        return "log-shipping"
    else:
        return "unsupported"

def format_bytes(size_bytes):
    """Convert bytes to human-readable format."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024
    return f"{size_bytes:.2f} PB"
```

```python
# File: main.py (uses the module)
# ==================================

from pg_utils import get_data_dir, get_replication_type, format_bytes, SUPPORTED_VERSIONS

for ver in SUPPORTED_VERSIONS:
    data_dir = get_data_dir(ver)
    repl = get_replication_type(ver)
    print(f"PG {ver}: {data_dir} ({repl})")

# Use format_bytes
db_size = 107374182400  # 100 GB in bytes
print(f"Database size: {format_bytes(db_size)}")
# Output: Database size: 100.00 GB
```

### Active Review (15 minutes)

```python
#!/usr/bin/env python3
"""
Session 3 Review: Create a pg_utils module and use it
Save the pg_utils.py code above as a file, then create this file:
"""

from pg_utils import get_data_dir, get_replication_type, format_bytes

def check_pg_status(host, version, port=5432):
    """Check PostgreSQL status and return a summary dict."""
    data_dir = get_data_dir(version)
    repl_type = get_replication_type(version)

    status = {
        "host": host,
        "port": port,
        "version": version,
        "data_dir": data_dir,
        "replication": repl_type,
        "status": "running",  # placeholder
    }

    print(f"Checked PG {version} on {host}:{port}")
    print(f"  Data Dir:    {data_dir}")
    print(f"  Replication: {repl_type}")

    return status

# Test it
result = check_pg_status("192.168.1.10", 16)
result2 = check_pg_status("192.168.1.20", 15, port=5433)
```

---

## Session 4 (Hours 7–8): File I/O, String Parsing, and Regular Expressions

### Core Concept

Reading log files, parsing config files, and extracting patterns — this is where Python becomes a daily DBA tool.

### Free Resources

1. **Real Python — "Reading and Writing Files":** <https://realpython.com/read-write-files-python/>
2. **Official re module docs:** <https://docs.python.org/3/library/re.html>

### Key Concepts with Examples

#### Reading Files

```python
# The 'with' statement (context manager) — ALWAYS use this for files
# It automatically closes the file when the block ends

# Read entire file as one string
with open("/apps/logs/postgresql-16.log", "r") as f:
    content = f.read()
print(f"File size: {len(content)} characters")

# Read line by line (memory-efficient for large files)
with open("/apps/logs/postgresql-16.log", "r") as f:
    for line_number, line in enumerate(f, start=1):
        if "ERROR" in line or "FATAL" in line:
            print(f"Line {line_number}: {line.strip()}")

# Read all lines into a list
with open("/apps/logs/postgresql-16.log", "r") as f:
    lines = f.readlines()
print(f"Total lines: {len(lines)}")
```

#### Writing Files

```python
# Write a new file (overwrites if exists)
errors = ["ERROR: relation not found", "FATAL: password failed"]
with open("/apps/logs/error_summary.txt", "w") as f:
    f.write("PostgreSQL Error Summary\n")
    f.write("=" * 40 + "\n\n")
    for error in errors:
        f.write(f"  - {error}\n")

# Append to an existing file
with open("/apps/logs/error_summary.txt", "a") as f:
    f.write(f"\nGenerated at: 2025-11-18 10:30:00\n")
```

#### Practical Log Parser

```python
#!/usr/bin/env python3
"""Parse PostgreSQL log file and extract error summary."""

import os
from datetime import datetime
from collections import Counter

def parse_pg_log(log_path):
    """Parse a PostgreSQL log file and return error statistics."""
    errors = []
    fatals = []
    warnings = []
    total_lines = 0

    with open(log_path, "r") as f:
        for line in f:
            total_lines += 1
            line = line.strip()

            if "ERROR:" in line:
                errors.append(line)
            elif "FATAL:" in line:
                fatals.append(line)
            elif "WARNING:" in line:
                warnings.append(line)

    return {
        "total_lines": total_lines,
        "errors": errors,
        "fatals": fatals,
        "warnings": warnings,
        "error_count": len(errors),
        "fatal_count": len(fatals),
        "warning_count": len(warnings),
    }

# Usage
log_file = "/apps/logs/postgresql-16.log"
if os.path.exists(log_file):
    result = parse_pg_log(log_file)
    print(f"Log Analysis: {log_file}")
    print(f"  Total lines:  {result['total_lines']}")
    print(f"  Errors:       {result['error_count']}")
    print(f"  Fatals:       {result['fatal_count']}")
    print(f"  Warnings:     {result['warning_count']}")
else:
    print(f"Log file not found: {log_file}")
```

#### Regular Expressions (re module)

```python
import re

# re.search — find first match
log_line = "2025-11-18 10:30:45.123 UTC [12345] ERROR:  relation \"users\" does not exist"

# Extract timestamp
match = re.search(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})', log_line)
if match:
    timestamp = match.group(1)
    print(f"Timestamp: {timestamp}")   # 2025-11-18 10:30:45

# Extract PID
match = re.search(r'\[(\d+)\]', log_line)
if match:
    pid = match.group(1)
    print(f"PID: {pid}")               # 12345

# re.findall — find ALL matches
text = "Servers: 192.168.1.10, 192.168.1.20, 10.0.0.5"
ips = re.findall(r'\d+\.\d+\.\d+\.\d+', text)
print(f"IP addresses: {ips}")   # ['192.168.1.10', '192.168.1.20', '10.0.0.5']

# Extract WAL file info
wal_line = "LOG: restored log file \"000000020000000000000015\" from archive"
match = re.search(r'"([0-9A-F]+)"', wal_line)
if match:
    wal_file = match.group(1)
    timeline = int(wal_file[:8])
    print(f"WAL file: {wal_file}, Timeline: {timeline}")

# re.sub — replace with regex
config_line = "primary_conninfo = 'host=192.168.1.10 port=5432 user=replicator password=secret123'"
# Mask the password
masked = re.sub(r"password=\S+", "password=****", config_line)
print(masked)

# Practical: Parse pg_stat_replication output
repl_output = """
 pid  | usename    | application_name    | client_addr   | state     | sent_lsn   | replay_lsn
------+------------+---------------------+---------------+-----------+------------+------------
 1234 | replicator | old_primary_standby | 192.168.1.10  | streaming | 0/5000140  | 0/5000140
"""

# Extract all LSN values
lsns = re.findall(r'(\d+/[0-9A-Fa-f]+)', repl_output)
print(f"LSN values found: {lsns}")
```

### Active Review (15 minutes)

```python
#!/usr/bin/env python3
"""
Session 4 Review: Parse PostgreSQL log, extract errors with timestamps
"""
import re

# Simulate a log file (replace with real file path in practice)
sample_log = """
2025-11-18 10:30:45.123 UTC [12345] LOG: checkpoint starting: time
2025-11-18 10:31:00.456 UTC [12345] LOG: checkpoint complete
2025-11-18 10:32:15.789 UTC [23456] ERROR:  relation "important_table" does not exist
2025-11-18 10:33:00.012 UTC [23457] FATAL:  password authentication failed for user "appuser"
2025-11-18 10:34:45.345 UTC [12345] LOG: checkpoint starting: time
2025-11-18 10:35:00.678 UTC [34567] ERROR:  deadlock detected
""".strip().split("\n")

print("=== PostgreSQL Error Report ===\n")
for line in sample_log:
    if "ERROR" in line or "FATAL" in line:
        match = re.search(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.\d+ \w+ \[(\d+)\] (\w+):\s+(.*)', line)
        if match:
            ts, pid, level, message = match.groups()
            print(f"  [{level}] {ts} (PID {pid})")
            print(f"          {message}\n")
```

---

## Session 5 (Hours 9–10): Error Handling and subprocess

### Core Concept

`try/except` and `subprocess` — how you wrap system commands (pg_ctl, pgbackrest, psql) in Python safely.

### Free Resources

1. **Corey Schafer YouTube — "Try/Except" video**
2. **Real Python — "Python subprocess":** <https://realpython.com/python-subprocess/>

### Key Concepts with Examples

#### try / except / else / finally

```python
# Basic try/except
try:
    result = 10 / 0
except ZeroDivisionError:
    print("Cannot divide by zero!")

# Catch specific exceptions
try:
    version = int("not_a_number")
except ValueError as e:
    print(f"Invalid input: {e}")

# Multiple exception types
try:
    with open("/apps/logs/nonexistent.log", "r") as f:
        content = f.read()
except FileNotFoundError:
    print("Log file not found")
except PermissionError:
    print("No permission to read log file")
except Exception as e:
    print(f"Unexpected error: {type(e).__name__}: {e}")

# else + finally
try:
    with open("/apps/logs/postgresql-16.log", "r") as f:
        first_line = f.readline()
except FileNotFoundError:
    print("File not found")
else:
    # Runs ONLY if no exception occurred
    print(f"First line: {first_line.strip()}")
finally:
    # Runs ALWAYS, even if exception occurred
    print("File operation complete")
```

#### Custom Exceptions

```python
class PgBackRestError(Exception):
    """Custom exception for pgBackRest operations."""
    def __init__(self, command, return_code, stderr):
        self.command = command
        self.return_code = return_code
        self.stderr = stderr
        super().__init__(f"pgBackRest command failed (rc={return_code}): {stderr}")

class BackupVerificationError(PgBackRestError):
    """Backup verification failed."""
    pass

# Usage
try:
    raise PgBackRestError("backup", 49, "WAL segment not found")
except PgBackRestError as e:
    print(f"Backup error: {e}")
    print(f"  Command: {e.command}")
    print(f"  Return code: {e.return_code}")
```

#### subprocess.run — Executing System Commands

```python
import subprocess

# Basic command execution
result = subprocess.run(
    ["pg_ctl", "status", "-D", "/apps/pgsql_data/16"],
    capture_output=True,     # Capture stdout and stderr
    text=True,               # Return strings instead of bytes
    timeout=30,              # Kill after 30 seconds
)

print(f"Return code: {result.returncode}")
print(f"Output: {result.stdout}")
if result.returncode != 0:
    print(f"Error: {result.stderr}")

# Run psql command
def run_psql(query, host="localhost", port=5432, user="postgres", dbname="postgres"):
    """Execute a psql query and return the output."""
    cmd = [
        "psql",
        "-h", host,
        "-p", str(port),
        "-U", user,
        "-d", dbname,
        "-t",          # Tuples only (no headers/footers)
        "-A",          # Unaligned output
        "-c", query,
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60,
        )
        if result.returncode != 0:
            raise Exception(f"psql failed: {result.stderr.strip()}")
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        raise Exception("psql query timed out after 60 seconds")

# Usage
try:
    version = run_psql("SELECT version()")
    print(f"PostgreSQL: {version}")

    is_recovery = run_psql("SELECT pg_is_in_recovery()")
    print(f"In recovery: {is_recovery}")
except Exception as e:
    print(f"Error: {e}")

# Run pgBackRest command
def run_pgbackrest(stanza, command, extra_args=None):
    """Execute a pgBackRest command and return the output."""
    cmd = ["pgbackrest", f"--stanza={stanza}", command]
    if extra_args:
        cmd.extend(extra_args)

    print(f"Running: {' '.join(cmd)}")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=3600,   # 1 hour timeout for backups
        )

        if result.returncode != 0:
            raise PgBackRestError(command, result.returncode, result.stderr.strip())

        return result.stdout
    except subprocess.TimeoutExpired:
        raise PgBackRestError(command, -1, "Command timed out")

# Usage
try:
    info = run_pgbackrest("pg16db", "info")
    print(info)

    # Verify backups
    verify_output = run_pgbackrest("pg16db", "verify")
    print("Backup verification passed!")

except PgBackRestError as e:
    print(f"pgBackRest error: {e}")
```

### Active Review (15 minutes)

```python
#!/usr/bin/env python3
"""
Session 5 Review: Build a pgBackRest info wrapper with error handling
"""
import subprocess
import sys

def pgbackrest_info(stanza, output_format="text"):
    """Get pgBackRest info for a stanza with proper error handling."""
    cmd = ["pgbackrest", f"--stanza={stanza}", "info"]
    if output_format == "json":
        cmd.append("--output=json")

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        if result.returncode != 0:
            print(f"ERROR: pgbackrest info failed (rc={result.returncode})")
            print(f"  stderr: {result.stderr.strip()}")
            return None

        return result.stdout

    except FileNotFoundError:
        print("ERROR: pgbackrest command not found. Is it installed?")
        return None
    except subprocess.TimeoutExpired:
        print("ERROR: pgbackrest info timed out after 30 seconds")
        return None
    except Exception as e:
        print(f"ERROR: Unexpected error: {type(e).__name__}: {e}")
        return None

# Test it
stanza = sys.argv[1] if len(sys.argv) > 1 else "pg16db"
output = pgbackrest_info(stanza)
if output:
    print(output)
else:
    print("Failed to get backup info")
```

---

## Session 6 (Hours 11–12): Working with JSON and YAML

### Core Concept

JSON is everywhere in DBA work — pgBackRest `--output=json`, Kubernetes manifests (YAML), REST APIs, monitoring tools.

### Free Resources

1. **Real Python — "Working With JSON":** <https://realpython.com/python-json/>
2. **PyYAML Docs:** <https://pyyaml.org/wiki/PyYAMLDocumentation>

### Key Concepts with Examples

#### JSON — Parsing and Creating

```python
import json

# Parse a JSON string
json_string = '''
{
    "stanza": "pg16db",
    "status": {"code": 0, "message": "ok"},
    "backup": [
        {
            "label": "20251118-020000F",
            "type": "full",
            "timestamp": {"start": 1731895200, "stop": 1731896100},
            "info": {
                "size": 107374182400,
                "repository": {"size": 5368709120}
            }
        },
        {
            "label": "20251119-020000D",
            "type": "diff",
            "timestamp": {"start": 1731981600, "stop": 1731982200},
            "info": {
                "size": 107374182400,
                "repository": {"size": 1073741824}
            }
        }
    ]
}
'''

data = json.loads(json_string)    # Parse JSON string -> Python dict

# Access nested data
stanza = data["stanza"]
status = data["status"]["message"]
print(f"Stanza: {stanza}, Status: {status}")

# Loop through backups
for backup in data["backup"]:
    label = backup["label"]
    btype = backup["type"]
    size_gb = backup["info"]["size"] / 1024**3
    repo_gb = backup["info"]["repository"]["size"] / 1024**3
    print(f"  {label} ({btype}): {size_gb:.1f} GB (repo: {repo_gb:.1f} GB)")

# Convert Python dict -> JSON string
config = {
    "stanza": "pg17db",
    "pg_path": "/apps/pgsql_data/17",
    "archive": "/apps/pgsql_archives/",
}
json_output = json.dumps(config, indent=2)
print(json_output)

# Write JSON to file
with open("/tmp/cluster_config.json", "w") as f:
    json.dump(config, f, indent=2)

# Read JSON from file
with open("/tmp/cluster_config.json", "r") as f:
    loaded = json.load(f)
print(f"Loaded stanza: {loaded['stanza']}")
```

#### Practical: Parse pgBackRest JSON Output

```python
import json
import subprocess
from datetime import datetime

def get_backup_summary(stanza):
    """Get and parse pgBackRest backup info as JSON."""
    try:
        result = subprocess.run(
            ["pgbackrest", f"--stanza={stanza}", "info", "--output=json"],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            return None

        data = json.loads(result.stdout)

        backups = []
        for stanza_info in data:
            for backup in stanza_info.get("backup", []):
                ts = datetime.fromtimestamp(backup["timestamp"]["stop"])
                size_gb = backup["info"]["size"] / 1024**3
                repo_gb = backup["info"]["repository"]["size"] / 1024**3

                backups.append({
                    "label": backup["label"],
                    "type": backup["type"],
                    "timestamp": ts.strftime("%Y-%m-%d %H:%M:%S"),
                    "db_size_gb": round(size_gb, 2),
                    "repo_size_gb": round(repo_gb, 2),
                })
        return backups
    except Exception as e:
        print(f"Error: {e}")
        return None

# Usage
summary = get_backup_summary("pg16db")
if summary:
    for b in summary:
        print(f"  {b['label']} | {b['type']:5s} | {b['timestamp']} | "
              f"DB: {b['db_size_gb']} GB | Repo: {b['repo_size_gb']} GB")
```

#### YAML — Configuration Files

```python
# pip install pyyaml --break-system-packages
import yaml

# Parse YAML string (similar to Kubernetes manifests)
yaml_string = """
clusters:
  pg16db:
    pg_path: /apps/pgsql_data/16
    archive: /apps/pgsql_archives/
    backup: /apps/backups
    replication: streaming
    servers:
      primary: 192.168.1.10
      standby: 192.168.1.20

  pg17db:
    pg_path: /apps/pgsql_data/17
    archive: /apps/pgsql_archives/
    backup: /apps/backups
    replication: streaming
    servers:
      primary: 192.168.1.30
      standby: 192.168.1.40
"""

config = yaml.safe_load(yaml_string)

for name, cluster in config["clusters"].items():
    print(f"\n{name}:")
    print(f"  Primary:  {cluster['servers']['primary']}")
    print(f"  Data Dir: {cluster['pg_path']}")
    print(f"  Repl:     {cluster['replication']}")

# Write YAML
with open("/tmp/pg_clusters.yaml", "w") as f:
    yaml.dump(config, f, default_flow_style=False)
```

### Active Review (15 minutes)

```python
#!/usr/bin/env python3
"""
Session 6 Review: Parse pgBackRest JSON and produce a summary report
"""
import json

# Simulated pgBackRest JSON output (replace with real subprocess call)
pgbackrest_json = '''[{"name":"pg16db","status":{"code":0,"message":"ok"},
"backup":[{"label":"20251118-020000F","type":"full",
"timestamp":{"start":1731895200,"stop":1731896100},
"info":{"size":107374182400,"repository":{"size":5368709120}}},
{"label":"20251119-020000D","type":"diff",
"timestamp":{"start":1731981600,"stop":1731982200},
"info":{"size":107374182400,"repository":{"size":1073741824}}}]}]'''

data = json.loads(pgbackrest_json)

for stanza in data:
    print(f"Stanza: {stanza['name']} (Status: {stanza['status']['message']})")
    print(f"  Backups: {len(stanza['backup'])}")

    for b in stanza["backup"]:
        repo_gb = b["info"]["repository"]["size"] / 1024**3
        print(f"    {b['label']} [{b['type']}] - Repo: {repo_gb:.2f} GB")
```

---

## Session 7 (Hours 13–14): Working with Databases — psycopg

### Core Concept

Connect to PostgreSQL from Python, execute queries, fetch results, and handle transactions.

### Free Resources

1. **psycopg3 docs:** <https://www.psycopg.org/psycopg3/docs/>
2. **Real Python — "PostgreSQL Python" tutorial**

### Key Concepts with Examples

```python
# pip install psycopg[binary] --break-system-packages
import psycopg

# Basic connection and query (context manager auto-closes)
with psycopg.connect("host=192.168.1.10 port=5432 user=postgres dbname=postgres") as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT version()")
        version = cur.fetchone()[0]
        print(f"PostgreSQL: {version}")

# Parameterized queries (NEVER use string formatting for SQL!)
def get_replication_status(host, port=5432):
    """Query pg_stat_replication and return standby info."""
    conn_str = f"host={host} port={port} user=postgres dbname=postgres"

    with psycopg.connect(conn_str) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    application_name,
                    client_addr,
                    state,
                    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
                    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag
                FROM pg_stat_replication
            """)

            rows = cur.fetchall()
            columns = [desc.name for desc in cur.description]

            results = []
            for row in rows:
                results.append(dict(zip(columns, row)))

            return results

# Usage
standbys = get_replication_status("192.168.1.10")
for s in standbys:
    print(f"  {s['application_name']} ({s['client_addr']}): "
          f"state={s['state']}, lag={s['lag']}")

# Parameterized queries (safe from SQL injection)
def get_table_size(host, dbname, table_name):
    """Get size of a specific table using parameterized query."""
    with psycopg.connect(f"host={host} dbname={dbname} user=postgres") as conn:
        with conn.cursor() as cur:
            # Use %s placeholders — NEVER f-strings in SQL!
            cur.execute("""
                SELECT pg_size_pretty(pg_total_relation_size(%s))
            """, (table_name,))    # Note: tuple with single element needs trailing comma

            result = cur.fetchone()
            return result[0] if result else None

# Using Row factories for dict-like access
def get_database_sizes(host):
    """Get all database sizes as a list of dicts."""
    with psycopg.connect(f"host={host} user=postgres dbname=postgres",
                         row_factory=psycopg.rows.dict_row) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
                FROM pg_database
                WHERE NOT datistemplate
                ORDER BY pg_database_size(datname) DESC
            """)
            return cur.fetchall()

# Usage
databases = get_database_sizes("192.168.1.10")
for db in databases:
    print(f"  {db['datname']}: {db['size']}")
```

### Active Review (15 minutes)

```python
#!/usr/bin/env python3
"""
Session 7 Review: Query pg_stat_replication and pg_replication_slots
"""
import psycopg

def cluster_health_check(host, port=5432):
    """Comprehensive cluster health check."""
    conn_str = f"host={host} port={port} user=postgres dbname=postgres"

    try:
        with psycopg.connect(conn_str, row_factory=psycopg.rows.dict_row) as conn:
            with conn.cursor() as cur:
                # Check if primary or standby
                cur.execute("SELECT pg_is_in_recovery() AS is_standby")
                row = cur.fetchone()
                role = "Standby" if row["is_standby"] else "Primary"
                print(f"\n{host}:{port} — Role: {role}")

                if role == "Primary":
                    # Check replication
                    cur.execute("""
                        SELECT application_name, client_addr, state,
                               pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag
                        FROM pg_stat_replication
                    """)
                    for r in cur.fetchall():
                        print(f"  Standby: {r['application_name']} "
                              f"({r['client_addr']}) — {r['state']}, lag: {r['lag']}")

                    # Check slots
                    cur.execute("""
                        SELECT slot_name, active,
                               pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained
                        FROM pg_replication_slots
                    """)
                    for r in cur.fetchall():
                        print(f"  Slot: {r['slot_name']} — "
                              f"active={r['active']}, retained={r['retained']}")

    except psycopg.OperationalError as e:
        print(f"Connection failed to {host}:{port}: {e}")

# Test
cluster_health_check("192.168.1.10")
```

---

## Session 8 (Hours 15–16): HTTP Requests and REST APIs

### Core Concept

Integrating with monitoring systems, Kubernetes API, cloud providers, and internal tools.

### Free Resources

1. **Real Python — "Python Requests":** <https://realpython.com/python-requests/>
2. **requests docs:** <https://docs.python-requests.org>

### Key Concepts with Examples

```python
# pip install requests --break-system-packages
import requests
import json

# Basic GET request
response = requests.get("https://httpbin.org/get", timeout=10)
print(f"Status: {response.status_code}")
print(f"JSON: {response.json()}")

# GET with parameters
response = requests.get(
    "https://httpbin.org/get",
    params={"stanza": "pg16db", "format": "json"},
    timeout=10,
)
print(response.url)  # Shows the full URL with query string

# POST with JSON body
payload = {
    "alert": "backup_failed",
    "stanza": "pg16db",
    "severity": "critical",
    "message": "Full backup failed with checksum error",
}
response = requests.post(
    "https://httpbin.org/post",
    json=payload,
    timeout=10,
)
print(f"Status: {response.status_code}")

# Error handling
def send_alert(webhook_url, message, severity="info"):
    """Send an alert to a webhook endpoint."""
    try:
        response = requests.post(
            webhook_url,
            json={"text": message, "severity": severity},
            timeout=10,
            headers={"Content-Type": "application/json"},
        )
        response.raise_for_status()   # Raises exception for 4xx/5xx
        return True
    except requests.exceptions.ConnectionError:
        print("ERROR: Cannot connect to webhook server")
        return False
    except requests.exceptions.Timeout:
        print("ERROR: Webhook request timed out")
        return False
    except requests.exceptions.HTTPError as e:
        print(f"ERROR: Webhook returned {e.response.status_code}")
        return False

# Practical: Query Prometheus/alerting API
def check_pg_exporter(host, port=9187):
    """Check PostgreSQL exporter metrics."""
    try:
        response = requests.get(f"http://{host}:{port}/metrics", timeout=5)
        response.raise_for_status()
        # Parse Prometheus text format
        for line in response.text.split("\n"):
            if "pg_up" in line and not line.startswith("#"):
                print(f"  {line}")
    except requests.exceptions.RequestException as e:
        print(f"Exporter check failed: {e}")
```

### Active Review (15 minutes)

```python
#!/usr/bin/env python3
"""
Session 8 Review: Build a simple health-check that hits an HTTP endpoint
"""
import requests
import json

def health_check(url, timeout=5):
    """Check if a service is healthy via HTTP GET."""
    try:
        response = requests.get(url, timeout=timeout)
        data = response.json() if response.headers.get("content-type", "").startswith("application/json") else None

        return {
            "url": url,
            "status_code": response.status_code,
            "healthy": response.status_code == 200,
            "response_time_ms": round(response.elapsed.total_seconds() * 1000, 2),
            "data": data,
        }
    except requests.exceptions.RequestException as e:
        return {
            "url": url,
            "status_code": None,
            "healthy": False,
            "error": str(e),
        }

# Test with httpbin
result = health_check("https://httpbin.org/get")
print(json.dumps(result, indent=2, default=str))
```

---

## Session 9 (Hours 17–18): Building CLI Tools — argparse

### Core Concept

Turn your scripts into professional CLI tools with flags, help text, and subcommands.

### Free Resources

1. **Official argparse tutorial:** <https://docs.python.org/3/howto/argparse.html>
2. **Real Python — "Command-Line Interfaces"**

### Key Concepts with Examples

```python
#!/usr/bin/env python3
"""
pg_health.py — PostgreSQL Health Check CLI Tool
Usage:
    python pg_health.py check --host 192.168.1.10 --port 5432
    python pg_health.py backup-info --stanza pg16db
    python pg_health.py log-errors --log-dir /apps/logs --severity ERROR
"""
import argparse
import subprocess
import re
import sys
import os


def cmd_check(args):
    """Check PostgreSQL server status."""
    print(f"\n{'='*50}")
    print(f"Checking PostgreSQL on {args.host}:{args.port}")
    print(f"{'='*50}")

    # Check if PostgreSQL is reachable
    cmd = ["pg_isready", "-h", args.host, "-p", str(args.port)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)

    if result.returncode == 0:
        print(f"  Status:  ONLINE")
    else:
        print(f"  Status:  OFFLINE")
        print(f"  Error:   {result.stderr.strip()}")
        return

    # Get version
    if args.verbose:
        psql_cmd = [
            "psql", "-h", args.host, "-p", str(args.port),
            "-U", args.user, "-t", "-A",
            "-c", "SELECT version()",
        ]
        result = subprocess.run(psql_cmd, capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            print(f"  Version: {result.stdout.strip()[:60]}")


def cmd_backup_info(args):
    """Show pgBackRest backup info for a stanza."""
    print(f"\nBackup info for stanza: {args.stanza}")
    print(f"{'='*50}")

    cmd = ["pgbackrest", f"--stanza={args.stanza}", "info"]
    if args.json:
        cmd.append("--output=json")

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print(result.stdout)
        else:
            print(f"ERROR: {result.stderr.strip()}")
    except FileNotFoundError:
        print("ERROR: pgbackrest not found in PATH")


def cmd_log_errors(args):
    """Parse PostgreSQL logs for errors."""
    log_dir = args.log_dir
    severity = args.severity.upper()

    print(f"\nSearching for {severity} in {log_dir}")
    print(f"{'='*50}")

    if not os.path.isdir(log_dir):
        print(f"ERROR: Directory not found: {log_dir}")
        return

    count = 0
    for filename in sorted(os.listdir(log_dir)):
        if not filename.endswith(".log"):
            continue
        filepath = os.path.join(log_dir, filename)
        with open(filepath, "r") as f:
            for line in f:
                if severity in line:
                    count += 1
                    if count <= args.limit:
                        print(f"  [{filename}] {line.strip()[:120]}")

    print(f"\nTotal {severity} entries found: {count}")
    if count > args.limit:
        print(f"  (showing first {args.limit} of {count})")


def main():
    parser = argparse.ArgumentParser(
        description="PostgreSQL Health Check CLI Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # 'check' subcommand
    check_parser = subparsers.add_parser("check", help="Check PostgreSQL server status")
    check_parser.add_argument("--host", required=True, help="PostgreSQL host")
    check_parser.add_argument("--port", type=int, default=5432, help="PostgreSQL port (default: 5432)")
    check_parser.add_argument("--user", default="postgres", help="PostgreSQL user (default: postgres)")
    check_parser.add_argument("-v", "--verbose", action="store_true", help="Show verbose output")

    # 'backup-info' subcommand
    backup_parser = subparsers.add_parser("backup-info", help="Show pgBackRest backup info")
    backup_parser.add_argument("--stanza", required=True, help="pgBackRest stanza name")
    backup_parser.add_argument("--json", action="store_true", help="Output in JSON format")

    # 'log-errors' subcommand
    log_parser = subparsers.add_parser("log-errors", help="Parse PostgreSQL logs for errors")
    log_parser.add_argument("--log-dir", default="/apps/logs", help="Log directory (default: /apps/logs)")
    log_parser.add_argument("--severity", default="ERROR", choices=["ERROR", "FATAL", "WARNING", "PANIC"],
                           help="Severity level to search (default: ERROR)")
    log_parser.add_argument("--limit", type=int, default=20, help="Max entries to display (default: 20)")

    args = parser.parse_args()

    if args.command == "check":
        cmd_check(args)
    elif args.command == "backup-info":
        cmd_backup_info(args)
    elif args.command == "log-errors":
        cmd_log_errors(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
```

### Active Review (15 minutes)

Run your tool with different commands:

```bash
# Show help
python pg_health.py --help
python pg_health.py check --help

# Check a server
python pg_health.py check --host 192.168.1.10 --verbose

# Show backup info
python pg_health.py backup-info --stanza pg16db --json

# Parse logs
python pg_health.py log-errors --severity FATAL --limit 10
```

---

## Session 10 (Hours 19–20): FastAPI Basics — Your First API Endpoint

### Core Concept

FastAPI ties everything together — functions, JSON, database access, HTTP — into a web service for DBA monitoring tools.

### Free Resources

1. **FastAPI official tutorial (first 4 sections):** <https://fastapi.tiangolo.com/tutorial/>
2. **FastAPI docs — very well written, with interactive examples**

### Key Concepts with Examples

```python
#!/usr/bin/env python3
"""
pg_monitor_api.py — PostgreSQL Monitoring API
Run: uvicorn pg_monitor_api:app --host 0.0.0.0 --port 8000 --reload
Test: curl http://localhost:8000/health
"""
# pip install fastapi uvicorn --break-system-packages

from fastapi import FastAPI, HTTPException
from datetime import datetime
import subprocess
import json

app = FastAPI(
    title="PostgreSQL Monitor API",
    description="REST API for PostgreSQL health monitoring",
    version="1.0.0",
)


# ===== Endpoint 1: Health check =====
@app.get("/health")
def health_check():
    """Simple health check — is the API running?"""
    return {
        "status": "ok",
        "timestamp": datetime.now().isoformat(),
        "service": "pg-monitor-api",
    }


# ===== Endpoint 2: PostgreSQL server status =====
@app.get("/pg/status/{host}")
def pg_status(host: str, port: int = 5432):
    """Check if a PostgreSQL server is reachable."""
    result = subprocess.run(
        ["pg_isready", "-h", host, "-p", str(port)],
        capture_output=True, text=True, timeout=10,
    )
    return {
        "host": host,
        "port": port,
        "reachable": result.returncode == 0,
        "message": result.stdout.strip(),
    }


# ===== Endpoint 3: pgBackRest backup info =====
@app.get("/backup/info/{stanza}")
def backup_info(stanza: str):
    """Get pgBackRest backup info for a stanza."""
    try:
        result = subprocess.run(
            ["pgbackrest", f"--stanza={stanza}", "info", "--output=json"],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode != 0:
            raise HTTPException(status_code=500,
                detail=f"pgBackRest error: {result.stderr.strip()}")

        data = json.loads(result.stdout)
        return {
            "stanza": stanza,
            "status": data[0]["status"]["message"] if data else "unknown",
            "backups": len(data[0]["backup"]) if data else 0,
            "raw": data,
        }
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="pgbackrest not installed")
    except json.JSONDecodeError:
        raise HTTPException(status_code=500, detail="Invalid JSON from pgbackrest")


# ===== Endpoint 4: Cluster configuration =====
@app.get("/config/clusters")
def list_clusters():
    """Return all configured PostgreSQL clusters."""
    clusters = {
        "pg15db": {"version": 15, "path": "/apps/pgsql_data/15", "replication": "log-shipping"},
        "pg16db": {"version": 16, "path": "/apps/pgsql_data/16", "replication": "streaming"},
        "pg17db": {"version": 17, "path": "/apps/pgsql_data/17", "replication": "streaming"},
        "pg18db": {"version": 18, "path": "/apps/pgsql_data/18", "replication": "streaming"},
    }
    return {
        "archive_dir": "/apps/pgsql_archives/",
        "log_dir": "/apps/logs",
        "backup_dir": "/apps/backups",
        "clusters": clusters,
    }
```

### Active Review (15 minutes)

```bash
# Install and run
pip install fastapi uvicorn --break-system-packages
uvicorn pg_monitor_api:app --host 0.0.0.0 --port 8000 --reload

# Test endpoints
curl http://localhost:8000/health
curl http://localhost:8000/pg/status/192.168.1.10
curl http://localhost:8000/backup/info/pg16db
curl http://localhost:8000/config/clusters

# Visit interactive docs (auto-generated by FastAPI!)
# http://localhost:8000/docs
```

---

## Summary — The 20% That Drives 80%

| Concept | Why It Matters for DBA Work |
|---|---|
| f-strings | Output formatting, log messages, path construction |
| Dictionaries | Config files, JSON, API responses, DB rows |
| `with open()` | Log file parsing, config reading/writing |
| `re` (regex) | Extracting timestamps, PIDs, LSNs from logs |
| `subprocess.run` | Wrapping pg_ctl, pgbackrest, psql |
| `try/except` | Robust error handling for all automation |
| `json` module | Parsing pgBackRest, API, and monitoring output |
| `argparse` | Building proper CLI tools with help text |
| `psycopg` | Direct PostgreSQL queries from Python |
| `FastAPI` | Building monitoring dashboards and APIs |

**The golden rule:** After each session, apply what you learned to something real in your environment. Parse an actual log, wrap an actual pgbackrest command, query an actual pg_stat_replication view. The retention difference between exercises and real-world application is enormous.
