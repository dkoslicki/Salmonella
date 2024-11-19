# This script will take the output of the containment comparison, and use the input query and target files
# to create a CSV file that can be used to generate a heatmap of the ANI values or other downstream analyses.

import pandas as pd
import matplotlib.pyplot as plt
import argparse
import subprocess

# set the following arguments: query txt file, target txt file, comparison csv file, and output csv file
parser = argparse.ArgumentParser(description='Create a CSV file from containment comparisons.')
parser.add_argument('query', type=str, help='The query txt file. List of file names of uncompressed FMH files.')
parser.add_argument('target', type=str, help='The target txt file. List of file names of uncompressed FMH files.')
parser.add_argument('comparison', type=str, help='The comparison csv file. Output of containment comparison.')
parser.add_argument('output', type=str, help='The output csv file. Contains ANI values for heatmap generation.')
args = parser.parse_args()

# parse the arguments
query_file = args.query
target_file = args.target
comparison_file = args.comparison
output_file = args.output

# read the query and target files
query_df = pd.read_csv(query_file, header=None, names=['query'])
target_df = pd.read_csv(target_file, header=None, names=['target'])

# for each of the query df entries, the following command gives the source file:
# $ sourmash sig describe /scratch/dmk333_new/temp/Salmonella/data/sketches_individual_unzipped/99327287.k=31.scaled=100.DNA.dup=0.GCA_009580765.1_PDT000269722.2_genomic.fna.sig
#
# == This is sourmash version 4.8.11. ==
# == Please cite Irber et. al (2024), doi:10.21105/joss.06830. ==
#
# ---
# signature filename: /scratch/dmk333_new/temp/Salmonella/data/sketches_individual_unzipped/99327287.k=31.scaled=100.DNA.dup=0.GCA_009580765.1_PDT000269722.2_genomic.fna.sig
# signature: GCA_009580765.1_PDT000269722.2_genomic.fna
# source file: /scratch/dmk333_new/temp/Salmonella/data/genomes/GCA_009580765.1_PDT000269722.2_genomic.fna
# md5: 993272873425de2ca6757376e1cec57b
# k=31 molecule=DNA num=0 scaled=100 seed=42 track_abundance=0
# size: 49641
# sum hashes: 49641
# signature license: CC0
#
# loaded 1 signatures from '/scratch/dmk333_new/temp/Salmonella/data/sketches_individual_unzipped/99327287.k=31.scaled=100.DNA.dup=0.GCA_009580765.1_PDT000269722.2_loaded 1 signatures total, from 1 files

# I want to grab the source file from the signature filename


# helper function to run the sourmash sig describe command
def get_source_file(sig_file):
    cmd = f'sourmash sig describe {sig_file}'
    output = subprocess.check_output(cmd, shell=True).decode('utf-8').split('\n')
    for line in output:
        if 'source file:' in line:
            return line.split(': ')[1]


# helper function to get the k-mer size from the source file
def get_ksize(file):
    cmd = f'sourmash sig describe {file}'
    output = subprocess.check_output(cmd, shell=True).decode('utf-8').split('\n')
    for line in output:
        if 'k=' in line:
            return int(line.split('=')[1].split('.')[0])


# helper function to get the first line in the source file
def get_first_line(file):
    with open(file, 'r') as f:
        # strip the `>` from the first line
        return f.readline().strip()[1:]


# collect the source files for the query and target files
query_df['source_file'] = query_df['query'].apply(get_source_file)
target_df['source_file'] = target_df['target'].apply(get_source_file)

# collect the first line of the source files
query_df['first_line'] = query_df['source_file'].apply(get_first_line)
target_df['first_line'] = target_df['source_file'].apply(get_first_line)

# read the comparison file
comparison_df = pd.read_csv(comparison_file)
# The structure of the comparison data frame is: <location in query file>, <location in target file>, <jaccard>, <containment(A,B), <containment(B,A)>
# I want to add the ANI value to this data frame via the formula: ANI = max(containment(A,B), containment(B,A))^(1/ksize)

# add the ksize to the comparison data frame
comparison_df['ksize'] = get_ksize(query_df['source_file'][0])

# add the ANI value to the comparison data frame
comparison_df['ANI'] = comparison_df.apply(lambda row: max(row['containment(A,B)'], row['containment(B,A)'])**(1/row['ksize']), axis=1)

# output the comparison data frame to a CSV file, just include the:
# <file name of query>,<file name of target>,<first line of query file>,<first line of target file>,<the maximum of containment(B,A) and containment(A,B)>,<that maximum to the power 31>
# create a blank data frame
output_df = pd.DataFrame()
# add the query file name
output_df['query'] = query_df['query']
# add the target file name
output_df['target'] = target_df['target']
# add the first line of the query file
output_df['query_first_line'] = query_df['first_line']
# add the first line of the target file
output_df['target_first_line'] = target_df['first_line']
# add the ANI value
output_df['ANI'] = comparison_df['ANI']

# output the data frame to a CSV file
output_df.to_csv(output_file, index=False)

