# IPLookup

A PowerShell toolkit for parsing, normalizing, and comparing IP address
expressions across CSV files. Supports single IPs, ranges, and CIDR
notation, with structured logging and an automated Pester test suite.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](#)
[![Pester Tests](https://img.shields.io/badge/tests-pester-brightgreen)](#)

Short highlights:

- Parse and normalize IP expressions (single IP, range, CIDR)
- Compare exports to find Exact matches, Overlaps, and Missing entries
- Generate CSV reports and detailed logs

---

## Table of contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Project Structure](#project-structure)
- [Commands &amp; Examples](#commands--examples)
- [Design Document](#design-document)

---

## Quick Start

Requirements:

- Windows PowerShell 5.1 (project uses classes)
- Pester (for running tests; v5+ recommended)

Install / run locally:

```powershell
# Load helpers interactively
. .\src\AllClasses.ps1

# Run unit tests (writes cleaned log to logs/)
.\Run-Tests.ps1

# Run a batch comparison across connector exports
.\Run-ConnectorComparisons.ps1

# Analyze each export for local issues (overlaps, tiny ranges)
.\Run-ServerAnalysis.ps1.ps1
```

---

## Features

- Expression parsing: single IPs, ranges, CIDR blocks
- Deterministic normalization to numeric Start/End for comparisons
- Pairwise comparison producing CSV reports with line numbers
- Configurable logging to console and/or file with simple rotation
- Pester test harness and a small interactive `TestHarness.ps1`

---

## Project Structure

- `data/` — example data files
- `exports/` — connector export CSVs (or synced from SharePoint via OneDrive)
- `logs/` — runtime and test logs
- `reports/` — generated comparison reports grouped by date
- `sanity/` — sanity test scripts for manual validation
- `src/` — main code (parsers, repository, services, helpers)
- `tests/` — Pester test suite (47 tests)
- `tools/` — utility scripts (`Generate-DateSummaries.ps1`)
- top-level scripts: `Run-ConnectorComparisons.ps1`, `Run-ServerAnalysis.ps1.ps1`, `Run-Tests.ps1`, `removelines.ps1`
- `project.properties` — configuration file for runtime behavior

---

## Commands & Examples

- Run tests:

```powershell
.\Run-Tests.ps1
```

- Run comparisons across connector export files:

```powershell
.\Run-ConnectorComparisons.ps1
```

- Analyze each export for local issues (overlaps, consecutive singles):

```powershell
.\Run-ServerAnalysis.ps1.ps1
```

---

## Design Document

This repository contains a PowerShell-based toolkit for parsing, normalizing,
and comparing IP address expressions across CSV files. The purpose of this
document is twofold: provide a usage-oriented README and act as a lightweight
design document describing core modules, data flow, extension points, and
operational guidance.

Contents of this README:

- Purpose & goals
- High-level architecture
- Key components and responsibilities
- Data flow and formats
- Configuration options
- Typical usage and examples
- Testing and automation
- Extension points and notes for contributors
- Troubleshooting and FAQs

---

**Purpose & Goals**

- **Primary goal:** provide reliable, auditable comparison of IP expression
  exports (single IPs, ranges, CIDRs) across multiple sources.
- **Secondary goals:** maintainable code (PowerShell 5.1), clear logging,
  deterministic normalization for range/equality checks, and an extensible
  structure so new loaders, exporters, or checks can be added.

---

**High-level Architecture**

- Input: one or more CSV/plain-text exports containing IP expressions.
- Parser layer: `IpExpressions.*` produces typed objects for Single/Range/CIDR.
- Normalizer: converts typed expressions to numeric `Start`/`End` values.
- Repository: `CsvRepository.ps1` loads expression objects from files.
- Services:
  - `LookupService.ps1` — in-memory lookup and query helpers.
  - `CompareIpFiles.ps1` — pairwise comparison logic that emits a structured
    CSV report (Exact / Overlap / Missing rows).
  - `Analyze-IpExpressionFile.ps1` — detects local issues (overlaps, small ranges).
- ExportSource: Abstract data layer supporting Local files and SharePoint (PnP/REST).
- Helpers: `Logger.ps1` (logging), `IpNetworkNative.cs` (CIDR math),
  `Parameters.ps1` and `ProjectConfig.ps1` for configuration handling.
- Orchestration: Top-level scripts such as `Run-ConnectorComparisons.ps1`
  and `Run-ServerAnalysis.ps1.ps1` run batch jobs and post-process reports.
- Tools: `Generate-DateSummaries.ps1` tracks issue resolution across dates.

Diagram (logical flow):

ExportSource (Local/SharePoint) -> CsvRepository -> IpExpression objects -> 
Normalizer -> Comparison/Analysis engine -> CSV reports / console logs

---

**Key Components (Files & Responsibilities)**

- `src/IpNetworkNative.cs`:
  - CIDR parsing, network arithmetic, and conversion to/from 32-bit integers.
  - Implemented in C# for performance and correctness of bitwise ops.
- `src/IpExpressions.ps1`:
  - Classes: `IpExpression` (base), `SingleIpExpression`, `RangeIpExpression`, `CidrIpExpression`.
  - Functions: `New-IpExpression` (factory), `Get-NormalizedRange`.
  - `New-IpExpression` factory: normalizes raw text and attempts parse in
    CIDR -> Range -> Single order.
  - `Get-NormalizedRange` converts expressions into `{Start, End}` numeric pairs.
- `src/CsvRepository.ps1`:
  - Functions: `Get-IpExpressionsFromFile`, `Get-AllExpressionsFromFiles`.
  - Reads files line-by-line, produces PSCustomObjects with metadata
    (`File`, `Line`, `Raw`, `Expression`).
- `src/LookupService.ps1`:
  - Classes: `LookupResult`, `LookupService`.
  - Provides in-memory representation and queries across loaded files.
  - `Exists($ip)` returns a `LookupResult` indicating file and matching raw text.
- `src/CompareIpFiles.ps1`:
  - Functions: `Get-IpExpressionsFromFile`, `Compare-TwoIpFiles`, `Compare-IpFiles`.
  - Pairwise comparison implementation used by batch scripts.
  - Produces report rows marked as `Exact`, `Overlap`, or `Missing`.
- `src/Analyze-IpExpressionFile.ps1`:
  - Function: `Analyze-IpExpressionFile`.
  - Detects overlapping ranges, consecutive single IPs (suggest range), small CIDRs (suggest flatten), and small ranges.
- `src/ExportSource.ps1`:
  - Classes: `ExportSource` (base), `LocalExportSource`, `SharePointExportSource`, `SharePointRestExportSource`.
  - Function: `New-ExportSource` (factory).
  - Abstract data source layer supporting Local files, SharePoint via PnP, and SharePoint via REST API.
- `src/Logger.ps1`:
  - Class: `Logger`.
  - Logging with levels: `Error`, `Warn`, `Info`, `Debug`.
  - Optional file output with simple rotation.
- `src/Parameters.ps1`:
  - Classes: `LogLevel`, `Parameters`.
  - Configuration containers for runtime parameters.
- `src/ProjectConfig.ps1`:
  - Class: `ProjectConfig`.
  - Loads configuration from `project.properties` file.
- `src/IpExpressionFactory.ps1`:
  - Class: `IpExpressionFactory`.
  - Factory pattern for creating IP expressions.
- `src/AllClasses.ps1`:
  - Loading/dot-sourcing convenience wrapper for interactive use.
- `tools/Generate-DateSummaries.ps1`:
  - Generates summary reports across date-organized export folders.
  - Tracks issue resolution by comparing consecutive dates.

---

**Data formats & Normalization**

- Input lines:
  - Plain expressions (not necessarily strict CSV fields) such as:
    - `192.168.1.10`
    - `192.168.1.20-192.168.1.25`
    - `192.168.2.0/30`
- Normalization:
  - All expressions are converted to 32-bit unsigned integer `Start`/`End`
    (IPv4 only in current implementation).
  - Comparison logic uses numeric range comparisons to determine equality
    or overlap.

Implication: CIDR blocks and ranges that cover the same numeric interval
are treated equivalently (e.g., `10.0.0.0/30` ≡ `10.0.0.0-10.0.0.3`).

---

**Configuration (project.properties)**

The `project.properties` file controls runtime behavior:

- `Environment` — Environment name (e.g., Dev, Prod)
- `InputFolder` — Path to input export files (default: `exports`)
- `OutputFolder` — Path for generated reports (default: `reports`)
- `LogFolder` — Path for log files (default: `logs`)
- `LogLevel` — Logging verbosity: `Error`, `Warn`, `Info`, or `Debug`
- `EnableUpload` — Enable/disable SharePoint upload functionality
- `ExportSourceType` — Data source type: `Local` or `SharePoint`
- `SharePointProvider` — SharePoint auth method: `REST` or `PnP` (when ExportSourceType=SharePoint)
- `SharePointUrl` — SharePoint site URL (e.g., `https://tenant.sharepoint.com/sites/SiteName`)
- `SharePointSite` — Alias for SharePointUrl
- `SharePointTenant` — SharePoint tenant domain (e.g., `tenant.onmicrosoft.com`)
- `LibraryName` — Document library name (e.g., `Shared Documents`)
- `TargetLibrary` — Alias for LibraryName
- `LibrarySubFolder` — Subfolder path within library (e.g., `Files Exported/Connector Export`)
- `ExportPath` — Local filesystem path for exports (when ExportSourceType=Local)

Example:
```properties
Environment=Dev
LogLevel=Error
ExportSourceType=Local
ExportPath=C:\Users\YourName\FDA\ODT-EaaS-Team - Shared Documents\Files Exported\Connector Export
```

For SharePoint mode, sync the library via OneDrive and use `ExportSourceType=Local` with the synced path, or configure SharePoint authentication (requires tenant admin consent for PnP/Graph apps).

---

**Typical usage**

1) Quick interactive load (PS session):

```powershell
. .\src\AllClasses.ps1
# Now types and helpers are available; try the test harness:
. .\src\TestHarness.ps1
```

2) Run the test suite (requires Pester):

```powershell
.\Run-Tests.ps1
```

3) Run a batch comparison across connector exports:

```powershell
.\Run-ConnectorComparisons.ps1
```

4) Analyze each export for local issues (overlaps, small ranges):

```powershell
.\Run-ServerAnalysis.ps1.ps1
```

5) Generate date-based summaries and track issue resolution:

```powershell
.\tools\Generate-DateSummaries.ps1
```

Notes: the batch scripts will write logs to `logs/` and CSV reports to
`reports/` by default.

---

**Testing & CI**

- The project includes a Pester test suite under the `tests/` folder with **47 test cases**.
- Test coverage: **~75-80%** of source code (1,180 lines across 13 files).
- `Run-Tests.ps1` wraps Pester invocation and writes a cleaned, timestamped
  log to `logs/TestResults-<timestamp>.txt`.
- All tests currently passing (47/47).
- When adding tests, prefer focused unit tests on `New-IpExpression` and
  `Get-NormalizedRange` to ensure normalization and parsing edge cases.

Test files:
- `ExportSource.Tests.ps1` — 11 tests for data source abstraction
- `IpExpressions.Tests.ps1` — 12 tests for IP parsing and normalization
- `LookupService.Tests.ps1` — 4 tests for IP lookup
- `LookupService.Multi.Tests.ps1` — 5 tests for multi-file lookup
- `CompareIPFiles.Tests.ps1` — 7 tests for comparison logic
- `Analyze-IpExpressionFile.Tests.ps1` — 5 tests for issue detection
- `Logger.Tests.ps1` — 3 tests for logging
- `ProjectConfig.Tests.ps1` — 2 tests for configuration loading

---

**Extension Points & Contribution Guidelines**

- To add IPv6 support:
  - Extend `IpNetworkNative.cs` to support IPv6 arithmetic or add a
    separate helper for IPv6 conversions.
  - Update `IpExpressions` subclasses to accept IPv6 addresses and
    maintain family checks.
- To add alternate input formats (Excel, JSON):
  - Implement a new repository loader that returns the same PSCustomObject
    shape used by `CsvRepository` (`File`, `Line`, `Raw`, `Expression`).
- To change output format: implement an exporter that converts the report
  array into the desired sink (e.g., database, JSON file, API).

Pull request checklist:

- Target branch: `main` (or create a feature branch)
- Include tests for new parsing/normalization edge cases
- Update README with any API/behavior changes

---

**Operational notes / Troubleshooting**

- If you see `Unsupported expression: '<text>'` in logs, that line failed
  to parse as CIDR, range, or single IP. Check for non-ASCII characters
  or en-dashes vs hyphens. The parser normalizes common characters but
  may still fail on malformed input.
- The current implementation is IPv4-only: IPv6 expressions will throw or
  be ignored. See Extension Points above to add IPv6.
- Log rotation is simple: when the configured log file exceeds ~10MB it
  is renamed with a timestamp suffix and a new log is started.

---

**Next steps & backlog**

- Add IPv6 support (high effort).
- Add a small CLI wrapper module for easier automation and parameter
  validation.
- Add stricter schema validation for input CSVs (currently lines are free-form).

---

Contact: open an issue or ping the repository owner for design discussions.
