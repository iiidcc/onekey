#/usr/bin/env bash
red='\033[0;31m'
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
#安装wget、curl、unzip
${InstallMethod} install unzip wget curl -y > /dev/null 2>&1 
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
copyright(){
    clear
echo -e "
—————————————————————————————————————————————————————————————
        Ark自助面板一键安装脚本                   
 ${green}          
                               ----v1.0
                             
        小白一路回车，拒绝花里胡哨        
—————————————————————————————————————————————————————————————
"
}
quit(){
exit
}

install_Ark(){
echo -e "${red}开始进行安装,请根据命令提示操作${plain}"
apt install git -y || yum install git -y > /dev/null
git clone https://ghproxy.com/https://github.com/NNNNolan/Ark.git /root/Ark
if [ ! -d "/root/Ark/.local-chromium/Linux-884014" ]; then
cd Ark
echo -e "${green}正在拉取chromium-browser-snapshots等依赖,体积100多M，请耐心等待下一步命令提示···${plain}"
mkdir -p  .local-chromium/Linux-884014 && cd .local-chromium/Linux-884014
wget https://mirrors.huaweicloud.com/chromium-browser-snapshots/Linux_x64/884014/chrome-linux.zip > /dev/null 2>&1 
unzip chrome-linux.zip > /dev/null 2>&1 
rm  -f chrome-linux.zip > /dev/null 2>&1 
fi
mkdir /root/Ark/Config && cd /root/Ark/Config
wget -O Config.json   https://ghproxy.com/https://raw.githubusercontent.com/Bulletgod/Arkdocker/main/Config/Config.json
read -p "请输入青龙服务器在web页面中显示的名称: " QLName && printf "\n"
read -p "请输入Ark面板标题: " title && printf "\n"
read -p "请输入Ark面板希望使用的端口号: " portinfo && printf "\n"
read -p "请输入XDD面板地址，格式如http://192.168.2.2:6666/api/login/smslogin  如不启用直接回车: " XDDurl && printf "\n"
read -p "请输入XDD面板Token（如不启用直接回车）: " XDDToken && printf "\n"
read -p "Ark是否对接青龙，输入y或者n " jdcqinglong && printf "\n"
 if [[ "$jdcqinglong" == "y" ]];then
read -p "请输入青龙OpenApi Client ID: " ClientID && printf "\n"
read -p "请输入青龙OpenApi Client Secret: " ClientSecret && printf "\n"
read -p "请输入青龙服务器的url地址（类似http://192.168.2.2:5700）: " QLurl && printf "\n"
read -p "请输入WP_APP_TOKEN: " WxPushertoken && printf "\n"
read -p "请输入WxMainWP_UID: " WxMainWP_UID && printf "\n"
cat > /root/Ark/Config/Config.json << EOF
{
  ///浏览器最多几个网页
  "MaxTab": "4",
  //网站标题
  "Title": "Ark",
  //回收时间分钟 不填默认3分钟
  "Closetime": "5",
  //不要修改
  "Captchaurl": "http://127.0.0.1:5000",
  //网站公告
  "Announcement": "为提高账户的安全性，请关闭免密支付。",
  //Proxy 支持不带密码的socks5 以及http 
  ///http  Proxy 只需要填写 ip:端口
  /// Socks5 需要填写socks5://ip:端口 不能填写下方账户密码
  "Proxy": "",
  //Proxy帐号
  "ProxyUser": "",
  //Proxy密码
  "ProxyPass": "",
  ///开启打印等待日志卡短信验证登陆 可开启 拿到日志群里回复 默认不要填写
  "Debug": "",
  ///自动滑块次数5次 5次后手动滑块 可设置为0默认手动滑块
  "AutoCaptchaCount": "5",
  ///XDD PLUS Url  http://IP地址:端口/api/login/smslogin
  "XDDurl": "",
  ///xddToken
  "XDDToken": "",
  ///登陆预警 0 0 12 * * ?  每天中午十二点 https://www.bejson.com/othertools/cron/ 表达式在线生成网址
  "ExpirationCron": " 0 0 12 * * ?",
  ///个人资产 0 0 10,20 * * ?  早十点晚上八点
  "BeanCron": "0 0 10,20 * * ?",
  // ======================================= WxPusher 通知设置区域 ===========================================
  // 此处填你申请的 appToken. 官方文档：https://wxpusher.zjiecode.com/docs
  // WP_APP_TOKEN 可在管理台查看: https://wxpusher.zjiecode.com/admin/main/app/appToken
  // MainWP_UID 填你自己uid
  ///这里的通知只用于用户登陆 删除 是给你的通知
  "WP_APP_TOKEN": "",
  "MainWP_UID": "",
  // ======================================= pushplus 通知设置区域 ===========================================
  ///Push Plus官方网站：http" //www.pushplus.plus  只有青龙模式有用
  ///下方填写您的Token，微信扫码登录后一对一推送或一对多推送下面的token，只填" "PUSH_PLUS_TOKEN",
  "PUSH_PLUS_TOKEN": "",
  //下方填写您的一对多推送的 "群组编码" ，（一对多推送下面->您的群组(如无则新建)->群组编码）
  "PUSH_PLUS_USER": "",
  ///青龙配置  注意对接XDD 对接芝士 设置为"Config":[]
  "Config": [
    {
      //序号必填从1 开始
      "QLkey": 1,
      //服务器名称
      "QLName": "阿里云",
      //青龙地址
      "QLurl": "http://ip:5700",
      //青龙2,9 OpenApi Client ID
      "QL_CLIENTID": "",
      //青龙2,9 OpenApi Client Secret
      "QL_SECRET": "",
      //CK最大数量
      "QL_CAPACITY": 99,
      ///建议一个青龙一个WxPusher 应用
      "WP_APP_TOKEN": ""
    }
  ]

}

EOF
else
cat > /root/Ark/Config/Config.json << EOF
{
  ///浏览器最多几个网页
  "MaxTab": "4",
  //网站标题
  "Title": "Ark",
  //回收时间分钟 不填默认3分钟
  "Closetime": "5",
  //网站公告
  "Announcement": "为提高账户的安全性，请关闭免密支付。",
   //Proxy 支持不带密码的socks5 以及http 
  ///http  Proxy 只需要填写 ip:端口
  /// Socks5 需要填写socks5://ip:端口 不能填写下方账户密码
  "Proxy": "",
  //Proxy帐号
  "ProxyUser": "",
  //Proxy密码
  "ProxyPass": "",
  //Opencv镜像地址  刚刚镜像的地址  ARM多一个配置 Captchaurl
  "Captchaurl": "http://xxxxx:5703",
  ///开启打印等待日志卡短信验证登陆 可开启 拿到日志群里回复 默认不要填写
  "Debug": "",
  ///自动滑块次数5次 5次后手动滑块 可设置为0默认手动滑块
  "AutoCaptchaCount": "5",
  ///XDD PLUS Url  http://IP地址:端口/api/login/smslogin
  "XDDurl": "",
  ///xddToken
  "XDDToken": "",
  ///登陆预警 0 0 12 * * ?  每天中午十二点 https://www.bejson.com/othertools/cron/ 表达式在线生成网址
  "ExpirationCron": " 0 0 12 * * ?",
  ///个人资产 0 0 10,20 * * ?  早十点晚上八点
  "BeanCron": "0 0 10,20 * * ?",
  // ======================================= WxPusher 通知设置区域 ===========================================
  // 此处填你申请的 appToken. 官方文档：https://wxpusher.zjiecode.com/docs
  // WP_APP_TOKEN 可在管理台查看: https://wxpusher.zjiecode.com/admin/main/app/appToken
  // MainWP_UID 填你自己uid
  ///这里的通知只用于用户登陆 删除 是给你的通知
  "WP_APP_TOKEN": "",
  "MainWP_UID": "",
  // ======================================= pushplus 通知设置区域 ===========================================
  ///Push Plus官方网站：http: //www.pushplus.plus  只有青龙模式有用
  ///下方填写您的Token，微信扫码登录后一对一推送或一对多推送下面的token，只填" "PUSH_PLUS_TOKEN",
  "PUSH_PLUS_TOKEN": "",
  //下方填写您的一对多推送的 "群组编码" ，（一对多推送下面->您的群组(如无则新建)->群组编码）
  "PUSH_PLUS_USER": "",
  ///青龙配置  注意对接XDD 对接芝士 设置为"Config":[]
  "Config": []

}

EOF
fi
read -p "请输入自动滑块次数 直接回车默认5次后手动滑块 输入0为默认手动滑块: " AutoCaptcha && printf "\n"
	if [ ! -n "$AutoCaptcha" ];then
    sed -i "14a \        \"AutoCaptchaCount\": \"5\"," /root/Ark/Config/Config.json
else
    sed -i "14a \        \"AutoCaptchaCount\": \"${AutoCaptcha}\"," /root/Ark/Config/Config.json
fi
read -p "请输入要安装的Ark版本，如安装最新版直接回车: " version && printf "\n"
	if [ ! -n "${version}" ];then
    version1=latest 
else
    version1=${version}
fi


#判断机器是否安装docker
if test -z "$(which docker)"; then
echo -e "检测到系统未安装docker，开始安装docker"
    curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun > /dev/null 2>&1 
    curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose && ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

#拉取Ark镜像
echo -e  "${green}开始拉取Ark镜像文件，Ark镜像比较大，请耐心等待${plain}"
docker pull nolanhzy/ark:${version1}


#创建并启动Ark容器
cd /root/Ark
echo -e "${green}开始创建Ark容器${plain}"
sudo docker run   --name ark -p ${portinfo}:80 -p 5000:5000 -d  -v  "$(pwd)":/app/Ark \
-v /etc/localtime:/etc/localtime:ro \
-it --privileged=true  nolanhzy/ark:${version1}
##docker update --restart=always Ark

baseip=$(curl -s ipip.ooo)  > /dev/null

echo -e "${green}安装完毕,面板访问地址：http://${baseip}:${portinfo}${plain}"
}

update_Ark(){
mv /root/Ark /root/Arkdb
git clone https://ghproxy.com/https://github.com/NNNNolan/Ark.git /root/Ark
cd /root/Ark &&  mkdir -p  Config &&  mv /root/Arkdb/Config.json /root/Ark/Config/Config.json
cd /root/Ark &&    mv /root/Arkdb/.local-chromium /root/Ark/.local-chromium
cd /root/Ark
portinfo=$(docker port Ark | head -1  | sed 's/ //g' | sed 's/80\/tcp->0.0.0.0://g')
condition=$(cat /root/Ark/Config/Config.json | grep -o '"XDDurl": .*' | awk -F":" '{print $1}' | sed 's/\"//g')
AutoCaptcha1=$(cat /root/Ark/Config/Config.json | grep -o '"AutoCaptchaCount": .*' | awk -F":" '{print $1}' | sed 's/\"//g')
if [ ! -n "$condition" ]; then
read -p "是否要对接XDD，输入y或者n: " XDD && printf "\n"
if [[ "$XDD" == "y" ]];then
read -p "请输入XDD面板地址，格式如http://192.168.2.2:6666/api/login/smslogin : " XDDurl && printf "\n"
read -p "请输入XDD面板Token: " XDDToken && printf "\n"
sed -i "7a \          \"XDDurl\": \"${XDDurl}\"," /root/Ark/Config/Config.json
sed -i "7a \        \"XDDToken\": \"${XDDToken}\"," /root/Ark/Config/Config.json
fi
fi

if [ ! -n "$AutoCaptcha1" ];then
	read -p "请输入自动滑块次数 直接回车默认5次后手动滑块 输入0为默认手动滑块: " AutoCaptcha && printf "\n"
	if [ ! -n "$AutoCaptcha" ];then
    sed -i "5a \        \"AutoCaptchaCount\": \"5\"," /root/Ark/Config/Config.json
else
    sed -i "5a \        \"AutoCaptchaCount\": \"${AutoCaptcha}\"," /root/Ark/Config/Config.json
fi
fi
baseip=$(curl -s ipip.ooo)  > /dev/null
docker rm -f ark
docker pull nolanhzy/ark
docker run   --name Ark -p ${portinfo}:80 -d  -v  "$(pwd)":/app \
-v /etc/localtime:/etc/localtime:ro \
-it --privileged=true  Bulletplus/Ark
docker update --restart=always Ark
echo -e "${green}Ark更新完毕，脚本自动退出。${plain}"
exit 0
}

uninstall_Ark(){
docker stop Ark
docker rm Ark
docker rmi nolanhzy/ark:${version1}
rm -rf /root/Ark
echo -e "${green}Ark面板已卸载，脚本自动退出，请手动删除Ark的镜像。${plain}"
exit 0
}

menu() {
  echo -e "\
${green}0.${plain} 退出脚本
${green}1.${plain} 安装Ark2.4
${green}2.${plain} 升级Ark2.4
${green}3.${plain} 卸载Ark
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
    install_Ark
    ;;
  2)
    update_Ark
    ;;	
  3)
    uninstall_Ark
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
