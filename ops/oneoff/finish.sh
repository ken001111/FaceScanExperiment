source ~/miniconda3/etc/profile.d/conda.sh
conda activate facescan
. "$HOME/FaceScan/last_run.txt"
export OUTPUT_PATH RUN_ID
~/miniconda3/envs/facescan/bin/python /mnt/c/Users/m352395/Downloads/finish_mesh.py
echo "--- results dir ---"
ls -la "$HOME/FaceScan/results/"
