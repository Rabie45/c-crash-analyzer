#!/usr/bin/env bash
# Resolve one or more raw addresses to function name + file:line for a given binary.
# Usage: symbolize.sh <binary> <addr> [addr...]
#
# Prefers addr2line for speed; falls back to gdb if addr2line is unavailable
# or produces "?? ??:0" (e.g. no debug info found via addr2line but present in gdb).

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <binary> <addr> [addr...]" >&2
  exit 1
fi

binary="$1"
shift

if [ ! -f "$binary" ]; then
  echo "error: binary not found: $binary" >&2
  exit 1
fi

if command -v addr2line >/dev/null 2>&1; then
  for addr in "$@"; do
    result=$(addr2line -f -C -e "$binary" "$addr" 2>/dev/null || true)
    func=$(echo "$result" | sed -n '1p')
    loc=$(echo "$result" | sed -n '2p')
    if [ -z "$loc" ] || [ "$loc" = "??:0" ]; then
      if command -v gdb >/dev/null 2>&1; then
        gdb_out=$(gdb --batch -ex "info line *$addr" "$binary" 2>/dev/null || true)
        echo "$addr  ->  (addr2line: no info; gdb) $gdb_out"
      else
        echo "$addr  ->  $func  $loc  (no debug info; is the binary built with -g?)"
      fi
    else
      echo "$addr  ->  $func  $loc"
    fi
  done
else
  if command -v gdb >/dev/null 2>&1; then
    for addr in "$@"; do
      gdb_out=$(gdb --batch -ex "info symbol $addr" -ex "info line *$addr" "$binary" 2>/dev/null || true)
      echo "$addr  ->  $gdb_out"
    done
  else
    echo "error: neither addr2line nor gdb found on PATH" >&2
    exit 1
  fi
fi
