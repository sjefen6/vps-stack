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
  (Get-Content "path\to\file" -Raw) -replace "`r`n", "`n" | Set-Content "path\to\file" -NoNewline
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
