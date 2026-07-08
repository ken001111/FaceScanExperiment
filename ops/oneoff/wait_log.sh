n=0
while [ $n -lt 80 ]; do
  if [ -s "$HOME/FaceScan/train.log" ]; then break; fi
  sleep 3
  n=$((n+1))
done
sleep 4
tail -14 "$HOME/FaceScan/train.log"
