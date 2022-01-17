#/usr/bin/env bash
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'


# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1
clear
# globals
CWD=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
[ -e "${CWD}/scripts/globals" ] && . ${CWD}/scripts/globals
checkos(){
  ifTermux=$(echo $PWD | grep termux)
  ifMacOS=$(uname -a | grep Darwin)
  if [ -n "$ifTermux" ];then
    os_version=Termux
  elif [ -n "$ifMacOS" ];then
    os_version=MacOS  
  else  
    os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
  fi
  
  if [[ "$os_version" == "2004" ]] || [[ "$os_version" == "10" ]] || [[ "$os_version" == "11" ]];then
    ssll="-k --ciphers DEFAULT@SECLEVEL=1"
  fi
}
checkos 

checkCPU(){
  CPUArch=$(uname -m)
  if [[ "$CPUArch" == "aarch64" ]];then
    arch=linux_arm64
  elif [[ "$CPUArch" == "i686" ]];then
    arch=linux_386
  elif [[ "$CPUArch" == "arm" ]];then
    arch=linux_arm
  elif [[ "$CPUArch" == "x86_64" ]] && [ -n "$ifMacOS" ];then
    arch=darwin_amd64
  elif [[ "$CPUArch" == "x86_64" ]];then
    arch=linux_amd64    
  fi
}
checkCPU
check_dependencies(){

  os_detail=$(cat /etc/os-release 2> /dev/null)
  if_debian=$(echo $os_detail | grep 'ebian')
  if_redhat=$(echo $os_detail | grep 'rhel')
  if [ -n "$if_debian" ];then
    InstallMethod="apt"
  elif [ -n "$if_redhat" ] && [[ "$os_version" -lt 8 ]];then
    InstallMethod="yum"
  elif [[ "$os_version" == "MacOS" ]];then
    InstallMethod="brew"  
  fi
}
check_dependencies
#安装wget、curl、unzip、git
echo -e "${green}检测运行环境中。。。${plain}"
yum install unzip wget curl git -y > /dev/null 2>&1 
${InstallMethod} install unzip wget curl git -y > /dev/null 2>&1 
get_opsy() {
  [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
  [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
  [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}
virt_check() {
  # if hash ifconfig 2>/dev/null; then
  # eth=$(ifconfig)
  # fi

  virtualx=$(dmesg) 2>/dev/null

  if [[ $(which dmidecode) ]]; then
    sys_manu=$(dmidecode -s system-manufacturer) 2>/dev/null
    sys_product=$(dmidecode -s system-product-name) 2>/dev/null
    sys_ver=$(dmidecode -s system-version) 2>/dev/null
  else
    sys_manu=""
    sys_product=""
    sys_ver=""
  fi

  if grep docker /proc/1/cgroup -qa; then
    virtual="Docker"
  elif grep lxc /proc/1/cgroup -qa; then
    virtual="Lxc"
  elif grep -qa container=lxc /proc/1/environ; then
    virtual="Lxc"
  elif [[ -f /proc/user_beancounters ]]; then
    virtual="OpenVZ"
  elif [[ "$virtualx" == *kvm-clock* ]]; then
    virtual="KVM"
  elif [[ "$cname" == *KVM* ]]; then
    virtual="KVM"
  elif [[ "$cname" == *QEMU* ]]; then
    virtual="KVM"
  elif [[ "$virtualx" == *"VMware Virtual Platform"* ]]; then
    virtual="VMware"
  elif [[ "$virtualx" == *"Parallels Software International"* ]]; then
    virtual="Parallels"
  elif [[ "$virtualx" == *VirtualBox* ]]; then
    virtual="VirtualBox"
  elif [[ -e /proc/xen ]]; then
    virtual="Xen"
  elif [[ "$sys_manu" == *"Microsoft Corporation"* ]]; then
    if [[ "$sys_product" == *"Virtual Machine"* ]]; then
      if [[ "$sys_ver" == *"7.0"* || "$sys_ver" == *"Hyper-V" ]]; then
        virtual="Hyper-V"
      else
        virtual="Microsoft Virtual Machine"
      fi
    fi
  else
    virtual="Dedicated母鸡"
  fi
}
get_system_info() {
  cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  #cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
  #freq=$(awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  #corescache=$(awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//')
  #tram=$(free -m | awk '/Mem/ {print $2}')
  #uram=$(free -m | awk '/Mem/ {print $3}')
  #bram=$(free -m | awk '/Mem/ {print $6}')
  #swap=$(free -m | awk '/Swap/ {print $2}')
  #uswap=$(free -m | awk '/Swap/ {print $3}')
  #up=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days %d hour %d min\n",a,b,c)}' /proc/uptime)
  #load=$(w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
  opsy=$(get_opsy)
  arch=$(uname -m)
  #lbit=$(getconf LONG_BIT)
  kern=$(uname -r)
  # disk_size1=$( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}' )
  # disk_size2=$( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}' )
  # disk_total_size=$( calc_disk ${disk_size1[@]} )
  # disk_used_size=$( calc_disk ${disk_size2[@]} )
  #tcpctrl=$(sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}')
  virt_check
}



#写入快捷方式
cat > /root/.bashrc <<EOF
# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi
alias quantum='bash <(curl -sL  http://jx.lim1.cn/onekey-install-liangzi.sh)'
alias lz='bash <(curl -sL  http://jx.lim1.cn/onekey-install-liangzi.sh)'
EOF

source ~/.bashrc



#判断机器是否安装docker
if test -z "$(which docker)"; then
echo -e "检测到系统未安装docker，开始安装docker"
  bash <(curl -sSL http://jx.lim1.cn/DockerInstallation.sh)
fi



copyright(){
    clear
echo -e "
—————————————————————————————————————————————————————————————
        量子助手一键安装脚本
 ${green}  
                快捷进入脚本方式：lz             
—————————————————————————————————————————————————————————————
"
}
quit(){
exit
}

install_liangzi(){

  read -p "请输入量子面板希望使用的端口号: " portinfo && printf "\n"
  read -p "请输入量子面板管理员用户名: " user && printf "\n"
  read -p "请输入量子面板管理员密码: " pwd && printf "\n"
  read -p "请输入量子面板管理员QQ: " adminqq && printf "\n"

  #拉取镜像
  echo -e  "${green}开始拉取量子镜像文件，请耐心等待${plain}"
  docker pull asupc/quantum



  #创建并启动容器
  echo -e "${green}开始创建量子容器${plain}"
  docker run --name quantum1 -v /root/quantum1/app:/app -p ${portinfo}:5088 -d asupc/quantum -restart:always

  #拉取git文件
  echo -e "${green}开始进行安装依赖文件${plain}"
  git clone https://ghproxy.com/https://github.com/asupc/quantum.git /root/quantum1/app
  mkdir -p /root/quantum1/app/config && touch /root/quantum1/app/config/Setting.xml
  baseip=$(curl -s ipip.ooo)  > /dev/null
  #配置文件
  cat > /root/quantum1/app/config/Setting.xml << EOF
<?xml version="1.0" encoding="utf-16"?>
<Setting xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <UserName>${user}</UserName>
  <PassWord>${pwd}</PassWord>
  <DBType>SQLite</DBType>
  <DBAddress>Quantum.db</DBAddress>
  <Port>5088</Port>
  <Host>http://*</Host>
  <ManagerQQ>${adminqq}</ManagerQQ>
  <CommandTimeInterval>3</CommandTimeInterval>
  <AuthInfo>9999-01-05</AuthInfo>
    <RefreshQLLoginCron>0 12 6 * * ?</RefreshQLLoginCron>
  <RefreshQLTokenCron>0 39 6 * * ?</RefreshQLTokenCron>
  <ServerPath>http://${baseip}:${portinfo}</ServerPath>
  <GitRepository>https://ghproxy.com/https://github.com/asupc/quantum-scripts.git</GitRepository>
</Setting>
EOF

#重要的一步重启容器
echo -e "${green}配置完成，重启量子容器${plain}"
docker restart quantum1
echo -e "\n"



echo -e "${green}安装完成，量子开始吞噬
—————————————————————————————————————————————————————————————
企鹅群1：994205351(已满)
企鹅群2：872628933
guyhub：https://github.com/asupc
tg频道：https://t.me/asupcqqbot
—————————————————————————————————————————————————————————————
"
echo -e "${green}面板访问地址：http://${baseip}:${portinfo}${plain}"
echo -e "${green}面板账号：${user}${plain}"
echo -e "${green}面板密码：${pwd}${plain}"
echo -e "\n"
exit 0
}

update_liangzi(){
    echo -e "${green}开始更新镜像文件${plain}"
  docker pull asupc/quantum
  echo -e "${green}开始git更新文件${plain}"
cd /root/quantum1/app
git pull
   portinfo=$(docker port quantum1 | head -1  | sed 's/ //g' | sed 's/5088\/tcp->0.0.0.0://g')
  echo -e "${green}删除旧容器${plain}"
  docker rm -f quantum1
    echo -e "${green}新建容器${plain}"
  docker run --name quantum1 -v /root/quantum1/app:/app -p ${portinfo}:5088 -d  asupc/quantum -restart:always
echo -e "${green}更新完毕，脚本自动退出。${plain}"
exit 0
}







uninstall_liangzi(){
docker rm -f quantum1
rm -rf /root/quantum1
echo -e "${green}面板已卸载，脚本自动退出，请手动删除镜像。${plain}"
exit 0
}

menu() {
  echo -e "\
${green}0.${plain} 退出脚本
${green}1.${plain} 安装量子助手
${green}2.${plain} 更新量子助手
${green}3.${plain} 卸载量子助手
"
get_system_info
echo -e "当前系统信息: ${Font_color_suffix}$opsy ${Green_font_prefix}$virtual${Font_color_suffix} $arch ${Green_font_prefix}$kern${Font_color_suffix}
"

  read -p "请输入数字 :" num
  case "$num" in
  0)
    quit
    ;;
  1)
    install_liangzi
    ;;
  2)
      update_liangzi
      ;;
  3)
    uninstall_liangzi
    ;;    
  *)
  clear
    echo -e "${Error}:请输入正确数字 [0-3]"
    sleep 5s
    menu
    ;;
  esac
}

copyright

menu

