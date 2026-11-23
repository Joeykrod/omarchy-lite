#!/usr/bin/env bash
# Omarchy Lite: re-check legacy GPU for this user after the desktop starts.
# The system service normally handles this before SDDM; this hook is a safety
# net for users created after installation. Fully offline, no-op on modern PCs.
[ -x /usr/local/bin/omarchy-lite-gpu-detect ] || exit 0
/usr/local/bin/omarchy-lite-gpu-detect --quiet >/dev/null 2>&1 || true
