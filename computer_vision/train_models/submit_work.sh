#!/bin/bash
#SBATCH --job-name=person_item_train
#SBATCH --output=/userhome/cs/u3606584/fyp/person_and_item/logs/person_and_item_%j.log
#SBATCH --error=/userhome/cs/u3606584/fyp/person_and_item/logs/person_and_item_%j.err
#SBATCH --time=30:00:00
#SBATCH -p batch
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mail-type=ALL
#SBATCH --mail-user=u3606584@connect.hku.hk


echo "=========================================="
echo "🔄 YOLOv11 Training Resume"
echo "Job ID: $SLURM_JOB_ID"
echo "Start time: $(date)"
echo "=========================================="

# 1. activate conda
source ~/miniconda3/etc/profile.d/conda.sh
conda activate fyp

nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv

cd ~

mkdir -p ~/fyp/person_and_item/logs

echo "🚀 Starting python script..."
python train_person_and_item.py

echo "=========================================="
echo "End time: $(date)"
echo "=========================================="