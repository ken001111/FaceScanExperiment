set -e
git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
cd ~
[ -d ~/svraster ] || git clone --recursive https://github.com/NVlabs/svraster.git ~/svraster 2>&1 | tail -2
[ -d ~/geosvr ]  || git clone --recursive https://github.com/Fictionarry/GeoSVR.git ~/geosvr 2>&1 | tail -2
echo "=== svraster top ==="; ls ~/svraster
echo "=== svraster: cuda ext + requirements ==="
ls ~/svraster/cuda 2>/dev/null || find ~/svraster -maxdepth 2 -name "setup.py" | head
cat ~/svraster/requirements.txt 2>/dev/null
echo "=== geosvr top ==="; ls ~/geosvr
echo "=== geosvr: cuda ext + requirements ==="
ls ~/geosvr/cuda 2>/dev/null || find ~/geosvr -maxdepth 2 -name "setup.py" | head
cat ~/geosvr/requirements.txt 2>/dev/null
