A=$(tr '\r' '\n' < "$HOME/FaceScan/train.log" | grep 'Loss=' | tail -1 | grep -oE '[0-9]+/20000' | head -1)
PID=$(pgrep -f 'python train.py' | head -1)
C1=$(ps -o %cpu= -p "$PID" 2>/dev/null)
sleep 8
B=$(tr '\r' '\n' < "$HOME/FaceScan/train.log" | grep 'Loss=' | tail -1 | grep -oE '[0-9]+/20000' | head -1)
echo "iter before: $A"
echo "iter after 8s: $B"
echo "train.py CPU%: $C1"
echo "latest: $(tr '\r' '\n' < "$HOME/FaceScan/train.log" | grep 'Loss=' | tail -1)"
