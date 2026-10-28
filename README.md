# bright keys.

<p align="center">
  <img src="https://raw.githubusercontent.com/alaska14/brightkeys/main/docs/BrightKeys-Final-Card.png" alt="bright keys. by MonoLab" width="700">
</p>

<p align="center">
  <b>Restore dedicated keyboard backlight control to F5 and F6 on Apple Silicon MacBooks.</b><br>
  Zero background daemons · 0.0% CPU overhead · Native macOS kernel HID remapping.
</p>

<p align="center">
  <a href="https://monolab-apps.gumroad.com"><img src="https://img.shields.io/badge/Gumroad-Buy%20Direct-FF90E8?style=flat-square&logo=gumroad" alt="Buy Direct on Gumroad"></a>
  <a href="https://github.com/alaska14/brightkeys/releases/latest"><img src="https://img.shields.io/badge/Download-DMG-blue?style=flat-square" alt="Download DMG"></a>
  <a href="https://github.com/alaska14/homebrew-tap"><img src="https://img.shields.io/badge/Homebrew-Tap-orange?style=flat-square" alt="Homebrew Tap"></a>
</p>

---

## The Problem

On Apple Silicon MacBooks (M1, M2, M3, M4), Apple removed the dedicated keyboard backlight keys and replaced them with **Dictation (F5)** and **Focus Mode (F6)**. 

To get their keys back, users have historically had to install bloated tools like Karabiner-Elements—which run four separate background daemons, install virtual drivers, and drain battery life.

## The Solution

**bright keys.** restores native hardware keyboard backlight control to your F5 and F6 keys with **zero background bloat**:

* **F5 (Dictation / Mic)** $\rightarrow$ **Dims Keyboard Backlight** (`illumination_down`)
* **F6 (Focus / Moon)** $\rightarrow$ **Increases Keyboard Backlight** (`illumination_up`)

---

## Highlights

* **0.0% CPU & 0 MB RAM:** Configures macOS's kernel-level Human Interface Device (`hidutil`) subsystem directly.
* **Persistent Across Reboots:** Starts automatically with macOS so your keys always work.
* **Sleep & Wake Resilient:** Automatically re-arms when waking from sleep or connecting external displays.
* **One-Click Toggle:** Sleek menu bar item matching macOS's native aesthetics.

---

## Installation

### Option 1: Direct Download
Download the latest `BrightKeys-1.0.dmg` from the [Releases](https://github.com/alaska14/brightkeys/releases/latest) page, open it, and drag `BrightKeys.app` to `/Applications`.

### Option 2: Homebrew
```bash
brew tap alaska14/tap
brew install --cask brightkeys
```

---

## Crafted by MonoLab

Part of the **MonoLab** micro-utility suite:
* **[clean keys.](https://github.com/alaska14/cleankeys)** — Clean your keyboard and trackpad safely without accidental keypresses.
* **[fold awake.](https://github.com/alaska14/foldawake)** — Keep your MacBook awake with the lid shut.
* **[charge watts.](https://github.com/alaska14/chargewatts)** — Native battery replacement showing live charging wattage and current draw.
* **[bright keys.](https://github.com/alaska14/brightkeys)** — Restore F5/F6 keyboard backlight keys on Apple Silicon.

---

## License

MIT License. Crafted with precision for macOS.
