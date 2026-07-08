PIDS=$(pgrep -f train.py)
if [ -n "$PIDS" ]; then
  kill $PIDS 2>/dev/null
  sleep 2
  kill -9 $PIDS 2>/dev/null
  echo "killed: $PIDS"
else
  echo "no train.py running"
fi
echo "--- densify config in train args / scene extent ---"
grep -rn "densify_from_iter\|densify_until_iter\|densification_interval\|opacity_reset\|cameras_extent\|spatial_lr_scale" ~/2d-gaussian-splatting/arguments/__init__.py 2>/dev/null | head
