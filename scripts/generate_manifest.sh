#!/bin/bash
(
  echo "name,genome_filename,protein_filename"
  ls -U ../data/genomes | while read -r genome; do
    name=$(basename "$genome")
    genome="/scratch/dmk333_new/temp/Salmonella/data/genomes/${name}"
    printf "%s,%s,%s\n" "$name" "$genome" ""
  done
) > /scratch/dmk333_new/temp/Salmonella/data/input/manifest.csv
