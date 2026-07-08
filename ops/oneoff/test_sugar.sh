EXT=/mnt/c/Users/m352395/Downloads/paper_experiments/external
tr -d '\r' < "$EXT/run_sugar.sh" > ~/run_sugar.sh
chmod +x ~/run_sugar.sh
echo "=== SuGaR on ken (dn_consistency, surface 0.3, refine short) ==="
SUGAR_REFINE_TIME=short bash ~/run_sugar.sh ~/FaceScan/work/face_scan ~/sugar_test.ply
echo "TEST_SUGAR_DONE"
