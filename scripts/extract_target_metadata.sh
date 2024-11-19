#!/bin/bash

# Default values
INPUT_FILE="target.txt"
OUTPUT_FILE="target_metadata.txt"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -i|--input) INPUT_FILE="$2"; shift ;;
        -o|--output) OUTPUT_FILE="$2"; shift ;;
        -h|--help)
            echo "Usage: $0 [-i|--input <input_file>] [-o|--output <output_file>]"
            exit 0 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if GNU parallel is installed
if ! command -v parallel &> /dev/null
then
    echo "GNU parallel could not be found. Please install it to proceed."
    exit 1
fi

# Ensure input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Input file '$INPUT_FILE' not found!"
    exit 1
fi

# Extract metadata from target signature files using GNU parallel
echo "Extracting metadata from target signature files..."

parallel -j50 --keep-order '
    metadata=$(jq -r ".[0] | \"\(.filename)\t\(.signatures[0].ksize)\"" {})
    source_file=$(echo "$metadata" | cut -f1)
    first_line=$(head -n1 "$source_file" | sed "s/^>//")
    echo -e "$metadata\t$first_line"
' :::: "$INPUT_FILE" > "$OUTPUT_FILE"

echo "Metadata extraction complete. Output saved to '$OUTPUT_FILE'"

