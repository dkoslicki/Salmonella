#!/bin/bash

# Make file list
# find /scratch/dmk333_new/temp/Salmonella/data/sketches_individual_unzipped/ -type f > /scratch/dmk333_new/temp/Salmonella/data/uncompressed_individual_paths.txt

/scratch/dmk333_new/temp/Salmonella/scripts/YACHT/src/yacht/./run_compute_similarity /scratch/dmk333_new/temp/Salmonella/data/target_genomes/query_file_locations.txt /scratch/dmk333_new/temp/Salmonella/data/uncompressed_individual_paths.txt /scratch/dmk333_new/temp/Salmonella/data/ani_results/threshold_0.001 -t 50 -p 1 -c 0.001 -C -o /scratch/dmk333_new/temp/Salmonella/data/ani_results/threshold_0.001/containments_threshold_0.001.csv
