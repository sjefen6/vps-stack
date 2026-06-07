# Agent Notes

## CRLF / Line Endings

**This repo runs on Linux (Docker). Files created on Windows will have CRLF (`\r\n`) line endings.**

Shell scripts and other executable files with CRLF line endings fail with a cryptic error:
```
cannot execute: required file not found
```
This happens because the shebang becomes `#!/bin/bash\r` and the kernel can't find `/bin/bash\r`.

### Rules:
- ALL shell scripts and executable files must use LF (`\n`) only
- After creating any script file on Windows, immediately fix it:
  ```powershell
  $path = "path\to\file"
  $content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  $content = $content -replace "`r`n", "`n"
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllBytes($path, $utf8NoBom.GetBytes($content))
  ```
- `.gitattributes` covers `*.sh` and `Dockerfile` — but **extensionless scripts must be added explicitly**:
  ```
  dockerfiles/apache-php/splitlog text eol=lf
  ```
- When creating a new extensionless script, always add it to `.gitattributes` AND fix the line endings immediately.
- **ALWAYS use `WriteAllBytes` with explicit LF conversion** when writing shell scripts from PowerShell. Both `Set-Content` and `WriteAllLines` add CRLF regardless of encoding settings. The only reliable method:
  ```powershell
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  $bytes = $utf8NoBom.GetBytes($content)  # $content must use "`n" not "`r`n"
  [System.IO.File]::WriteAllBytes("path\to\file", $bytes)
  ```

## Design Philosophy

### 1. Fail Fast (Fail Loud, Fail Early)
- Do not build silent fallback logic for missing or misconfigured critical environment variables (e.g., `VPS_HOSTNAME`, `MYSQL_ROOT_PASSWORD`).
- If a required configuration is missing or empty, scripts must print a clear error message to `stderr` and exit immediately with status `1`.
- In `compose.yaml`, use the required variable syntax `${VAR:?error_message}` to prevent the stack from starting if variables are missing from `.env`.

### 2. Single Responsibility Principle (SRP)
- Keep automated lifecycle/initialization scripts (like those running inside `/docker-entrypoint-initdb.d/`) strictly focused on their automated tasks.
- Do not overload automated scripts to handle manual intervention or manual runs if it introduces unnecessary branching complexity (such as password file check branches). If a manual task is a separate concern, handle it separately.
