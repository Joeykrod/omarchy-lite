-- Change the default Omarchy look'n'feel.
--
-- Omarchy Lite: low-RAM profile for old CPUs / <2 GB RAM.
-- This file loads AFTER Omarchy's defaults, so the theme, top bar and
-- Super+Space launcher are unchanged. Only expensive effects are trimmed.
hl.config({
  animations = { enabled = false },
  decoration = {
    blur = { enabled = false },
    shadow = { enabled = false },
    rounding = 0,
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_scale_notification = true,
  },
})

-- Opt another application in to Omarchy's standard transparency.
-- o.transparent_window("my-app")

-- Re-enable animations on a faster machine by deleting the block above or
-- running:  omarchy-lite-agent  ->  "Apply low-RAM graphics profile"
