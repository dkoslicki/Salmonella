#!/usr/bin/env bash
# ===========================================================
# NCBI Genome Downloader – v2 (datasets-style)
# ===========================================================
# Downloads batches of genomes using the official NCBI Datasets
# CLI.  Each batch file is given wholesale to `datasets`, which
# returns one ZIP archive; the script then unpacks only the
# *.fna files to the desired output directory.
#
#  Tested with Datasets CLI 15.34.0  (May 2025)
# ===========================================================

set -euo pipefail

# ------------- defaults -----------------------------------------------------
DEFAULT_INPUT_DIR="./data/input"
DEFAULT_OUTPUT_DIR="./data/genomes"
DEFAULT_BATCH_WAIT=43200          # 12 h
DEFAULT_BATCH_PREFIX="batch_"
DEFAULT_KEY_FILE="$HOME/NCBI/API_key.txt"

# ------------- helper: usage ------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options
  -i, --input-dir DIR      Directory with batch files      (default $DEFAULT_INPUT_DIR)
  -o, --output-dir DIR     Directory for *.fna genomes     (default $DEFAULT_OUTPUT_DIR)
  -k, --api-key KEY        NCBI API key (overrides key-file)
  -f, --key-file FILE      File containing an API key      (default $DEFAULT_KEY_FILE)
  -w, --wait SEC           Seconds to wait between batches (default $DEFAULT_BATCH_WAIT)
  -p, --prefix PFX|FILE    Batch file prefix OR single filename (default $DEFAULT_BATCH_PREFIX)
  -h, --help               Show this help and exit
EOF
}

# ------------- dependencies -------------------------------------------------
need() { command -v "$1" >/dev/null || { echo "Missing dependency: $1" >&2; exit 1; }; }
check_deps() { need datasets; need unzip; }

# ------------- argument parsing --------------------------------------------
INPUT_DIR=$DEFAULT_INPUT_DIR
OUTPUT_DIR=$DEFAULT_OUTPUT_DIR
API_KEY=""
KEY_FILE=$DEFAULT_KEY_FILE
BATCH_WAIT=$DEFAULT_BATCH_WAIT
PREFIX=$DEFAULT_BATCH_PREFIX

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input-dir)  INPUT_DIR=$2; shift 2;;
        -o|--output-dir) OUTPUT_DIR=$2; shift 2;;
        -k|--api-key)    API_KEY=$2; shift 2;;
        -f|--key-file)   KEY_FILE=$2; shift 2;;
        -w|--wait)       BATCH_WAIT=$2; shift 2;;
        -p|--prefix)     PREFIX=$2; shift 2;;
        -h|--help)       usage; exit 0;;
        *) echo "Unknown option $1" >&2; usage; exit 1;;
    esac
done

[[ -d $INPUT_DIR ]]  || { echo "Input dir $INPUT_DIR not found"; exit 1; }
mkdir -p "$OUTPUT_DIR"

# API key handling -----------------------------------------------------------
if [[ -z $API_KEY ]]; then
    if [[ -f $KEY_FILE ]]; then
        API_KEY=$(<"$KEY_FILE")
    else
        echo "API key not provided and key file $KEY_FILE missing." >&2
        exit 1
    fi
fi

# sanity ---------------------------------------------------------------------
check_deps
[[ $BATCH_WAIT =~ ^[0-9]+$ ]] || { echo "--wait requires integer" >&2; exit 1; }

# single-file or multi-batch mode? ------------------------------------------
if [[ $PREFIX == *.txt || $PREFIX == *.tsv || $PREFIX == *.csv ]]; then
    BATCH_FILES=("$INPUT_DIR/$PREFIX")
    [[ -f ${BATCH_FILES[0]} ]] || { echo "Batch file ${BATCH_FILES[0]} not found"; exit 1; }
else
    mapfile -t BATCH_FILES < <(find "$INPUT_DIR" -maxdepth 1 -type f -name "${PREFIX}*" | sort)
    (( ${#BATCH_FILES[@]} )) || { echo "No files starting with '$PREFIX' inside $INPUT_DIR"; exit 1; }
fi

echo "========== NCBI Genome Downloader (datasets version) =========="
echo "Batches      : ${#BATCH_FILES[@]}"
echo "Input dir    : $INPUT_DIR"
echo "Output dir   : $OUTPUT_DIR"
echo "API key      : ${API_KEY:0:3}...${API_KEY: -3}"
echo "==============================================================="

# ------------- core routine -------------------------------------------------
process_batch () {
    local batch_file=$1
    local stem
    stem=$(basename "$batch_file")
    echo "→ Processing $stem ($(grep -v '^[[:space:]]*$\|^#' "$batch_file" | wc -l) accs)"

    # 1. download                                            ────
    local tmp_zip
    tmp_zip=$(mktemp --suffix=".zip")
    datasets download genome accession \
        --inputfile   "$batch_file" \
        --include     genome \
        --api-key     "$API_KEY" \
        --filename    "$tmp_zip"   \
         || {
            echo "Datasets failed for $stem" >&2
            rm -f "$tmp_zip"
            return 1
        }

    # 2. extract *.fna                                        ────
    unzip -o -q -j "$tmp_zip" -d "$OUTPUT_DIR"
    local extracted=$?
    rm -f "$tmp_zip"

    # 3. prune vestigial artefacts -------------------------------------------
    #    (they would appear only if you extend the extract pattern later)
    find "$OUTPUT_DIR" -maxdepth 1 -type f \
        \( -name 'README.md' \
           -o -name 'assembly_data_report.jsonl' \
           -o -name 'dataset_catalog.json' \
           -o -name 'README.md' \
           -o -name 'md5sum.txt' \) -delete

    if [[ $extracted -ne 0 ]]; then
        echo "Warning: unzip issues on $stem" >&2
    else
        echo "✓ Done with $stem"
    fi
}

# ------------- main loop ----------------------------------------------------
batch_idx=0
for bf in "${BATCH_FILES[@]}"; do
    (( ++batch_idx ))
    process_batch "$bf"
    # pause unless last batch or single-file mode
    if (( batch_idx < ${#BATCH_FILES[@]} )); then
        echo "Sleeping $BATCH_WAIT s to respect NCBI rate limits…"
        sleep "$BATCH_WAIT"
    fi
done

echo "All batches completed – genomes are in $OUTPUT_DIR"
