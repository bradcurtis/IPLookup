# IPLookup Utilities

A PowerShell toolkit for parsing, normalizing, and comparing IP address expressions across multiple CSV files.  
Supports single IPs, ranges, and CIDR notation, with structured logging and automated test coverage via Pester.

---

## ✨ Features

- **Expression parsing**  
  - Single IPs (`192.168.1.10`)  
  - Ranges (`192.168.1.20-192.168.1.25`)  
  - CIDR blocks (`192.168.2.0/30`)  

- **Normalization**  
  Converts all expressions into integer start/end ranges for deterministic comparison.

- **Comparison utility (`Compare-IpFiles.ps1`)**  
  - Detects **Exact matches** (identical expressions)  
  - Detects **Overlaps** (different forms covering the same range, or partial overlaps)  
  - Detects **Missing entries** (present in one file but not another)  
  - Produces a structured **CSV report** with file names, line numbers, and comparison type.

- **Logging**  
  Verbose, structured logging via the `Logger` class.  
  Warnings are emitted for invalid or unsupported expressions.

- **Automated tests**  
  Comprehensive Pester suite (`CompareIpFiles.Tests.ps1`) covering exact matches, overlaps, CIDR vs range equivalence, missing entries, and invalid lines.

---

## 📂 Project Structure
