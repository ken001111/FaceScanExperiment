#!/bin/bash
LOG="$HOME/clone_methods.log"
echo "START $(date)" > "$LOG"
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
cd "$HOME" || exit 1
clone() {
  local url="$1" dir="$2"
  if [ -d "$HOME/$dir/.git" ]; then
    echo "[skip] $dir present" >> "$LOG"
  else
    echo "[clone] $dir <- $url $(date)" >> "$LOG"
    git clone --recursive "$url" "$HOME/$dir" >> "$LOG" 2>&1 && echo "  ok $dir" >> "$LOG" || echo "  FAIL $dir" >> "$LOG"
  fi
}
clone https://github.com/Fictionarry/GeoSVR.git         geosvr
clone https://github.com/NVlabs/svraster.git            svraster
clone https://github.com/hbb1/2d-gaussian-splatting.git 2d-gaussian-splatting
clone https://github.com/graphdeco-inria/gaussian-splatting.git gaussian-splatting
clone https://github.com/Anttwo/SuGaR.git               SuGaR
echo "ALLDONE $(date)" >> "$LOG"
for d in geosvr svraster 2d-gaussian-splatting gaussian-splatting SuGaR; do
  echo "== $d ==" >> "$LOG"
  ls "$HOME/$d" >> "$LOG" 2>&1
done
