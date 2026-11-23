# Omarchy Lite additions

These files make stock Omarchy 4.5 usable on an old 2-core x86-64 CPU with
less than 2 GB of RAM, **without changing the Omarchy launcher**
(`SUPER + SPACE`) or the look of the desktop.

## What changed

1. **Low-RAM graphics profile** (applied automatically in the installed system)
   - Hyprland animations disabled (biggest CPU/GPU saving).
   - Blur and shadows off.
   - `GDK_SCALE` 1 instead of 2 -> much smaller framebuffers.

2. **Automatic offline legacy GPU detection**
   - Detects Intel GMA 950 / 915 / 945 / G31 / X3100 / X4500 and similar GPUs.
   - Only on those GPUs: Mesa GLES/GL overrides, llvmpipe software rendering,
     split-monitor-workspaces plugin disabled, and `mitigations=off` added to
     the installed Limine boot entry.
   - On modern GPUs the workarounds are removed/not applied, so newer PCs keep
     full hardware acceleration.
   - Runs from a systemd unit before SDDM, plus a per-user post-boot hook.
   - No internet or package download is needed.

3. **Terminal agent** - two tools, both work on old CPUs:
   - `omarchy-lite-agent` - a `gum` TUI for guided setup and repair
     (low-RAM profile, offline GPU repair, display fixes, network check,
     system info, terminal). Bound to `SUPER + ALT + A`.
   - `opencode` - the OpenCode AI coding agent, **baseline x64 build**
     (no AVX2 required), so it runs on Core 2 Duo-era processors. The binary
     is bundled in the image; only signing in needs internet.

## Use

- Press `SUPER + ALT + A` for the guided agent, or run `omarchy-lite-agent`.
- Choose **Launch OpenCode AI agent** to start the code agent. `/auth` needs
  internet, but running OpenCode does not.
- If Hyprland shows a black screen, run `omarchy-lite-safe-mode` from a TTY,
  or choose **Repair legacy GPU (offline Safe Graphics Mode)** in the agent.
  This forces llvmpipe and restarts the display manager.

## Logs

- System-wide: `/var/log/omarchy-lite-gpu.log`
- Per user: `~/.local/state/omarchy-lite/gpu-setup.log`

## Revert

Delete `~/.config/hypr/looknfeel.lua`, `~/.config/hypr/monitors.lua` and
`~/.config/environment.d/omarchy-lite.conf`, then reload Hyprland. To undo the
legacy GPU overrides specifically, run
`sudo omarchy-lite-gpu-detect --system --force` on a machine with a modern GPU.
