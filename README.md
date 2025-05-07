# Salmonella
Salmonella strain detection and the likea

Work in progress


Will need to clone https://github.com/KoslickiLab/YACHT/tree/dev-fast-yacht-run
and checkout commit 653a247f10b036435f43636858a97ad1f7237687

Rember compilation of C++ code
and location of directories


## Workflow

### Training/reference data
```bash
./download.sh  # downloads the Salmonella genomes
./generate_manifest.sh  # Creates a manifest (list of file names etc.) in prep for `sourmash manysketch` 
./make_sketches.sh  # Uses `sourmash manysketch` to sketch all the Salmonella genomes
# The below may change based on the update to the new Mahmudur code
./split_to_uncompressed.sh # Takes the single zip file of sketches and turns it into a bunch of individual, uncompressed signatures
./extract_target_metadata.sh 
./calculate_ani.sh
python convert_containment_to_csv_preprocess_metadata.py

```