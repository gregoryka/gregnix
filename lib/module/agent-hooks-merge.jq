if ($dynamic | type) != "object" or (($dynamic.hooks // {}) | type) != "object" then
  error("expected a JSON object with an object `hooks`")
else
  $static.markers as $markers
  | (($dynamic.hooks // {})
      | map_values(
          map((.hooks // []) |= map(select(
            (.command | type) != "string"
            or ([$markers[] as $m | .command | contains($m)] | any | not)
          )))
          | map(select((.hooks | length) > 0))
        )) as $kept
  | (reduce ($static.hooks | to_entries[]) as $e ($kept; .[$e.key] = (.[$e.key] // []) + $e.value))
  | with_entries(select(.value | length > 0)) as $hooks
  | if $hooks == {} and ($dynamic | has("hooks") | not) then $dynamic else $dynamic + { hooks: $hooks } end
end
