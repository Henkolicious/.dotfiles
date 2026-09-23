# Suggested Claude Code configuration

Nothing in `suggested/` is installed. `~/.claude` stays outside this repo on purpose --
it holds machine and account state next to its settings -- so this is an offer, not a
step: take it if the machine is going to run Claude Code, skip it otherwise.

## The statusline

`statusline-command.ps1` prints one line under the prompt:

```
Opus 5 | ctx 34% | session 12% (3h41m) | week 58% (4d2h)
```

- **ctx** -- how full the context window is. Watching it climb is the cue to wrap a
  thread up or hand off before a compaction happens mid-task.
- **session** -- the 5-hour rate-limit window, and how long it has left to run.
- **week** -- the 7-day window, same shape.

Each turns yellow at 75% and red at 90%. A field the payload does not carry is dropped
rather than shown empty, so the line degrades to just the model name.

## Installing it

Copy the script into `~/.claude` and name it in `settings.json` -- the path has to be
absolute, so substitute the real username:

```powershell
Copy-Item .\suggested\claude\statusline-command.ps1 $HOME\.claude\
```

```jsonc
{
  "statusLine": {
    "type": "command",
    "command": "pwsh.exe -NoProfile -File \"C:/Users/<you>/.claude/statusline-command.ps1\""
  }
}
```

`pwsh.exe`, not `powershell.exe`: the script uses `$PSStyle`, which is PowerShell 7 only.
Forward slashes in the JSON avoid escaping backslashes. Claude Code picks the new
statusline up on the next prompt render; no restart.

Copying rather than junctioning is deliberate here, and the one place in this repo where
two copies of a file are fine -- the alternative is claiming a directory that Claude Code
writes its own state into.
