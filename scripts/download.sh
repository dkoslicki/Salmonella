#!/bin/bash
set -eo

echo "Before running, go to https://www.ncbi.nlm.nih.gov/pathogens/isolates/#taxgroup_name:%22Salmonella%20enterica%22 the accessions in a text file in data/input directory. Split this into a few different batches (I did 3 of about ~200K last time)."

# Define a function to process each accession
process_accession() {
    accession="$1"
    output_dir="./data/genomes"
    
    # Download the genome accession zip file
    datasets --api-key <at ~/NCBI/API_key.txt> download genome accession --filename "$accession.zip" "$accession"
    
    # Extract the .fna file from the zip to the output directory
    unzip -j "$accession.zip" "ncbi_dataset/data/$accession/*.fna" -d "${output_dir}"
    
    # Remove the original zip file to save space
    rm -f "$accession.zip"
}

export -f process_accession  # Export the function for use by GNU parallel

# Use GNU parallel to run the download and processing for each accession in parallel (10 jobs at a time)
#cat small_accessions.txt | parallel -j 10 process_accession

#echo "Download, extraction, and compression complete."

for batch_file in ./data/input/batch_*; do
    echo "Processing batch file: $batch_file"
    cat "$batch_file" | parallel -j 10 process_accession
    # sleep for a while before starting on the next batch
    sleep 43200  # Wait for 24 hours before starting the next batch
done

echo "All downloads complete."

