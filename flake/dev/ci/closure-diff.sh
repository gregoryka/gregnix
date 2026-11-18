#!/usr/bin/env bash
# CHECKS_SYSTEM: the system whose checks to build and compare.

base_ref="${1:?usage: closure-diff <base-ref>}"

closure_checks() {
  nix eval --json "$1#checks.$CHECKS_SYSTEM" --apply \
    'c: builtins.filter (n: builtins.match "(darwin|home)-.*" n != null) (builtins.attrNames c)' |
    jq -r '.[]'
}
build() {
  nix build --no-link --print-out-paths "$1#checks.$CHECKS_SYSTEM.\"$2\""
}

base="$(mktemp -d)"
trap 'git worktree remove --force "$base"' EXIT
git worktree add --quiet --detach "$base" "$base_ref"
base_names="$(closure_checks "$base")"

echo "## Closure changes ($CHECKS_SYSTEM)"
closure_checks . | while read -r name; do
  echo
  echo "### \`$name\`"
  new="$(build . "$name")"
  if ! grep -qxF "$name" <<<"$base_names"; then
    echo "New check; nothing to compare against."
    continue
  fi
  old="$(build "$base" "$name")"
  echo '```'
  dix --color=never diff "$old" "$new"
  echo '```'
done
