# Merge the pimp-my-claude hook template into an existing settings.json / hooks.json.
# Shared by setup.sh and setup-codex.sh.
#
# Input:  [existing, template]
# Args:   $mode     "merge" (default re-run) or "upgrade" (--upgrade-hooks)
#         $known    [{event, handler}] every handler this repository has shipped (git history + current)
#         $retired  [command] commands this repository no longer ships; unbound only in "upgrade"
#         $home     $HOME, so "~/x", "$HOME/x" and "/Users/me/x" compare equal
# Output: {settings, report: {added, replaced, removed, unbound, conflicts, differs}}
#
# Rules
# - Existing values win. Keys only in the template are added; nothing else changes in "merge".
# - A template handler is added only if no handler for the same command exists in that event.
# - "upgrade" changes a handler only when its command is ours AND its whole definition equals
#   a version we shipped. If any handler for that command was edited (extra or changed fields),
#   every handler for it is left alone and reported as a conflict.
# - A duplicate is dropped only when an earlier copy sits in a group with the same matcher
#   (same group fields). Copies under another matcher keep that matcher's coverage.
# - Groups are dropped only when this run removed their last handler.

def norm:
  if type != "string" then .
  elif startswith($home + "/") then "~/" + .[($home | length) + 1:]
  elif startswith("$HOME/") then "~/" + .[6:]
  elif startswith("${HOME}/") then "~/" + .[8:]
  else . end;
def nh: if type == "object" and has("command") then .command |= norm else . end;
def cmd: if type == "object" then (.command | norm) else null end;
def member($a): . as $x | any($a[]; . == $x);
def hlabel($ev): "\($ev): \(.command // "?")";

.[0] as $e | .[1] as $t |
# Refuse shapes we do not understand instead of rewriting them.
if ($e | type) != "object" then error("settings is not a JSON object")
elif ($e.hooks != null) and (($e.hooks | type) != "object"
      or any($e.hooks[]; type != "array" or any(.[]; type != "object" or ((.hooks // []) | type) != "array")))
then error("unexpected hooks structure") else . end |
($retired | map(norm)) as $rset |
[ ($t.hooks // {}) | to_entries[] | .key as $ev | .value[] | . as $g
  | (.hooks // [])[] | {event: $ev, group: $g, handler: .} ] as $tpl |
def known_in($ev; $h): any($known[]; .event == $ev and (.handler | nh) == ($h | nh));
def known_any($h): any($known[]; (.handler | nh) == ($h | nh));
def removable($h):
  known_any($h) or ($h.type == "command" and (($h | keys) - ["type", "command"]) == []);

# One event in "upgrade" mode -> {groups, report}
def upgrade_event($ev; $groups):
  [ $tpl[] | select(.event == $ev) ] as $tev |
  [ $tev[] | .handler | cmd ] as $tc |
  [ $groups | to_entries[] | .key as $gi | (.value | del(.hooks)) as $gk
    | (.value.hooks // []) | to_entries[]
    | {gi: $gi, gk: $gk, hi: .key, h: .value, c: (.value | cmd)} ] as $flat |
  [ $flat[] | select((.c | member($tc)) and (known_in($ev; .h) | not)) | .c ] as $conflict |
  [ $flat[] |
    . as $it |
    if ($it.c | member($rset)) then
      if removable($it.h) then $it + {act: "unbind"} else $it + {act: "conflict"} end
    elif ($it.c | member($tc)) then
      if ($it.c | member($conflict)) then $it + {act: "conflict"}
      elif ([ $flat[] | select(.c == $it.c and .gk == $it.gk) ][0] | [.gi, .hi]) == [$it.gi, $it.hi] then
        ([ $tev[] | select((.handler | cmd) == $it.c) ][0].handler) as $new |
        if ($new | nh) == ($it.h | nh) then $it + {act: "keep"}
        else $it + {act: "replace", new: $new} end
      else $it + {act: "drop"} end
    else $it + {act: "keep"} end
  ] as $plan |
  {
    groups: [ $groups | to_entries[] | .key as $gi | .value as $g
      | [ $plan[] | select(.gi == $gi)
          | if .act == "replace" then .new
            elif .act == "drop" or .act == "unbind" then empty
            else .h end ] as $hs
      | if (($g.hooks // []) | length) > 0 and ($hs | length) == 0 then empty
        else (if $g | has("hooks") then $g + {hooks: $hs} else $g end) end ],
    report: {
      replaced: [ $plan[] | select(.act == "replace") | .h | hlabel($ev) ],
      removed:  [ $plan[] | select(.act == "drop") | .h | hlabel($ev) ],
      unbound:  [ $plan[] | select(.act == "unbind") | .h | hlabel($ev) ],
      conflicts: [ $plan[] | select(.act == "conflict") | .h | hlabel($ev) ] | unique
    }
  };

# Add template handlers whose command is not bound in that event yet.
def add_missing($hooks):
  reduce $tpl[] as $x ({hooks: $hooks, added: []};
    ([ (.hooks[$x.event] // [])[] | (.hooks // [])[] | cmd ]) as $have |
    if ($x.handler | cmd | member($have)) then .
    else
      .hooks[$x.event] = ((.hooks[$x.event] // [])
        + [ ($x.group | del(.hooks)) + {hooks: [$x.handler]} ])
      | .added += [ $x.handler | hlabel($x.event) ]
    end);

($e.hooks // {}) as $eh |
(if $mode == "upgrade" then
   reduce ($eh | keys_unsorted[]) as $ev ({hooks: {}, r: []};
     upgrade_event($ev; $eh[$ev]) as $u
     | (if ($u.groups | length) == 0 and ($eh[$ev] | length) > 0 then . else .hooks[$ev] = $u.groups end)
     | .r += [$u.report])
   | {hooks: .hooks,
      report: {replaced: [.r[].replaced[]], removed: [.r[].removed[]],
               unbound: [.r[].unbound[]], conflicts: [.r[].conflicts[]]}}
 else {hooks: $eh, report: {replaced: [], removed: [], unbound: [], conflicts: []}} end) as $step |
add_missing($step.hooks) as $add |
# Template handlers that exist only in another form (shown so the user can run --upgrade-hooks).
[ $tpl[] | . as $x
  | [ ($add.hooks[$x.event] // [])[] | (.hooks // [])[] | select(cmd == ($x.handler | cmd)) ] as $same
  | select(($same | length) > 0 and (any($same[]; nh == ($x.handler | nh)) | not))
  | $x.handler | hlabel($x.event) ] as $differs |
# statusLine is replaced or kept as a whole: never mix template fields into a user's handler.
(if $mode == "upgrade" then $e
 else $e * ($t * $e) | .statusLine = ($e.statusLine // $t.statusLine)
   | if .statusLine == null then del(.statusLine) else . end end) as $base |
{
  settings: ($base
    | if ($eh | length) > 0 or ($add.hooks | length) > 0 then .hooks = $add.hooks else . end
    | if $mode != "upgrade" and (($e.permissions.additionalDirectories // $t.permissions.additionalDirectories) != null) then
        .permissions.additionalDirectories =
          ((($e.permissions.additionalDirectories // []) + ($t.permissions.additionalDirectories // [])) | unique)
      else . end),
  report: ($step.report + {added: $add.added, differs: $differs})
}
