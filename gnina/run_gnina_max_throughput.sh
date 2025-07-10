#!/bin/bash

# === Configuration ===
# 1. How many GPUs do you have available?
NUM_GPUS=2

# 2. How many concurrent gnina processes to run on EACH GPU?
JOBS_PER_GPU=14

# 3. Directory containing all your ligand .pdbqt files
LIGAND_DIR="$HOME/projects/drug_repurposing/AutoDOCK/docking_converted_filtered/"

# 4. Name of your prepared receptor file
RECEPTOR_FILE="5l2m_protein.pdb"

# 5. Directory where scored output files will be saved
OUTPUT_DIR="scored"
# === End of Configuration ===


# --- Sanity Checks & Preparation ---
if ! command -v parallel &> /dev/null; then
    echo "ERROR: GNU Parallel is not installed. Please install it first."
    exit 1
fi

ACTUAL_GPUS=$(nvidia-smi -L | wc -l)
if [ "$NUM_GPUS" -gt "$ACTUAL_GPUS" ]; then
    echo "ERROR: Your configuration requests NUM_GPUS=$NUM_GPUS, but only $ACTUAL_GPUS GPUs were found."
    echo "Please set NUM_GPUS to $ACTUAL_GPUS or lower in the script."
    exit 1
fi

if [ ! -d "$LIGAND_DIR" ]; then
    echo "ERROR: Ligand directory not found: $LIGAND_DIR"
    exit 1
fi

if [ ! -f "$RECEPTOR_FILE" ]; then
    echo "ERROR: Receptor file not found: $RECEPTOR_FILE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# --- Create Master Ligand List ---
MASTER_LIST_FILE="all_ligands_to_process.txt"
find "$LIGAND_DIR" -name "*.pdbqt" > "$MASTER_LIST_FILE"

TOTAL_LIGANDS=$(wc -l < "$MASTER_LIST_FILE")
if [ "$TOTAL_LIGANDS" -eq 0 ]; then
    echo "ERROR: No .pdbqt files found in '$LIGAND_DIR'."
    rm "$MASTER_LIST_FILE"
    exit 1
fi

# --- Create processing function ---
process_ligand() {
    ligand_file="$1"
    GPU_ID=$(( (${PARALLEL_SEQ} - 1) % NUM_GPUS ))
    base=$(basename "$ligand_file" .pdbqt)
    output_file="$OUTPUT_DIR/${base}_scored.sdf"
    
    # Skip if output file already exists
    if [ -f "$output_file" ]; then
        echo "Skipping ligand $base - already scored (output file exists)"
        return 0
    fi
    
    echo "Processing ligand $base on GPU $GPU_ID (job ${PARALLEL_SEQ})"
    
    # Corrected ligand path for use inside the container
    ligand_path_in_container="/ligands/$(basename "$ligand_file")"

    # Add timeout to prevent hanging jobs
    timeout 600 docker run --rm --ipc=host --gpus "device=$GPU_ID" \
      --memory="4g" --memory-swap="4g" \
      --cpus="1.0" \
      -v "$(pwd)":/work \
      -v "$LIGAND_DIR":"/ligands" \
      -w /work \
      gnina/gnina:latest \
      gnina --score_only --cnn_scoring all \
            -r "$RECEPTOR_FILE" \
            -l "$ligand_path_in_container" \
            --autobox_ligand "$ligand_path_in_container" \
            -o "$output_file"
    
    # Check if the job completed successfully
    if [ $? -ne 0 ]; then
        echo "ERROR: Job for ligand $base failed or timed out"
        return 1
    fi
}

# --- Export variables and function so they are available to the subshells created by parallel ---
export LIGAND_DIR
export RECEPTOR_FILE
export OUTPUT_DIR
export NUM_GPUS
export -f process_ligand

TOTAL_JOBS=$((NUM_GPUS * JOBS_PER_GPU))

echo "Receptor:      $RECEPTOR_FILE"
echo "Total Ligands: $TOTAL_LIGANDS"
echo "GPUs to use:   $NUM_GPUS"
echo "Jobs per GPU:  $JOBS_PER_GPU"
echo "Total concurrent Docker containers: $TOTAL_JOBS"
echo "----------------------------------------------------"
echo "Starting parallel processing... Progress will be shown below."

# --- Run everything using GNU Parallel with periodic cleanup ---
echo "Starting processing with periodic cleanup every 2000 jobs..."

# Function to run cleanup
cleanup_docker() {
    echo "Running Docker cleanup..."
    docker system prune -f > /dev/null 2>&1 || true
}

# Export cleanup function
export -f cleanup_docker

# Run with periodic cleanup every 2000 jobs
cat "$MASTER_LIST_FILE" | parallel -j "$TOTAL_JOBS" --eta --joblog gnina_parallel.log \
  --line-buffer \
  'if (( {#} % 2000 == 0 )); then cleanup_docker; fi; process_ligand {}'

# --- Cleanup ---
rm "$MASTER_LIST_FILE"

echo "----------------------------------------------------"
echo "All jobs completed. Check '$OUTPUT_DIR' for results and 'gnina_parallel.log' for a detailed log."