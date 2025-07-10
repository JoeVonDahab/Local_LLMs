# run from the directory that contains:  receptor_ready_5tbm.pdb   all_sdf/*.sdf
mkdir -p scored

docker run --rm --gpus all \
  -v "$(pwd)":/work gnina/gnina:latest \
  bash -c '
  for lig in /work/all_sdf/*.sdf; do
    base=$(basename "$lig" .sdf)
    gnina --score_only --cnn_scoring all \
          -r /work/receptor_ready_5tbm.pdb \
          -l "$lig" \
          --autobox_ligand "$lig" \
          -o /work/scored/${base}_scored.sdf
  done
  '
