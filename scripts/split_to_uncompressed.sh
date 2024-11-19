#!/bin/bash
set -eo
sourmash sig split --output-dir ../sketches -k 31 /scratch/dmk333_new/temp/Salmonella/data/sketches/salmonella_k31.sig.zip
