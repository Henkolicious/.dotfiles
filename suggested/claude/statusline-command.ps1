# A Claude Code statusline showing, after the model name, how full the context window is
# and how much of the 5-hour and 7-day rate-limit windows has been spent:
#
#   Opus 5 | ctx 34% | session 12% (3h41m) | week 58% (4d2h)
#
# Copy this file to ~/.claude/ and point settings.json at it -- see suggested/claude/README.md.

# Claude Code captures this script's stdout, and on a redirected stream PowerShell sets
# OutputRendering to PlainText and strips every ANSI escape - which silently discarded the
# colours below. Forcing ANSI keeps them.
if ($PSStyle) { $PSStyle.OutputRendering = 'ANSI' }

$input_data = $input | Out-String | ConvertFrom-Json

$model = if ($input_data.model.display_name) { $input_data.model.display_name } else { "Claude" }
$remaining = $input_data.context_window.remaining_percentage
$session = $input_data.rate_limits.five_hour
$week = $input_data.rate_limits.seven_day

$cyan  = "`e[0;36m"
$green = "`e[0;32m"
$yellow= "`e[0;33m"
$red   = "`e[0;31m"
$dim   = "`e[0;90m"
$reset = "`e[0m"

function Get-LoadColor($pct) {
    if ($pct -ge 90) { $script:red } elseif ($pct -ge 75) { $script:yellow } else { $script:green }
}

# rate_limits carries resets_at as unix seconds. Showing how long the window still has to
# run makes a high percentage actionable: throttle now, or wait it out.
function Format-Reset($epoch) {
    if ($null -eq $epoch) { return $null }
    $span = [DateTimeOffset]::FromUnixTimeSeconds([long]$epoch) - [DateTimeOffset]::Now
    if ($span.TotalSeconds -le 0) { return $null }
    if ($span.TotalDays -ge 1)  { return "{0}d{1}h" -f [int]$span.TotalDays, $span.Hours }
    if ($span.TotalHours -ge 1) { return "{0}h{1:00}m" -f [int]$span.TotalHours, $span.Minutes }
    return "{0}m" -f [math]::Max(1, [int]$span.TotalMinutes)
}

# Every field here is absent on some plans and in some sessions, so each one is skipped
# rather than printed empty; the statusline degrades to just the model name.
function Format-Limit($label, $limit) {
    if ($null -eq $limit -or $null -eq $limit.used_percentage) { return $null }
    $pct = [int][math]::Round($limit.used_percentage)
    $c = Get-LoadColor $pct
    $until = Format-Reset $limit.resets_at
    if ($until) { return "${c}${label} ${pct}% ${script:dim}(${until})${script:reset}" }
    return "${c}${label} ${pct}%${script:reset}"
}

$parts = @("${cyan}${model}${reset}")

# The payload reports what is left; the interesting number is what is gone, so that all
# three percentages rise as the session wears on and share one colour scale.
if ($null -ne $remaining) {
    $used = 100 - [int][math]::Round($remaining)
    $c = Get-LoadColor $used
    $parts += "${c}ctx ${used}%${reset}"
}

foreach ($p in @((Format-Limit 'session' $session), (Format-Limit 'week' $week))) {
    if ($p) { $parts += $p }
}

$sep = " ${dim}|${reset} "
Write-Host ($parts -join $sep) -NoNewline
