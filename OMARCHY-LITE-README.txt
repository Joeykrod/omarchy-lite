OMARCHY LITE - old CPU / low RAM build
======================================

Based on official Omarchy 4.5.0 x86_64 ISO, reconfigured for old 2-core
x86-64 PCs with less than 2 GB of RAM. The Omarchy launcher (Super+Space),
top bar, and theme are unchanged.

WHAT IS DIFFERENT
-----------------
* Boot menu default: "Omarchy Lite - low RAM / old CPU"
  - mitigations=off for old CPUs
  - quiet splash removed so boot errors are visible
  - copytoram=n retained (keeps RAM use low)
  - Stock and Safe Graphics boot entries are also provided.

* Low-RAM graphics settings applied to installed system:
  - Hyprland animations disabled
  - blur/shadow off
  - GDK_SCALE 1 instead of 2 (much smaller framebuffers)

* Automatic, fully offline legacy GPU detection:
  - Intel GMA 950 / 915 / 945 / G31 / X3100 / X4500 and similar GPUs are
    detected via lspci/sysfs at boot.
  - On those GPUs only: Mesa GLES/GL version overrides, llvmpipe software
    rendering, split-monitor-workspaces plugin disabled, and the Limine
    mitigations=off boot tweak are applied.
  - On modern GPUs: nothing is applied; full GPU acceleration is preserved.
  - No network, package download, or internet connection is required.

* Terminal agent (two tools), bound to Super+Alt+A:
  - omarchy-lite-agent : guided setup/repair menu (gum TUI)
  - opencode           : OpenCode AI coding agent, BASELINE x64 build
                         (works on CPUs without AVX2, e.g. Core 2 Duo)
                         Bundled in the image; no install needed.

INSTALL
-------
Boot the USB (F12 on Dell), choose the "Omarchy Lite" entry, then run the
normal Omarchy installer. It installs to the internal disk; do NOT point it
at the USB stick.

AFTER INSTALL
-------------
* Super+Space  -> Omarchy launcher (unchanged)
* Super+Alt+A  -> Omarchy Lite guided agent
* `omarchy agent` -> launches OpenCode in a floating terminal
* In OpenCode: /help for commands, /exit to leave. Signing in with /auth
  needs internet, but running the bundled agent does not.

RECOVERY
--------
If the screen is black or Hyprland will not start:
* From a TTY (Ctrl+Alt+F3):  omarchy-lite-safe-mode
* From the Omarchy Lite agent menu: "Repair legacy GPU (offline Safe Graphics Mode)"
* From the USB boot menu: "Omarchy Lite - Safe Graphics Mode"

Logs:
* /var/log/omarchy-lite-gpu.log (system-wide)
* ~/.local/state/omarchy-lite/gpu-setup.log (per user)
