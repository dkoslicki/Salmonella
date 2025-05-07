#!/usr/bin/env bash
# make_sketches.sh – run sourmash manysketch for a dataset. This is a silly little wrapper for sourmash
set -euo pipefail

usage() {
  cat <<EOF >&2
Usage: $(basename "$0") -d DATA_DIR [-o OUTPUT.zip] [-m MANIFEST.csv]
                       [-k KSIZE] [-s SCALED] [-c CORES]
Defaults: KSIZE=31  SCALED=100  CORES=50
EOF
  exit 1
}

# defaults
k=31 scaled=100 cores=50

while getopts ":d:o:m:k:s:c:h" opt; do
  case $opt in
    d) data=$(realpath "${OPTARG%/}") ;;
    o) out=$OPTARG ;;
    m) manifest=$OPTARG ;;
    k) k=$OPTARG ;;
    s) scaled=$OPTARG ;;
    c) cores=$OPTARG ;;
    h|*) usage ;;
  esac
done
[[ ${data:-} ]] || usage

out=${out:-"$data/salmonella_k${k}.sig.zip"}
manifest=${manifest:-"$data/input/manifest.csv"}

sourmash scripts manysketch \
  -o "$out" \
  -p "dna,k=${k},scaled=${scaled}" \
  -c "$cores" \
  -f "$manifest"
