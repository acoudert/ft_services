#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
ORANGE='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

function banner() {
	echo -e "${GREEN} ____  ____      ___  ____  ____  _  _  ____  ___  ____  ___   ";
	echo -e "( ___)(_  _)    / __)( ___)(  _ \( \/ )(_  _)/ __)( ___)/ __)  ";
	echo -e " )__)   )(  ___ \__ \ )__)  )   / \  /  _)(_( (__  )__) \__ \  ";
	echo -e "(__)   (__)(___)(___/(____)(_)\_)  \/  (____)\___)(____)(___/ ${NC} ";
	echo "";
}

function check() {
	KERNEL=$(uname -s)
	if [ "$KERNEL" != "Linux" ]; then
		echo -e "Kernel is ${RED}${KERNEL}${NC} instead of ${RED}Linux${NC}"
		exit
	fi
	if [ "$USER" != "user42" ]; then
		echo -e "Program should be launched from ${RED}user42 xubuntu VM${NC}"
		exit
	fi
	which minikube > /dev/null
	if [ $? -ne 0 ]; then
		echo -e "${RED}Minikube${NC} not installed"
		exit
	fi
	which kubectl > /dev/null
	if [ $? -ne 0 ]; then
		echo -e "${RED}Kubectl${NC} not installed"
		exit
	fi
}

function loading_animation() {
	COND1=$(echo $2 | tr '_' ' ')
	COND2=$(echo $3 | tr '_' ' ')
	spinner='/-\|'
	echo -ne "$1${RED}" | tr '_' ' '
	tput civis
	while [ $(eval $COND1) $COND2 ]; do
		printf "\b${spinner:i++%${#spinner}:1}"
		sleep 0.1
	done
	echo -e "\b${NC}${GREEN}✅${NC}"
	tput cnorm
}

function minikube_startup() {
	echo -e "user42\n" | sudo -S chmod 666 /var/run/docker.sock &> /dev/null
	minikube delete &> /dev/null
	minikube start --driver=docker --cpus=2 --memory=2048m 2>&1 >> minikube-startup &
	STR=$(printf "Building ${BLUE}%-10s${NC} %-12s:  " "minikube" "node" | sed 's/ /_/g')
	ARG="grep_'Done!'_minikube-startup|_wc_-l"
	REF="-ne_1"
	loading_animation $STR $ARG $REF
	rm minikube-startup
	eval $(minikube docker-env)
}

function ip_setup() {
	NODE_IP=$(kubectl get node -owide | awk 'NR==2{print $6}' \
		| awk -F '.' '{print $1"."$2"."$3"."}')
	sed -i "s/\"235/\"${NODE_IP}235/" srcs/wordpress/init_wordpress.sh
	sed -i "s/235-235/${NODE_IP}235-${NODE_IP}235/" srcs/metallb/config.yaml
	sed -i "s/\/235/\/${NODE_IP}235/g" srcs/nginx/index.html
	sed -i "s/\/235/\/${NODE_IP}235/g" srcs/nginx/nginx-server.conf
	sed -i "s/=235/=${NODE_IP}235/g" srcs/ftps/init_ftps.sh
	printf "Building ${BLUE}%-10s${NC} %-12s: ${GREEN}✅${NC}\n" "files" "ip"
}

function loadbalancer_apply() {
	touch metallb-startup
	kubectl apply -f \
		https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/namespace.yaml \
		>> metallb-startup
	kubectl apply -f \
		https://raw.githubusercontent.com/metallb/metallb/v0.9.5/manifests/metallb.yaml \
		>> metallb-startup
	kubectl create secret generic -n metallb-system memberlist \
		--from-literal=secretkey="$(openssl rand -base64 128)" \
		>> metallb-startup
	kubectl apply -f srcs/metallb/config.yaml >> metallb-startup
	rm metallb-startup
}

function loadbalancer_startup() {
	loadbalancer_apply &
	sleep 0.5
	STR=$(printf "Building ${BLUE}%-10s${NC} %-12s:  " "metallb" "loadbalancer" | sed 's/ /_/g')
	ARG="kubectl_get_pod_-n_metallb-system_2>&1_|_grep_'Running'_|_wc_-l"
	REF="-ne_2"
	loading_animation $STR $ARG $REF
}

function secrets_build_apply() {
	SRCS="nginx mariadb wordpress_db wordpress_admin wordpress_editor wordpress_author wordpress_contributor wordpress_subscriber phpmyadmin ftps influxdb grafana"
	for SVC in $SRCS; do
		USER_SVC=$(echo -n "user_$SVC" | base64)
		PASS_SVC=$(openssl rand -hex 12 | tr -d '\n' | base64)
		# To avoid dealing with PBKDF2 encryption
		if [ "$SVC" = "influxdb" ]; then
			PASS_SVC='YzBkMTY3YTZkMTFkZTUyMDI1OWM3NDFj'
		elif [ "$SVC" = "grafana" ]; then
			PASS_SVC='MDcxOTBjOTBlNjlhNzljMGI5NGY3YWNh'
		fi
		sed -i "s/user_$SVC:.*/user_$SVC: $USER_SVC/" srcs/secrets/secrets.yaml
		sed -i "s/pass_$SVC:.*/pass_$SVC: $PASS_SVC/" srcs/secrets/secrets.yaml
	done
	kubectl apply -f srcs/secrets/secrets.yaml >> secrets-startup
}

function secrets_startup() {
	secrets_build_apply &
	STR=$(printf "Building ${BLUE}%-10s${NC} %-12s:  " "services" "secrets" | sed 's/ /_/g')
	ARG="grep_'secret/services-secrets_created'_secrets-startup_2>_/dev/null_|_wc_-l"
	REF="-ne_1"
	loading_animation $STR $ARG $REF
	rm secrets-startup
}

function image_build_apply() {
	if [ $1 != "ftps" ]; then
		docker build -t $1:0.0 srcs/$1 >> $1-startup
	else
		docker build -t $1:0.0 -f srcs/$1/Dockerfile . >> $1-startup
	fi
	kubectl apply -f srcs/$1/$1.yaml >> $1-startup
}

function images_startup() {
	SRCS="influxdb mariadb wordpress phpmyadmin nginx ftps grafana"
	for SVC in $SRCS; do
		image_build_apply $SVC &
		STR=$(printf "Building ${BLUE}%-10s${NC} %-12s:  " "${SVC}" "deployment" | sed 's/ /_/g')
		ARG="grep_'service/$SVC-service_created'_$SVC-startup|_wc_-l"
		REF="-ne_1"
		loading_animation $STR $ARG $REF
		rm $SVC-startup
	done
}

function dashboard_apply() {
	kubectl create ns metrics >> dashboard-startup
	kubectl apply -f srcs/dashboard/dashboard.yaml >> dashboard-startup
	while [ $(kubectl get all -n metrics 2> /dev/null | awk 'NR==2{print $2}' \
		| grep '1/1' | wc -l) -ne 1 ]; do
		sleep 0.1
	done
	minikube dashboard &>> dashboard-startup
}

function dashboard_startup() {
	dashboard_apply &
	STR=$(printf "Building ${BLUE}%-10s${NC} %-12s:  " "minikube" "dashboard" | sed 's/ /_/g')
	ARG="grep_'default_browser'_dashboard-startup_|_wc_-l"
	REF="-ne_1"
	loading_animation $STR $ARG $REF
	rm dashboard-startup
}

function user-pass_create() {
	SRCS="nginx mariadb wordpress_db wordpress_admin wordpress_editor wordpress_author wordpress_contributor wordpress_subscriber phpmyadmin ftps influxdb grafana"
	for SVC in $SRCS; do
		USER_SVC=$(cat srcs/secrets/secrets.yaml | grep "user_$SVC" | \
			awk '{print $2}' | base64 -d)
		PASS_SVC=$(cat srcs/secrets/secrets.yaml | grep "pass_$SVC" | \
			awk '{print $2}' | base64 -d)
		echo "$USER_SVC : $PASS_SVC" >> user-pass.txt
	done
}

function user-pass_setup() {
	rm -f user-pass.txt
	touch user-pass.txt
	user-pass_create &
	STR=$(printf "Building ${BLUE}%-10s${NC} %-12s:  " "user-pass" "file" | sed 's/ /_/g')
	ARG="grep_'grafana'_user-pass.txt_|_wc_-l"
	REF="-ne_1"
	loading_animation $STR $ARG $REF
}

function info_display() {
	IP=$(kubectl get svc | awk 'NR==2{print $4}')
	echo -e "${ORANGE}------------------------------------${NC}"
	# Nginx
	echo -e "${GREEN}Nginx${NC}"
	PASS=$(cat user-pass.txt | grep nginx | awk '{print $3}')
	echo -e "\t${BLUE}Port 22${NC}   - SSH  :\n\t\tcmd : ${ORANGE}ssh user_nginx@${IP}${NC}"
	echo -e "\t\tuser: ${RED}user_nginx${NC}                 | pass: ${RED}${PASS}${NC}"
	echo -e "\t${BLUE}Port 80${NC}   - HTTP :\n\t\tcmd : ${ORANGE}firefox http://${IP}${NC}"
	echo -e "\t${BLUE}Port 443${NC}  - HTTPS:\n\t\tcmd : ${ORANGE}firefox https://${IP}${NC}"
	# Wordpress
	echo -e "${GREEN}Wordpress${NC}"
	echo -e "\t${BLUE}Port 5050${NC} - HTTPS:\n\t\tcmd : ${ORANGE}firefox https://${IP}:5050${NC}"
	echo -e "\t\tcmd : ${ORANGE}firefox https://${IP}/wordpress${NC}"
	echo -e "\t\tcmd : ${ORANGE}firefox https://${IP}:5050/wp-login.php${NC}"
	PASS=$(cat user-pass.txt | grep wordpress_admin | awk '{print $3}')
	echo -e "\t\tuser: ${RED}user_wordpress_admin${NC}       | pass: ${RED}${PASS}${NC}"
	PASS=$(cat user-pass.txt | grep wordpress_editor | awk '{print $3}')
	echo -e "\t\tuser: ${RED}user_wordpress_editor${NC}      | pass: ${RED}${PASS}${NC}"
	PASS=$(cat user-pass.txt | grep wordpress_author | awk '{print $3}')
	echo -e "\t\tuser: ${RED}user_wordpress_author${NC}      | pass: ${RED}${PASS}${NC}"
	PASS=$(cat user-pass.txt | grep wordpress_contributor | awk '{print $3}')
	echo -e "\t\tuser: ${RED}user_wordpress_contributor${NC} | pass: ${RED}${PASS}${NC}"
	PASS=$(cat user-pass.txt | grep wordpress_subscriber | awk '{print $3}')
	echo -e "\t\tuser: ${RED}user_wordpress_subscriber${NC}  | pass: ${RED}${PASS}${NC}"
	# PMA
	echo -e "${GREEN}PhpMyAdmin${NC}"
	PASS=$(cat user-pass.txt | grep phpmyadmin | awk '{print $3}')
	echo -e "\t${BLUE}Port 5000${NC} - HTTPS:\n\t\tcmd : ${ORANGE}firefox https://${IP}:5000${NC}"
	echo -e "\t\tcmd : ${ORANGE}firefox https://${IP}/phpmyadmin${NC}"
	echo -e "\t\tuser: ${RED}user_phpmyadmin${NC}            | pass: ${RED}${PASS}${NC}"
	# FTPS
	echo -e "${GREEN}FTPS${NC}"
	PASS=$(cat user-pass.txt | grep ftps | awk '{print $3}')
	echo -e "\t${BLUE}Port 21${NC}   - FTPS :\n\t\tcmd : ${ORANGE}sudo filezilla${NC}"
	echo -e "\t\tuser: ${RED}user_ftps${NC}                  | pass: ${RED}${PASS}${NC}"
	# Grafana
	echo -e "${GREEN}Grafana${NC}"
	PASS=$(cat user-pass.txt | grep grafana | awk '{print $3}')
	echo -e "\t${BLUE}Port 3000${NC} - HTTPS:\n\t\tcmd : ${ORANGE}firefox https://${IP}:3000${NC}"
	echo -e "\t\tuser: ${RED}user_grafana${NC}               | pass: ${RED}${PASS}${NC}"
}

function cleaner() {
	NODE_IP=$(kubectl get node -owide | awk 'NR==2{print $6}' \
		| awk -F '.' '{print $1"."$2"."$3"."}')
	sed -i "s/${NODE_IP}235/235/" srcs/wordpress/init_wordpress.sh
	sed -i "s/${NODE_IP}235-${NODE_IP}235/235-235/" srcs/metallb/config.yaml
	sed -i "s/${NODE_IP}235/235/g" srcs/nginx/index.html
	sed -i "s/${NODE_IP}235/235/g" srcs/nginx/nginx-server.conf
	sed -i "s/${NODE_IP}235/235/g" srcs/ftps/init_ftps.sh
	echo -e "user42\n" | sudo -S chmod 660 /var/run/docker.sock &> /dev/null
	minikube delete &> /dev/null
	rm user-pass.txt
	SRCS="nginx mariadb wordpress_db wordpress_admin wordpress_editor wordpress_author wordpress_contributor wordpress_subscriber phpmyadmin ftps influxdb grafana"
	for SVC in $SRCS; do
		sed -i "s/user_$SVC:.*/user_$SVC:/" srcs/secrets/secrets.yaml
		sed -i "s/pass_$SVC:.*/pass_$SVC:/" srcs/secrets/secrets.yaml
	done
}

function main()
{
	if [ $1 ]; then
		cleaner
	else
		banner 
		check
		minikube_startup
		ip_setup
		loadbalancer_startup
		secrets_startup
		images_startup
		user-pass_setup
		dashboard_startup
		info_display
	fi
}

main $1
