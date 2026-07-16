#!/usr/bin/env bash
# gera o card de linguagens do readme (os cards publicos da vercel vivem fora do ar)
set -euo pipefail
export LC_ALL=C

user="${1:-lirenzzzin}"
out="${2:-dist/langs.svg}"
mkdir -p "$(dirname "$out")"

agg=$(gh api "users/$user/repos?per_page=100&type=owner" \
    --jq '[.[] | select(.fork | not) | .full_name][]' |
  while read -r repo; do gh api "repos/$repo/languages"; done |
  jq -s 'reduce .[] as $o ({}; reduce ($o | to_entries[]) as $e (.; .[$e.key] += $e.value))
         | to_entries | sort_by(-.value) | .[0:6]')

count=$(jq length <<<"$agg")
total=$(jq 'map(.value) | add // 0' <<<"$agg")
height=$((78 + count * 26))

{
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="480" height="%s" viewBox="0 0 480 %s" xml:space="preserve">\n' "$height" "$height"
  printf '<style>text{font-family:%s,monospace;font-size:14px}</style>\n' "'JetBrains Mono','Fira Code','Courier New'"
  printf '<rect width="480" height="%s" rx="10" fill="#0d1117" stroke="#30363d"/>\n' "$height"
  printf '<text x="22" y="34" fill="#39FF14">lox@github:~$ <tspan fill="#e6edf3">langs --by-bytes</tspan></text>\n'

  i=0
  while read -r entry; do
    name=$(jq -r '.key' <<<"$entry" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    bytes=$(jq -r '.value' <<<"$entry")
    pct=$(awk -v b="$bytes" -v t="$total" 'BEGIN { printf "%.1f", t ? b * 100 / t : 0 }')
    filled=$(awk -v p="$pct" 'BEGIN { f = int(p * 20 / 100 + 0.5); print (f == 0 && p > 0) ? 1 : f }')
    bar=""
    for ((j = 0; j < 20; j++)); do
      if ((j < filled)); then bar+="█"; else bar+="░"; fi
    done
    y=$((68 + i * 26))
    printf '<text x="22" y="%s"><tspan fill="#e6edf3">%-14s</tspan><tspan fill="#39FF14">%s</tspan><tspan fill="#8b949e"> %5s%%</tspan></text>\n' \
      "$y" "$name" "$bar" "$pct"
    i=$((i + 1))
  done < <(jq -c '.[]' <<<"$agg")

  if ((count == 0)); then
    printf '<text x="22" y="68" fill="#8b949e">no code found. only chaos.</text>\n'
  fi

  printf '</svg>\n'
} > "$out"

echo "ok: $out ($count linguagens)"
