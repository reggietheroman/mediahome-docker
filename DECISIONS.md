# GPD Pocket 2 Homelab Architecture & Decisions

This document outlines the final locked-down architecture and component stack for the GPD Pocket 2 homelab setup. Each component has been selected to optimize performance, resource efficiency, and ease of management on a compact, low-power portable server.

---

## 1. Core Services & Media Server
* **Jellyfin**: The primary media server responsible for streaming movies, TV shows, and music to clients across the local network and remotely.

## 2. Download & Automation Pipeline
* **qBittorrent (Headless / `qbittorrent-nox`)**: A lightweight, web-managed torrent client running as a background service. Configured to download directly to the attached external storage drive.
* **Sonarr**: Dedicated media automation manager for TV series. Automatically monitors feeds, grabs torrents via qBittorrent, renames files, and organizes them into the correct directory structure.
* **Radarr**: Dedicated media automation manager for movies. Works in tandem with Sonarr to handle movie discovery, downloading, and library organization.
* **Bazarr**: Companion automation tool that integrates directly with Sonarr and Radarr to automatically fetch, score, and sync subtitles in preferred languages.

## 3. Observability & Management
* **Beszel**: A lightweight, modern monitoring hub designed for homelabs. Tracks CPU, memory, disk, network usage, and individual Docker container performance metrics with minimal RAM overhead.
* **Dozzle**: A lightweight, real-time web-based log viewer that connects directly to the Docker socket, enabling quick debugging and log monitoring across all homelab containers.
