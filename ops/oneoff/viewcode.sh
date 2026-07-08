echo "=== gaussian_model.py around add_densification_stats (395-412) ==="
sed -n '395,412p' "$HOME/2d-gaussian-splatting/scene/gaussian_model.py"
echo ""
echo "=== train.py around line 128 ==="
sed -n '120,132p' "$HOME/2d-gaussian-splatting/train.py"
echo ""
echo "=== current iter (still hung?) ==="
tr '\r' '\n' < "$HOME/FaceScan/train.log" | grep 'Loss=' | tail -1
