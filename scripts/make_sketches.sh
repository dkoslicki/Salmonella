#!/bin/bash
dataDir="/scratch/dmk333_new/temp/Salmonella/data"
sourmash scripts manysketch -o /scratch/dmk333_new/temp/Salmonella/data/sketches/salmonella_k31.sig.zip -p dna,k=31,scaled=100 -c 50 -f /scratch/dmk333_new/temp/Salmonella/data/input/manifest.csv
