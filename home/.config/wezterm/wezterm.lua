-- WezTerm configuration -- https://wezterm.org/config/files.html
--
-- Layout and behaviour follow github.com/kunchenguid/dotfiles (home/.config/wezterm),
-- with the font and shell kept as-is for this machine and the macOS-only bits replaced
-- by their Windows equivalents. Deviations are commented where they occur.

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

local FONT = 'CaskaydiaCove Nerd Font Mono'

-- CaskaydiaCove Nerd Font v3.5.1, installed per-user in four faces. The same family
-- name is what the Windows Terminal profile uses, so both terminals stay in sync.
-- DirectWrite also exposes it under its Win32 name, "CaskaydiaCove NFM".
config.font = wezterm.font_with_fallback {
  FONT,
  'Cascadia Mono',
  'Segoe UI Emoji',
}
config.font_size = 11.0

-- This WezTerm build does not pick the Bold face out of the family on its own: left to
-- itself it falls back to Cascadia Mono for bold and synthesizes bold italic. Naming
-- each face explicitly makes it load the real files. Verified with `wezterm ls-fonts`.
config.font_rules = {
  { intensity = 'Bold', italic = false, font = wezterm.font(FONT, { weight = 'Bold' }) },
  { intensity = 'Bold', italic = true, font = wezterm.font(FONT, { weight = 'Bold', style = 'Italic' }) },
  { intensity = 'Normal', italic = true, font = wezterm.font(FONT, { style = 'Italic' }) },
}

-- A glyph the font lacks should fall through to the fallback list quietly rather than
-- drawing attention to itself.
config.warn_about_missing_glyphs = false

config.color_scheme = 'rose-pine-moon'

-- The PowerShell profile that loads starship lives in Documents\PowerShell, which is
-- PowerShell 7. WezTerm would otherwise start Windows PowerShell 5.1 and load neither.
local PWSH = [[C:\Program Files\PowerShell\7\pwsh.exe]]
config.default_prog = { PWSH, '-NoLogo' }

-- What a new tab offers to start. Spelled out rather than taken from
-- wezterm.default_wsl_domains(), which enumerates every registered distribution --
-- docker-desktop's included, and that one is plumbing, not a shell to sit in.
config.launch_menu = {
  { label = 'PowerShell', args = { PWSH, '-NoLogo' } },
  { label = 'Ubuntu 24.04 (WSL)', args = { 'wsl.exe', '--distribution', 'Ubuntu-24.04', '--cd', '~' } },
}

config.scrollback_lines = 10000
config.window_padding = { left = 8, right = 8, top = 8, bottom = 4 }

-- macos_window_background_blur has no effect off macOS; the Windows 11 equivalent is a
-- system backdrop, which only shows through while the window is translucent.
config.window_background_opacity = 0.9
config.win32_system_backdrop = 'Acrylic'

-- No title bar, no window buttons, just a resize edge -- same as upstream. On Windows
-- that also takes the close/minimise buttons with it, since they live in the title bar
-- rather than in a strip of their own: close with Alt+F4, move with Alt+Space then M.
config.window_decorations = 'RESIZE'
config.hide_tab_bar_if_only_one_tab = true

-- Ctrl+T / Ctrl+W for tabs, the shape the rest of Windows uses. WezTerm's own
-- Ctrl+Shift+T / Ctrl+Shift+W stay bound as well.
--
-- Ctrl+W is also vim's window prefix, and a key the terminal claims never reaches the
-- program inside it -- binding it outright would put nvim's splits out of reach. So the
-- editors that want the key get it, and everything else closes the tab.
local CTRL_W_BELONGS_TO = { ['nvim.exe'] = true, ['vim.exe'] = true, ['hx.exe'] = true }

local function process_name(pane)
  local path = pane:get_foreground_process_name()
  if not path then
    return ''
  end
  return (path:match('[^/\\]+$') or path):lower()
end

-- Ctrl+T picks from launch_menu instead of spawning the default shell outright; the
-- stock Ctrl+Shift+T still spawns one without asking, for when that is what you want.
local NEW_TAB = act.ShowLauncherArgs { flags = 'LAUNCH_MENU_ITEMS', title = 'New tab' }

-- The + button on the tab bar is the same gesture, so it asks the same question.
-- Returning false keeps WezTerm from also spawning its own default tab.
wezterm.on('new-tab-button-click', function(window, pane, button)
  if button == 'Left' then
    window:perform_action(NEW_TAB, pane)
    return false
  end
end)

config.keys = {
  { key = 't', mods = 'CTRL', action = NEW_TAB },
  {
    key = 'w',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      if CTRL_W_BELONGS_TO[process_name(pane)] then
        window:perform_action(act.SendKey { key = 'w', mods = 'CTRL' }, pane)
      else
        -- confirm = true only prompts when something other than the shell is running,
        -- which is what keeps a mistyped Ctrl+W from killing a build.
        window:perform_action(act.CloseCurrentTab { confirm = true }, pane)
      end
    end),
  },
}

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
  if actual == nil or expected == nil then
    return actual == expected
  end
  return actual.hue == expected.hue
    and actual.saturation == expected.saturation
    and actual.brightness == expected.brightness
end

wezterm.on('window-focus-changed', function(window)
  local overrides = window:get_config_overrides() or {}
  local text_hsb, opacity
  if not window:is_focused() then
    text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
    opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
  end

  -- Only write when one of the two values we own actually changes; a redundant
  -- set_config_overrides() call would trigger another config reload.
  if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
    return
  end

  overrides.foreground_text_hsb = text_hsb
  overrides.window_background_opacity = opacity
  window:set_config_overrides(overrides)
end)

return config
