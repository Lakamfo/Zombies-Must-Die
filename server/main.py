import sqlite3
from flask import Flask, request, jsonify, render_template_string, redirect, url_for, Response
from functools import wraps
from dotenv import load_dotenv
import config
import bcrypt
import threading
from datetime import datetime
import time
import os
import secrets
import hmac as hmac_lib
import hashlib
import json

locations = ["WAREHOUSE"]

app = Flask(__name__)
db_path = "data_base.db"

load_dotenv()

def require_env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)

    if value is None:
        raise RuntimeError(
            f"Missing environment variable: {name}"
        )

    return value


UPDATE_LEADERBOARD_TIME = int(require_env("UPDATE_LEADERBOARD_TIME", "300"))
REGISTRATION_COOLDOWN   = int(require_env("REGISTRATION_COOLDOWN", "60"))
RECORD_SUBMIT_COOLDOWN  = int(require_env("RECORD_SUBMIT_COOLDOWN", "60"))
SESSION_TTL_SECONDS     = int(require_env("SESSION_TTL_SECONDS", "86400"))


MAX_WAVE     = int(require_env("MAX_WAVE", "200"))
MAX_SCORE    = int(require_env("MAX_SCORE", "60"))
MAX_LIFETIME = int(require_env("MAX_LIFETIME", "60"))
MAX_SCORE_PER_MINUTE = int(require_env("MAX_SCORE_PER_MINUTE", "7500"))


# Replay protection
MAX_REQUEST_AGE = int(require_env("MAX_REQUEST_AGE", "30"))


# Proxy trust settings
TRUST_PROXY = require_env(
    "TRUST_PROXY",
    "false"
).lower() == "true"

# Admin settings
LOGIN_ATTEMPT_LIMIT = int(require_env("LOGIN_ATTEMPT_LIMIT", "50"))
BLOCK_TIME_SECONDS  = int(require_env("BLOCK_TIME_SECONDS", "60"))

ADMIN_USERNAME = require_env("ADMIN_USERNAME")
ADMIN_PASSWORD = require_env("ADMIN_PASSWORD")
ADMIN_PANEL_URL = require_env("ADMIN_PANEL_URL")
ADMIN_TEMPLATE = config.ADMIN_TEMPLATE

CLIENT_SECRET = require_env("CLIENT_SECRET")

ALLOWED_INSERT_TABLES = {
    "player", "records", "player_stats",
    "registration_attempts", "record_attempts_ip", "record_attempts_player",
    "login_attempts", "sessions"
}


EXCLUDED_ENDPOINTS = {
    "game_version",
    "get_leaderboard",
    "debug_ip",
    "admin_panel",
    "delete_player",
    "delete_record",
    "update_leaderboard_from_admin",
    "change_game_version",
}


#  Database
def get_connection():
    conn = sqlite3.connect(db_path, timeout=30, check_same_thread=False)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db():
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.executescript("""
        CREATE TABLE IF NOT EXISTS player (
            player_id INTEGER PRIMARY KEY AUTOINCREMENT,
            login     TEXT NOT NULL UNIQUE,
            password  TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS player_stats (
            player_id   INT PRIMARY KEY,
            games_played INT NOT NULL,
            score        INT NOT NULL,
            enemy_kills  INT NOT NULL,
            FOREIGN KEY (player_id) REFERENCES player(player_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS records (
            record_id    INTEGER PRIMARY KEY AUTOINCREMENT,
            player_id    INTEGER NOT NULL,
            max_wave     INTEGER NOT NULL,
            max_score    INTEGER NOT NULL,
            max_lifetime INTEGER NOT NULL,
            location     TEXT,
            date         DATE NOT NULL,
            FOREIGN KEY (player_id) REFERENCES player(player_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS leaderboard (
            login        TEXT NOT NULL,
            max_wave     INTEGER NOT NULL,
            max_score    INTEGER NOT NULL,
            max_lifetime INTEGER NOT NULL,
            location     TEXT NOT NULL,
            date         DATE NOT NULL,
            PRIMARY KEY (login, location)
        );

        -- Sessions: token -> player with per-session HMAC secret
        CREATE TABLE IF NOT EXISTS sessions (
            token      TEXT    PRIMARY KEY,
            player_id  INTEGER NOT NULL,
            hmac_secret TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (player_id) REFERENCES player(player_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS active_runs (
            run_id TEXT PRIMARY KEY,
            player_id INTEGER NOT NULL,
            session_token TEXT NOT NULL,
            location TEXT NOT NULL,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            status TEXT NOT NULL,
            run_secret TEXT NOT NULL
        );

        -- Used nonces for replay attack protection
        CREATE TABLE IF NOT EXISTS used_nonces (
            nonce      TEXT    PRIMARY KEY,
            created_at INTEGER NOT NULL
        );

        -- Rate limiting by IP
        CREATE TABLE IF NOT EXISTS record_attempts_ip (
            ip           TEXT PRIMARY KEY,
            last_attempt INTEGER NOT NULL
        );

        -- Rate limiting by account
        CREATE TABLE IF NOT EXISTS record_attempts_player (
            player_id    INTEGER PRIMARY KEY,
            last_attempt INTEGER NOT NULL,
            FOREIGN KEY (player_id) REFERENCES player(player_id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS registration_attempts (
            ip           TEXT PRIMARY KEY,
            last_attempt INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS login_attempts (
            ip              TEXT PRIMARY KEY,
            failed_attempts INTEGER NOT NULL,
            last_attempt    INTEGER NOT NULL
        );
        """)


#  Helper functions
def get_remote_ip():
    if TRUST_PROXY:
        forwarded_for = request.headers.get('X-Forwarded-For')
        if forwarded_for:
            return forwarded_for.split(',')[0].strip()
    return request.remote_addr or "unknown"


def insert_row(table_name, data_dict):
    if table_name not in ALLOWED_INSERT_TABLES:
        raise ValueError(f"Table '{table_name}' is not allowed for insert")
    with get_connection() as conn:
        cursor = conn.cursor()
        keys            = ', '.join(data_dict.keys())
        question_marks  = ', '.join('?' * len(data_dict))
        values          = tuple(data_dict.values())
        cursor.execute(f"INSERT INTO {table_name} ({keys}) VALUES ({question_marks})", values)
        conn.commit()


# Passwords (bcrypt)
def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, stored: str) -> bool:
    """
    Verifies a bcrypt password hash.
    """
    return bcrypt.checkpw(plain.encode(), stored.encode())


# Session tokens

def create_session(player_id: int) -> tuple[str, str]:
    """
    Creates a session token and per-session HMAC secret.
    Returns: (token, hmac_secret)
    """
    token = secrets.token_hex(32)
    hmac_secret = secrets.token_hex(64)
    now = int(time.time())

    with get_connection() as conn:
        conn.execute(
            "DELETE FROM sessions WHERE player_id = ? AND created_at < ?",
            (player_id, now - SESSION_TTL_SECONDS)
        )
        conn.execute(
            "INSERT INTO sessions (token, player_id, hmac_secret, created_at) VALUES (?, ?, ?, ?)",
            (token, player_id, hmac_secret, now)
        )
        conn.commit()
    return token, hmac_secret


def get_session() -> dict | None:
    """
    Reads the token from X-Session-Token header.
    Returns session dict with token, player_id, hmac_secret or None if invalid/expired.
    """
    token = request.headers.get('X-Session-Token', '').strip()
    if not token:
        return None

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT player_id, hmac_secret, created_at FROM sessions WHERE token = ?",
            (token,)
        )
        row = cursor.fetchone()

    if not row:
        return None

    player_id, hmac_secret, created_at = row

    if int(time.time()) - created_at > SESSION_TTL_SECONDS:
        with get_connection() as conn:
            conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
            conn.commit()
        return None

    return {
        "token": token,
        "player_id": player_id,
        "hmac_secret": hmac_secret
    }


def get_player_id_from_token() -> int | None:
    """Deprecated: use get_session() instead. Kept for compatibility."""
    session = get_session()
    return session["player_id"] if session else None


def require_session(f):
    """Decorator: endpoint requires a valid token and returns session to handler."""
    @wraps(f)
    def decorated(*args, **kwargs):
        session = get_session()
        if session is None:
            return jsonify(success=False, error="Unauthorized"), 401
        return f(session, *args, **kwargs)
    return decorated


# HMAC request signature
def hmac_verify(secret: str, data: dict, signature: str) -> bool:
    payload = json.dumps(data, sort_keys=True, separators=(',', ':'))
    expected = hmac_lib.new(
        secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()

    return secrets.compare_digest(expected, signature)


@app.before_request
def verify_client_secret():
    if request.method == "OPTIONS":
        return
    if request.endpoint in EXCLUDED_ENDPOINTS:
        return

    received = request.headers.get("X-Client-Signature", "")
    if not received:
        return jsonify(error="missing_client_signature"), 403

    path = request.full_path.rstrip("?") if not request.query_string else request.full_path

    body = request.get_data()
    payload = f"{request.method}:{path}:".encode() + body

    expected = hmac_lib.new(
        CLIENT_SECRET.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()

    if not secrets.compare_digest(expected, received):
        return jsonify(error="invalid_client_signature"), 403


def validate_request_freshness(data: dict) -> bool:
    """
    Prevents replay attacks by checking timestamp and nonce.
    Rejects requests older than MAX_REQUEST_AGE seconds.
    Rejects requests with duplicate nonces.
    """
    timestamp = int(data.get("timestamp", 0))
    nonce = data.get("nonce", "")

    now = int(time.time())

    if abs(now - timestamp) > MAX_REQUEST_AGE:
        return False

    if not nonce:
        return False

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT nonce FROM used_nonces WHERE nonce = ?",
            (nonce,)
        )
        if cursor.fetchone():
            return False

        cursor.execute(
            "INSERT INTO used_nonces (nonce, created_at) VALUES (?, ?)",
            (nonce, now)
        )
        conn.commit()

    return True


#  Game endpoints
def is_record_valid(data: dict) -> bool:
    """Limits are taken from .env"""
    try:
        wave = int(data.get('max_wave', 0))
        score = int(data.get('max_score', 0))
        lifetime = int(data.get('max_lifetime', 0))

        if not (0 < wave < MAX_WAVE):
            return False

        if not (0 < score < MAX_SCORE):
            return False

        if not (0 < lifetime < MAX_LIFETIME):
            return False

        minutes = lifetime / 60

        if minutes <= 0:
            return False

        score_per_minute = score / minutes

        if score_per_minute > MAX_SCORE_PER_MINUTE:
            return False

        return True
    except (TypeError, ValueError):
        return False


@app.route("/start_run", methods=["POST"])
@require_session
def start_run(session):
    player_id = session["player_id"]
    data = request.get_json()
    location = data.get("location", "").upper()

    if location not in locations:
        return jsonify(error="invalid_location"), 400

    run_id = secrets.token_hex(16)
    run_secret = secrets.token_hex(32)
    now = int(time.time())

    with get_connection() as conn:
        conn.execute("""
            INSERT INTO active_runs
            (run_id, player_id, session_token, location, start_time, status, run_secret)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            run_id,
            player_id,
            request.headers.get("X-Session-Token"),
            location,
            now,
            "active",
            run_secret
        ))
        conn.commit()

    return jsonify(
        success=True,
        run_id=run_id,
        run_secret=run_secret
    )


@app.route("/finish_run", methods=["POST"])
@require_session
def finish_run(session: dict):
    player_id = session["player_id"]

    data = request.get_json()

    run_id = request.headers.get("X-Run-ID")
    signature = request.headers.get("X-Run-Signature")

    if not run_id or not signature:
        return jsonify(error="missing_headers"), 400

    with get_connection() as conn:
        cursor = conn.cursor()

        cursor.execute("""
            SELECT start_time, location, run_secret, status
            FROM active_runs
            WHERE run_id = ? AND player_id = ?
        """, (run_id, player_id))

        row = cursor.fetchone()
        if not row:
            return jsonify(error="invalid_run"), 403

        start_time, location, run_secret, status = row

        if status != "active":
            return jsonify(error="run_already_finished"), 403

        if not hmac_verify(run_secret, data, signature):
            return jsonify(error="invalid_signature"), 403

        now = int(time.time())
        real_duration = now - start_time

        if real_duration < data.get("max_lifetime", 0):
            return jsonify(error="time_mismatch"), 403

        if real_duration < 60:
            return jsonify(error="run_too_short"), 403

        cursor.execute("""
            UPDATE active_runs
            SET end_time = ?, status = 'finished'
            WHERE run_id = ?
        """, (now, run_id))

        if cursor.rowcount == 0:
            return jsonify(error="update_failed"), 500

    if is_record_valid(data):
        return save_record_internal(player_id, data, location)
    else:
        return jsonify(error="invalid_record_values"), 500

def save_record_internal(player_id: int, data: dict, location: str):
    with get_connection() as conn:
        cursor = conn.cursor()

        cursor.execute("""
            SELECT max_score FROM records
            WHERE player_id = ? AND location = ?
            ORDER BY max_score DESC LIMIT 1
        """, (player_id, location))

        existing = cursor.fetchone()
        if existing and data["max_score"] <= existing[0]:
            return jsonify(error="not_better_record"), 403

        cursor.execute("""
            INSERT INTO records
            (player_id, max_wave, max_score, max_lifetime, location, date)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            player_id,
            int(data["max_wave"]),
            int(data["max_score"]),
            int(data["max_lifetime"]),
            location,
            datetime.utcnow().date().isoformat()
        ))

        conn.commit()

    return jsonify(success=True)


@app.route('/update_stats', methods=['POST'])
@require_session
def update_stats(session: dict):
    data = request.get_json()
    if not data:
        return jsonify(success=False, error="Invalid JSON")

    if not hmac_verify(session["hmac_secret"], session, request.headers.get('X-Signature', '')):
        return jsonify(success=False, error="Invalid signature"), 403

    if not validate_request_freshness(data):
        return jsonify(success=False, error="Invalid or replayed request"), 403

    player_id = session["player_id"]

    try:
        score = int(data['score'])
        kills = int(data['kills'])
    except (KeyError, ValueError, TypeError):
        return jsonify(success=False, error="Invalid stats data")

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE player_stats
            SET games_played = games_played + 1,
                score        = score + ?,
                enemy_kills  = enemy_kills + ?
            WHERE player_id = ?
        """, (score, kills, player_id))
        conn.commit()

    return jsonify(success=True)


@app.route('/get_stats', methods=['GET'])
@require_session
def get_stats(session: dict):
    player_id = session["player_id"]
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM player_stats WHERE player_id = ?", (player_id,))
        row = cursor.fetchone()

    if not row:
        return jsonify(success=False, error="Stats not found")

    return jsonify({
        "player_id":    row[0],
        "games_played": row[1],
        "score":        row[2],
        "enemy_kills":  row[3],
    })


@app.route('/get_record', methods=['GET'])
@require_session
def get_record(session: dict):
    player_id = session["player_id"]
    location = request.args.get('location', '').upper()

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM records WHERE player_id = ? AND location = ? ORDER BY max_score DESC LIMIT 1",
            (player_id, location)
        )
        result = cursor.fetchone()

    return jsonify(response=result)


@app.route('/get_leaderboard', methods=['GET'])
def get_leaderboard():
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            'SELECT login, max_wave, max_score, max_lifetime, location, date '
            'FROM leaderboard LIMIT 0,30'
        )
        rows = cursor.fetchall()

    formatted_result = []
    for row in rows:
        login, max_wave, max_score, max_lifetime, location, date_str = row
        try:
            if isinstance(date_str, str):
                date_obj = datetime.strptime(date_str, "%Y-%m-%d")
            elif isinstance(date_str, datetime):
                date_obj = date_str
            else:
                raise ValueError("Unsupported date format")
            formatted_date = date_obj.strftime("%d-%m-%Y")
        except Exception as e:
            formatted_date = str(date_str)
            print("Failed formatting date:", repr(date_str), "Error:", e)

        formatted_result.append({
            "login":       login,
            "max_wave":    max_wave,
            "max_score":   max_score,
            "max_lifetime": max_lifetime,
            "location":    location,
            "date":        formatted_date,
        })

    return jsonify(response=formatted_result)


#  Authentication / registration
@app.route('/login', methods=['POST'])
def login_player():
    data = request.get_json()
    if not data:
        return jsonify(success=False, error="Invalid JSON")

    login    = data.get('login', '').strip()
    password = data.get('password', '')

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT player_id, password FROM player WHERE login = ?", (login,)
        )
        result = cursor.fetchone()

    if not result or not verify_password(password, result[1]):
        print(f"Failed login attempt for login: {login!r}")
        return jsonify(success=False, error="Invalid credentials")

    player_id, stored_hash = result

    token, hmac_secret = create_session(player_id)
    print(f"Login OK: player_id={player_id}")
    return jsonify(success=True, token=token, hmac_secret=hmac_secret)


@app.route('/logout', methods=['POST'])
@require_session
def logout(session: dict):
    token = session["token"]
    with get_connection() as conn:
        conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
        conn.commit()
    return jsonify(success=True)


@app.route('/register', methods=['POST'])
def reg_player():
    data = request.get_json()
    if not data:
        return jsonify(success=False, error="Invalid JSON")

    login    = data.get('login', '').strip()
    password = data.get('password', '')

    if not login or not password:
        return jsonify(success=False, error="Login and password are required")

    ip           = get_remote_ip()
    current_time = int(time.time())

    with get_connection() as conn:
        cursor = conn.cursor()

        cursor.execute(
            "SELECT last_attempt FROM registration_attempts WHERE ip = ?", (ip,)
        )
        row = cursor.fetchone()
        if row and current_time - row[0] < REGISTRATION_COOLDOWN:
            return jsonify(success=False, error="Too many registration attempts. Try later.")

        try:
            hashed = hash_password(password)
            insert_row("player", {"login": login, "password": hashed})

            cursor.execute("SELECT player_id FROM player WHERE login = ?", (login,))
            result = cursor.fetchone()

            if result:
                player_id = result[0]
                cursor.execute("""
                    INSERT INTO player_stats (player_id, games_played, score, enemy_kills)
                    VALUES (?, 0, 0, 0)
                """, (player_id,))
                cursor.execute(
                    "INSERT OR REPLACE INTO registration_attempts (ip, last_attempt) VALUES (?, ?)",
                    (ip, current_time)
                )
                conn.commit()

            return jsonify(success=True)

        except Exception as e:
            if "UNIQUE" in str(e):
                return jsonify(success=False, error="Username already exists")
            raise


@app.route('/game_version', methods=['GET'])
def game_version():
    with open('version.txt', 'r') as file:
        version = file.read().strip()
    return jsonify(version=version)


#  Leaderboard (background thread)
def cleanup_expired_data():
    """Periodically clean up expired sessions and nonces."""
    now = int(time.time())
    cutoff_time = now - SESSION_TTL_SECONDS
    nonce_cutoff = now - MAX_REQUEST_AGE * 2

    with get_connection() as conn:
        conn.execute("DELETE FROM sessions WHERE created_at < ?", (cutoff_time,))
        conn.execute("DELETE FROM used_nonces WHERE created_at < ?", (nonce_cutoff,))
        conn.commit()


def update_leaderboard_loop():
    while True:
        force_update_leaderboard()
        cleanup_expired_data()
        time.sleep(UPDATE_LEADERBOARD_TIME)


def force_update_leaderboard():
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.executescript("""
        BEGIN;

        DELETE FROM leaderboard;

        WITH MaxScores AS (
            SELECT player_id, location, MAX(max_score) AS max_score
            FROM records
            GROUP BY player_id, location
        ),
        BestRecords AS (
            SELECT r.player_id, r.max_wave, r.max_score, r.max_lifetime, r.location, r.date
            FROM records r
            JOIN MaxScores m
              ON r.player_id = m.player_id
             AND r.location  = m.location
             AND r.max_score = m.max_score
        )

        INSERT OR REPLACE INTO leaderboard (login, max_wave, max_score, max_lifetime, location, date)
        SELECT p.login, b.max_wave, b.max_score, b.max_lifetime, b.location, b.date
        FROM BestRecords b
        JOIN player p ON b.player_id = p.player_id
        ORDER BY b.max_score DESC;

        COMMIT;
        """)
    print(f"{time.ctime()} : Leaderboard updated.")


#  Admin panel
def get_client_ip():
    if TRUST_PROXY:
        forwarded_for = request.headers.get('X-Forwarded-For')
        if forwarded_for:
            return forwarded_for.split(',')[0].strip()
    return request.remote_addr or "unknown"


def check_auth(username, password):
    return (
        secrets.compare_digest(username, ADMIN_USERNAME) and
        secrets.compare_digest(password, ADMIN_PASSWORD)
    )


def is_ip_blocked(ip):
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT failed_attempts, last_attempt FROM login_attempts WHERE ip = ?", (ip,)
        )
        row = cursor.fetchone()
        if row:
            failed_attempts, last_attempt = row
            if failed_attempts >= LOGIN_ATTEMPT_LIMIT:
                if time.time() - last_attempt < BLOCK_TIME_SECONDS:
                    return True
    return False


def record_failed_login(ip):
    with get_connection() as conn:
        cursor = conn.cursor()
        now = int(time.time())
        cursor.execute(
            "SELECT failed_attempts, last_attempt FROM login_attempts WHERE ip = ?", (ip,)
        )
        row = cursor.fetchone()
        if row:
            failed_attempts, last_attempt = row
            if failed_attempts >= LOGIN_ATTEMPT_LIMIT and now - last_attempt >= BLOCK_TIME_SECONDS:
                failed_attempts = 0
            failed_attempts += 1
            cursor.execute(
                "UPDATE login_attempts SET failed_attempts = ?, last_attempt = ? WHERE ip = ?",
                (failed_attempts, now, ip)
            )
        else:
            cursor.execute(
                "INSERT INTO login_attempts (ip, failed_attempts, last_attempt) VALUES (?, ?, ?)",
                (ip, 1, now)
            )
        conn.commit()


def clear_login_attempts(ip):
    with get_connection() as conn:
        conn.execute("DELETE FROM login_attempts WHERE ip = ?", (ip,))
        conn.commit()


def authenticate():
    return Response(
        'Access Denied. Login Required.', 401,
        {'WWW-Authenticate': 'Basic realm="Login Required"'}
    )


def requires_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        ip = get_client_ip()
        if is_ip_blocked(ip):
            return Response('Too many attempts. Try later.', 429)
        auth = request.authorization
        if not auth or not check_auth(auth.username, auth.password):
            record_failed_login(ip)
            return authenticate()
        clear_login_attempts(ip)
        return f(*args, **kwargs)
    return decorated


@app.route('/' + ADMIN_PANEL_URL)
@requires_auth
def admin_panel():
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT player_id, login FROM player")
        players = cursor.fetchall()
        cursor.execute("SELECT * FROM records")
        records = cursor.fetchall()
    version = "unknown"
    if os.path.exists("version.txt"):
        with open("version.txt") as f:
            version = f.read().strip()
    return render_template_string(ADMIN_TEMPLATE, players=players, records=records, version=version, admin_url=ADMIN_PANEL_URL)


@app.route('/debug_ip')
@requires_auth
def debug_ip():
    ip = get_client_ip()
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM login_attempts WHERE ip = ?", (ip,))
        row = cursor.fetchone()
    return jsonify(ip=ip, row=row, time=int(time.time()))


@app.route('/' + ADMIN_PANEL_URL + '/delete_player/<int:player_id>', methods=['POST'])
@requires_auth
def delete_player(player_id):
    with get_connection() as conn:
        conn.execute("DELETE FROM player WHERE player_id = ?", (player_id,))
        conn.commit()
    return redirect(url_for('admin_panel'))


@app.route('/' + ADMIN_PANEL_URL + '/delete_record/<int:record_id>', methods=['POST'])
@requires_auth
def delete_record(record_id):
    with get_connection() as conn:
        conn.execute("DELETE FROM records WHERE record_id = ?", (record_id,))
        conn.commit()
    return redirect(url_for('admin_panel'))


@app.route('/' + ADMIN_PANEL_URL + '/force_update_leaderboard', methods=['POST'])
@requires_auth
def update_leaderboard_from_admin():
    force_update_leaderboard()
    return redirect(url_for('admin_panel'))


@app.route('/' + ADMIN_PANEL_URL + '/change_game_version', methods=['POST'])
@requires_auth
def change_game_version():
    new_version = request.form.get('new_version', '').strip()
    if new_version:
        with open('version.txt', 'w') as f:
            f.write(new_version)
    return redirect(url_for('admin_panel'))


#  Startup
if __name__ == '__main__':
    init_db()
    leaderboard_thread = threading.Thread(target=update_leaderboard_loop, daemon=True)
    leaderboard_thread.start()
    app.run(host='0.0.0.0', port=5000, debug=False)