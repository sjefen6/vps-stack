param (
    [Parameter(Mandatory=$true)]
    [string]$Target
)

$RemoteDir = "~/vps-stack"

Write-Host "=== Checking target $Target ===" -ForegroundColor Cyan

ssh $Target "[ -d $RemoteDir ]" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Error: Directory $RemoteDir does not exist on the target." -ForegroundColor Red
    Write-Host "  Please clone the repository on the server first:"
    Write-Host "  git clone https://github.com/sjefen6/vps-stack.git $RemoteDir" -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Uploading secrets and .env to $Target ===" -ForegroundColor Cyan
scp -r secrets/* "${Target}:${RemoteDir}/secrets/"
scp .env "${Target}:${RemoteDir}/"

Write-Host "✓ Done!" -ForegroundColor Green