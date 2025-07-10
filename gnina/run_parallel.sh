#!/usr/bin/env bash
set -euo pipefail

### ─── USER SETTINGS ────────────────────────────────────────────────
RECEPTOR="receptor_ready_5tbm.pdb"   # rigid receptor       (in CWD)
LIG_DIR="all_sdf"                    # folder of *.sdf poses
OUT_DIR="scored"                     # results land here
LOG_DIR="gnina_logs"                 # one log per GPU
IMAGE="gnina/gnina:latest"           # docker image / tag
CNN_OPTION="all"                     # cnn_scoring mode
# --------------------------------------------------------------------

# detect GPUs the Docker runtime can see
GPU_LIST=$(nvidia-smi --query-gpu=index --format=csv,noheader)
NUM_GPU=$(echo "$GPU_LIST" | wc -l)
if [[ $NUM_GPU -eq 0 ]]; then
    echo "❌  No NVIDIA GPUs detected by nvidia-smi."; exit 1
fi
echo "🖥️  Detected $NUM_GPU GPU(s): $GPU_LIST"

mkdir -p "$OUT_DIR" "$LOG_DIR"

# build an array of ligand files
mapfile -t ALL_LIGANDS < <(find "$LIG_DIR" -maxdepth 1 -name "*.sdf" -printf "%p\n" | sort)
TOTAL=${#ALL_LIGANDS[@]}
if [[ $TOTAL -eq 0 ]]; then
    echo "❌  No .sdf poses found in $LIG_DIR"; exit 1
fi
echo "🔍  Found $TOTAL ligand files."

# split ligand list into N roughly equal chunks (one per GPU)
CHUNK_SIZE=$(( (TOTAL + NUM_GPU - 1) / NUM_GPU ))
echo "📦  Chunk size = $CHUNK_SIZE files / GPU"

pids=()
i_gpu=0
for gpu in $GPU_LIST; do
    chunk=("${ALL_LIGANDS[@]:$((i_gpu*CHUNK_SIZE)):CHUNK_SIZE}")
    ((i_gpu++))
    [[ ${#chunk[@]} -eq 0 ]] && continue   # extra GPU if ligands < GPUs

    # write chunk list into a temp file inside CWD
    LIST_FILE="lig_chunk_gpu${gpu}.lst"
    printf "%s\n" "${chunk[@]}" > "$LIST_FILE"

    echo "🚀  GPU $gpu  →  ${#chunk[@]} ligands  →  $LIST_FILE"

    # launch detached container bound to that single GPU
    docker run --rm --gpus "device=${gpu}" \
      -v "$(pwd)":/work "$IMAGE" \
      bash -c "
        while read lig; do
          base=\$(basename \"\$lig\" .sdf)
          gnina --score_only --cnn_scoring $CNN_OPTION \
                -r /work/$RECEPTOR \
                -l \"/work/\$lig\" \
                --autobox_ligand \"/work/\$lig\" \
                -o /work/$OUT_DIR/\${base}_scored.sdf
        done < /work/$LIST_FILE
      " > "$LOG_DIR/gnina_gpu${gpu}.log" 2>&1 &

    pids+=($!)
done

# ─── Wait for all containers ────────────────────────────────────────
for pid in "${pids[@]}"; do
    wait "$pid"
done

echo "✅  All Gnina scoring jobs finished."
echo "• Results:   $OUT_DIR/"
echo "• Logs:      $LOG_DIR/"
