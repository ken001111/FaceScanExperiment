git config --global http.sslCAInfo /etc/ssl/certs/ca-certificates.crt
cd ~
[ -d ~/SuGaR ] || git clone --recursive https://github.com/Anttwo/SuGaR.git 2>&1 | tail -4
echo "=== top-level ==="; ls ~/SuGaR
echo "=== entry scripts ==="; ls ~/SuGaR/*.py
echo "=== gaussian_splatting submodule present? ==="; ls ~/SuGaR/gaussian_splatting 2>/dev/null | head
echo "=== train.py help head ==="; sed -n '1,60p' ~/SuGaR/train.py
echo "=== install instructions ==="; sed -n '1,60p' ~/SuGaR/install.sh 2>/dev/null
