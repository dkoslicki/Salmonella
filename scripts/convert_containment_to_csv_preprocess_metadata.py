import pandas as pd
import json
import argparse
import subprocess
import csv

# Set the arguments: query txt file, target txt file, comparison csv file, output csv file, and target metadata file
parser = argparse.ArgumentParser(description='Create a CSV file from containment comparisons.')
parser.add_argument('query', type=str, help='The query txt file. List of file names of uncompressed FMH files.')
parser.add_argument('target', type=str, help='The target txt file. List of file names of uncompressed FMH files.')
parser.add_argument('comparison', type=str, help='The comparison csv file. Output of containment comparison.')
parser.add_argument('output', type=str, help='The output csv file. Contains ANI values for heatmap generation.')
parser.add_argument('--target_metadata', type=str, required=True, help='The preprocessed target metadata file.')
args = parser.parse_args()

# Parse the arguments
query_file = args.query
target_file = args.target
comparison_file = args.comparison
output_file = args.output
target_metadata_file = args.target_metadata

query_file = 'query.txt'
target_file = 'target.txt'
comparison_file = 'small_output.txt'
output_file = 'converted_small_output.csv'
target_metadata_file = 'target_metadata.csv'

# Helper function to parse the query sig file using jq via subprocess
def parse_sig_file_jq(sig_file):
    cmd = ["jq", '-r', '.[0] | "\(.filename)\t\(.signatures[0].ksize)"', sig_file]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        # Handle error
        raise Exception(f"jq command failed for file {sig_file}")
    output = result.stdout.strip()
    filename, ksize = output.split('\t', 1)
    return filename, int(ksize)

# Helper function to get the first line of a source file
def get_first_line(file):
    with open(file, 'r') as f:
        line = f.readline().strip()
        if line.startswith('>'):
            return line[1:]  # Remove leading '>'
        else:
            return line

# Read the query and target files
query_df = pd.read_csv(query_file, header=None, names=['query'])
target_df = pd.read_csv(target_file, header=None, names=['target'])

# Collect the source files and ksize for the query files using jq
print('Parsing query sig files...')
query_df[['source_file', 'ksize']] = query_df['query'].apply(
    lambda x: pd.Series(parse_sig_file_jq(x))
)

# Read the preprocessed target metadata
print('Loading target metadata...')
target_metadata_df = pd.read_csv(target_metadata_file, header=None, names=['source_file', 'ksize', 'first_line'], sep='\t')

target_df = pd.concat([target_df.reset_index(drop=True), target_metadata_df], axis=1)

# Ensure the target DataFrame has the correct data types
target_df['ksize'] = target_df['ksize'].astype(int)

# Collect the first line of the query source files
print('Getting first line of query files...')
query_df['first_line'] = query_df['source_file'].apply(get_first_line)

# Read the comparison file
print('Loading comparisons...')
comparison_df = pd.read_csv(comparison_file, header=None, names=['query_index', 'target_index', 'jaccard',
                                                                 'containment(A,B)', 'containment(B,A)'])

# Use the ksize from the first query file (assuming consistent ksize)
ksize = query_df['ksize'].iloc[0]

# Add the ANI value to the comparison DataFrame
print('Computing ANIs...')
comparison_df['ANI'] = comparison_df.apply(
    lambda row: max(row['containment(A,B)'], row['containment(B,A)'])**(1/ksize), axis=1
)

# Create the output file
print(f"Writing output to {output_file}...")
with open(output_file, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(["query", "target", "query_first_line", "target_first_line", "ANI"])
    for row_num, row in comparison_df.iterrows():
        if row_num % 1000 == 0:
            print(f"Processing row {row_num}")
        query_index = int(row['query_index'])
        target_index = int(row['target_index'])
        query = query_df['query'].iloc[query_index]
        target = target_df['target'].iloc[target_index]
        query_first_line = query_df['first_line'].iloc[query_index]
        target_first_line = target_df['first_line'].iloc[target_index]
        ANI = row['ANI']
        writer.writerow([query, target, query_first_line, target_first_line, ANI])
print("Processing complete.")
