#!/bin/bash

curl -s https://raw.githubusercontent.com/bombermine3/cryptohamster/main/logo.sh | bash && sleep 1

if [ $# -ne 1 ]; then 
	echo "Использование:"
	echo "bundlr.sh <command>"
	echo "	install   Установка ноды"
	echo "	uninstall Удаление"
	echo "	update    Обновление"
	echo "	backup    Бэкап приватного ключа"
	echo ""
fi

backup () {
	mkdir -p $HOME/massa_backup
	cp $HOME/massa/massa-node/config/node_privkey.key $HOME/massa_backup/
	cp $HOME/massa/massa-client/wallet.dat $HOME/massa_backup/
}

case "$1" in
install)
	apt update && apt -y upgrade
	sudo apt -y install pkg-config curl git build-essential libssl-dev libclang-dev jq
	
	MASSA_LATEST=`wget -qO- https://api.github.com/repos/massalabs/massa/releases/latest | jq -r ".tag_name"`
	wget -qO $HOME/massa.tar.gz "https://github.com/massalabs/massa/releases/download/${MASSA_LATEST}/massa_${MASSA_LATEST}_release_linux.tar.gz"
	tar -xvf $HOME/massa.tar.gz
	rm -rf $HOME/massa.tar.gz

	read -p "Введите пароль: " MASSA_PASSSWORD
	echo 'export MASSA_PASSWORD='$MASSA_PASSWORD >> $HOME/.bash_profile
	echo 'function massa_client() { (cd /root/massa/massa-client/ && ./massa-client -p $MASSA_PASSWORD $@); }' >> $HOME/.bash_profile
	source $HOME/.bash_profile

	printf "[Unit]
Description=Massa Node
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/massa/massa-node
ExecStart=$HOME/massa/massa-node/massa-node -p "$MASSA_PASSWORD"
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/massa-node.service

	sudo tee <<EOF >/dev/null $HOME/massa/massa-node/config/config.toml
[network]
routable_ip = "`curl -s ifconfig.me/ip`"
EOF

	systemctl daemon-reload
	systemctl enable massa-node
	systemctl restart massa-node

	massa_client wallet_generate_secret_key
	
	MASSA_SECRET_KEY=$(massa_client wallet_info -j | jq -r ".[].keypair.secret_key")
	MASSA_ADDRESS=$(massa_client wallet_info -j | jq -r ".[].address_info.address")
	massa_client node_add_staking_secret_keys $MASSA_SECRET_KEY
	
	backup

	echo "Установка завершена"
	echo "Адрес Massa: ${MASSA_ADDRESS}"
	echo "Далее следуйте гайду"
	;;

update)
	backup

	systemctl stop massa-node
	MASSA_LATEST=`wget -qO- https://api.github.com/repos/massalabs/massa/releases/latest | jq -r ".tag_name"`
        wget -qO $HOME/massa.tar.gz "https://github.com/massalabs/massa/releases/download/${MASSA_LATEST}/massa_${MASSA_LATEST}_release_linux.tar.gz"
        tar -xvf $HOME/massa.tar.gz
        rm -rf $HOME/massa.tar.gz
	systemctl start massa-node

	echo "Обновлено до версии ${MASSA_LATEST}"
	;;

backup)
	backup
	;;		

uninstall)
	backup
	systemctl stop massa-node
	systemctl disable massa-node
	rm /etc/systemd/system/massa-node.service
	rm -rf $HOME/massa

	echo "Удаление завершено"
	;;

esac
