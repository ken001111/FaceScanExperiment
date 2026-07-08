n=0
PID=""
while [ $n -lt 30 ]; do
  PID=$(pgrep -f 'python train.py' | head -1)
  if [ -n "$PID" ]; then break; fi
  sleep 2
  n=$((n+1))
done
if [ -n "$PID" ]; then
  echo "train.py RUNNING pid=$PID"
  ps -o pid,etime,%cpu,cmd -p "$PID" | tail -1 | cut -c1-90
else
  echo "train.py NOT found"
fi
