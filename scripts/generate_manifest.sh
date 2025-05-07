#!/usr/bin/env bash
# manifest.sh – create CSV manifest for genome files
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") -g GENOME_DIR -o OUTPUT.csv" >&2
  exit 1
}

while getopts ":g:o:h" opt; do
  case $opt in
    g) genomes=$OPTARG ;;
    o) out=$OPTARG ;;
    h|*) usage ;;
  esac
done
[[ ${genomes:-} && ${out:-} ]] || usage

prefix=$(realpath "${genomes%/}")   # full path to GENOME_DIR (no trailing /)

{
  echo "name,genome_filename,protein_filename"
  for f in "$genomes"/*.fna; do
    [[ -f $f ]] || continue
    name=$(basename "$f")
    printf '%s,%s/%s,%s\n' "$name" "$prefix" "$name" ""
  done
} > "$out"
