#!/usr/bin/env python3
import argparse
import datetime
import multiprocessing
import os
import platform as _platform
import subprocess
import sys
import threading
import zipfile

PLATFORMS = ["windows", "linuxbsd", "macos", "android", "ios", "web"]

OPTIONAL_MODULES = [
    "module_astcenc_enabled",
    "module_basis_universal_enabled",
    "module_bcdec_enabled",
    "module_bmp_enabled",
    "module_camera_enabled",
    "module_csg_enabled",
    "module_dds_enabled",
    "module_enet_enabled",
    "module_etcpak_enabled",
    "module_fbx_enabled",
    "module_gltf_enabled",
    "module_gridmap_enabled",
    "module_hdr_enabled",
    "module_interactive_music_enabled",
    "module_jsonrpc_enabled",
    "module_ktx_enabled",
    "module_mbedtls_enabled",
    "module_meshoptimizer_enabled",
    "module_mp3_enabled",
    "module_mobile_vr_enabled",
    "module_msdfgen_enabled",
    "module_multiplayer_enabled",
    "module_noise_enabled",
    "module_navigation_2d_enabled",
    "module_navigation_3d_enabled",
    "module_ogg_enabled",
    "module_openxr_enabled",
    "module_raycast_enabled",
    "module_regex_enabled",
    "module_svg_enabled",
    "module_tga_enabled",
    "module_theora_enabled",
    "module_tinyexr_enabled",
    "module_upnp_enabled",
    "module_vhacd_enabled",
    "module_vorbis_enabled",
    "module_webrtc_enabled",
    "module_websocket_enabled",
    "module_webxr_enabled",
    "module_zip_enabled",
]

REQUIRED_MODULES = {
    "module_mbedtls_enabled",
}

DEFAULT_TEMPLATE = {
    "module_camera_enabled":            "no",
    "module_mobile_vr_enabled":         "no",
    "module_openxr_enabled":            "no",
    "module_webrtc_enabled":            "no",
    "module_websocket_enabled":         "no",
    "module_webxr_enabled":             "no",
    "module_zip_enabled":               "no",
}

MSVC_PATHS = [
    r"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat",
    r"C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat",
    r"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat",
    r"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat",
    r"C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvars64.bat",
    r"C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat",
]

CROSS_COMPILE_NOTES = {
    "windows":  "Requires MinGW or MSVC cross toolchain.",
    "android":  "Requires Android NDK + ANDROID_NDK_ROOT env variable.",
    "linuxbsd": "Requires llvm-mingw (https://github.com/mstorsjo/llvm-mingw).",
    "macos":    "Requires Xcode or osxcross on non-Mac.",
    "ios":      "Requires Xcode, macOS only.",
    "web":      "Requires Emscripten (emcc in PATH).",
}

# scons output filename -> official Godot template filename
# { platform: { scons_name: official_name } }
TEMPLATE_RENAME_MAP = {
    "windows": {
        "godot.windows.template_debug.x86_64.exe":         "windows_debug_x86_64.exe",
        "godot.windows.template_debug.x86_64.console.exe": "windows_debug_x86_64_console.exe",
        "godot.windows.template_debug.x86_32.exe":         "windows_debug_x86_32.exe",
        "godot.windows.template_debug.x86_32.console.exe": "windows_debug_x86_32_console.exe",
        "godot.windows.template_debug.arm64.exe":          "windows_debug_arm64.exe",
        "godot.windows.template_debug.arm64.console.exe":  "windows_debug_arm64_console.exe",
        "godot.windows.template_release.x86_64.exe":         "windows_release_x86_64.exe",
        "godot.windows.template_release.x86_64.console.exe": "windows_release_x86_64_console.exe",
        "godot.windows.template_release.x86_32.exe":         "windows_release_x86_32.exe",
        "godot.windows.template_release.x86_32.console.exe": "windows_release_x86_32_console.exe",
        "godot.windows.template_release.arm64.exe":          "windows_release_arm64.exe",
        "godot.windows.template_release.arm64.console.exe":  "windows_release_arm64_console.exe",
    },
    "linuxbsd": {
        "godot.linuxbsd.template_debug.x86_64":   "linux_debug.x86_64",
        "godot.linuxbsd.template_debug.x86_32":   "linux_debug.x86_32",
        "godot.linuxbsd.template_debug.arm64":    "linux_debug.arm64",
        "godot.linuxbsd.template_debug.arm32":    "linux_debug.arm32",
        "godot.linuxbsd.template_release.x86_64": "linux_release.x86_64",
        "godot.linuxbsd.template_release.x86_32": "linux_release.x86_32",
        "godot.linuxbsd.template_release.arm64":  "linux_release.arm64",
        "godot.linuxbsd.template_release.arm32":  "linux_release.arm32",
    },
    "macos": {
        "godot.macos.template_debug.universal":   "macos.zip",
        "godot.macos.template_release.universal": "macos.zip",
    },
    "ios": {
        "godot.ios.template_debug.universal":   "ios.zip",
        "godot.ios.template_release.universal": "ios.zip",
    },
    "web": {
        "godot.web.template_debug.wasm32.zip":                  "web_debug.zip",
        "godot.web.template_release.wasm32.zip":                "web_release.zip",
        "godot.web.template_debug.wasm32.nothreads.zip":        "web_nothreads_debug.zip",
        "godot.web.template_release.wasm32.nothreads.zip":      "web_nothreads_release.zip",
        "godot.web.template_debug.wasm32.dlink.zip":            "web_dlink_debug.zip",
        "godot.web.template_release.wasm32.dlink.zip":          "web_dlink_release.zip",
        "godot.web.template_debug.wasm32.nothreads.dlink.zip":  "web_dlink_nothreads_debug.zip",
        "godot.web.template_release.wasm32.nothreads.dlink.zip":"web_dlink_nothreads_release.zip",
    },
    "android": {
        "android_debug.apk":   "android_debug.apk",
        "android_release.apk": "android_release.apk",
        "android_source.zip":  "android_source.zip",
    },
}

# --- Logging ---

_log_file    = None
_log_path    = None
_log_lock    = threading.Lock()


def _open_log(godot_root: str) -> None:
    global _log_file, _log_path
    script_dir = os.path.dirname(os.path.abspath(__file__))
    logs_dir   = os.path.join(script_dir, "build_logs")
    os.makedirs(logs_dir, exist_ok=True)
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    _log_path = os.path.join(logs_dir, f"build_{timestamp}.log")
    _log_file = open(_log_path, "w", encoding="utf-8", errors="replace")
    _log_write(f"Build log started: {timestamp}\n")
    print(f"\nLog file: {_log_path}\n")


def _log_write(text: str) -> None:
    if _log_file:
        with _log_lock:
            _log_file.write(text)
            _log_file.flush()


def _close_log() -> None:
    if _log_file:
        _log_file.close()
    if _log_path:
        print(f"\nLog saved: {_log_path}")


def log_print(text: str = "") -> None:
    print(text)
    _log_write(text + "\n")


def log_input(prompt: str) -> str:
    print(prompt, end="", flush=True)
    ans = input()
    _log_write(prompt + ans + "\n")
    return ans


# --- Version ---

def get_godot_version(godot_root: str) -> str:
    version_file = os.path.join(godot_root, "version.py")
    if not os.path.isfile(version_file):
        return "4.x.stable"
    data = {}
    with open(version_file) as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                key, _, val = line.partition("=")
                data[key.strip()] = val.strip().strip('"').strip("'")
    major  = data.get("major", "4")
    minor  = data.get("minor", "0")
    patch  = data.get("patch", "0")
    status = data.get("status", "stable")
    return f"{major}.{minor}.{patch}.{status}"


# --- Template packing ---

def strip_extra_suffix(fname: str, extra_suffix: str) -> str:
    if not extra_suffix:
        return fname

    suffix = extra_suffix if extra_suffix.startswith(".") else f".{extra_suffix}"

    if suffix in fname:
        return fname.replace(suffix, "", 1)

    return fname

def pack_tpz(godot_root: str, platforms: list[str],
             version: str, rename_official: bool,
             extra_suffix: str = "") -> None:
    bin_dir  = os.path.join(godot_root, "bin")
    out_path = os.path.join(bin_dir, f"Godot_v{version}_export_templates.tpz")

    log_print(f"\nPacking export templates → {out_path}")
    if rename_official:
        log_print("  Using official Godot template filenames.")
    else:
        log_print("  Using scons output filenames (as-is).")

    found_any = False
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("templates/version.txt", version)
        log_print(f"  + templates/version.txt ({version})")

        for platform in platforms:
            rename_map = TEMPLATE_RENAME_MAP.get(platform, {})

            for fname in sorted(os.listdir(bin_dir)):
                src = os.path.join(bin_dir, fname)
                if not os.path.isfile(src):
                    continue

                platform_prefix = f"godot.{platform}." if platform != "android" else ""
                is_platform_file = (
                    fname.startswith(platform_prefix) if platform_prefix
                    else fname in rename_map
                )
                if not is_platform_file:
                    continue

                lookup_name = strip_extra_suffix(fname, extra_suffix)

                if rename_official and lookup_name in rename_map:
                    archive_name = rename_map[lookup_name]
                else:
                    archive_name = fname

                zf.write(src, f"templates/{archive_name}")
                size_mb = os.path.getsize(src) / 1024 / 1024
                arrow   = f" → {archive_name}" if archive_name != fname else ""
                log_print(f"  + {fname}{arrow} ({size_mb:.1f} MB)")
                found_any = True

        icu_file = os.path.join(bin_dir, "icudt_godot.dat")
        if os.path.isfile(icu_file):
            zf.write(icu_file, "templates/icudt_godot.dat")
            size_mb = os.path.getsize(icu_file) / 1024 / 1024
            log_print(f"  + icudt_godot.dat ({size_mb:.1f} MB)")

    if found_any:
        total_mb = os.path.getsize(out_path) / 1024 / 1024
        log_print(f"\nDone: {out_path} ({total_mb:.1f} MB)")
    else:
        os.remove(out_path)
        log_print("[ERROR] No template files found in bin/, .tpz not created.")


# --- Template loading ---

def load_template_file(path: str) -> list[str]:
    if not os.path.isfile(path):
        log_print(f"[ERROR] Template file not found: {path}")
        sys.exit(1)
    disabled = []
    skipped  = []
    with open(path, encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            key   = key.strip()
            value = value.strip().strip('"').strip("'")
            if key in REQUIRED_MODULES:
                skipped.append(key)
                continue
            if value.lower() == "no":
                disabled.append(f"{key}=no")
    if skipped:
        log_print(f"  [WARNING] Skipped required modules: {', '.join(skipped)}")
    return disabled


def ask_modules_source(godot_root: str) -> list[str]:
    log_print("\nModule configuration:")
    log_print("  1. Interactive (ask for each module)")
    log_print("  2. Load from file (godot-build-options-generator format)")
    log_print("  3. Use default template (minimal build)")
    log_print("  4. No changes (keep all modules)")
    ans = log_input("Choice [1/2/3/4]: ").strip()
    if ans == "1":
        return ask_modules()
    if ans == "2":
        log_print("\n  Tip: generate at https://godot-build-options-generator.github.io")
        path = log_input("  Path to template file: ").strip().strip('"')
        if not os.path.isabs(path):
            path = os.path.join(godot_root, path)
        disabled = load_template_file(path)
        log_print(f"  Loaded {len(disabled)} disabled modules from file.")
        return disabled
    if ans == "3":
        disabled = [f"{k}={v}" for k, v in DEFAULT_TEMPLATE.items()
                    if k not in REQUIRED_MODULES]
        log_print(f"  Default template: {len(disabled)} modules disabled.")
        return disabled
    return []


def ask_modules() -> list[str]:
    log_print("\nAvailable modules (Enter — keep, 'n' — disable):")
    disabled = []
    for mod in OPTIONAL_MODULES:
        if mod in REQUIRED_MODULES:
            log_print(f"  {mod}? [required, skipping]")
            continue
        ans = log_input(f"  {mod}? [Y/n]: ").strip().lower()
        if ans == "n":
            disabled.append(f"{mod}=no")
    return disabled


# --- MSVC / MinGW ---

def find_vcvars() -> str:
    for path in MSVC_PATHS:
        if os.path.isfile(path):
            return path
    return ""


def load_msvc_env(vcvars_path: str) -> dict:
    cmd    = f'"{vcvars_path}" && set'
    result = subprocess.run(cmd, shell=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    env = {}
    for line in result.stdout.splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            env[key.strip()] = value.strip()
    return env


def ask_compiler(platform: str) -> tuple[bool, str, dict]:
    if platform != "windows":
        return False, "", {}
    log_print("\nCompiler:")
    log_print("  1. MSVC (Visual Studio)")
    log_print("  2. MinGW")
    ans = log_input("Choice [1/2]: ").strip()
    if ans == "2":
        log_print("\nMinGW prefix examples:")
        log_print("  C:/mingw64")
        log_print("  C:/msys64/mingw64")
        log_print("  C:/msys64/ucrt64")
        prefix = log_input("Enter MinGW path (Enter — skip): ").strip().replace("\\", "/")
        return True, prefix, {}
    vcvars = find_vcvars()
    if vcvars:
        log_print(f"  Found: {vcvars}")
        if log_input("  Use this? [Y/n]: ").strip().lower() == "n":
            vcvars = ""
    if not vcvars:
        vcvars = log_input("  Enter path to vcvars64.bat: ").strip().strip('"')
    if not os.path.isfile(vcvars):
        log_print(f"[ERROR] vcvars64.bat not found: {vcvars}")
        sys.exit(1)
    log_print("  Loading MSVC environment...")
    env = load_msvc_env(vcvars)
    log_print("  MSVC environment loaded.")
    return False, "", env


# --- Questions ---

def ask_platform() -> str:
    log_print("\nPlatforms:")
    for i, p in enumerate(PLATFORMS, 1):
        log_print(f"  {i}. {p}")
    while True:
        ans = log_input("Select platform (number or name): ").strip().lower()
        if ans.isdigit() and 1 <= int(ans) <= len(PLATFORMS):
            return PLATFORMS[int(ans) - 1]
        if ans in PLATFORMS:
            return ans
        log_print("Invalid input, try again.")


def ask_template_platforms() -> list[str]:
    log_print("\nSelect platforms for export templates (comma-separated numbers or names):")
    for i, p in enumerate(PLATFORMS, 1):
        log_print(f"  {i}. {p}")
    log_print("  Example: 1,2  or  windows,linuxbsd")
    while True:
        ans     = log_input("Platforms: ").strip().lower()
        parts   = [p.strip() for p in ans.split(",") if p.strip()]
        result  = []
        invalid = False
        for part in parts:
            if part.isdigit() and 1 <= int(part) <= len(PLATFORMS):
                result.append(PLATFORMS[int(part) - 1])
            elif part in PLATFORMS:
                result.append(part)
            else:
                log_print(f"  [ERROR] Unknown platform: '{part}'")
                invalid = True
                break
        if not invalid and result:
            return list(dict.fromkeys(result))
        log_print("  Please enter at least one valid platform.")


def ask_targets() -> list[str]:
    log_print("\nWhat to build:")
    log_print("  1. Editor only")
    log_print("  2. Export templates only (debug + release)")
    log_print("  3. Everything (editor + templates)")
    ans = log_input("Choice [1/2/3]: ").strip()
    if ans == "1":
        return ["editor"]
    if ans == "2":
        return ["template_debug", "template_release"]
    return ["editor", "template_debug", "template_release"]


def ask_optimize(targets: list[str]) -> str:
    if not any(t.startswith("template") for t in targets):
        return ""
    ans = log_input("\nOptimize template builds for size? (longer build time) [y/N]: ").strip().lower()
    return "optimize=size" if ans == "y" else ""


def ask_encryption_key(targets: list[str]) -> str:
    if not any(t.startswith("template") for t in targets):
        return ""
    log_print("\nScript encryption key for export templates.")
    log_print("  Must be a 64-character hex string (256-bit).")
    log_print("  Example: a3f1e2d4b5c6a7f8e9d0c1b2a3f4e5d6c7b8a9f0e1d2c3b4a5f6e7d8c9b0a1f2")
    while True:
        ans = log_input("  Enter key (Enter — skip): ").strip().lower()
        if ans == "":
            return ""
        if len(ans) == 64 and all(c in "0123456789abcdef" for c in ans):
            return ans
        log_print("  [ERROR] Invalid key. Must be exactly 64 hex characters.")


def ask_production(targets: list[str]) -> bool:
    ans = log_input("\nEnable production build flags? (LTO, no debug symbols) [y/N]: ").strip().lower()
    return ans == "y"


def ask_extra_suffix() -> str:
    log_print("\nExtra suffix for output binaries (e.g. _zmd). Leave empty to skip.")
    return log_input("  Extra suffix (Enter — none): ").strip()


def warn_cross_compile(platforms: list[str], host: str) -> list[str]:
    cross = [p for p in platforms if p != host]
    if not cross:
        return platforms
    log_print("\n[WARNING] Cross-compilation detected:")
    for p in cross:
        note = CROSS_COMPILE_NOTES.get(p, "Unknown toolchain required.")
        log_print(f"  {p}: {note}")
    log_print("\nOptions:")
    log_print("  1. Continue with all platforms (will fail without toolchain)")
    log_print("  2. Remove unsupported platforms, build host only")
    log_print("  3. Cancel")
    ans = log_input("Choice [1/2/3]: ").strip()
    if ans == "1":
        return platforms
    if ans == "2":
        filtered = [p for p in platforms if p == host]
        log_print(f"  Building for host only: {', '.join(filtered)}")
        return filtered
    log_print("Cancelled.")
    _close_log()
    sys.exit(0)


# --- Build ---

def build(platform: str, target: str, jobs: int,
          extra_flags: list[str], use_mingw: bool, mingw_prefix: str,
          optimize_size: str, env: dict, encryption_key: str,
          extra_suffix: str, production: bool) -> bool:
    cmd = ["scons", f"platform={platform}", f"target={target}", f"-j{jobs}"]
    if extra_suffix:
        cmd.append(f"extra_suffix={extra_suffix}")
    if use_mingw:
        cmd.append("use_mingw=yes")
    if mingw_prefix:
        cmd.append(f"MINGW_PREFIX={mingw_prefix}")
    if optimize_size and target.startswith("template"):
        cmd.append(optimize_size)
    if encryption_key and target.startswith("template"):
        cmd.append(f"script_encryption_key={encryption_key}")
    if production:
        cmd.append("production=yes")
    cmd.extend(extra_flags)

    log_print(f"\n{'='*60}")
    log_print(f"  Build:   {target} | {platform}")
    log_print(f"  Command: {' '.join(cmd)}")
    log_print(f"{'='*60}\n")

    process = subprocess.Popen(
        cmd,
        env=env if env else None,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        errors="replace",
    )
    for line in process.stdout:
        print(line, end="")
        _log_write(line)
    process.wait()
    return process.returncode == 0


def build_templates_parallel(platforms: list[str], jobs_total: int,
                              extra_flags: list[str], use_mingw: bool,
                              mingw_prefix: str, optimize_size: str,
                              env: dict, encryption_key: str,
                              extra_suffix: str, production: bool) -> list[str]:
    per_platform     = max(1, jobs_total // len(platforms))
    template_targets = ["template_debug", "template_release"]
    failed           = []
    lock             = threading.Lock()

    def run_platform(platform: str) -> None:
        for target in template_targets:
            ok = build(platform, target, per_platform, extra_flags,
                       use_mingw, mingw_prefix, optimize_size, env,
                       encryption_key, extra_suffix, production)
            if not ok:
                with lock:
                    failed.append(f"{target}|{platform}")
                log_print(f"\n[ERROR] Build '{target}|{platform}' failed.")

    log_print(f"\nStarting {len(platforms)} parallel platform builds "
              f"({per_platform} cores each)...")
    log_print("  NOTE: debug/release per platform are sequential to avoid obj conflicts.\n")

    threads = [threading.Thread(target=run_platform, args=(p,), daemon=True)
               for p in platforms]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    return failed


# --- Main ---

def main() -> None:
    parser = argparse.ArgumentParser(description="Godot Engine Builder")
    parser.add_argument("source_root", nargs="?", default=None,
                        help="Path to Godot source root (default: current directory)")
    parser.add_argument("--jobs", type=int, default=0,
                        help="Number of CPU cores (0 = all available)")
    parser.add_argument("--template", type=str, default=None,
                        help="Path to module template file")
    args = parser.parse_args()

    if args.source_root is None:
        godot_root = os.getcwd()
        print("\nNo directory specified. Using current directory as Godot Source Root.")
    else:
        godot_root = os.path.abspath(args.source_root)

    if not os.path.isdir(godot_root):
        print(f"\n[ERROR] Directory not found: {godot_root}")
        sys.exit(1)
    if not os.path.isfile(os.path.join(godot_root, "SConstruct")):
        print(f"\n[ERROR] No SConstruct found in: {godot_root}")
        print("        Make sure this is a valid Godot source root.")
        sys.exit(1)

    _open_log(godot_root)
    log_print(f"Godot source root: {godot_root}")
    os.chdir(godot_root)

    jobs = args.jobs or multiprocessing.cpu_count()
    log_print(f"CPU cores for build: {jobs}")

    host = ("windows" if _platform.system() == "Windows" else
            "macos"   if _platform.system() == "Darwin"  else "linuxbsd")

    platform                     = ask_platform()
    use_mingw, mingw_prefix, env = ask_compiler(platform)
    targets                      = ask_targets()

    if args.template:
        log_print(f"\nLoading module template: {args.template}")
        disabled = load_template_file(args.template)
        log_print(f"  {len(disabled)} modules disabled.")
    else:
        disabled = ask_modules_source(godot_root)

    optimize_size  = ask_optimize(targets)
    encryption_key = ask_encryption_key(targets)
    production     = ask_production(targets)
    extra_suffix   = ask_extra_suffix()

    template_platforms = [platform]
    if any(t.startswith("template") for t in targets):
        log_print("\nBuild templates for multiple platforms?")
        if log_input("  [y/N]: ").strip().lower() == "y":
            template_platforms = ask_template_platforms()
            template_platforms = warn_cross_compile(template_platforms, host)

    # Summary
    log_print(f"\n--- Build Summary {'='*42}")
    log_print(f"  Host:               {host}")
    log_print(f"  Editor platform:    {platform}")
    log_print(f"  Template platforms: {', '.join(template_platforms)}")
    log_print(f"  Targets:            {', '.join(targets)}")
    log_print(f"  Compiler:           {'MinGW' if use_mingw else 'MSVC'}")
    if mingw_prefix:
        log_print(f"  MinGW prefix:       {mingw_prefix}")
    log_print(f"  Jobs:               {jobs}")
    log_print(f"  Modules disabled:   {len(disabled)}")
    if disabled:
        for d in disabled:
            log_print(f"    - {d}")
    if extra_suffix:
        log_print(f"  Extra suffix:       {extra_suffix}")
    if optimize_size:
        log_print("  Size optimization:  enabled")
    if encryption_key:
        log_print(f"  Encryption key:     {encryption_key[:8]}...{encryption_key[-8:]}")
    if production:
        log_print("  Production mode:    enabled (LTO, no debug symbols)")
    log_print(f"{'='*60}")

    if log_input("\nStart build? [Y/n]: ").strip().lower() == "n":
        log_print("Cancelled.")
        _close_log()
        sys.exit(0)

    failed = []

    if "editor" in targets:
        ok = build(platform, "editor", jobs, disabled,
                   use_mingw, mingw_prefix, optimize_size, env,
                   encryption_key, extra_suffix, production)
        if not ok:
            failed.append(f"editor|{platform}")
            log_print("\n[ERROR] Build 'editor' failed.")

    template_targets = [t for t in targets if t.startswith("template")]
    if template_targets:
        if len(template_platforms) > 1:
            failed.extend(build_templates_parallel(
                template_platforms, jobs, disabled,
                use_mingw, mingw_prefix, optimize_size, env,
                encryption_key, extra_suffix, production,
            ))
        else:
            for target in template_targets:
                ok = build(template_platforms[0], target, jobs, disabled,
                           use_mingw, mingw_prefix, optimize_size, env,
                           encryption_key, extra_suffix, production)
                if not ok:
                    failed.append(f"{target}|{template_platforms[0]}")
                    log_print(f"\n[ERROR] Build '{target}' failed.")

    log_print(f"\n{'='*60}")
    if not failed:
        log_print("  All builds completed successfully.")
    else:
        log_print(f"  Failed: {', '.join(failed)}")
    log_print(f"{'='*60}")

    # Pack .tpz
    if template_targets:
        version = get_godot_version(godot_root)
        log_print(f"\nPack templates into .tpz? (version: {version})")
        if log_input("  [Y/n]: ").strip().lower() != "n":
            log_print("\nUse official Godot filenames inside .tpz?")
            log_print("  (Required for 'Install from file' in the editor)")
            rename = log_input("  [Y/n]: ").strip().lower() != "n"
            pack_tpz(godot_root, template_platforms, version, rename, extra_suffix=extra_suffix)

    _close_log()



if __name__ == "__main__":
    main()