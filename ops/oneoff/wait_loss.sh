n=0
while [ $n -lt 50 ]; do
  if grep -q 'Loss=' "$HOME/FaceScan/train.log"; then break; fi
  sleep 3
  n=$((n+1))
done
sleep 3
echo "--- latest loss readings ---"
tr '\r' '\n' < "$HOME/FaceScan/train.log" | grep 'Loss=' | tail -4
