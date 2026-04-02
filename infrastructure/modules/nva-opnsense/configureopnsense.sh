#!/bin/sh

if [ "$4" = "TwoNics" ]; then
    fetch $1config.xml
    fetch $1get_nic_gw.py
    gwip=$(python get_nic_gw.py $5)
    sed -i "" "s/yyy.yyy.yyy.yyy/$gwip/" config.xml
    sed -i "" "s_zzz.zzz.zzz.zzz_$6_" config.xml
    cp config.xml /usr/local/etc/config.xml
fi

fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in
sed -i "" 's/#PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i "" "s/set -e/#set -e/g" opnsense-bootstrap.sh.in
sed -i "" "s/reboot/shutdown -r +1/g" opnsense-bootstrap.sh.in
sh ./opnsense-bootstrap.sh.in -y -r "$2"

fetch https://github.com/Azure/WALinuxAgent/archive/refs/tags/v$3.tar.gz
tar -xvzf v$3.tar.gz
cd WALinuxAgent-$3/
python3 setup.py install --register-service --lnx-distro=freebsd --force
cd ..

ln -s /usr/local/bin/python3.11 /usr/local/bin/python
sed -i "" 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/' /etc/waagent.conf
fetch $1actions_waagent.conf
cp actions_waagent.conf /usr/local/opnsense/service/conf/actions.d

pkg install -y bash
pkg install -y os-frr

cat > /usr/local/etc/rc.syshook.d/start/22-remoteroute <<EOL
#!/bin/sh
route delete 168.63.129.16
EOL
chmod +x /usr/local/etc/rc.syshook.d/start/22-remoteroute

echo # Add Azure Internal VIP >> /etc/rc.conf
echo static_arp_pairs=\"azvip\" >>  /etc/rc.conf
echo static_arp_azvip=\"168.63.129.16 12:34:56:78:9a:bc\" >> /etc/rc.conf
service static_arp start
echo service static_arp start >> /usr/local/etc/rc.syshook.d/start/20-freebsd

echo #\!/bin/sh >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
echo configctl webgui restart renew >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
echo rm /usr/local/etc/rc.syshook.d/start/94-restartwebgui >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
chmod +x /usr/local/etc/rc.syshook.d/start/94-restartwebgui

echo "OPNsense installation completed. System will reboot in 1 minute."
