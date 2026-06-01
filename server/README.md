
---

# Zombies Must Die — Server Setup (Ubuntu/Debian)/systemd

This guide explains how to deploy and run the server using **systemd services** (`zmd-server` + `zmd-funnel`) with automatic startup and Tailscale Funnel support.

# Short overview
# Game Server

Lightweight Python/Flask backend for a wave-based game. Handles authentication, run validation, stats, and leaderboard.

---

## How It Works

1. Player registers and logs in — receives a session token and a per-session HMAC secret.
2. `POST /start_run` — server creates an active run and returns `run_id` + `run_secret`.
3. `POST /finish_run` — server verifies the HMAC signature, checks real elapsed time against reported duration, validates result values, and saves the record.
4. A background thread rebuilds the leaderboard every `UPDATE_LEADERBOARD_TIME` seconds.

---

## Why Flask + SQLite

Both were chosen for simplicity. The API surface is small, deployment is a single file, and the expected load doesn't justify a heavier stack. WAL mode is enabled for concurrent reads without blocking.

---

## Security

- **Passwords** stored as bcrypt hashes.
- **Per-session HMAC-SHA256** — every request body is signed; unsigned or tampered payloads are rejected.
- **Replay protection** — requests require a `timestamp` + one-time `nonce`; used nonces are stored and rejected on reuse. Requests older than `MAX_REQUEST_AGE` seconds are discarded.
- **Run validation** — server enforces limits on wave, score, lifetime, and score-per-minute. Real elapsed time is measured server-side and compared to the reported value.
- **Admin panel** — served at a secret URL from `.env`, protected by HTTP Basic Auth with timing-safe comparison, IP blocking after too many failed attempts.
- **No SQL injection** — all queries use bound parameters; dynamic inserts are restricted to an explicit table allowlist.

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `SESSION_TTL_SECONDS` | `86400` | Session lifetime |
| `MAX_WAVE` / `MAX_SCORE` / `MAX_LIFETIME` | `200` / `60` / `60` | Result value caps |
| `MAX_SCORE_PER_MINUTE` | `7500` | Score rate cap |
| `MAX_REQUEST_AGE` | `30` | Request freshness window (seconds) |
| `REGISTRATION_COOLDOWN` | `60` | Cooldown between registrations per IP |
| `LOGIN_ATTEMPT_LIMIT` | `50` | Failed logins before IP block |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` / `ADMIN_PANEL_URL` | — | Admin credentials and secret path |

---

## API

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `POST` | `/register` | — | Register |
| `POST` | `/login` | — | Login, get token + HMAC secret |
| `POST` | `/logout` | Session | Invalidate session |
| `POST` | `/start_run` | Session | Begin a run |
| `POST` | `/finish_run` | Session | Submit result |
| `POST` | `/update_stats` | Session + HMAC | Update cumulative stats |
| `GET` | `/get_stats` | Session | Get player stats |
| `GET` | `/get_record` | Session | Get personal best |
| `GET` | `/get_leaderboard` | — | Top 30 global results |
| `GET` | `/game_version` | — | Current game version |


---

# 1. Install Python

```bash
sudo apt update
sudo apt install python3 python3-venv python3-pip
```

Verify installation:

```bash
python3 --version
```

---

# 2. Prepare the Project

Copy 'database_server' folder into user`s home directory and rename to 'zmd_server'

Go to the project directory:

```bash
cd /opt/zmd-server/
```

Create a virtual environment:

```bash
python3 -m venv venv
```

Activate it:

```bash
source venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Deactivate:

```bash
deactivate
```

---

# 3. Install and Configure Tailscale

Install Tailscale:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

Enable and start the daemon:

```bash
sudo systemctl enable --now tailscaled
```

Authenticate:

```bash
sudo tailscale up
```

Setup TailScale Funnel:
```bash 
sudo tailscale funnel 5000
```
configure and exit (should be executable by non-root user)

---

# 4. Install systemd Services

The project includes:

```
zmd-server.service
zmd-funnel.service
```

Change paths in services 
Copy them into systemd:

```bash
sudo cp zmd-server.service /etc/systemd/system/
sudo cp zmd-funnel.service /etc/systemd/system/
```

Reload systemd:

```bash
sudo systemctl daemon-reload
```

---

# 5. Enable and Start Services

Enable auto-start:

```bash
sudo systemctl enable zmd-funnel
sudo systemctl enable zmd-server
```

Start services:

```bash
sudo systemctl start zmd-funnel
sudo systemctl start zmd-server
```

---

# 6. Service Management

Check status:

```bash
systemctl status zmd-funnel
systemctl status zmd-server
```

View live logs:

```bash
journalctl -u zmd-server -f
journalctl -u zmd-funnel -f
```

Restart services:

```bash
sudo systemctl restart zmd-server
sudo systemctl restart zmd-funnel
```

Stop services:

```bash
sudo systemctl stop zmd-server
sudo systemctl stop zmd-funnel
```

Disable autostart:

```bash
sudo systemctl disable zmd-server
sudo systemctl disable zmd-funnel
```

---

# Service Architecture

* `zmd-funnel.service` — launches `tailscale funnel`
* `zmd-server.service` — runs the Python server
* Server depends on Funnel (`Requires` + `After`)
* Both services automatically start on boot
* Server automatically restarts on crash

---

# Result

After setup:

* Server starts automatically on system boot
* Tailscale Funnel launches automatically
* Fully managed via `systemctl`

---
