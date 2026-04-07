# Go (Golang) for PostgreSQL DBAs — 20-Hour Accelerated Study Plan

**Target Audience:** Database Administrators with PostgreSQL/Infrastructure/DevOps background  
**Goal:** Learn the 20% of Go that drives 80% of real-world DBA and DevOps tooling  
**Environment:** AlmaLinux 8/9, PostgreSQL 15/16/17/18  
**Paths:** `/apps/pgsql_data/<ver>`, `/apps/pgsql_archives/`, `/apps/logs`, `/apps/backups`

**Why Go for DBA/DevOps Work?**

Go is the language behind Kubernetes, Docker, Terraform, Prometheus, pgBackRest exporters, and most modern infrastructure tooling. Unlike Python, Go compiles to a single static binary — no runtime dependencies, no virtual environments, no "works on my machine" problems. You `go build`, copy the binary to any Linux box, and it runs. For DBA automation that ships to production servers, this is transformative.

---

## Session 1 (Hours 1–2): Go Fundamentals — Variables, Types, and Control Flow

### Core Concept

Go is a statically typed, compiled language. Every variable has a fixed type declared at compile time. This catches bugs early — before your automation script runs against production. Learn variables, basic types, `if/else`, `for` loops (Go has no `while`), and `fmt.Println`/`fmt.Printf`.

### Free Resources

1. **A Tour of Go (official interactive tutorial):** <https://go.dev/tour/> — Complete "Basics" section (exercises 1–25)
2. **Go by Example:** <https://gobyexample.com/> — Work through "Hello World" to "For" sections

### Key Concepts with Examples

#### Your First Go Program

```go
// Every Go file starts with a package declaration.
// 'main' is special — it's the entry point for executables.
package main

// Import standard library packages
import (
    "fmt"      // Formatted I/O (like Python's print + f-strings)
    "os"       // OS-level operations
)

// main() is the entry point — Go runs this function first
func main() {
    fmt.Println("PostgreSQL DBA Toolkit — Go Edition")
    fmt.Println("====================================")

    // Get hostname
    hostname, err := os.Hostname()
    if err != nil {
        fmt.Println("ERROR: Cannot get hostname:", err)
        return
    }
    fmt.Println("Hostname:", hostname)
}
```

Save as `main.go`, then:

```bash
# Compile and run in one step
go run main.go

# OR compile to a binary
go build -o pg_toolkit main.go
./pg_toolkit

# Cross-compile for a different OS/arch (e.g., build on Mac, deploy to Linux)
GOOS=linux GOARCH=amd64 go build -o pg_toolkit main.go
```

#### Variables and Types

```go
package main

import "fmt"

func main() {
    // Explicit type declaration
    var pgVersion int = 16
    var pgHost string = "192.168.1.10"
    var pgPort int = 5432
    var isPrimary bool = true
    var replicationLagMB float64 = 12.5

    // Short declaration with := (type inferred by compiler)
    // This is the form you'll use 90% of the time
    dataDir := fmt.Sprintf("/apps/pgsql_data/%d", pgVersion)
    archiveDir := "/apps/pgsql_archives/"
    logDir := "/apps/logs"
    backupDir := "/apps/backups"

    // fmt.Printf — formatted output (like Python f-strings)
    // %d = integer, %s = string, %t = bool, %f = float, %v = any value
    fmt.Printf("PG Version:   %d\n", pgVersion)
    fmt.Printf("Host:         %s\n", pgHost)
    fmt.Printf("Port:         %d\n", pgPort)
    fmt.Printf("Primary:      %t\n", isPrimary)
    fmt.Printf("Lag:          %.2f MB\n", replicationLagMB)
    fmt.Printf("Data Dir:     %s\n", dataDir)
    fmt.Printf("Archive Dir:  %s\n", archiveDir)
    fmt.Printf("Log Dir:      %s\n", logDir)
    fmt.Printf("Backup Dir:   %s\n", backupDir)

    // fmt.Sprintf — returns a formatted string (doesn't print)
    connStr := fmt.Sprintf("host=%s port=%d user=postgres dbname=postgres",
        pgHost, pgPort)
    fmt.Println("Connection:", connStr)

    // Constants — values that never change
    const maxRetries = 5
    const defaultTimeout = 30 // seconds

    // Multiple variables at once
    var (
        primaryHost = "192.168.1.10"
        standbyHost = "192.168.1.20"
        replType    = "streaming"
    )
    fmt.Printf("Primary: %s, Standby: %s (%s)\n",
        primaryHost, standbyHost, replType)
}
```

#### String Operations

```go
package main

import (
    "fmt"
    "strings"
    "strconv"
)

func main() {
    logLine := `2025-11-18 10:30:45 UTC [12345] ERROR:  relation "users" does not exist`

    // Check if string contains something
    if strings.Contains(logLine, "ERROR") {
        fmt.Println("Found an error!")
    }

    // Split a string
    parts := strings.Split(logLine, " ")
    timestamp := parts[0] + " " + parts[1]
    fmt.Println("Timestamp:", timestamp)

    // HasPrefix / HasSuffix (like Python's startswith/endswith)
    walFile := "000000010000000000000003"
    if strings.HasPrefix(walFile, "00000001") {
        fmt.Println("Timeline 1 WAL file:", walFile)
    }

    // Replace
    masked := strings.Replace(logLine, "ERROR", "CRITICAL", 1)
    fmt.Println("Masked:", masked)

    // ToUpper / ToLower
    severity := "error"
    fmt.Println(strings.ToUpper(severity)) // "ERROR"

    // TrimSpace (like Python's strip())
    userInput := "  pg16db  "
    stanza := strings.TrimSpace(userInput)
    fmt.Println("Stanza:", stanza)

    // Join — combine a slice of strings
    servers := []string{"192.168.1.10", "192.168.1.20", "192.168.1.30"}
    fmt.Println("Servers:", strings.Join(servers, ", "))

    // String to int / int to string
    portStr := "5432"
    port, err := strconv.Atoi(portStr) // Atoi = ASCII to integer
    if err != nil {
        fmt.Println("Invalid port:", err)
    } else {
        fmt.Printf("Port: %d (type: int)\n", port)
    }
    backToStr := strconv.Itoa(port) // Itoa = integer to ASCII
    fmt.Println("Port string:", backToStr)
}
```

#### if / else — Go Has No elif (Use else if)

```go
package main

import "fmt"

func main() {
    pgVersion := 16

    if pgVersion >= 18 {
        fmt.Println("PG 18: Data checksums ON by default")
        fmt.Println("  Streaming replication with slots recommended")
    } else if pgVersion >= 16 {
        fmt.Printf("PG %d: Streaming replication with slots\n", pgVersion)
        fmt.Println("  Enable data checksums manually")
    } else if pgVersion >= 13 {
        fmt.Printf("PG %d: Log-shipping replication\n", pgVersion)
        fmt.Println("  Set archive_timeout = 300")
    } else {
        fmt.Printf("PG %d: Consider upgrading — EOL version\n", pgVersion)
    }

    // Go's unique feature: if with initialization statement
    // The variable 'size' is scoped ONLY to this if/else block
    dbSizeGB := 750
    if size := dbSizeGB; size < 50 {
        fmt.Println("Strategy: daily full backup")
    } else if size < 500 {
        fmt.Println("Strategy: weekly full + daily differential")
    } else {
        fmt.Println("Strategy: weekly full + daily incremental")
    }
}
```

#### for Loops — Go's Only Loop Construct

```go
package main

import "fmt"

func main() {
    // Standard for loop (like C)
    for i := 1; i <= 5; i++ {
        fmt.Printf("Backup attempt %d/5\n", i)
    }

    // for-range loop (like Python's "for x in list")
    pgVersions := []int{15, 16, 17, 18}
    for i, ver := range pgVersions {
        dataDir := fmt.Sprintf("/apps/pgsql_data/%d", ver)
        fmt.Printf("  [%d] PG %d: %s\n", i, ver, dataDir)
    }

    // If you don't need the index, use _ (blank identifier)
    servers := []string{"192.168.1.10", "192.168.1.20"}
    for _, server := range servers {
        fmt.Println("Checking server:", server)
    }

    // "while" loop — Go uses 'for' with just a condition
    retryCount := 0
    maxRetries := 5
    for retryCount < maxRetries {
        retryCount++
        fmt.Printf("Attempt %d/%d...\n", retryCount, maxRetries)
        if retryCount == 3 {
            fmt.Println("Connected!")
            break
        }
    }

    // Infinite loop (common for daemons/monitors)
    // for {
    //     // Check health, sleep, repeat
    //     time.Sleep(30 * time.Second)
    // }
}
```

### Active Review (15 minutes)

```go
// Save as pg_version_check.go
package main

import (
    "bufio"
    "fmt"
    "os"
    "strconv"
    "strings"
)

func main() {
    supported := []int{15, 16, 17, 18}

    fmt.Print("Enter PostgreSQL version number: ")
    reader := bufio.NewReader(os.Stdin)
    input, _ := reader.ReadString('\n')
    input = strings.TrimSpace(input)

    version, err := strconv.Atoi(input)
    if err != nil {
        fmt.Println("Invalid version number:", input)
        return
    }

    // Check if version is supported
    found := false
    for _, v := range supported {
        if v == version {
            found = true
            break
        }
    }

    if found {
        fmt.Printf("\nPostgreSQL %d is SUPPORTED\n", version)
        fmt.Printf("  Data Directory:    /apps/pgsql_data/%d\n", version)
        fmt.Printf("  WAL Archive:       /apps/pgsql_archives/\n")
        fmt.Printf("  Logs:              /apps/logs\n")
        fmt.Printf("  Backups:           /apps/backups\n")

        if version >= 16 {
            fmt.Println("  Replication:       Streaming with Physical Slots")
        } else {
            fmt.Println("  Replication:       Log-Shipping (archive-based)")
        }
        if version >= 18 {
            fmt.Println("  Checksums:         ON by default (PG 18+)")
        } else {
            fmt.Println("  Checksums:         Enable manually with pg_checksums --enable")
        }
    } else {
        fmt.Printf("\nPostgreSQL %d is NOT supported. Supported: %v\n", version, supported)
    }
}
```

---

## Session 2 (Hours 3–4): Data Structures — Slices, Maps, and Structs

### Core Concept

Go's `map` (dictionary), `slice` (dynamic array), and `struct` (custom type) are the three data structures you will use in every program. Maps and structs together replace Python dictionaries for structured data — but with compile-time type safety.

### Free Resources

1. **A Tour of Go — "More Types" section:** <https://go.dev/tour/moretypes/1>
2. **Go by Example — "Slices", "Maps", "Structs":** <https://gobyexample.com/>

### Key Concepts with Examples

#### Slices — Dynamic Arrays

```go
package main

import (
    "fmt"
    "sort"
    "strings"
)

func main() {
    // Create a slice (Go's dynamic array — like Python list)
    servers := []string{"192.168.1.10", "192.168.1.20", "192.168.1.30"}
    pgVersions := []int{15, 16, 17, 18}

    // Access elements (0-indexed)
    primary := servers[0]
    fmt.Println("Primary:", primary)

    // Length
    fmt.Printf("Total servers: %d\n", len(servers))

    // Append (like Python's list.append)
    servers = append(servers, "192.168.1.40")
    fmt.Println("After append:", servers)

    // Slicing (like Python's list[start:end])
    firstTwo := servers[:2]
    fmt.Println("First two:", firstTwo)
    modernPG := pgVersions[1:] // [16, 17, 18]
    fmt.Println("Modern PG:", modernPG)

    // Check if element exists (Go has no 'in' operator — must loop)
    target := "192.168.1.20"
    found := false
    for _, s := range servers {
        if s == target {
            found = true
            break
        }
    }
    fmt.Printf("Found %s: %t\n", target, found)

    // Sort
    sort.Strings(servers)
    sort.Ints(pgVersions)
    fmt.Println("Sorted servers:", servers)

    // Build paths from versions (like Python list comprehension)
    dataDirs := make([]string, 0, len(pgVersions))
    for _, v := range pgVersions {
        dataDirs = append(dataDirs, fmt.Sprintf("/apps/pgsql_data/%d", v))
    }
    fmt.Println("Data dirs:", strings.Join(dataDirs, ", "))

    // Filter (no built-in — use a loop)
    var streamingVersions []int
    for _, v := range pgVersions {
        if v >= 16 {
            streamingVersions = append(streamingVersions, v)
        }
    }
    fmt.Println("Streaming versions:", streamingVersions)
}
```

#### Maps — Key-Value Pairs (Go's Dictionary)

```go
package main

import "fmt"

func main() {
    // Create a map (like Python dict)
    serverConfig := map[string]interface{}{
        "host":       "192.168.1.10",
        "port":       5432,
        "version":    16,
        "is_primary": true,
        "data_dir":   "/apps/pgsql_data/16",
    }

    // Access values
    fmt.Println("Host:", serverConfig["host"])

    // Check if key exists (Go's "comma ok" idiom)
    if maxConn, ok := serverConfig["max_connections"]; ok {
        fmt.Println("Max connections:", maxConn)
    } else {
        fmt.Println("max_connections not set")
    }

    // Add/update
    serverConfig["max_connections"] = 200
    serverConfig["archive_dir"] = "/apps/pgsql_archives/"

    // Delete a key
    delete(serverConfig, "is_primary")

    // Loop through a map
    fmt.Println("\n=== Server Configuration ===")
    for key, value := range serverConfig {
        fmt.Printf("  %-20s: %v\n", key, value)
    }

    // Strongly-typed maps (preferred over interface{})
    // Map of stanza name -> data directory
    stanzaPaths := map[string]string{
        "pg15db": "/apps/pgsql_data/15",
        "pg16db": "/apps/pgsql_data/16",
        "pg17db": "/apps/pgsql_data/17",
        "pg18db": "/apps/pgsql_data/18",
    }

    for stanza, path := range stanzaPaths {
        fmt.Printf("  Stanza %-8s -> %s\n", stanza, path)
    }

    // Map of version -> replication type
    replTypes := map[int]string{
        15: "log-shipping",
        16: "streaming",
        17: "streaming",
        18: "streaming",
    }

    for ver, repl := range replTypes {
        fmt.Printf("  PG %d: %s\n", ver, repl)
    }
}
```

#### Structs — Custom Types (Go's Replacement for Classes)

```go
package main

import "fmt"

// Define a struct (like a Python class, but simpler — no inheritance)
type ClusterConfig struct {
    Stanza         string
    PgVersion      int
    DataDir        string
    ArchiveDir     string
    BackupDir      string
    LogDir         string
    PrimaryHost    string
    StandbyHost    string
    Replication    string
    RetentionFull  int
    RetentionDiff  int
}

// Method on a struct (like a Python class method)
func (c ClusterConfig) Summary() string {
    return fmt.Sprintf("Stanza: %s (PG %d) — %s replication\n"+
        "  Primary:  %s\n  Standby:  %s\n  Data:     %s",
        c.Stanza, c.PgVersion, c.Replication,
        c.PrimaryHost, c.StandbyHost, c.DataDir)
}

func (c ClusterConfig) BackupStrategy() string {
    if c.RetentionFull > 0 && c.RetentionDiff > 0 {
        return fmt.Sprintf("Full: %d retained, Diff: %d retained",
            c.RetentionFull, c.RetentionDiff)
    }
    return "Not configured"
}

func main() {
    // Create struct instances
    pg16 := ClusterConfig{
        Stanza:        "pg16db",
        PgVersion:     16,
        DataDir:       "/apps/pgsql_data/16",
        ArchiveDir:    "/apps/pgsql_archives/",
        BackupDir:     "/apps/backups",
        LogDir:        "/apps/logs",
        PrimaryHost:   "192.168.1.10",
        StandbyHost:   "192.168.1.20",
        Replication:   "streaming",
        RetentionFull: 4,
        RetentionDiff: 14,
    }

    pg15 := ClusterConfig{
        Stanza:        "pg15db",
        PgVersion:     15,
        DataDir:       "/apps/pgsql_data/15",
        ArchiveDir:    "/apps/pgsql_archives/",
        BackupDir:     "/apps/backups",
        LogDir:        "/apps/logs",
        PrimaryHost:   "192.168.1.30",
        StandbyHost:   "192.168.1.40",
        Replication:   "log-shipping",
        RetentionFull: 4,
        RetentionDiff: 14,
    }

    // Use struct methods
    clusters := []ClusterConfig{pg15, pg16}
    for _, c := range clusters {
        fmt.Println("\n" + c.Summary())
        fmt.Println("  Backup:  ", c.BackupStrategy())
    }

    // Access individual fields
    fmt.Printf("\nPG16 primary host: %s\n", pg16.PrimaryHost)
    fmt.Printf("PG16 data dir:     %s\n", pg16.DataDir)
}
```

#### Slice of Structs — The Most Common Pattern

```go
// You'll constantly work with slices of structs:
// - List of servers
// - List of backups
// - Query result rows

type BackupInfo struct {
    Label     string
    Type      string  // "full", "diff", "incr"
    SizeGB    float64
    RepoGB    float64
    Timestamp string
}

func main() {
    backups := []BackupInfo{
        {"20251118-020000F", "full", 100.0, 5.0, "2025-11-18 02:00:00"},
        {"20251119-020000D", "diff", 100.0, 1.0, "2025-11-19 02:00:00"},
        {"20251120-020000I", "incr", 100.0, 0.5, "2025-11-20 02:00:00"},
    }

    fmt.Println("=== pgBackRest Backups ===")
    for _, b := range backups {
        fmt.Printf("  %s [%s] DB: %.1f GB, Repo: %.1f GB (%s)\n",
            b.Label, b.Type, b.SizeGB, b.RepoGB, b.Timestamp)
    }
}
```

### Active Review (15 minutes)

```go
// Save as stanza_config.go
package main

import "fmt"

type Stanza struct {
    Name          string
    PgVersion     int
    PgPath        string
    Replication   string
    RetentionFull int
    RetentionDiff int
    Checksums     string
}

func (s Stanza) Display() {
    fmt.Printf("\n%-50s\n", "==================================================")
    fmt.Printf("Stanza: %s\n", s.Name)
    fmt.Printf("%-50s\n", "==================================================")
    fmt.Printf("  %-20s: %d\n", "PG Version", s.PgVersion)
    fmt.Printf("  %-20s: %s\n", "Data Path", s.PgPath)
    fmt.Printf("  %-20s: %s\n", "Replication", s.Replication)
    fmt.Printf("  %-20s: %d\n", "Retention Full", s.RetentionFull)
    fmt.Printf("  %-20s: %d\n", "Retention Diff", s.RetentionDiff)
    fmt.Printf("  %-20s: %s\n", "Checksums", s.Checksums)
}

func main() {
    stanzas := []Stanza{
        {"pg15db", 15, "/apps/pgsql_data/15", "log-shipping", 4, 14, "manual"},
        {"pg16db", 16, "/apps/pgsql_data/16", "streaming", 4, 14, "manual"},
        {"pg17db", 17, "/apps/pgsql_data/17", "streaming", 4, 14, "manual"},
        {"pg18db", 18, "/apps/pgsql_data/18", "streaming", 2, 7, "on_by_default"},
    }

    for _, s := range stanzas {
        s.Display()
    }

    // Find streaming stanzas
    fmt.Println("\n=== Streaming Replication Stanzas ===")
    for _, s := range stanzas {
        if s.Replication == "streaming" {
            fmt.Printf("  %s (PG %d)\n", s.Name, s.PgVersion)
        }
    }

    // Sum total retention
    totalFull := 0
    for _, s := range stanzas {
        totalFull += s.RetentionFull
    }
    fmt.Printf("\nTotal full backup retention: %d across %d stanzas\n",
        totalFull, len(stanzas))
}
```

---

## Session 3 (Hours 5–6): Functions, Multiple Return Values, and Error Handling

### Core Concept

Go functions return multiple values — the idiomatic pattern is `(result, error)`. This is the foundation of all Go error handling. There are no exceptions, no try/catch — every error is an explicit return value you must check. This forces robust code by design.

### Free Resources

1. **A Tour of Go — "Functions" + "Methods" sections**
2. **Go by Example — "Functions", "Multiple Return Values", "Errors":** <https://gobyexample.com/>

### Key Concepts with Examples

#### Functions with Multiple Return Values

```go
package main

import (
    "errors"
    "fmt"
)

// Go functions can return multiple values
// Convention: the LAST return value is 'error'
func getDataDir(pgVersion int) (string, error) {
    supported := []int{15, 16, 17, 18}
    for _, v := range supported {
        if v == pgVersion {
            return fmt.Sprintf("/apps/pgsql_data/%d", pgVersion), nil
        }
    }
    return "", fmt.Errorf("unsupported PostgreSQL version: %d", pgVersion)
}

func getReplicationType(pgVersion int) string {
    if pgVersion >= 16 {
        return "streaming"
    } else if pgVersion >= 13 {
        return "log-shipping"
    }
    return "unsupported"
}

// Return a struct from a function
type ClusterInfo struct {
    Stanza      string
    PgVersion   int
    DataDir     string
    ArchiveDir  string
    Replication string
}

func getClusterInfo(stanza string, pgVersion int) (ClusterInfo, error) {
    dataDir, err := getDataDir(pgVersion)
    if err != nil {
        return ClusterInfo{}, err // Return zero-value struct + error
    }

    return ClusterInfo{
        Stanza:      stanza,
        PgVersion:   pgVersion,
        DataDir:     dataDir,
        ArchiveDir:  "/apps/pgsql_archives/",
        Replication: getReplicationType(pgVersion),
    }, nil
}

func main() {
    // Always check errors!
    dataDir, err := getDataDir(16)
    if err != nil {
        fmt.Println("Error:", err)
        return
    }
    fmt.Println("Data dir:", dataDir)

    // Error case
    _, err = getDataDir(9)
    if err != nil {
        fmt.Println("Error:", err) // "unsupported PostgreSQL version: 9"
    }

    // Using the struct-returning function
    cluster, err := getClusterInfo("pg16db", 16)
    if err != nil {
        fmt.Println("Error:", err)
        return
    }
    fmt.Printf("Stanza: %s, Repl: %s, Dir: %s\n",
        cluster.Stanza, cluster.Replication, cluster.DataDir)

    // Custom errors
    var ErrNotFound = errors.New("resource not found")
    fmt.Println(ErrNotFound) // "resource not found"
}
```

#### Variadic Functions (Like Python's *args)

```go
package main

import (
    "fmt"
    "strings"
    "time"
)

// ... means "any number of arguments" (collected into a slice)
func logMessage(level string, messages ...string) {
    timestamp := time.Now().Format("2006-01-02 15:04:05")
    fullMsg := strings.Join(messages, " | ")
    fmt.Printf("[%s] [%s] %s\n", timestamp, level, fullMsg)
}

func main() {
    logMessage("INFO", "Backup started")
    logMessage("ERROR", "Restore failed", "Checksum mismatch", "stanza=pg16db")
    // [2025-11-18 10:30:45] [INFO] Backup started
    // [2025-11-18 10:30:45] [ERROR] Restore failed | Checksum mismatch | stanza=pg16db
}
```

#### Closures and Function Variables

```go
package main

import "fmt"

func main() {
    // Functions are first-class values in Go
    // You can assign them to variables and pass them around
    formatBytes := func(bytes int64) string {
        units := []string{"B", "KB", "MB", "GB", "TB"}
        size := float64(bytes)
        for _, unit := range units {
            if size < 1024 {
                return fmt.Sprintf("%.2f %s", size, unit)
            }
            size /= 1024
        }
        return fmt.Sprintf("%.2f PB", size)
    }

    fmt.Println(formatBytes(107374182400)) // "100.00 GB"
    fmt.Println(formatBytes(5368709120))   // "5.00 GB"
    fmt.Println(formatBytes(1048576))      // "1.00 MB"
}
```

#### defer — Cleanup That Always Runs (Like Python's finally)

```go
package main

import (
    "fmt"
    "os"
)

func readLogFile(path string) error {
    file, err := os.Open(path)
    if err != nil {
        return fmt.Errorf("cannot open %s: %w", path, err)
    }
    defer file.Close() // This ALWAYS runs when the function exits
                        // Even if there's a panic or early return

    buf := make([]byte, 1024)
    n, err := file.Read(buf)
    if err != nil {
        return fmt.Errorf("cannot read %s: %w", path, err)
    }
    fmt.Printf("Read %d bytes from %s\n", n, path)
    return nil
}

func main() {
    err := readLogFile("/apps/logs/postgresql-16.log")
    if err != nil {
        fmt.Println("Error:", err)
    }
}
```

### Active Review (15 minutes)

```go
// Save as pg_utils.go — your reusable utility package
package main

import (
    "fmt"
    "strings"
)

var supportedVersions = []int{15, 16, 17, 18}

func getDataDir(version int) (string, error) {
    for _, v := range supportedVersions {
        if v == version {
            return fmt.Sprintf("/apps/pgsql_data/%d", version), nil
        }
    }
    return "", fmt.Errorf("unsupported version: %d", version)
}

func getReplicationType(version int) string {
    if version >= 16 { return "streaming" }
    if version >= 13 { return "log-shipping" }
    return "unsupported"
}

func formatBytes(bytes int64) string {
    units := []string{"B", "KB", "MB", "GB", "TB"}
    size := float64(bytes)
    for _, unit := range units {
        if size < 1024 { return fmt.Sprintf("%.2f %s", size, unit) }
        size /= 1024
    }
    return fmt.Sprintf("%.2f PB", size)
}

func buildConnString(host string, port int, user, dbname string) string {
    parts := []string{
        fmt.Sprintf("host=%s", host),
        fmt.Sprintf("port=%d", port),
        fmt.Sprintf("user=%s", user),
        fmt.Sprintf("dbname=%s", dbname),
    }
    return strings.Join(parts, " ")
}

func main() {
    for _, ver := range supportedVersions {
        dir, err := getDataDir(ver)
        if err != nil {
            fmt.Printf("PG %d: ERROR — %s\n", ver, err)
            continue
        }
        repl := getReplicationType(ver)
        fmt.Printf("PG %d: %s (%s)\n", ver, dir, repl)
    }

    fmt.Println("\nFormatted sizes:")
    fmt.Println("  ", formatBytes(107374182400))
    fmt.Println("  ", formatBytes(5368709120))

    conn := buildConnString("192.168.1.10", 5432, "postgres", "postgres")
    fmt.Println("\nConnection:", conn)
}
```

---

## Session 4 (Hours 7–8): File I/O and Regular Expressions

### Core Concept

Reading log files, parsing configs, extracting patterns from PostgreSQL logs — essential for DBA automation.

### Free Resources

1. **Go by Example — "Reading Files", "Writing Files", "Regular Expressions"**
2. **Official regexp package docs:** <https://pkg.go.dev/regexp>

### Key Concepts with Examples

#### Reading Files

```go
package main

import (
    "bufio"
    "fmt"
    "os"
    "strings"
)

func main() {
    // Read entire file
    content, err := os.ReadFile("/apps/logs/postgresql-16.log")
    if err != nil {
        fmt.Println("Error:", err)
        return
    }
    fmt.Printf("File size: %d bytes\n", len(content))

    // Read line by line (memory-efficient for large logs)
    file, err := os.Open("/apps/logs/postgresql-16.log")
    if err != nil {
        fmt.Println("Error:", err)
        return
    }
    defer file.Close()

    scanner := bufio.NewScanner(file)
    lineNum := 0
    errorCount := 0

    for scanner.Scan() {
        lineNum++
        line := scanner.Text()

        if strings.Contains(line, "ERROR") || strings.Contains(line, "FATAL") {
            errorCount++
            fmt.Printf("  Line %d: %s\n", lineNum, line)
        }
    }

    if err := scanner.Err(); err != nil {
        fmt.Println("Scanner error:", err)
    }
    fmt.Printf("\nTotal lines: %d, Errors: %d\n", lineNum, errorCount)
}
```

#### Writing Files

```go
package main

import (
    "fmt"
    "os"
    "time"
)

func main() {
    // Write a new file
    report := fmt.Sprintf("PostgreSQL Error Summary\n"+
        "Generated: %s\n"+
        "========================================\n\n"+
        "  - ERROR: relation not found\n"+
        "  - FATAL: password authentication failed\n",
        time.Now().Format("2006-01-02 15:04:05"))

    err := os.WriteFile("/apps/logs/error_summary.txt", []byte(report), 0644)
    if err != nil {
        fmt.Println("Write error:", err)
        return
    }
    fmt.Println("Report written successfully")

    // Append to a file
    file, err := os.OpenFile("/apps/logs/error_summary.txt",
        os.O_APPEND|os.O_WRONLY, 0644)
    if err != nil {
        fmt.Println("Error:", err)
        return
    }
    defer file.Close()

    fmt.Fprintf(file, "\nAppended at: %s\n",
        time.Now().Format("2006-01-02 15:04:05"))
}
```

#### Regular Expressions

```go
package main

import (
    "fmt"
    "regexp"
)

func main() {
    logLine := `2025-11-18 10:30:45.123 UTC [12345] ERROR:  relation "users" does not exist`

    // Compile regex pattern (do this once, reuse the compiled pattern)
    tsPattern := regexp.MustCompile(`(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})`)
    pidPattern := regexp.MustCompile(`\[(\d+)\]`)
    ipPattern := regexp.MustCompile(`\d+\.\d+\.\d+\.\d+`)

    // FindString — first match
    timestamp := tsPattern.FindString(logLine)
    fmt.Println("Timestamp:", timestamp)

    // FindStringSubmatch — first match with capture groups
    pidMatch := pidPattern.FindStringSubmatch(logLine)
    if len(pidMatch) > 1 {
        fmt.Println("PID:", pidMatch[1]) // pidMatch[0] = full match, [1] = group 1
    }

    // FindAllString — all matches
    text := "Servers: 192.168.1.10, 192.168.1.20, 10.0.0.5"
    ips := ipPattern.FindAllString(text, -1) // -1 = find all
    fmt.Println("IP addresses:", ips)

    // ReplaceAllString
    configLine := "primary_conninfo = 'host=192.168.1.10 password=secret123'"
    pwPattern := regexp.MustCompile(`password=\S+`)
    masked := pwPattern.ReplaceAllString(configLine, "password=****")
    fmt.Println("Masked:", masked)

    // Practical log parser
    logPattern := regexp.MustCompile(
        `(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.\d+ \w+ \[(\d+)\] (\w+):\s+(.*)`)

    lines := []string{
        `2025-11-18 10:32:15.789 UTC [23456] ERROR:  relation "important_table" does not exist`,
        `2025-11-18 10:33:00.012 UTC [23457] FATAL:  password authentication failed`,
    }

    fmt.Println("\n=== Parsed Errors ===")
    for _, line := range lines {
        match := logPattern.FindStringSubmatch(line)
        if len(match) >= 5 {
            ts, pid, level, msg := match[1], match[2], match[3], match[4]
            fmt.Printf("  [%s] %s (PID %s)\n          %s\n", level, ts, pid, msg)
        }
    }
}
```

### Active Review (15 minutes)

```go
// Save as log_parser.go
package main

import (
    "bufio"
    "fmt"
    "os"
    "regexp"
    "strings"
)

func parseLogFile(path string) {
    file, err := os.Open(path)
    if err != nil {
        fmt.Printf("Cannot open %s: %v\n", path, err)
        return
    }
    defer file.Close()

    pattern := regexp.MustCompile(
        `(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\.\d+ \w+ \[(\d+)\] (\w+):\s+(.*)`)

    scanner := bufio.NewScanner(file)
    errors, fatals := 0, 0

    for scanner.Scan() {
        line := scanner.Text()
        if !strings.Contains(line, "ERROR") && !strings.Contains(line, "FATAL") {
            continue
        }

        match := pattern.FindStringSubmatch(line)
        if len(match) >= 5 {
            level := match[3]
            if level == "ERROR" { errors++ }
            if level == "FATAL" { fatals++ }
            fmt.Printf("  [%s] %s (PID %s): %s\n", level, match[1], match[2], match[4])
        }
    }

    fmt.Printf("\nSummary: %d ERRORs, %d FATALs\n", errors, fatals)
}

func main() {
    if len(os.Args) < 2 {
        fmt.Println("Usage: go run log_parser.go <log_file_path>")
        fmt.Println("Example: go run log_parser.go /apps/logs/postgresql-16.log")
        return
    }
    parseLogFile(os.Args[1])
}
```

---

## Session 5 (Hours 9–10): Running External Commands — os/exec

### Core Concept

Go's `os/exec` package replaces Python's `subprocess`. This is how you wrap `pg_ctl`, `pgbackrest`, `psql`, and system commands in Go with proper error handling and timeout support.

### Free Resources

1. **Go by Example — "Spawning Processes", "Exec'ing Processes"**
2. **Official os/exec docs:** <https://pkg.go.dev/os/exec>

### Key Concepts with Examples

```go
package main

import (
    "context"
    "fmt"
    "os/exec"
    "strings"
    "time"
)

// Basic command execution
func runCommand(name string, args ...string) (string, error) {
    cmd := exec.Command(name, args...)
    output, err := cmd.CombinedOutput() // stdout + stderr
    return strings.TrimSpace(string(output)), err
}

// Command with timeout
func runCommandWithTimeout(timeout time.Duration, name string, args ...string) (string, error) {
    ctx, cancel := context.WithTimeout(context.Background(), timeout)
    defer cancel()

    cmd := exec.CommandContext(ctx, name, args...)
    output, err := cmd.CombinedOutput()

    if ctx.Err() == context.DeadlineExceeded {
        return "", fmt.Errorf("command timed out after %s", timeout)
    }
    return strings.TrimSpace(string(output)), err
}

// Run psql query
func runPsql(host string, port int, query string) (string, error) {
    return runCommandWithTimeout(60*time.Second,
        "psql",
        "-h", host,
        "-p", fmt.Sprintf("%d", port),
        "-U", "postgres",
        "-d", "postgres",
        "-t", "-A",      // tuples-only, unaligned
        "-c", query,
    )
}

// Run pgBackRest command
func runPgBackRest(stanza, command string, extraArgs ...string) (string, error) {
    args := []string{fmt.Sprintf("--stanza=%s", stanza), command}
    args = append(args, extraArgs...)
    return runCommandWithTimeout(3600*time.Second, "pgbackrest", args...)
}

func main() {
    // Check if PostgreSQL is running
    output, err := runCommand("pg_isready", "-h", "192.168.1.10", "-p", "5432")
    if err != nil {
        fmt.Println("PostgreSQL is NOT reachable:", output)
    } else {
        fmt.Println("PostgreSQL is reachable:", output)
    }

    // Run a psql query
    version, err := runPsql("192.168.1.10", 5432, "SELECT version()")
    if err != nil {
        fmt.Println("psql error:", err)
    } else {
        fmt.Println("Version:", version)
    }

    // Get pgBackRest info
    info, err := runPgBackRest("pg16db", "info")
    if err != nil {
        fmt.Println("pgBackRest error:", err)
    } else {
        fmt.Println(info)
    }

    // Separate stdout and stderr
    cmd := exec.Command("pgbackrest", "--stanza=pg16db", "verify")
    var stdout, stderr strings.Builder
    cmd.Stdout = &stdout
    cmd.Stderr = &stderr

    err = cmd.Run()
    if err != nil {
        fmt.Printf("verify failed (rc=%v): %s\n", err, stderr.String())
    } else {
        fmt.Println("verify passed:", stdout.String())
    }
}
```

### Active Review (15 minutes)

```go
// Save as pg_command.go
package main

import (
    "context"
    "fmt"
    "os/exec"
    "strings"
    "time"
)

type CommandResult struct {
    Command    string
    Stdout     string
    Stderr     string
    ExitCode   int
    Duration   time.Duration
    Success    bool
}

func executeCommand(timeout time.Duration, name string, args ...string) CommandResult {
    start := time.Now()
    ctx, cancel := context.WithTimeout(context.Background(), timeout)
    defer cancel()

    cmd := exec.CommandContext(ctx, name, args...)
    var stdout, stderr strings.Builder
    cmd.Stdout = &stdout
    cmd.Stderr = &stderr

    err := cmd.Run()
    duration := time.Since(start)

    result := CommandResult{
        Command:  name + " " + strings.Join(args, " "),
        Stdout:   strings.TrimSpace(stdout.String()),
        Stderr:   strings.TrimSpace(stderr.String()),
        Duration: duration,
        Success:  err == nil,
    }

    if exitErr, ok := err.(*exec.ExitError); ok {
        result.ExitCode = exitErr.ExitCode()
    }

    return result
}

func main() {
    result := executeCommand(10*time.Second, "pg_isready", "-h", "localhost")
    fmt.Printf("Command:  %s\n", result.Command)
    fmt.Printf("Success:  %t\n", result.Success)
    fmt.Printf("Duration: %s\n", result.Duration)
    fmt.Printf("Output:   %s\n", result.Stdout)
    if !result.Success {
        fmt.Printf("Error:    %s\n", result.Stderr)
    }
}
```

---

## Session 6 (Hours 11–12): JSON and YAML Processing

### Core Concept

Go has built-in JSON support via `encoding/json`. For YAML, use `gopkg.in/yaml.v3`. The key difference from Python: Go uses struct tags to map JSON/YAML keys to struct fields.

### Free Resources

1. **Go by Example — "JSON":** <https://gobyexample.com/json>
2. **Official encoding/json docs:** <https://pkg.go.dev/encoding/json>

### Key Concepts with Examples

```go
package main

import (
    "encoding/json"
    "fmt"
    "time"
)

// Struct tags tell Go how to map JSON keys to struct fields
// The `json:"..."` tag maps the JSON key name
type BackupInfo struct {
    Label     string  `json:"label"`
    Type      string  `json:"type"`
    Timestamp struct {
        Start int64 `json:"start"`
        Stop  int64 `json:"stop"`
    } `json:"timestamp"`
    Info struct {
        Size       int64 `json:"size"`
        Repository struct {
            Size int64 `json:"size"`
        } `json:"repository"`
    } `json:"info"`
}

type StanzaInfo struct {
    Name   string `json:"name"`
    Status struct {
        Code    int    `json:"code"`
        Message string `json:"message"`
    } `json:"status"`
    Backup []BackupInfo `json:"backup"`
}

func main() {
    // Simulated pgBackRest JSON output
    jsonData := `[{
        "name": "pg16db",
        "status": {"code": 0, "message": "ok"},
        "backup": [
            {
                "label": "20251118-020000F",
                "type": "full",
                "timestamp": {"start": 1731895200, "stop": 1731896100},
                "info": {"size": 107374182400, "repository": {"size": 5368709120}}
            },
            {
                "label": "20251119-020000D",
                "type": "diff",
                "timestamp": {"start": 1731981600, "stop": 1731982200},
                "info": {"size": 107374182400, "repository": {"size": 1073741824}}
            }
        ]
    }]`

    // Parse JSON into Go structs
    var stanzas []StanzaInfo
    err := json.Unmarshal([]byte(jsonData), &stanzas)
    if err != nil {
        fmt.Println("JSON parse error:", err)
        return
    }

    for _, s := range stanzas {
        fmt.Printf("Stanza: %s (Status: %s)\n", s.Name, s.Status.Message)
        for _, b := range s.Backup {
            ts := time.Unix(b.Timestamp.Stop, 0)
            dbGB := float64(b.Info.Size) / 1024 / 1024 / 1024
            repoGB := float64(b.Info.Repository.Size) / 1024 / 1024 / 1024
            fmt.Printf("  %s [%s] %s — DB: %.1f GB, Repo: %.1f GB\n",
                b.Label, b.Type, ts.Format("2006-01-02 15:04"), dbGB, repoGB)
        }
    }

    // Go struct -> JSON (marshaling)
    config := map[string]interface{}{
        "stanza":      "pg17db",
        "pg_path":     "/apps/pgsql_data/17",
        "archive_dir": "/apps/pgsql_archives/",
        "backup_dir":  "/apps/backups",
    }

    jsonOutput, err := json.MarshalIndent(config, "", "  ")
    if err != nil {
        fmt.Println("Marshal error:", err)
        return
    }
    fmt.Println("\nGenerated JSON:")
    fmt.Println(string(jsonOutput))
}
```

### Active Review (15 minutes)

```go
// Save as parse_backup.go
package main

import (
    "encoding/json"
    "fmt"
    "time"
)

type Backup struct {
    Label string `json:"label"`
    Type  string `json:"type"`
    TS    struct {
        Stop int64 `json:"stop"`
    } `json:"timestamp"`
    Info struct {
        Size int64 `json:"size"`
        Repo struct {
            Size int64 `json:"size"`
        } `json:"repository"`
    } `json:"info"`
}

type Stanza struct {
    Name   string   `json:"name"`
    Backup []Backup `json:"backup"`
}

func main() {
    data := `[{"name":"pg16db","backup":[
      {"label":"20251118-020000F","type":"full",
       "timestamp":{"stop":1731896100},
       "info":{"size":107374182400,"repository":{"size":5368709120}}},
      {"label":"20251119-020000D","type":"diff",
       "timestamp":{"stop":1731982200},
       "info":{"size":107374182400,"repository":{"size":1073741824}}}
    ]}]`

    var stanzas []Stanza
    if err := json.Unmarshal([]byte(data), &stanzas); err != nil {
        fmt.Println("Error:", err)
        return
    }

    for _, s := range stanzas {
        fmt.Printf("Stanza: %s (%d backups)\n", s.Name, len(s.Backup))
        for _, b := range s.Backup {
            ts := time.Unix(b.TS.Stop, 0).Format("2006-01-02 15:04")
            repoGB := float64(b.Info.Repo.Size) / 1024 / 1024 / 1024
            fmt.Printf("  %s [%-4s] %s — Repo: %.2f GB\n",
                b.Label, b.Type, ts, repoGB)
        }
    }
}
```

---

## Session 7 (Hours 13–14): Database Access — database/sql + pgx

### Core Concept

Go has a standard `database/sql` interface. The `pgx` driver is the best PostgreSQL driver. Connect, query, scan results into structs, and handle transactions.

### Free Resources

1. **pgx docs:** <https://pkg.go.dev/github.com/jackc/pgx/v5>
2. **Go wiki — SQL Database:** <https://go.dev/doc/database/>

### Key Concepts with Examples

```go
package main

import (
    "context"
    "fmt"
    "log"
    "time"

    "github.com/jackc/pgx/v5/pgxpool"
)

// Initialize first: go mod init pg_monitor && go get github.com/jackc/pgx/v5

type ReplicationStatus struct {
    ApplicationName string
    ClientAddr      string
    State           string
    LagBytes        int64
    Lag             string
    SyncState       string
}

func main() {
    connStr := "host=192.168.1.10 port=5432 user=postgres dbname=postgres"

    // Create a connection pool (preferred for production)
    ctx := context.Background()
    pool, err := pgxpool.New(ctx, connStr)
    if err != nil {
        log.Fatalf("Cannot connect: %v", err)
    }
    defer pool.Close()

    // Simple query
    var version string
    err = pool.QueryRow(ctx, "SELECT version()").Scan(&version)
    if err != nil {
        log.Fatalf("Query failed: %v", err)
    }
    fmt.Println("PostgreSQL:", version[:60])

    // Check if primary or standby
    var isStandby bool
    pool.QueryRow(ctx, "SELECT pg_is_in_recovery()").Scan(&isStandby)
    if isStandby {
        fmt.Println("Role: Standby")
    } else {
        fmt.Println("Role: Primary")
    }

    // Query multiple rows — replication status
    rows, err := pool.Query(ctx, `
        SELECT application_name, client_addr::text, state,
               pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
               pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag,
               sync_state
        FROM pg_stat_replication`)
    if err != nil {
        log.Fatalf("Replication query failed: %v", err)
    }
    defer rows.Close()

    fmt.Println("\n=== Replication Status ===")
    for rows.Next() {
        var r ReplicationStatus
        err := rows.Scan(&r.ApplicationName, &r.ClientAddr, &r.State,
            &r.LagBytes, &r.Lag, &r.SyncState)
        if err != nil {
            log.Printf("Scan error: %v", err)
            continue
        }
        fmt.Printf("  %s (%s): state=%s, lag=%s, sync=%s\n",
            r.ApplicationName, r.ClientAddr, r.State, r.Lag, r.SyncState)
    }

    // Parameterized query (safe from SQL injection)
    tableName := "pg_stat_user_tables"
    var rowCount int64
    err = pool.QueryRow(ctx,
        "SELECT count(*) FROM pg_tables WHERE tablename = $1",
        tableName).Scan(&rowCount)
    if err != nil {
        log.Printf("Count query error: %v", err)
    } else {
        fmt.Printf("\nTable '%s' exists: %t\n", tableName, rowCount > 0)
    }

    // Query with timeout
    queryCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    var dbSize string
    err = pool.QueryRow(queryCtx,
        "SELECT pg_size_pretty(pg_database_size(current_database()))").Scan(&dbSize)
    if err != nil {
        log.Printf("Size query error: %v", err)
    } else {
        fmt.Println("Database size:", dbSize)
    }
}
```

### Active Review (15 minutes)

```go
// Save as cluster_health.go
// go mod init cluster_health && go get github.com/jackc/pgx/v5
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/jackc/pgx/v5/pgxpool"
)

func checkCluster(host string, port int) {
    connStr := fmt.Sprintf("host=%s port=%d user=postgres dbname=postgres "+
        "connect_timeout=5", host, port)

    ctx := context.Background()
    pool, err := pgxpool.New(ctx, connStr)
    if err != nil {
        fmt.Printf("  %s:%d — OFFLINE (%v)\n", host, port, err)
        return
    }
    defer pool.Close()

    var isStandby bool
    pool.QueryRow(ctx, "SELECT pg_is_in_recovery()").Scan(&isStandby)
    role := "Primary"
    if isStandby {
        role = "Standby"
    }
    fmt.Printf("  %s:%d — ONLINE (%s)\n", host, port, role)
}

func main() {
    servers := []struct {
        Host string
        Port int
    }{
        {"192.168.1.10", 5432},
        {"192.168.1.20", 5432},
    }

    fmt.Println("=== Cluster Health Check ===")
    for _, s := range servers {
        checkCluster(s.Host, s.Port)
    }
}
```

---

## Session 8 (Hours 15–16): HTTP Clients and Servers

### Core Concept

Go's `net/http` package is production-grade out of the box — it powers most Go web services with zero external dependencies. Learn both client (calling APIs) and server (building APIs).

### Free Resources

1. **Go by Example — "HTTP Client", "HTTP Server"**
2. **Official net/http docs:** <https://pkg.go.dev/net/http>

### Key Concepts with Examples

```go
package main

import (
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "time"
)

// HTTP Client — making requests
func healthCheck(url string) (int, time.Duration, error) {
    client := &http.Client{Timeout: 5 * time.Second}

    start := time.Now()
    resp, err := client.Get(url)
    duration := time.Since(start)

    if err != nil {
        return 0, duration, err
    }
    defer resp.Body.Close()

    return resp.StatusCode, duration, nil
}

// GET with JSON parsing
func getJSON(url string, target interface{}) error {
    client := &http.Client{Timeout: 10 * time.Second}
    resp, err := client.Get(url)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        body, _ := io.ReadAll(resp.Body)
        return fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
    }

    return json.NewDecoder(resp.Body).Decode(target)
}

func main() {
    // Health check
    status, duration, err := healthCheck("https://httpbin.org/get")
    if err != nil {
        fmt.Println("Health check failed:", err)
    } else {
        fmt.Printf("Status: %d, Duration: %s\n", status, duration)
    }

    // Parse JSON response
    var result map[string]interface{}
    err = getJSON("https://httpbin.org/get", &result)
    if err != nil {
        fmt.Println("GET error:", err)
    } else {
        fmt.Printf("Origin: %v\n", result["origin"])
    }
}
```

#### HTTP Server — Building a Monitoring API

```go
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "time"
)

func healthHandler(w http.ResponseWriter, r *http.Request) {
    response := map[string]interface{}{
        "status":    "ok",
        "timestamp": time.Now().Format(time.RFC3339),
        "service":   "pg-monitor-api",
    }
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func clustersHandler(w http.ResponseWriter, r *http.Request) {
    clusters := map[string]interface{}{
        "archive_dir": "/apps/pgsql_archives/",
        "log_dir":     "/apps/logs",
        "backup_dir":  "/apps/backups",
        "clusters": map[string]interface{}{
            "pg16db": map[string]string{
                "version": "16", "path": "/apps/pgsql_data/16", "replication": "streaming",
            },
            "pg18db": map[string]string{
                "version": "18", "path": "/apps/pgsql_data/18", "replication": "streaming",
            },
        },
    }
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(clusters)
}

func main() {
    http.HandleFunc("/health", healthHandler)
    http.HandleFunc("/config/clusters", clustersHandler)

    fmt.Println("Starting pg-monitor API on :8080...")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
// Test: curl http://localhost:8080/health
// Test: curl http://localhost:8080/config/clusters
```

### Active Review (15 minutes)

Build and run the HTTP server above, then test with `curl`. Add one more endpoint that returns a mock backup info JSON response.

---

## Session 9 (Hours 17–18): Building CLI Tools — cobra and flag

### Core Concept

Go's `flag` package handles basic CLI flags. For professional multi-command CLIs (like `kubectl`, `docker`), use the `cobra` library. Since most Go infrastructure tools use cobra, learning it is high-value.

### Free Resources

1. **Go by Example — "Command-Line Flags"**
2. **Cobra docs:** <https://github.com/spf13/cobra>

### Key Concepts with Examples

```go
// Save as main.go
// go mod init pg_health && go get github.com/spf13/cobra
package main

import (
    "fmt"
    "os"
    "os/exec"
    "strings"

    "github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
    Use:   "pg_health",
    Short: "PostgreSQL Health Check CLI Tool",
    Long:  "A CLI tool for PostgreSQL health monitoring and pgBackRest operations.",
}

var checkCmd = &cobra.Command{
    Use:   "check",
    Short: "Check PostgreSQL server status",
    Run: func(cmd *cobra.Command, args []string) {
        host, _ := cmd.Flags().GetString("host")
        port, _ := cmd.Flags().GetInt("port")

        fmt.Printf("Checking PostgreSQL on %s:%d...\n", host, port)

        result, err := exec.Command("pg_isready",
            "-h", host, "-p", fmt.Sprintf("%d", port)).CombinedOutput()

        if err != nil {
            fmt.Printf("  Status:  OFFLINE\n  Error:   %s\n", strings.TrimSpace(string(result)))
        } else {
            fmt.Printf("  Status:  ONLINE\n  Output:  %s\n", strings.TrimSpace(string(result)))
        }
    },
}

var backupInfoCmd = &cobra.Command{
    Use:   "backup-info",
    Short: "Show pgBackRest backup info",
    Run: func(cmd *cobra.Command, args []string) {
        stanza, _ := cmd.Flags().GetString("stanza")
        asJSON, _ := cmd.Flags().GetBool("json")

        cmdArgs := []string{fmt.Sprintf("--stanza=%s", stanza), "info"}
        if asJSON {
            cmdArgs = append(cmdArgs, "--output=json")
        }

        result, err := exec.Command("pgbackrest", cmdArgs...).CombinedOutput()
        if err != nil {
            fmt.Printf("ERROR: %s\n", strings.TrimSpace(string(result)))
            return
        }
        fmt.Println(string(result))
    },
}

var logErrorsCmd = &cobra.Command{
    Use:   "log-errors",
    Short: "Parse PostgreSQL logs for errors",
    Run: func(cmd *cobra.Command, args []string) {
        logDir, _ := cmd.Flags().GetString("log-dir")
        severity, _ := cmd.Flags().GetString("severity")

        fmt.Printf("Searching for %s in %s...\n", severity, logDir)
        // (Add file reading logic from Session 4 here)
    },
}

func init() {
    checkCmd.Flags().String("host", "localhost", "PostgreSQL host")
    checkCmd.Flags().Int("port", 5432, "PostgreSQL port")

    backupInfoCmd.Flags().String("stanza", "", "pgBackRest stanza name")
    backupInfoCmd.MarkFlagRequired("stanza")
    backupInfoCmd.Flags().Bool("json", false, "Output in JSON format")

    logErrorsCmd.Flags().String("log-dir", "/apps/logs", "Log directory")
    logErrorsCmd.Flags().String("severity", "ERROR", "Severity: ERROR, FATAL, WARNING")

    rootCmd.AddCommand(checkCmd, backupInfoCmd, logErrorsCmd)
}

func main() {
    if err := rootCmd.Execute(); err != nil {
        os.Exit(1)
    }
}
```

```bash
# Build and test
go build -o pg_health .
./pg_health --help
./pg_health check --host 192.168.1.10 --port 5432
./pg_health backup-info --stanza pg16db --json
./pg_health log-errors --severity FATAL
```

### Active Review (15 minutes)

Build the CLI tool above, compile it to a single binary, and copy it to another server. It runs with zero dependencies — this is Go's killer feature for DBA tooling.

---

## Session 10 (Hours 19–20): Concurrency — Goroutines and Channels

### Core Concept

Concurrency is Go's superpower. Goroutines are lightweight threads that cost almost nothing to create. Channels allow goroutines to communicate safely. This is how you build parallel health checks, concurrent backups, and monitoring daemons.

### Free Resources

1. **A Tour of Go — "Concurrency" section:** <https://go.dev/tour/concurrency/1>
2. **Go by Example — "Goroutines", "Channels", "WaitGroups"**

### Key Concepts with Examples

```go
package main

import (
    "fmt"
    "os/exec"
    "sync"
    "time"
)

// Check multiple servers in parallel
type ServerStatus struct {
    Host     string
    Port     int
    Online   bool
    Duration time.Duration
    Error    string
}

func checkServer(host string, port int) ServerStatus {
    start := time.Now()
    cmd := exec.Command("pg_isready", "-h", host, "-p", fmt.Sprintf("%d", port))
    err := cmd.Run()

    status := ServerStatus{
        Host:     host,
        Port:     port,
        Online:   err == nil,
        Duration: time.Since(start),
    }
    if err != nil {
        status.Error = err.Error()
    }
    return status
}

func main() {
    servers := []struct {
        Host string
        Port int
    }{
        {"192.168.1.10", 5432},
        {"192.168.1.20", 5432},
        {"192.168.1.30", 5432},
        {"192.168.1.40", 5432},
    }

    // Sequential check (slow — one after another)
    fmt.Println("=== Sequential Check ===")
    seqStart := time.Now()
    for _, s := range servers {
        status := checkServer(s.Host, s.Port)
        fmt.Printf("  %s:%d — online=%t (%s)\n",
            status.Host, status.Port, status.Online, status.Duration)
    }
    fmt.Printf("  Total time: %s\n\n", time.Since(seqStart))

    // Parallel check with goroutines + WaitGroup (FAST!)
    fmt.Println("=== Parallel Check ===")
    parStart := time.Now()

    var wg sync.WaitGroup
    results := make([]ServerStatus, len(servers))

    for i, s := range servers {
        wg.Add(1)
        go func(index int, host string, port int) {
            defer wg.Done()
            results[index] = checkServer(host, port)
        }(i, s.Host, s.Port)
    }

    wg.Wait() // Block until all goroutines finish

    for _, status := range results {
        emoji := "ONLINE"
        if !status.Online {
            emoji = "OFFLINE"
        }
        fmt.Printf("  %s:%d — %s (%s)\n",
            status.Host, status.Port, emoji, status.Duration)
    }
    fmt.Printf("  Total time: %s\n", time.Since(parStart))

    // With channels — a goroutine sends results through a channel
    fmt.Println("\n=== Channel-Based Check ===")
    ch := make(chan ServerStatus, len(servers))

    for _, s := range servers {
        go func(host string, port int) {
            ch <- checkServer(host, port) // Send result to channel
        }(s.Host, s.Port)
    }

    // Receive results from channel
    for range servers {
        status := <-ch // Receive from channel
        fmt.Printf("  %s:%d — online=%t\n",
            status.Host, status.Port, status.Online)
    }

    // Periodic health monitor (daemon pattern)
    fmt.Println("\n=== Health Monitor (will run 3 cycles) ===")
    ticker := time.NewTicker(2 * time.Second)
    defer ticker.Stop()

    cycles := 0
    for range ticker.C {
        cycles++
        fmt.Printf("Cycle %d: checking servers...\n", cycles)
        // (Add parallel check logic here)
        if cycles >= 3 {
            break
        }
    }
}
```

### Active Review (15 minutes)

```go
// Save as parallel_check.go
package main

import (
    "fmt"
    "os/exec"
    "sync"
    "time"
)

type CheckResult struct {
    Name     string
    Host     string
    Port     int
    Online   bool
    Duration time.Duration
}

func checkPg(name, host string, port int) CheckResult {
    start := time.Now()
    err := exec.Command("pg_isready", "-h", host, "-p",
        fmt.Sprintf("%d", port)).Run()
    return CheckResult{
        Name: name, Host: host, Port: port,
        Online: err == nil, Duration: time.Since(start),
    }
}

func main() {
    clusters := []struct{ Name, Host string; Port int }{
        {"pg15db-primary", "192.168.1.10", 5432},
        {"pg15db-standby", "192.168.1.20", 5432},
        {"pg16db-primary", "192.168.1.30", 5432},
        {"pg16db-standby", "192.168.1.40", 5432},
    }

    start := time.Now()
    var wg sync.WaitGroup
    results := make([]CheckResult, len(clusters))

    for i, c := range clusters {
        wg.Add(1)
        go func(idx int, name, host string, port int) {
            defer wg.Done()
            results[idx] = checkPg(name, host, port)
        }(i, c.Name, c.Host, c.Port)
    }
    wg.Wait()

    fmt.Println("=== Cluster Health Dashboard ===")
    fmt.Printf("%-25s %-18s %s   %s\n", "CLUSTER", "HOST", "STATUS", "LATENCY")
    fmt.Println(strings.Repeat("-", 70))
    for _, r := range results {
        status := "ONLINE "
        if !r.Online { status = "OFFLINE" }
        fmt.Printf("%-25s %-18s %s   %s\n",
            r.Name, fmt.Sprintf("%s:%d", r.Host, r.Port),
            status, r.Duration.Round(time.Millisecond))
    }
    fmt.Printf("\nTotal check time: %s (parallel)\n", time.Since(start))
}
```

Note: Add `"strings"` to imports for the `strings.Repeat` call above.

---

## Summary — The 20% of Go That Drives 80% of DBA/DevOps Results

| Concept | Why It Matters | Python Equivalent |
|---|---|---|
| `fmt.Sprintf` / `fmt.Printf` | Output formatting, path construction | f-strings |
| `map[K]V` | Config data, JSON mapping | `dict` |
| Structs + methods | Typed data models, replacing classes | `class` / `dataclass` |
| Multiple return `(result, error)` | Every function returns errors explicitly | `try/except` |
| `os/exec` | Running pg_ctl, pgbackrest, psql | `subprocess.run` |
| `encoding/json` | Parsing pgBackRest output, API data | `json` module |
| `bufio.Scanner` | Line-by-line log file parsing | `for line in file` |
| `regexp` | Extracting patterns from logs | `re` module |
| `cobra` | Professional CLI tools | `argparse` |
| `net/http` | HTTP servers and clients | `requests` + `FastAPI` |
| Goroutines + `sync.WaitGroup` | Parallel server checks, concurrent ops | `threading` / `asyncio` |
| `go build` → single binary | Deploy to any Linux box with zero deps | Not possible in Python |

**Go's killer advantage for DBA work:** You write the tool once, run `go build`, and get a single binary that runs on any Linux server with zero dependencies. No Python version mismatches, no pip install, no virtual environments. Copy the binary and run it. This matters enormously for production infrastructure tooling.

**After each session:** Apply what you learned to your real environment. Build a real server health checker, parse a real log file, wrap a real pgbackrest command. The compiled binary you produce is immediately deployable to production.
