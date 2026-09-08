# Anthropic's usage response in, a provider-neutral document out.
#
# This is the only place in the shell that knows Anthropic's field names. What
# comes out is a list of providers, each with a list of windows, so a second
# provider is another entry rather than a change to anything downstream.
#
# Fed `{}` -- which is what a failed or unparseable request becomes -- it emits
# the same document with every number null and the status "unknown". One shape,
# defined once, and no path through it that invents a number.
#
# Every field is type-checked rather than trusted. The endpoint is undocumented
# and internal (its responses carry fields called `nimbus_quill` and
# `iguana_necktie`), so it can change shape without warning, and a changed shape
# must read as "unknown" and not as 0%. Plenty of headroom, shown at the moment
# there is none, is the one failure this indicator exists to prevent.

def num($v): if ($v | type) == "number" then $v else null end;
def txt($v): if ($v | type) == "string" then $v else null end;
def win($id; $label; $src):
    { id: $id,
      label: $label,
      percent: num($src.utilization),
      resetsAt: txt($src.resets_at),
      lockedReason: txt($src.locked_reason) };

(if type == "object" then . else {} end) as $r
| (if ($r.five_hour | type) == "object" then $r.five_hour else {} end) as $session
| (if ($r.seven_day | type) == "object" then $r.seven_day else {} end) as $weekly
| [ win("session"; "Session"; $session), win("weekly"; "Weekly"; $weekly) ] as $windows
| { providers: [ {
      id: "claude",
      name: "Claude",
      # locked beats ok: being told you are limited outranks any number.
      status: (if   ([$windows[] | .lockedReason] | any(. != null)) then "locked"
               elif ([$windows[] | .percent]      | any(. != null)) then "ok"
               else "unknown" end),
      model: (if $model == "" then null else $model end),
      windows: $windows } ] }
