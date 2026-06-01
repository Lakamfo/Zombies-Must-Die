# Godot Builder & Godot Secure Guide

Interactive CLI tools to patch, secure, and build **Godot Engine from source**.

## Requirements

* **Python 3.8+** & **SCons**
* **C++ Toolchain:** MSVC/MinGW (Win), GCC/Clang (Linux), Xcode (macOS).
* *Optional:* Android NDK, Emscripten (Web), `llvm-mingw` (Cross-compile), **OpenSSL** (for keygen).

---

## Quick Start

### 1. Download & Preparation

1. Download the matching version from [Godot Secure Releases](https://github.com/KnifeXRage/Godot-Secure/releases/tag/v4.0-Released).
2. Generate a 256-bit encryption key and save it securely (needed for builds and exports):

```bash
openssl rand -hex 32 > godot.gdkey

```

### 2. Guard & Patch (Godot Secure)

Run the protection script inside your Godot source directory:

```bash
python godot_secure.py /path/to/godot_source/

```

> **Note:** Accept all prompts, enable recommended options (including key derivation), and provide your generated key.

### 3. Build Engine & Templates (Godot Builder)

Run the builder tool:

```bash
python godot_builder.py /path/to/godot_source/

```

* **Options:** Select your target platforms and toolchains.
* **Modules:** Default preset is recommended (tested & suitable for *Zombies Must Die*).
* **Encryption:** Use the same key from Step 1. Skip `.tpz` packaging if global install isn't needed.

---

## 4. Godot Editor & Export Setup

1. Open your project in the newly built Godot Editor.
2. Go to **Project -> Export**.
3. Enable encryption in the export tab and enter your encryption key.
4. Specify your custom export binaries.
5. **Verify:** Test the final binaries against decompilation using [gdsdecomp](https://github.com/GDRETools/gdsdecomp).

---

### Reference & Docs

* [Official Compiling Guide](https://docs.godotengine.org/en/latest/engine_details/development/compiling/index.html) ([Linux](https://docs.godotengine.org/en/latest/engine_details/development/compiling/compiling_for_linuxbsd.html) / [Windows](https://docs.godotengine.org/en/latest/engine_details/development/compiling/compiling_for_windows.html))
