# mediahome-docker

Docker Compose stack for a compact homelab media pipeline: torrent downloads, *arr* automation, Jellyfin streaming, and lightweight observability. Designed for low-power hosts with media on an external drive (see [DECISIONS.md](DECISIONS.md) for architecture notes).

## Services

| Service     | URL (default)        | Role                          |
|------------|----------------------|-------------------------------|
| Jellyfin   | http://localhost:8096 | Media server / streaming   |
| qBittorrent | http://localhost:8080 | Download client           |
| Sonarr     | http://localhost:8989 | TV automation              |
| Radarr     | http://localhost:7878 | Movie automation           |
| Bazarr     | http://localhost:6767 | Subtitles                  |
| Prowlarr   | http://localhost:9696 | Indexer manager (feeds Sonarr/Radarr) |
| FlareSolverr | _(internal only)_ | Cloudflare bypass for Prowlarr indexers (`http://flaresolverr:8191`) |
| Seerr      | http://localhost:5055 | Request movies / TV (Jellyfin login) |
| Dozzle     | http://localhost:9999 | Container logs             |
| Beszel     | http://localhost:8090 | Host & container metrics   |

### Caddy / DNS (`*.home.arpa`)

When devops-hub Caddy (`../devops-hub/caddy/`) and Pi-hole are configured on the same host, these HTTPS URLs route to the media stack (host ports from `.env`; qBittorrent uses **8083** when Vaultwarden occupies 8080):

| Service     | URL |
|------------|-----|
| Jellyfin   | https://jellyfin.home.arpa |
| qBittorrent | https://qbittorrent.home.arpa |
| Sonarr     | https://sonarr.home.arpa |
| Radarr     | https://radarr.home.arpa |
| Bazarr     | https://bazarr.home.arpa |
| Prowlarr   | https://prowlarr.home.arpa |
| Seerr      | https://seerr.home.arpa |
| Dozzle     | https://dozzle.home.arpa |
| Beszel     | https://beszel.home.arpa |

Clients must use Pi-hole (or equivalent) DNS so `*.home.arpa` resolves to the machine running Caddy.

## Prerequisites

- Docker Engine and Docker Compose v2
- An external (or local) drive mounted on the host with a layout like:

  ```
  /mnt/external-drive/
  ├── downloads/   # torrents complete here
  └── media/       # organized library (movies, tv, …)
  ```

  Sonarr and Radarr import via **hardlinks** when downloads and media live on the same filesystem under one root; keep `MEDIAHOME_DRIVE_DOWNLOADS` and `MEDIAHOME_DRIVE_MEDIA` as subpaths of `MEDIAHOME_DRIVE` unless you intentionally split drives (imports will copy instead of hardlink).

## Configuration

Host storage paths are set with a `.env` file in this directory. Compose loads it automatically and substitutes variables in [docker-compose.yml](docker-compose.yml).

1. Copy the example file:

   ```bash
   cp .env.example .env
   ```

2. Edit `.env` for your mount points and, if needed, host ports:

   | Variable | Used by | Container path |
   |----------|---------|----------------|
   | `MEDIAHOME_DRIVE` | Sonarr, Radarr, Bazarr | `/data` |
   | `MEDIAHOME_DRIVE_DOWNLOADS` | qBittorrent | `/downloads` |
   | `MEDIAHOME_DRIVE_MEDIA` | Jellyfin | `/data/media` |

   | Variable | Service | Default host port |
   |----------|---------|-------------------|
   | `QBITTORRENT_PORT` | qBittorrent Web UI | 8080 |
   | `QBITTORRENT_BT_PORT` | qBittorrent (TCP/UDP) | 6881 |
   | `JELLYFIN_PORT` | Jellyfin | 8096 |
   | `SONARR_PORT` | Sonarr | 8989 |
   | `RADARR_PORT` | Radarr | 7878 |
   | `BAZARR_PORT` | Bazarr | 6767 |
   | `PROWLARR_PORT` | Prowlarr | 9696 |
   | `SEERR_PORT` | Seerr | 5055 |
   | `DOZZLE_PORT` | Dozzle | 9999 |
   | `BESZEL_PORT` | Beszel | 8090 |

   Example:

   ```dotenv
   MEDIAHOME_DRIVE=/mnt/external-drive
   MEDIAHOME_DRIVE_DOWNLOADS=/mnt/external-drive/downloads
   MEDIAHOME_DRIVE_MEDIA=/mnt/external-drive/media
   JELLYFIN_PORT=18096
   ```

   If `.env` is missing, compose falls back to the defaults above via `${VAR:-default}` syntax in `docker-compose.yml`. Container ports stay fixed; services on the Compose network still use Docker hostnames and those internal ports (for example `http://jellyfin:8096` in the Seerr wizard), regardless of what you set on the host.

3. Optional: use a different env file:

   ```bash
   docker compose --env-file /path/to/custom.env up -d
   ```

Inside each app’s web UI, point paths at the **container** paths (e.g. qBittorrent save folder `/downloads`, Sonarr root folders under `/data/media/...`, download client path `/data/downloads/...`).

## Run

```bash
docker compose config   # verify resolved volume paths and host ports
docker compose up -d
docker compose logs -f  # optional
```

Application config persists under `./config/<service>/` (created on first run).

### First-time Seerr

After the stack is up, open Seerr at the host URL from the table above (default http://localhost:5055) and complete the setup wizard:

1. Connect **Jellyfin** at `http://jellyfin:8096` (admin account; use an API key from the Jellyfin dashboard if prompted).
2. Add **Sonarr** at `http://sonarr:8989` and **Radarr** at `http://radarr:7878`, each with the API key from Settings → General in that app.
3. Enable **Jellyfin authentication** so household users sign in with their Jellyfin accounts (create users in Jellyfin first).
4. Set default permissions for non-admin users (for example auto-approve vs manual approval) in Seerr’s settings.

Use Docker service hostnames (`jellyfin`, `sonarr`, `radarr`), not `localhost`, in the wizard.

Torrent/usenet **indexers** are not configured in Seerr; add them in **Prowlarr** and sync to Sonarr/Radarr (see below).

### Prowlarr (indexers → Sonarr / Radarr)

Prowlarr manages indexers and pushes Torznab/Newznab entries into Sonarr and Radarr. Downloads still go through qBittorrent.

1. Open Prowlarr at http://localhost:9696 or https://prowlarr.home.arpa.
2. **Settings → Indexers → Add indexer** — add sources you are entitled to use (private trackers, Usenet Newznab, etc.). Indexers blocked by Cloudflare (e.g. 1337x) need **FlareSolverr** (below).
3. **Settings → Apps → Add application** — add **Sonarr** and **Radarr** separately:

   | Field | Sonarr | Radarr |
   |-------|--------|--------|
   | Sync Level | Full Sync | Full Sync |
   | Sonarr/Radarr Server | `http://sonarr:8989` | `http://radarr:7878` |
   | API Key | Sonarr → Settings → General → Security | Radarr → Settings → General → Security |

   Use Docker hostnames, not `localhost`. Click **Test**, then **Save**.

4. Confirm **Settings → Indexers** in Sonarr and Radarr lists Prowlarr-synced indexers.
5. Manual **Search** on a missing episode/movie should return releases and send grabs to qBittorrent.

If Sonarr/Radarr **Allowed Hosts** is set, include `prowlarr` / `prowlarr:9696` or leave the field empty.

### FlareSolverr (Cloudflare indexers in Prowlarr)

FlareSolverr runs on the Compose network only (no browser URL). **Do not** expose port 8191 on Caddy or the public internet — it can act as an open proxy.

1. Ensure the container is up: `docker compose up -d flaresolverr`.
2. In Prowlarr: **Settings → Indexer Proxies → +**
   - Type: **FlareSolverr**
   - Name: `flaresolverr` (any label)
   - URL: `http://flaresolverr:8191`
   - **Test** → success
3. Edit the Cloudflare-protected indexer (e.g. **1337x**): set **Indexer Proxy** to that FlareSolverr entry, then **Test** the indexer again.
4. If tests fail, check `docker logs flaresolverr` (timeouts/RAM) and update images.

To start only Seerr after other services are already running:

```bash
docker compose up -d seerr
```

### Dozzle (login + persistent data)

Dozzle can read all container logs via `docker.sock` — equivalent to high privilege on the host. Enable login before relying on it over Tailscale/Caddy.

1. Set `DOZZLE_ADMIN_USER` and `DOZZLE_ADMIN_PASSWORD` in `.env` (use a strong password).
2. Generate `config/dozzle/users.yml`:

   ```bash
   ./scripts/generate-dozzle-users.sh
   ```

3. Recreate Dozzle: `docker compose up -d dozzle`
4. Sign in at http://localhost:9999 or https://dozzle.home.arpa with those credentials.

Re-run the script after changing the password. UI preferences are stored under `./config/dozzle/` (mounted as `/data`). Leave shell/actions disabled in Dozzle unless you explicitly need them.

## PUID / PGID

Services use `PUID=1000` and `PGID=1000` by default. Change these in `docker-compose.yml` if your host user owns the external drive with different IDs.
