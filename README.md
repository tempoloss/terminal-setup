# AnekTerminal

A minimal Windows Terminal setup: PowerShell, Oh My Posh, MesloLGS Nerd Font, and a two-line prompt. One script installs everything and applies it.

```text
C:\Users\Anek\kao on  master is 󰏗 v0.1.0 via  v3.13.12
› your command here
```

| part | meaning |
|---|---|
| `C:\Users\Anek\kao` | full current directory |
| `on  master` | git branch — only inside a repo |
| `is 󰏗 v0.1.0` | project version read from `pyproject.toml`, `package.json`, etc. |
| `via  v3.13.12` | Python version, resolved through `uv` |
| `›` | the input line, kept separate from the status line |

Status on top, input underneath — so a long path never pushes what you're typing off to the right.

## Requirements

- Windows 10 / 11 with [winget](https://learn.microsoft.com/windows/package-manager/winget/)
- An internet connection for the first run

Everything else — PowerShell 7, Windows Terminal, Oh My Posh, the font — is installed by the script if missing.

## Install

```powershell
git clone https://github.com/an8kk/AnekTerminal.git
cd AnekTerminal/dotfiles/terminal
pwsh -ExecutionPolicy Bypass -File setup.ps1
```

Restart Windows Terminal afterwards.

> Use `pwsh` (PowerShell 7) rather than `powershell` (5.1). The script parses your existing `settings.json`, and 5.1's JSON parser chokes on the comments Windows Terminal ships in that file.

## What it changes on your machine

Worth reading before you run it — the script edits a config file you may have customised.

**Installs via winget** (skipped if already present): PowerShell, Windows Terminal, Oh My Posh. Then MesloLGS Nerd Font through Oh My Posh.

**Copies into your home directory:**
- `minimal.omp.json` — the prompt theme
- `terminalbg-<hash>.png` — the background image, hashed so a new image never gets served from cache

**Overwrites your PowerShell profile** at all four locations, so the prompt shows up in both PowerShell 7 and Windows PowerShell:

```
Documents\PowerShell\profile.ps1
Documents\PowerShell\Microsoft.PowerShell_profile.ps1
Documents\WindowsPowerShell\profile.ps1
Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

**Rewrites Windows Terminal `settings.json`** — adds an `Anek` colour scheme and sets these under `profiles.defaults`:

| setting | value |
|---|---|
| `colorScheme` | `Anek` |
| `font.face` | `MesloLGS Nerd Font` |
| `backgroundImage` | the hashed copy in your home directory |
| `backgroundImageOpacity` | `0.22` |
| `backgroundImageStretchMode` | `uniformToFill` |
| `cursorShape` | `bar` |
| `useAcrylic` | `false` |
| `opacity` | `100` |

Other colour schemes and profiles are preserved. **Comments in `settings.json` are not** — the file is reparsed and rewritten. Back it up first if it holds anything you care about:

```powershell
$s = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Copy-Item $s "$s.bak"
```

If Windows Terminal has never been opened, `settings.json` won't exist yet. The script says so and skips the appearance step — open the terminal once, then run it again.

## Customising

**Background strength** — `backgroundImageOpacity` in Windows Terminal settings. `0.22` is subtle; raise it for a stronger image, or drop `backgroundImage` entirely for a plain background.

**Your own image** — replace `terminalbg.png` and rerun `setup.ps1`. The filename hash changes, which is what stops Windows Terminal from showing the previous image out of cache.

**Prompt segments** — edit `~/minimal.omp.json`. It's a standard [Oh My Posh](https://ohmyposh.dev/docs/configuration/overview) config: the first block is the status line, the second is the `›`. Changes apply on the next shell.

**Colours** — the `Anek` scheme lives in `setup.ps1` as `$anekScheme`. Edit and rerun, or just change the scheme in Windows Terminal.

## Reverting

```powershell
# restore the settings backup you made above
Move-Item "$s.bak" $s -Force

# drop the profiles
Remove-Item "$HOME\Documents\PowerShell\*profile.ps1"
Remove-Item "$HOME\Documents\WindowsPowerShell\*profile.ps1"

# and the copied assets
Remove-Item "$HOME\minimal.omp.json", "$HOME\terminalbg-*.png"
```

winget-installed packages stay; remove them with `winget uninstall` if you want them gone.

## Layout

```
dotfiles/terminal/
  setup.ps1                        installs everything and applies it
  minimal.omp.json                 Oh My Posh prompt theme
  Microsoft.PowerShell_profile.ps1 loads the theme, guarded against double-init
  terminalbg.png                   background image
```
