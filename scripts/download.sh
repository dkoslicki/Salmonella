#!/bin/bash
# NCBI Genome Downloader
# A script to download and process genome sequences from NCBI

set -eo pipefail

# Default values
DEFAULT_INPUT_DIR="./data/input"
DEFAULT_OUTPUT_DIR="./data/genomes"
DEFAULT_PARALLEL_JOBS=10
DEFAULT_BATCH_WAIT=43200  # 12 hours in seconds
DEFAULT_BATCH_PREFIX="batch_"

# Function to display usage information
show_help() {
    cat << EOF
NCBI Genome Downloader

Usage: $(basename "$0") [OPTIONS]

This script downloads genome sequences from NCBI using accession numbers
provided in batch files.

Before running:
  1. Go to: https://www.ncbi.nlm.nih.gov/pathogens/isolates/#taxgroup_name:%22Salmonella%20enterica%22
  2. Extract accessions from the 'Assembly' column:
     cat isolates.tsv | cut -f 15 | grep -v '^$' | tail -n +2 > all_accessions.txt
  3. Split into batch files:
     split -l 1000 all_accessions.txt batch_
  4. Place batch files in the input directory

Options:
  -i, --input-dir DIR      Directory containing batch files with accessions
                           Default: $DEFAULT_INPUT_DIR
  -o, --output-dir DIR     Directory to store downloaded genome files
                           Default: $DEFAULT_OUTPUT_DIR
  -k, --api-key KEY        NCBI API key (preferred over API key file)
  -f, --key-file FILE      Path to file containing NCBI API key
                           Default: ~/NCBI/API_key.txt
  -j, --jobs NUM           Number of parallel download jobs
                           Default: $DEFAULT_PARALLEL_JOBS
  -w, --wait SECONDS       Wait time between batch processing in seconds
                           Default: $DEFAULT_BATCH_WAIT (12 hours)
  -p, --prefix PREFIX      Prefix for batch files to process
                           Default: $DEFAULT_BATCH_PREFIX
                           Examples: "batch_", "accessions_", "batch.txt"
  -h, --help               Display this help message and exit

Examples:
  $(basename "$0") --input-dir ./my_batches --output-dir ./my_genomes --api-key abc123 --jobs 5
  $(basename "$0") --prefix accessions_ --input-dir ./custom_input
  $(basename "$0") --prefix batch.txt   # Process a single batch file named batch.txt

EOF
}

# Function to check for required dependencies
check_dependencies() {
    local missing_deps=()

    # Check for GNU parallel
    if ! command -v parallel &> /dev/null; then
        missing_deps+=("GNU parallel")
    fi

    # Check for NCBI datasets tool
    if ! command -v datasets &> /dev/null; then
        missing_deps+=("NCBI datasets command line tool")
    fi

    # Check for unzip
    if ! command -v unzip &> /dev/null; then
        missing_deps+=("unzip")
    fi

    # Check for flock (used for progress tracking)
    if ! command -v flock &> /dev/null; then
        missing_deps+=("flock")
    fi

    # If any dependencies are missing, display error and exit
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies:" >&2
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep" >&2
        done

        # Provide installation instructions
        echo -e "\nInstallation instructions:" >&2
        echo "  - GNU parallel: sudo apt-get install parallel" >&2
        echo "  - NCBI datasets: https://www.ncbi.nlm.nih.gov/datasets/docs/v2/download-and-install/" >&2
        echo "  - unzip: sudo apt-get install unzip" >&2
        echo "  - flock: sudo apt-get install util-linux" >&2

        exit 1
    fi
}

# Function to process a single accession
process_accession() {
    local accession="$1"
    local output_dir="$2"
    local api_key="$3"

    # Skip empty lines and commented out lines
    if [[ -z "$accession" || "$accession" =~ ^[[:space:]]*# ]]; then
        return 0
    fi

    # Strip any whitespace
    accession=$(echo "$accession" | tr -d '[:space:]')

    # Create a temporary directory
    local temp_dir=$(mktemp -d)

    # Download the genome accession zip file
    if datasets --api-key "$api_key" download genome accession --filename "$temp_dir/$accession.zip" "$accession" > /dev/null 2>&1; then
        # Extract the .fna file from the zip to the output directory
        if unzip -j "$temp_dir/$accession.zip" "ncbi_dataset/data/$accession/*.fna" -d "$output_dir" > /dev/null 2>&1; then
            # Success - but don't print anything to avoid cluttering output with parallel jobs
            :
        else
            echo -e "\nWarning: Failed to extract .fna file for $accession" >&2
        fi
    else
        echo -e "\nError: Failed to download $accession" >&2
    fi

    # Clean up
    rm -rf "$temp_dir"
}

# Function to ensure directory exists
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "Created directory: $dir"
    fi
}

# Parse command line arguments
parse_arguments() {
    input_dir="$DEFAULT_INPUT_DIR"
    output_dir="$DEFAULT_OUTPUT_DIR"
    api_key=""
    key_file="$HOME/NCBI/API_key.txt"
    parallel_jobs="$DEFAULT_PARALLEL_JOBS"
    batch_wait="$DEFAULT_BATCH_WAIT"
    batch_prefix="$DEFAULT_BATCH_PREFIX"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--input-dir)
                input_dir="$2"
                shift 2
                ;;
            -o|--output-dir)
                output_dir="$2"
                shift 2
                ;;
            -k|--api-key)
                api_key="$2"
                shift 2
                ;;
            -f|--key-file)
                key_file="$2"
                shift 2
                ;;
            -j|--jobs)
                parallel_jobs="$2"
                shift 2
                ;;
            -w|--wait)
                batch_wait="$2"
                shift 2
                ;;
            -p|--prefix)
                batch_prefix="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done

    # Validate arguments
    if ! [[ "$parallel_jobs" =~ ^[0-9]+$ ]]; then
        echo "Error: Number of jobs must be a positive integer" >&2
        exit 1
    fi

    if ! [[ "$batch_wait" =~ ^[0-9]+$ ]]; then
        echo "Error: Wait time must be a positive integer in seconds" >&2
        exit 1
    fi

    # Get API key if not provided as argument
    if [ -z "$api_key" ]; then
        if [ -f "$key_file" ]; then
            api_key=$(cat "$key_file")
        else
            echo "Error: API key not provided and key file not found: $key_file" >&2
            exit 1
        fi
    fi

    # Check if API key is empty
    if [ -z "$api_key" ]; then
        echo "Error: Empty API key" >&2
        exit 1
    fi
}

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"

    # Ensure directories exist
    ensure_directory "$input_dir"
    ensure_directory "$output_dir"

    # Check for dependencies more thoroughly
    check_dependencies

    # Display summary of settings
    echo "=== NCBI Genome Downloader ==="
    echo "Input directory:     $input_dir"
    echo "Output directory:    $output_dir"
    echo "Batch file prefix:   $batch_prefix"
    echo "Parallel jobs:       $parallel_jobs"
    echo "Batch wait time:     $batch_wait seconds"
    echo "API key:             ${api_key:0:3}...${api_key: -3}"
    echo "==========================="

    # Handle case for single batch file or batch files with prefix
    single_file_mode=false
    if [[ "$batch_prefix" == *".txt" || "$batch_prefix" == *".csv" || "$batch_prefix" == *".tsv" ]]; then
        # This appears to be a single file rather than a prefix
        single_file_mode=true
        single_batch_file="$input_dir/$batch_prefix"

        if [ ! -f "$single_batch_file" ]; then
            echo "Error: Specified batch file not found: $single_batch_file" >&2
            exit 1
        fi

        echo "Single batch file mode: Using $single_batch_file"
    else
        # This is a prefix for multiple batch files
        # Note: We're using find instead of shell globbing for better error handling
        file_count=$(find "$input_dir" -type f -name "${batch_prefix}*" | wc -l)
        if [ "$file_count" -eq 0 ]; then
            echo "Error: No batch files found in $input_dir with prefix '$batch_prefix'" >&2
            echo "Please add batch files matching the pattern '${batch_prefix}*'" >&2
            exit 1
        fi

        echo "Found $file_count batch files with prefix '$batch_prefix'"
    fi

    # Function to process a single batch file
    process_batch_file() {
        local batch_file="$1"
        if [ -f "$batch_file" ]; then
            echo "Processing batch file: $batch_file"

            # Get the total count of lines for reporting
            local total_lines=$(grep -v "^[[:space:]]*$\|^[[:space:]]*#" "$batch_file" | wc -l)
            echo "Found $total_lines accessions in $batch_file"

            # Validate total_lines to avoid division by zero
            if [ "$total_lines" -eq 0 ]; then
                echo "Warning: No valid accessions found in $batch_file, skipping" >&2
                return 0
            fi

            # Create a temporary file to track progress
            local progress_file=$(mktemp)
            echo "0" > "$progress_file"  # Initialize with 0

            # Export necessary variables for GNU parallel to use
            export output_dir
            export api_key
            export progress_file
            export total_lines

            # Define the worker function for GNU parallel
            worker_function() {
                local acc="$1"
                # Skip empty lines and commented out lines
                if [[ -z "$acc" || "$acc" =~ ^[[:space:]]*# ]]; then
                    return 0
                fi

                # Call the process_accession function
                process_accession "$acc" "$output_dir" "$api_key"

                # Update progress counter (in a thread-safe way)
                flock -x "$progress_file.lock" bash -c "
                    completed=\$(cat \"$progress_file\")
                    completed=\$((completed + 1))
                    echo \"\$completed\" > \"$progress_file\"
                    progress=\$((completed * 100 / $total_lines))
                    printf \"\\rProgress: %d/%d accessions completed (%d%%)\" \"\$completed\" \"$total_lines\" \"\$progress\"
                "
            }
            export -f worker_function
            export -f process_accession

            # Create a lock file for the progress counter
            touch "$progress_file.lock"

            # Process accessions in parallel
            grep -v "^[[:space:]]*$\|^[[:space:]]*#" "$batch_file" | \
                parallel -j "$parallel_jobs" worker_function

            # Clean up
            rm -f "$progress_file" "$progress_file.lock"
            echo -e "\nCompleted processing batch file: $batch_file"
            return 0
        else
            echo "Warning: Skipping non-file: $batch_file" >&2
            return 1
        fi
    }

    # Process each batch file or the single batch file
    if [ "$single_file_mode" = true ]; then
        process_batch_file "$single_batch_file"
    else
        batch_count=0
        total_batches=$(find "$input_dir" -type f -name "${batch_prefix}*" | wc -l)

        # Process each batch file
        while read -r batch_file; do
            if [ -f "$batch_file" ]; then
                batch_count=$((batch_count + 1))
                echo "Processing batch file $batch_count/$total_batches: $batch_file"

                process_batch_file "$batch_file"

                # Check if this is the last batch file
                if [ $batch_count -lt $total_batches ]; then
                    echo "Batch $batch_count/$total_batches complete"
                    echo "Waiting for $batch_wait seconds before processing the next batch..."
                    sleep "$batch_wait"
                fi
            fi
        done < <(find "$input_dir" -type f -name "${batch_prefix}*" | sort)
    fi

    echo "All downloads complete. Genomes are available in: $output_dir"
}

# Run the main function with all script arguments
main "$@"