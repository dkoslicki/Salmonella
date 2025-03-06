import pandas as pd
import numpy as np

# Define the function to calculate SNP values
def calculate_snp(containment, sketch_size):
    return (1 - containment ** (1 / 31)) * sketch_size * 100

# Read the input CSV
input_file = "threshold_0.001_with_sketch_sizes4.csv"
output_file = "threshold_0.001_with_sketch_sizes4_with_SNPs.csv"

try:
    # Load the CSV file
    df = pd.read_csv(input_file)

    # Validate column names (adjust these if needed)
    required_columns = [
        "containment_query_in_match",
        "containment_match_in_query",
        "query_sketch_size",
        "match_sketch_size",
        "max_containment_ani"
    ]
    for col in required_columns:
        if col not in df.columns:
            raise ValueError(f"Missing required column: {col}")

    # Calculate the new columns
    df["query_SNPs"] = calculate_snp(df["containment_query_in_match"], df["query_sketch_size"])
    df["target_SNPs"] = calculate_snp(df["containment_match_in_query"], df["match_sketch_size"])

    # Sort by max_containment_ani in descending order
    df.sort_values(by="max_containment_ani", ascending=False, inplace=True)

    # Save to the output CSV
    df.to_csv(output_file, index=False)
    print(f"Processed file saved to {output_file}")

except Exception as e:
    print(f"An error occurred: {e}")