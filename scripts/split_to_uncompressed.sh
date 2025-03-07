#!/bin/bash
set -eo
dataDir="/scratch/dmk333_new/temp/Salmonella/data"
export dataDir="/scratch/dmk333_new/temp/Salmonella/data"
mkdir -p ${dataDir}/sketches_unzipped
sourmash sig split -f -E ".sig" --dna --output-dir ${dataDir}/sketches_unzipped -k 31 ${dataDir}/salmonella_k31.sig.zip


# Not needed since specifying the extension makes it not zip it
# Use find with null-separated names and GNU Parallel to process files in parallel.
#find sketches -maxdepth 1 -type f -name "*.zip" -print0 | \
#parallel --env dataDir -0 -j25 '
#    # Get the base name of the zip file (without the .zip extension)
#    base=$(basename {} .zip)
#    # Extract the zip file quietly into a folder inside "extracted"
#    unzip -qq {} -d ${dataDir}/sketches_unzipped/"$base"
#    # Remove the zip file once extraction is complete
#    rm {}
#'

# Next, create a text file with the full paths of all the newely extracted .sig files
#find ${dataDir}/sketches_unzipped -type f -name "*.sig" > ${dataDir}/sig_files.txt
find ${dataDir}/sketches_unzipped -type f -name "*.sig" -exec realpath {} \; > "${dataDir}/sig_files.txt"
