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
| Seerr      | http://localhost:5055 | Request movies / TV (Jellyfin login) |
| Dozzle     | http://localhost:9999 | Container logs             |
| Beszel     | http://localhost:8090 | Host & container metrics   |

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

2. Edit `.env` for your mount points:

   | Variable | Used by | Container path |
   |----------|---------|----------------|
   | `MEDIAHOME_DRIVE` | Sonarr, Radarr, Bazarr | `/data` |
   | `MEDIAHOME_DRIVE_DOWNLOADS` | qBittorrent | `/downloads` |
   | `MEDIAHOME_DRIVE_MEDIA` | Jellyfin | `/data/media` |

   Example:

   ```dotenv
   MEDIAHOME_DRIVE=/mnt/external-drive
   MEDIAHOME_DRIVE_DOWNLOADS=/mnt/external-drive/downloads
   MEDIAHOME_DRIVE_MEDIA=/mnt/external-drive/media
   ```

   If `.env` is missing, compose falls back to the paths above via `${VAR:-default}` syntax in `docker-compose.yml`.

3. Optional: use a different env file:

   ```bash
   docker compose --env-file /path/to/custom.env up -d
   ```

Inside each app’s web UI, point paths at the **container** paths (e.g. qBittorrent save folder `/downloads`, Sonarr root folders under `/data/media/...`, download client path `/data/downloads/...`).

## Run

```bash
docker compose config   # verify resolved volume paths
docker compose up -d
docker compose logs -f  # optional
```

Application config persists under `./config/<service>/` (created on first run).

### First-time Seerr

After the stack is up, open http://localhost:5055 and complete the setup wizard:

1. Connect **Jellyfin** at `http://jellyfin:8096` (admin account; use an API key from the Jellyfin dashboard if prompted).
2. Add **Sonarr** at `http://sonarr:8989` and **Radarr** at `http://radarr:7878`, each with the API key from Settings → General in that app.
3. Enable **Jellyfin authentication** so household users sign in with their Jellyfin accounts (create users in Jellyfin first).
4. Set default permissions for non-admin users (for example auto-approve vs manual approval) in Seerr’s settings.

Use Docker service hostnames (`jellyfin`, `sonarr`, `radarr`), not `localhost`, in the wizard.

To start only Seerr after other services are already running:

```bash
docker compose up -d seerr
```

## PUID / PGID

Services use `PUID=1000` and `PGID=1000` by default. Change these in `docker-compose.yml` if your host user owns the external drive with different IDs.
