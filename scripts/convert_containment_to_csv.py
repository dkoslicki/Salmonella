import pandas as pd
import json
import argparse

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


# Helper function to parse the JSON file and extract desired fields
def parse_sig_file(sig_file):
    with open(sig_file, 'r') as f:
        data = json.load(f)
        source_file = data[0]['filename']
        ksize = data[0]['signatures'][0]['ksize']
        return source_file, ksize


# Helper function to get the first line of a source file
def get_first_line(file):
    with open(file, 'r') as f:
        return f.readline().strip()[1:]


# Read the query and target files
query_df = pd.read_csv(query_file, header=None, names=['query'])
target_df = pd.read_csv(target_file, header=None, names=['target'])

# Collect the source files and ksize for the query and target files
print('parsing query sig files')
query_df[['source_file', 'ksize']] = query_df['query'].apply(
    lambda x: pd.Series(parse_sig_file(x))
)
#print('parsing target sig files')
#target_df[['source_file', 'ksize']] = target_df['target'].apply(
#    lambda x: pd.Series(parse_sig_file(x))
#)
print('parsing target sig files')
parsed_target_files = [parse_sig_file(x) for x in target_df['target']]
# Unpack the results into separate lists
source_files, ksize_values = zip(*parsed_target_files)

# Update the target_df in one go
target_df['source_file'] = source_files
target_df['ksize'] = ksize_values

# Collect the first line of the source files
print('getting first line of query files')
query_df['first_line'] = query_df['source_file'].apply(get_first_line)
print('getting first line of target files')
target_df['first_line'] = target_df['source_file'].apply(get_first_line)

# Read the comparison file, name the columns: query, target, containment(A,B), containment(B,A)
# also, don't treat the first column as the index: that's supposed to be the `query_index`
print('loading comparisons')
comparison_df = pd.read_csv(comparison_file, header=None, names=['query_index', 'target_index', 'jaccard',
                                                                 'containment(A,B)',
                                                                'containment(B,A)'])

# Use the ksize from the first query file (assuming consistent ksize across files)
ksize = query_df['ksize'].iloc[0]

# Add the ANI value to the comparison data frame
print('computing ANIs')
comparison_df['ANI'] = comparison_df.apply(
    lambda row: max(row['containment(A,B)'], row['containment(B,A)'])**(1/ksize), axis=1
)

# Create the output
row_num = 0
with open(output_file, 'w') as f:
    f.write("query,target,query_first_line,target_first_line,ANI\n")
    for index, row in comparison_df.iterrows():
        if row_num % 1000 == 0:
            print(f"Processing row {row_num}")
        query_index = int(row['query_index'])
        target_index = int(row['target_index'])
        query = query_df['query'].iloc[query_index]
        target = target_df['target'].iloc[target_index]
        query_first_line = query_df['first_line'].iloc[query_index]
        target_first_line = target_df['first_line'].iloc[target_index]
        ANI = row['ANI']
        f.write(f"{query},{target},{query_first_line},{target_first_line},{ANI}\n")
        row_num += 1
print(f"Output written to {output_file}")
