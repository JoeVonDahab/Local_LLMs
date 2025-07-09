mk_prepare_receptor.py \
  --read_pdb protien_3p0g.pdb \
  -o          myreceptor_targeted \
  -p -g -v \
  --box_enveloping ligand_3p0g.pdb \
  --padding 5.0 \
  --allow_bad_res
# This will create a receptor file with a box around the example ligand