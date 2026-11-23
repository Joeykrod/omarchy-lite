-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
--
-- Omarchy Lite: scale 1 instead of 2. On a <2 GB RAM machine, a 2x
-- framebuffer can consume hundreds of MB and cripple an old integrated GPU.
local omarchy_monitor_scale = 1
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- GDK_SCALE must be a whole number; 1 keeps GTK/XWayland windows small.
hl.env("GDK_SCALE", "1")

-- If your old monitor reports a bad "preferred" mode, uncomment and adjust:
-- hl.monitor({ output = "", mode = "1024x768@60", position = "auto", scale = 1 })
