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
1. Clone your private fork of this repo (or the clean public version) to your workstation.
2. Run `./scripts/op-sync.ps1 -Pull -Server "web01.example.com"` as described above to populate your local files.
3. Upload the entire directory to your VPS:
   ```bash
   scp -r ~/vps-stack user@vps-ip:~/
   ```

### 3. Start the Stack
On the VPS:
```bash
cd ~/vps-stack
./deploy.sh
```

---

## 📦 Backup & Recovery

The `backup` service (enabled in `production` profile) automatically dumps databases and creates an encrypted Restic snapshot of the entire `/vps-stack` directory (including secrets) every night.

### To Restore a Rig:
1. Provision a new VPS.
2. Clone this repo.
3. Pull your secrets using `./scripts/op-sync.ps1 -Pull -Server "web01.example.com"` so Restic can access the vault credentials in `secrets/backup.ini`.
4. Run the restore script on the VPS:
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

