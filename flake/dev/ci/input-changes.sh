#!/usr/bin/env bash
# INPUT_CHANGES_JQ: the jq program that renders the table.

base_ref="${1:?usage: input-changes <base-ref>}"

git show "$base_ref:flake.lock" |
  jq -r --slurpfile new flake.lock -f "$INPUT_CHANGES_JQ"
