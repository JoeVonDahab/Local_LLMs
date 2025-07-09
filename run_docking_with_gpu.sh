#!/usr/bin/env bash
###############################################################################
#  AutoDock-GPU – ONE GPU, BATCH MODE
#  - first line of the batch is the absolute path to the .maps.fld
#  - all following lines are absolute paths to ligand *.pdbqt files
###############################################################################

#####  USER SETTINGS  #########################################################
AUTODOCK_GPU_EXEC="/home/percy/projects/AutoDOCK/AutoDock-GPU/bin/autodock_gpu_128wi"
MAP_FILE_FLD="myreceptor_targeted.maps.fld"     # pre-computed grid maps
LIGAND_DIR="ligands_pdbqt"                      # folder with *.pdbqt ligands
OUTPUT_DIR="docking_results_gpu1"               # where *.dlg files go
NUM_RUNS=10                                     # --nrun
GPU_DEVNUM=1                                    # AutoDock-GPU is 1-indexed
BATCH_FILE="ligand_batch_gpu1.txt"              # will be (re)generated
LOG_FILE="adgpu_gpu1.log"                       # runtime log
################################################################################

set -euo pipefail
cd "$(dirname "$0")"          # run script from its own folder

#####  SANITY CHECKS  #########################################################
[[ -x "$AUTODOCK_GPU_EXEC" ]]   || { echo "Binary not executable: $AUTODOCK_GPU_EXEC"; exit 1; }
[[ -f "$MAP_FILE_FLD" ]]        || { echo ".fld not found: $MAP_FILE_FLD";            exit 1; }
[[ -d "$LIGAND_DIR" ]]          || { echo "Ligand dir not found: $LIGAND_DIR";        exit 1; }

mkdir -p "$OUTPUT_DIR"

#####  BUILD BATCH LIST (SKIP ALREADY DOCKED)  ###############################
echo "Building batch file: $BATCH_FILE"
{
    # first line = absolute path to the .fld  (REGISTERED **ONCE**)
    realpath "$MAP_FILE_FLD"
    
    # then every ligand – absolute path, one per line (skip if .dlg already exists)
    find "$(realpath "$LIGAND_DIR")" -maxdepth 1 -type f -name '*.pdbqt' -print0 \
        | sort -z \
        | while IFS= read -r -d '' ligand_file; do
            ligand_basename=$(basename "$ligand_file" .pdbqt)
            dlg_file="$OUTPUT_DIR/${ligand_basename}.dlg"
            if [[ ! -f "$dlg_file" ]]; then
                realpath "$ligand_file"
            fi
        done
} > "$BATCH_FILE"

TOTAL_LIGANDS=$(($(wc -l < "$BATCH_FILE") - 1))
echo "→ $TOTAL_LIGANDS ligands queued for GPU $GPU_DEVNUM (skipped already docked)"
echo "-----------------------------------------------------------------"

if [[ $TOTAL_LIGANDS -le 0 ]]; then
    echo "No new ligands to dock. All appear to be already completed."
    exit 0
fi

#####  RUN AUTODOCK-GPU  ######################################################
"$AUTODOCK_GPU_EXEC" \
        -B "$BATCH_FILE" \
        --nrun "$NUM_RUNS" \
        -resnam "${OUTPUT_DIR}/" \
        --devnum "$GPU_DEVNUM" \
        > "$LOG_FILE" 2>&1

EXIT=$?
[[ $EXIT -eq 0 ]] && echo "✔︎ Docking finished OK." || echo "✗ Docking exited with code $EXIT."
echo "See $LOG_FILE for details."
###############################################################################
