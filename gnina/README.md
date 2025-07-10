# GNINA Drug Repurposing Package

This package provides high-throughput molecular docking and scoring using GNINA (GPU-accelerated neural network-based molecular docking) for drug repurposing projects. It supports both SDF and PDBQT input formats with parallel GPU processing.

## Overview

The package includes scripts for:
- **High-throughput GNINA docking** with GPU parallelization
- **Automated scoring** of large compound libraries
- **CSV generation** from docking results for analysis
- Support for both **SDF** and **PDBQT** file formats

## Prerequisites

### Software Requirements
- Docker with GPU support
- NVIDIA Container Toolkit
- GNU Parallel
- Python 3.x with the following packages:
  - pandas
  - rdkit (for SDF processing)

### Hardware Requirements
- NVIDIA GPU(s) with CUDA support
- Sufficient disk space for compound libraries and results

## Installation

1. **Install Docker and NVIDIA Container Toolkit:**
```bash
# Follow NVIDIA's official installation guide for your system
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
```

2. **Install GNU Parallel:**
```bash
# Ubuntu/Debian
sudo apt-get install parallel

# CentOS/RHEL
sudo yum install parallel
```

3. **Pull GNINA Docker image:**
```bash
docker pull gnina/gnina:latest
```

4. **Install Python dependencies:**
```bash
pip install pandas rdkit
```

## File Structure

```git 
gnina/
├── README.md                           # This file
├── run_gnina_max_throughput_sdf.sh     # SDF workflow script
├── run_gnina_max_throughput_pdbqt.sh   # PDBQT workflow script
├── make_csv_sdf.py                     # SDF results processor
├── make_csv_pdbqt.py                   # PDBQT results processor
├── 5l2m_protein.pdb                    # Example receptor file
├── all_sdf/                            # SDF compound library
├── scored/                             # Output directory for scored compounds
└── gnina_parallel.log                  # Parallel processing log
```

## Usage

### SDF Workflow (Recommended)

Use this workflow when you have compound libraries in SDF format.

#### 1. Setup
- Place your receptor PDB file in the main directory
- Place your SDF compound library in the `all_sdf/` directory
- Configure `run_gnina_max_throughput_sdf.sh`:

```bash
# Edit the configuration section
NUM_GPUS=2                    # Number of GPUs available
JOBS_PER_GPU=50              # Concurrent processes per GPU
LIGAND_DIR="all_sdf/"        # Directory with SDF files
RECEPTOR_FILE="5l2m_protein.pdb"  # Your receptor file
OUTPUT_DIR="scored"          # Output directory
```

#### 2. Run GNINA Scoring
```bash
chmod +x run_gnina_max_throughput_sdf.sh
./run_gnina_max_throughput_sdf.sh
```

#### 3. Generate CSV Results
```bash
python make_csv_sdf.py
```

This creates `gnina_scores.csv` with columns:
- `ligand`: Compound name
- `CNNscore`: Neural network binding score
- `CNNaffinity`: Predicted binding affinity
- `Affinity`: Traditional AutoDock Vina affinity

### PDBQT Workflow

Use this workflow when you have compound libraries in PDBQT format (e.g., from AutoDock Vina).

#### 1. Setup
Configure `run_gnina_max_throughput_pdbqt.sh`:

```bash
# Edit the configuration section
NUM_GPUS=2                    # Number of GPUs available
JOBS_PER_GPU=50              # Concurrent processes per GPU
LIGAND_DIR="\\wsl.localhost\Ubuntu\home\joe\projects\drug_repurposing\AutoDOCK\docking_converted_filtered\"
RECEPTOR_FILE="5l2m_protein.pdb"
OUTPUT_DIR="scored"
```

#### 2. Run GNINA Scoring
```bash
chmod +x run_gnina_max_throughput_pdbqt.sh
./run_gnina_max_throughput_pdbqt.sh
```

#### 3. Generate CSV Results
```bash
python make_csv_pdbqt.py
```

## Configuration Options

### GPU Settings
- **NUM_GPUS**: Set to the number of NVIDIA GPUs available
- **JOBS_PER_GPU**: Number of concurrent GNINA processes per GPU
  - Start with 50 and adjust based on GPU memory
  - Higher values = more throughput but more memory usage

### Performance Tuning
- **Total concurrent jobs** = NUM_GPUS × JOBS_PER_GPU
- Monitor GPU memory usage with `nvidia-smi`
- Adjust JOBS_PER_GPU if you encounter out-of-memory errors

## Output Files

### Scored Compounds
- **Location**: `scored/` directory
- **Format**: `{compound_name}_scored.sdf`
- **Content**: Original structure + GNINA scores

### CSV Results
- **File**: `gnina_scores.csv`
- **Sorted by**: CNNaffinity (best to worst)
- **Columns**:
  - `ligand`: Compound identifier
  - `CNNscore`: Neural network confidence score (0-1)
  - `CNNaffinity`: Predicted binding affinity (kcal/mol)
  - `Affinity`: Traditional docking score (kcal/mol)

### Log Files
- **gnina_parallel.log**: Detailed execution log for each compound
- **Progress tracking**: Real-time ETA and completion status

## Troubleshooting

### Common Issues

1. **"ERROR: GNU Parallel is not installed"**
   ```bash
   sudo apt-get install parallel  # Ubuntu/Debian
   sudo yum install parallel      # CentOS/RHEL
   ```

2. **GPU not found errors**
   - Verify NVIDIA drivers: `nvidia-smi`
   - Check Docker GPU support: `docker run --gpus all nvidia/cuda:11.0-base nvidia-smi`

3. **Out of memory errors**
   - Reduce JOBS_PER_GPU value
   - Monitor memory with `nvidia-smi`

4. **No input files found**
   - Verify LIGAND_DIR path is correct
   - Check file extensions (.sdf or .pdbqt)
   - Ensure files are readable

5. **Permission denied**
   ```bash
   chmod +x run_gnina_max_throughput_*.sh
   ```

### Performance Monitoring

Monitor progress in real-time:
```bash
# Watch GPU usage
watch -n 1 nvidia-smi

# Monitor log file
tail -f gnina_parallel.log

# Check current progress
wc -l scored/*_scored.sdf
```

## Example Results Interpretation

```csv
ligand,CNNscore,CNNaffinity,Affinity
Belzutifan,0.89,-9.2,-8.5
PT2385,0.85,-8.8,-8.1
Ruxolitinib,0.82,-8.3,-7.9
```

- **Higher CNNscore** = Higher confidence in binding prediction
- **More negative CNNaffinity** = Stronger predicted binding
- **More negative Affinity** = Better traditional docking score

## Citation

If you use this package in your research, please cite:
- GNINA: [McNutt et al. J Cheminform (2021)](https://doi.org/10.1186/s13321-021-00522-2)
- AutoDock Vina: [Eberhardt et al. J Chem Inf Model (2021)](https://doi.org/10.1021/acs.jcim.1c00203)

## License

This package is provided as-is for research purposes. Please refer to GNINA's license for commercial use restrictions.
