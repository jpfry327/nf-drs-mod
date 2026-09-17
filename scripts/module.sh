#!/usr/bin/env bash
#
# Install / update / remove modules from the personal library (github.com/jpfry327/nf-modules)
# into modules/lib/, recording the source commit in modules.json.
#
#   scripts/module.sh add    <tool> [--ref <branch|tag|sha>] [--force]   # default ref: main
#   scripts/module.sh update [<tool> | --all] [--ref <ref>]
#   scripts/module.sh remove <tool>
#   scripts/module.sh list
#
# <tool> is the library path under modules/jpfry327/, e.g. fastp or samtools/index.
# NF_MODULES_REMOTE overrides the library remote. Needs git, curl, tar.
#
# Fetch = one GitHub archive tarball at the resolved SHA (no API rate limit). If that is
# blocked (e.g. a proxy that only allows git), it falls back to a shallow sparse git clone
# of modules/jpfry327/<tool> at the same SHA.

set -euo pipefail

REMOTE="${NF_MODULES_REMOTE:-https://github.com/jpfry327/nf-modules.git}"
LIB_ORG="jpfry327"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/modules/lib"
JSON="$ROOT/modules.json"

die()  { echo "module.sh: $*" >&2; exit 1; }
slug() { local s="${REMOTE#https://github.com/}"; echo "${s%.git}"; }

resolve_sha() {
    if [[ $1 =~ ^[0-9a-f]{40}$ ]]; then echo "$1"; return; fi
    git ls-remote "$REMOTE" "refs/heads/$1" "refs/tags/$1" | head -1 | cut -f1
}

# modules.json <-> TSV (tool sha ref date), one module per line
entries() {
    [[ -f $JSON ]] || return 0
    awk -F'"' '/^    "/ { print $2 "\t" $6 "\t" $10 "\t" $14 }' "$JSON"
}
write_json() {
    local data; data="$(cat)"   # buffer stdin first: the producer may still be reading $JSON
    {
        printf '{\n  "remote": "%s",\n  "modules": {\n' "$REMOTE"
        printf '%s\n' "$data" | grep -v '^$' | sort | awk -F'\t' '{
            printf "%s    \"%s\": { \"sha\": \"%s\", \"ref\": \"%s\", \"date\": \"%s\" }", (NR > 1 ? ",\n" : ""), $1, $2, $3, $4
        } END { if (NR > 0) print "" }'
        printf '  }\n}\n'
    } > "$JSON"
}
recorded() { entries | awk -F'\t' -v t="$1" -v col="$2" '$1 == t { print $col }'; }

# Fallback when the archive download is blocked (proxy, offline mirror): a shallow sparse
# clone of just modules/<org>/<tool> at the resolved SHA. Prints the checkout root.
sparse_fetch() { # <sha> <tool> <tmp>
    local sha="$1" tool="$2" tmp="$3" dir="$3/sparse"
    git init -q "$dir" \
        && git -C "$dir" remote add origin "$REMOTE" \
        && git -C "$dir" sparse-checkout set --no-cone "modules/$LIB_ORG/$tool" \
        && git -C "$dir" fetch -q --depth 1 origin "$sha" \
        && git -C "$dir" checkout -q FETCH_HEAD \
        && echo "$dir"
}

fetch() { # <sha> <tool>
    local sha="$1" tool="$2" tmp root src
    tmp="$(mktemp -d)"
    if curl -fsSL "https://github.com/$(slug)/archive/${sha}.tar.gz" 2>/dev/null | tar -xz -C "$tmp" 2>/dev/null; then
        root="$tmp/$(ls "$tmp")"
    else
        echo "module.sh: archive download failed, falling back to sparse git clone" >&2
        root="$(sparse_fetch "$sha" "$tool" "$tmp")" \
            || { rm -rf "$tmp"; die "could not download library at $sha"; }
    fi
    src="$root/modules/$LIB_ORG/$tool"
    [[ -f "$src/main.nf" ]] || { rm -rf "$tmp"; die "no module '$tool' in library at ${sha:0:7}"; }
    rm -rf "${DEST:?}/$tool"
    mkdir -p "$DEST/$tool"
    # copy everything except tests/, meta.yml, environment.yml
    (cd "$src" && find . -type f ! -path './tests/*' ! -name meta.yml ! -name environment.yml -print0) \
        | (cd "$src" && while IFS= read -r -d '' f; do
              mkdir -p "$DEST/$tool/$(dirname "$f")"
              cp "$f" "$DEST/$tool/$f"
          done)
    rm -rf "$tmp"
}

cmd_add() { # <tool> <ref> <force>
    local tool="$1" ref="$2" force="$3" sha cur
    [[ -n $tool ]] || die "usage: add <tool> [--ref <ref>] [--force]"
    sha="$(resolve_sha "$ref")"
    [[ -n $sha ]] || die "ref '$ref' not found on $REMOTE"
    cur="$(recorded "$tool" 2)"
    if [[ $cur == "$sha" && -z $force && -f "$DEST/$tool/main.nf" ]]; then
        echo "$tool already at ${sha:0:7}"
        return
    fi
    fetch "$sha" "$tool"
    { entries | awk -F'\t' -v t="$tool" '$1 != t'
      printf '%s\t%s\t%s\t%s\n' "$tool" "$sha" "$ref" "$(date -u +%F)"
    } | write_json
    echo "installed $tool @ ${sha:0:7} -> modules/lib/$tool"
    grep -ho '^process [A-Za-z0-9_]*' "$DEST/$tool"/*.nf \
        | awk -v t="$tool" '{ print "  include { " $2 " } from '\''../modules/lib/" t "/main'\''" }'
}

cmd_update() { # <tool|--all> <ref-override>
    local target="$1" ref="$2" tools=() t
    if [[ $target == "--all" || -z $target ]]; then
        while IFS=$'\t' read -r t _; do tools+=("$t"); done < <(entries)
    else
        tools=("$target")
    fi
    [[ ${#tools[@]} -gt 0 ]] || { echo "nothing installed"; return; }
    for t in "${tools[@]}"; do
        local r="${ref:-$(recorded "$t" 3)}"
        cmd_add "$t" "${r:-main}" "force"
    done
}

cmd_remove() { # <tool>
    local tool="$1"
    [[ -n $tool ]] || die "usage: remove <tool>"
    rm -rf "${DEST:?}/$tool"
    # prune empty parent dirs (e.g. modules/lib/samtools/) up to modules/lib
    local parent; parent="$(dirname "$DEST/$tool")"
    while [[ $parent != "$DEST" ]] && rmdir "$parent" 2>/dev/null; do parent="$(dirname "$parent")"; done
    entries | awk -F'\t' -v t="$tool" '$1 != t' | write_json
    echo "removed $tool"
}

cmd_list() {
    { printf 'MODULE\tSHA\tREF\tINSTALLED\n'; entries | awk -F'\t' '{ print $1 "\t" substr($2,1,7) "\t" $3 "\t" $4 }'; } | column -t
}

# ---- arg parsing ----
cmd="${1:-}"; shift || true
tool="" ref="" force=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ref)   ref="${2:-}"; shift 2 ;;
        --force) force="yes"; shift ;;
        --all)   tool="--all"; shift ;;
        -*)      die "unknown option $1" ;;
        *)       tool="${1%/}"; shift ;;
    esac
done

case "$cmd" in
    add)    cmd_add "$tool" "${ref:-main}" "$force" ;;
    update) cmd_update "$tool" "$ref" ;;
    remove) cmd_remove "$tool" ;;
    list)   cmd_list ;;
    *)      sed -n '3,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
