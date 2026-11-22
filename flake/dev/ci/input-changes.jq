# Input: the base flake.lock. $new[0]: the changed flake.lock.
# Output: a Markdown table of root inputs whose locked revision changed.

def roots: . as $lock | .nodes[.root].inputs | with_entries(.value |= $lock.nodes[.]);
def rev: .locked.rev // .locked.narHash;
def date: (.locked.lastModified // 0) | strftime("%Y-%m-%d");
def ref: if . == null then "(none)" else "`\(rev[0:12])` (\(date))" end;
def link($old; $new):
  if $old != null and $new != null and $new.locked.type == "github"
    and $old.locked.owner == $new.locked.owner and $old.locked.repo == $new.locked.repo
  then "[compare](https://github.com/\($new.locked.owner)/\($new.locked.repo)/compare/\($old | rev)...\($new | rev))"
  else "" end;

(roots) as $old
| ($new[0] | roots) as $new
| [($old + $new) | keys[]
   | . as $name
   | {name: $name, old: $old[$name], new: $new[$name]}
   | select((.old | if . == null then null else rev end) != (.new | if . == null then null else rev end))]
| if length == 0 then "No flake inputs changed."
  else
    (["## Flake input changes", "", "| Input | Old | New | |", "| :---- | :---- | :---- | :---- |"]
     + map("| `\(.name)` | \(.old | ref) | \(.new | ref) | \(link(.old; .new)) |"))
    | join("\n")
  end
