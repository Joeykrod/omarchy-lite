-- Keep only your personal keybinding overrides here. Add new bindings with
-- o.bind or replace defaults with o.rebind.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- Omarchy Lite: terminal agent (guided setup/repair + AI code agent).
-- NOTE: the Omarchy launcher on SUPER + SPACE is intentionally left untouched.
o.bind("SUPER + ALT + A", "Omarchy Lite agent", "omarchy-lite-agent")

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"):
--   omarchy_default_bindings = false
