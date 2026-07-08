L=~/SuGaR/output/sugar_rerun.log
i=0
while [ $i -lt 120 ]; do
  if grep -qiE 'Mesh saved|sugarmesh|Traceback|Error|FAILED|pipeline_exit|No module|CUDA error|out of memory' "$L" 2>/dev/null; then
    echo "=== signal after $((i*10))s ==="
    grep -iE 'Mesh saved|sugarmesh|Traceback|Error|FAILED|pipeline_exit|No module|CUDA error|coarse|Regularization|Optimizing' "$L" | tail -12
    exit 0
  fi
  i=$((i+1)); sleep 10
done
echo "timeout; tail:"; tail -6 "$L"
