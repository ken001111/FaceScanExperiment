PID=$(pgrep -f 'python train.py' | head -1)
echo "PID=$PID"
echo "--- state (R=run, D=uninterruptible IO, S=sleep) ---"
cat /proc/$PID/stat | awk '{print "state="$3}'
echo "--- wchan (kernel func if blocked) ---"
cat /proc/$PID/wchan; echo
echo "--- current syscall ---"
cat /proc/$PID/syscall 2>/dev/null
echo "--- threads ---"
ls /proc/$PID/task | wc -l
echo "--- passwordless sudo? ---"
sudo -n true 2>&1 && echo "SUDO_OK" || echo "SUDO_NEEDS_PASSWORD"
echo "--- iter still ---"
tr '\r' '\n' < "$HOME/FaceScan/train.log" | grep 'Loss=' | tail -1 | grep -oE '[0-9]+/20000' | head -1
