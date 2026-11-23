# VPS-Stack VPS Rig

A professional Docker-based VPS-Stack stack designed for multi-service VPS environments. Features automated Restic backups to Backblaze B2, Certbot with DNS-01 challenges, and secret management via 1Password.

---

## 🔐 Secret Management

This repository contains **no secrets**. All credentials (.env, API tokens, passwords) are managed in **1Password** and synced using the 1Password CLI (`op`).

### Example Retention (How it works)
The repository uses `.example` files (e.g., `secrets/backup.ini.example`) to define the structure of your secrets. The sync script relies on these `.example` files to know *which* secrets to push to 1Password. If a secret doesn't have an `.example` file, it won't be pushed. This prevents accidental uploads of temporary or local files.

### 1. Prerequisite: Install 1Password CLI
Install the `op` CLI on your workstation: [Installation Guide](https://developer.1password.com/docs/cli/installation/). Ensure you are signed in (`op signin`).

### 2. Sync Secrets
We use a universal PowerShell script to manage bi-directional syncing. It dynamically reads your `.example` files and maps them to items in 1Password named `[Server] - [Filename]`.

**To seed 1Password with empty templates (First time setup):**
```powershell
./scripts/op-sync.ps1 -PushExample -Server "web01.example.com" -Vault "Private" -Tags "VPS,VPS-Stack"
```

**To push your real local secrets to 1Password:**
```powershell
./scripts/op-sync.ps1 -Push -Server "web01.example.com" -Vault "Private"
```
*(The script will interactively ask you before adding or overwriting fields in 1Password).*

**To pull your secrets from 1Password to your local rig:**
```powershell
./scripts/op-sync.ps1 -Pull -Server "web01.example.com" -Vault "Private"
```

---

## 🚀 Deployment

### 1. Setup the VPS
Use the provided `cloudinit/cloud-init.yaml` when provisioning your VPS to automatically install Docker and harden the system.

### 2. Upload Rig & Secrets
1. Clone this repository directly to your VPS:
   ```bash
   git clone https://github.com/sjefen6/vps-stack.git ~/vps-stack
   ```
2. Pull your secrets onto your local workstation using `./scripts/op-sync.ps1 -Pull -Server "web01.example.com"`.
3. Upload your local secrets and `.env` to the VPS by running the upload script from your workstation:
   ```powershell
   ./scripts/upload-secrets.ps1 -Target user@vps-ip
   ```

### 3. Start the Stack
On the VPS:
```bash
cd ~/vps-stack
./deploy.sh
```

---

## MariaDB updates and system-table upgrades

The database image is pinned to `mariadb:13.0`, the series already deployed on the VPS. Builds pull patch updates within that series; moving to another series requires an explicit Dockerfile change and review of MariaDB's upgrade instructions. Do not downgrade an existing data volume to an older server series.

Compose sets `MARIADB_AUTO_UPGRADE=1`. On startup, the official entrypoint checks the existing data directory and runs `mariadb-upgrade` when required, before accepting normal connections. This also repairs installations that already run 13.0 with older system tables (for example, `mysql.proc` from 12.2). Allow extra startup time for the upgrade.

The entrypoint keeps a pre-upgrade system-database backup named `system_mysql_backup_*.sql.zst` inside the database volume. Do not set `MARIADB_DISABLE_UPGRADE_BACKUP`. This system-table backup is not a full application-data backup, and the nightly Restic job does not directly back up the Docker database volume.

Before the first deployment of this fix or a deliberate series upgrade, take a verified full database backup. If logical dumps are already failing, stop the database and take a cold copy or storage snapshot of its data volume before proceeding; copying live database files is not a consistent backup.

After taking that safety copy, build and recreate the database from the repository directory:

```bash
git pull --ff-only
./build.sh
docker compose up -d --no-deps --force-recreate db
docker compose logs --tail=100 -f db
```

Wait for successful upgrade completion and `ready for connections`, then leave the log view with Ctrl-C. Verify the routine query that previously broke backups (the command reads the existing password file inside the container):

```bash
docker compose exec db sh -c 'MYSQL_PWD="$(cat /secrets/db-root-password.txt)" mariadb -uroot -e "SELECT VERSION(); SHOW FUNCTION STATUS;"'
```

Then rerun the production backup, which performs database dumps followed by the Restic upload and retention steps, and confirm success:

```bash
docker compose exec backup /usr/local/bin/backup.sh
```

See the [official MariaDB image upgrade settings](https://mariadb.com/docs/server/server-management/automated-mariadb-deployment-and-administration/docker-and-mariadb/mariadb-server-docker-official-image-environment-variables) for details.

## 📦 Backup & Recovery

The `backup` service (enabled in `production` profile) automatically dumps databases and creates an encrypted Restic snapshot of the entire `/vps-stack` directory (including secrets) every night.

### To Restore a Rig:
1. Provision a new VPS.
2. Clone this repo.
3. Pull your secrets using `./scripts/op-sync.ps1 -Pull -Server "web01.example.com"` so Restic can access the vault credentials in `secrets/backup.ini`.
4. Run the restore script on the VPS (it will automatically build its own helper container):
   ```bash
   ./scripts/restore-backup.sh . --delete
   ```
5. Deploy: `./deploy.sh`

---

## 🛠 Features

- **Apache & PHP:** Embedded PHP 8 with UID/GID remapping to UID 1000 for seamless host file permissions.
- **MariaDB:** Relational database with automated daily dumps.
- **Certbot:** Automated wildcard SSL renewals via Cloudflare/Domeneshop DNS-01.
- **Restic:** Deduplicated, encrypted off-site backups.

