#!/bin/sh
set -e

global_box_home_path=
global_box_temp_path=
global_box_log_path=
global_box_log_file=
global_box_down_path=
ip=""
argo=""

global_cf_enabled=
global_box_version=

global_reality_enabled=
global_reality_port=
global_reality_auth_user=
global_reality_auth_password=
global_reality_tls_sni=
global_reality_tls_key_pair=
global_reality_tls_private_key=
global_reality_tls_public_key=
global_reality_tls_random=

global_hysteria2_enabled=
global_hysteria2_port=
global_hysteria2_auth_user=
global_hysteria2_auth_password=
global_hysteria2_obfs_password=
global_hysteria2_tls_sni=
global_hysteria2_tls_public_key_path=
global_hysteria2_tls_private_key_path=

global_vmess_ws_enabled=
global_vmess_ws_port=
global_vmess_ws_auth_user=
global_vmess_ws_auth_password=
global_vmess_ws_path=

global_code_failure=50
global_code_param_missing=11
global_code_param_invalid=12
global_code_no_access=41
global_code_not_found=44

readonly DEFAULT_CF_ENABLED="N"
readonly DEFAULT_BOX_VERSION="1.10.7"
readonly DEFAULT_REALITY_ENABLED="Y"
readonly DEFAULT_REALITY_PORT=5443
readonly DEFAULT_REALITY_SNI="itunes.apple.com"
readonly DEFAULT_HYSTERIA2_ENABLED="Y"
readonly DEFAULT_HYSTERIA2_PORT=6443
readonly DEFAULT_HYSTERIA2_DOMAIN="bing.com"
readonly DEFAULT_VMESS_ENABLED="Y"
readonly DEFAULT_VMESS_PORT=7443
readonly DEFAULT_VMESS_WS_PATH="/im/msg"
readonly DEFAULT_CF_VERSION="N"

print_message(){
  echo "$1"
}

delete_file(){
  org_path="$1"
  opt_desc="$2"
  #real_path=$(realpath -f "$org_path")
  real_path=$(readlink -f "$org_path")
  path_desc="$org_path"
  if [ ! "${org_path}" = "$real_path" ]; then
    path_desc="${org_path} (${real_path})"
  fi
  opt_desc="                $opt_desc -->> "

  if [ -z "$real_path" ]; then
    return 0
  fi
  # 用空格分隔的主要目录
  main_dirs="/ /bin /boot /dev /etc /home /lib /lib64 /media /mnt /opt /proc /root /run /sbin /srv /sys /tmp /usr /var"
  # 判断路径是否在主要目录中
  for dir in $main_dirs; do
    if [ "$real_path" = "$dir" ]; then
      print_message "${opt_desc}拒绝删除：${path_desc}"
      return $global_code_no_access
    fi
  done

  if [ -e "$real_path" ]; then
    print_message "${opt_desc}删除：${path_desc}"
    rm -rf "$real_path"
  fi
}

clean_up(){
  code=$1
  #delete_file "${global_box_home_path}/_temps_"
}

exit_now(){
  code=$1
  msg=$2
  clean_up $code
  exit $code
}

command_exists() {
  # command -v $1 > /dev/null 2>&1
  command -v "$@" > /dev/null 2>&1
  # return $?
}

get_internet_ip(){
  # ip=$( get_internet_ip )
  if [ -z "${ip}" ]; then
    ip=$(curl -s4m8 https://ipinfo.io/ip -k) || ip=$(curl -s6m8 https://ipinfo.io/ip -k)
  fi
  echo "$ip"
}

get_internet_argo(){
  # argo=$( get_internet_argo )
  if [ -z "${argo}" ]; then
    if [ -f "${global_box_home_path}/argo.txt.base64" ]; then
      argo=$(base64 --decode "${global_box_home_path}"/argo.txt.base64)
    fi
  fi
  echo "${argo}"
}

file_executable_add(){
  file_name="$1"
  if [ -z "$file_name" ]; then
    return $global_code_failure
  fi
  if [ -f "$file_name" ]; then
    sudo chmod +x "$file_name"
    return $?
  fi
  return $global_code_failure
}

file_download(){
  file_name="$1"
  file_url="$2"
  # curl -fsSL https://get.docker.com -o install-docker.sh | sh
  curl -fL "$file_url" -o "${global_box_down_path}/${file_name}"
  return $?
}

# 校验端口号 (1-65535)
is_port() {
  local port="$1"
  case "$port" in
      ''|*[!0-9]*) return 1 ;;  # 检查非数字字符
      *) [ "$port" -ge 80 -a "$port" -le 65535 ] ;;  # 检查范围
  esac
}

# 校验域名 (兼容常见域名格式)
is_domain() {
    echo "$1" | grep -E '^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$' >/dev/null 2>&1
}

# 校验软件版本号 (数字+点格式，如 10.2.9)
is_soft_version() {
    echo "$1" | grep -E '^[0-9]+(\.[0-9]+){2}$' >/dev/null 2>&1
}

# 校验文件路径 (绝对路径格式)
is_uri_path() {
    case "$1" in
        /*) ;;          # 必须为绝对路径
        *) return 1 ;;
    esac
    echo "$1" | grep -E '^/[a-zA-Z0-9_ ./-]*$' >/dev/null 2>&1 &&  # 基础字符校验
    ! echo "$1" | grep -q '[<>|"]'  # 排除高危字符
}

env_init() {
  print_message "正在初始化环境 ..."
  if [ "$global_box_home_path" = "" ]; then
    print_message "singbox 主目录未设置"
    exit_now $global_code_failure
  fi
  global_box_temp_path="$global_box_home_path/_temp_"
  global_box_down_path="$global_box_temp_path"
  global_box_log_path="$global_box_home_path/logs"
  global_box_log_file="$global_box_log_path/sing-box.log"

  mkdir -p "$global_box_home_path"
  mkdir -p "$global_box_temp_path"
  mkdir -p "$global_box_log_path"
}

package_jq_install(){
  # installed if no, (curl ?)
  if ! command_exists jq; then
    print_message "准备安装jq包..."
    if command_exists apt-get; then
      sudo apt-get update
      sudo apt-get -y install jq
    elif command_exists yum; then
      sudo yum check-update
      sudo yum -y install epel-release jq
    elif command_exists dnf; then
      sudo dnf check-update
      sudo dnf -y install jq
    else
      print_message "安装jq包失败！"
      exit_now $global_code_failure
    fi
    if [ $? -ne 0 ]; then
      print_message "安装jq包失败！"
      exit_now $global_code_failure
    fi
  fi
}

sing_box_daemon(){
  # Create sing-box.service
  cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target network-online.target

[Service]
# debug with more permissions
User=root
WorkingDirectory=${global_box_home_path}
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
#AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=${global_box_home_path}/sing-box run -c ${global_box_home_path}/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
  sudo systemctl enable sing-box || true
  sudo systemctl daemon-reload || true
}

find_sing_box_hone_path(){
  if [ ! -f "/etc/systemd/system/sing-box.service" ]; then
    echo ""
    return 0
  fi
  command_path=$(cat /etc/systemd/system/sing-box.service | grep "^ExecStart" | cut -d= -f2 | cut -d' ' -f1)
  if [ -z "$command_path" ]; then
    echo ""
    return 0
  fi
  resolved_path=$(readlink -f "$command_path")
  parent_path=$(dirname "$resolved_path")
  if [ -f "${parent_path}/sing-box" ]; then
    echo "$parent_path"
    return 0
  fi
  echo ""
}

sing_box_uninstall() (
  set -e
  print_message "准备卸载sing-box ..."
  # Stop and disable sing-box service
  print_message "关闭sing-box ..."
  sudo systemctl stop sing-box || true
  print_message "关闭开机自启动sing-box ..."
  sudo systemctl disable sing-box || true
  #sudo systemctl stop cloudflared-linux
  #sudo systemctl disable cloudflared-linux
  sudo systemctl daemon-reload || true

  print_message "清理垃圾 ..."
  delete_file /etc/systemd/system/sing-box.service
  #delete_file /etc/systemd/system/cloudflared-linux.service
  parent_path="${global_box_home_path}/.."
  parent_path=$(readlink -f "$parent_path")
  delete_file "${parent_path}/singbox"
  if [ -f "${global_box_home_path}/sing-box" ]; then
    print_message "卸载已完成"
  else
    print_message "未找到sing-box程序：请确认指定的安装目录是否正确 ${global_box_home_path} ..."
  fi
)

sing_box_install() {
  # https://github.com/SagerNet/sing-box/releases/download/v1.11.0-alpha.6/sing-box-1.11.0-alpha.6-linux-amd64.tar.gz
  # https://github.com/SagerNet/sing-box/releases/download/v1.10.7/sing-box-1.10.7-linux-amd64.tar.gz
  arch=$(uname -m)
  case ${arch} in
    x86_64)
      arch="amd64"
      ;;
    aarch64)
      arch="arm64"
      ;;
    armv7l)
      arch="armv7"
      ;;
  esac
  version="$global_box_version"
  package_name="sing-box-${version}-linux-${arch}"
  down_url="https://github.com/SagerNet/sing-box/releases/download/v${version}/${package_name}.tar.gz"
  print_message "准备下载 sing-box：$down_url"
  print_message "下载 sing-box：${global_box_down_path}/${package_name}.tar.gz"
  if [ -f "${global_box_down_path}/${package_name}.tar.gz" ]; then
    print_message "安装包已存在，跳过下载：sing-box=${version}"
  else
    file_download "${package_name}.tar.gz" "$down_url"
    if [ $? -ne 0 ]; then
      print_message "下载失败 sing-box=${version}：请确认版本是否正确，或者网络是否连通。"
      exit_now $global_code_failure
    fi
  fi

  tar -xzf "${global_box_down_path}/${package_name}.tar.gz" -C "${global_box_down_path}"
  mv "${global_box_down_path}/${package_name}/sing-box" "${global_box_home_path}"

  # Set the permissions
  chown root:root "${global_box_home_path}/sing-box"
  chmod +x "${global_box_home_path}/sing-box"

  # todo
  delete_file "${global_box_down_path}/${package_name}"
  #delete_file "${global_box_down_path}/${package_name}.tar.gz"

  sing_box_config_init
  sing_box_config_save
  sing_box_daemon

  print_message "安装完成【sing-box】：${global_box_home_path}"
}

sing_box_config_init() {
  if [ "$global_reality_enabled" = "Y" ]; then
    print_message "正在生成 Reality协议 配置参数 ..."
    global_reality_tls_key_pair=$("${global_box_home_path}"/sing-box generate reality-keypair)
    global_reality_tls_private_key=$(echo "$global_reality_tls_key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
    global_reality_tls_public_key=$(echo "$global_reality_tls_key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
    echo "$global_reality_tls_private_key" | base64 > "${global_box_home_path}"/reality.private.key.base64
    echo "$global_reality_tls_public_key" | base64 > "${global_box_home_path}"/reality.public.key.base64
    global_reality_auth_password=$("${global_box_home_path}"/sing-box generate uuid)
    global_reality_tls_random=$("${global_box_home_path}"/sing-box generate rand --hex 8)
  fi

  if [ "$global_hysteria2_enabled" = "Y" ]; then
    print_message "正在生成 Hysteria2协议 配置参数 ..."
    global_hysteria2_auth_password=$("${global_box_home_path}"/sing-box generate rand --hex 8)
    global_hysteria2_obfs_password=$("${global_box_home_path}"/sing-box generate rand --hex 8)
    global_hysteria2_tls_public_key_path="${global_box_home_path}/hysteria2.public.key"
    global_hysteria2_tls_private_key_path="${global_box_home_path}/hysteria2.private.key"
    touch /root/.rnd
    chmod 600 /root/.rnd
    chown root:root /root/.rnd
    openssl ecparam -genkey -name prime256v1 -out "${global_hysteria2_tls_private_key_path}"
    openssl req -new -x509 -days 3650 -key "${global_hysteria2_tls_private_key_path}" -out "${global_box_home_path}/hysteria2.public.key" -subj "/CN=${global_hysteria2_tls_sni}"
  fi

  if [ "$global_vmess_ws_enabled" = "Y" ]; then
    print_message "正在生成 Vmess协议 配置参数 ..."
    global_vmess_ws_auth_password=$("${global_box_home_path}"/sing-box generate uuid)
  fi
}

sing_box_config_load() {
  if [ ! -f "${global_box_home_path}/config.json" ]; then
    print_message "未找相关配置：请确定指定正确的安装目录 ..."
    exit_now $global_code_failure
  fi
  print_message "正在加载配置 ..."
  ip=$( get_internet_ip )
  inbounds_count=$(jq -r '.inbounds | length' "${global_box_home_path}"/config.json)
  i=0
  while [ $i -lt $inbounds_count ]; do
  #for ((i=0; i<inbounds_count; i++)); do
    tag=$(jq -r ".inbounds[${i}].tag" "${global_box_home_path}"/config.json)
    if [ "$tag" = "reality-in" ]; then
      global_reality_port=$(jq -r ".inbounds[${i}].listen_port" "${global_box_home_path}"/config.json)
      global_reality_tls_sni=$(jq -r ".inbounds[${i}].tls.server_name" "${global_box_home_path}"/config.json)
      global_reality_tls_public_key=$(base64 --decode "${global_box_home_path}"/reality.public.key.base64)
      global_reality_auth_password=$(jq -r ".inbounds[${i}].users[0].uuid" "${global_box_home_path}"/config.json)
      global_reality_tls_random=$(jq -r ".inbounds[${i}].tls.reality.short_id[0]" "${global_box_home_path}"/config.json)

    elif [ "$tag" = "hysteria2-in" ]; then
      global_hysteria2_port=$(jq -r ".inbounds[${i}].listen_port" "${global_box_home_path}"/config.json)
      global_hysteria2_tls_sni=$(openssl x509 -in "${global_box_home_path}"/hysteria2.public.key -noout -subject -nameopt RFC2253 | awk -F'=' '{print $NF}')
      global_hysteria2_auth_password=$(jq -r ".inbounds[${i}].users[0].password" "${global_box_home_path}"/config.json)
      global_hysteria2_obfs_type=$(jq -r ".inbounds[${i}].obfs.type" "${global_box_home_path}"/config.json)
      if [ -n "$global_hysteria2_obfs_type" ]; then
        global_hysteria2_obfs_enabled=enabled
        global_hysteria2_obfs_password=$(jq -r ".inbounds[${i}].obfs.password" "${global_box_home_path}"/config.json)
      fi
      global_hysteria2_tls_public_key_path="${global_box_home_path}/hysteria2.public.key"
      global_hysteria2_tls_private_key_path="${global_box_home_path}/hysteria2.private.key"

    elif [ "$tag" = "vmess-ws-in" ]; then
      global_vmess_ws_port=$(jq -r ".inbounds[${i}].listen_port" "${global_box_home_path}"/config.json)
      global_vmess_ws_auth_password=$(jq -r ".inbounds[${i}].users[0].uuid" "${global_box_home_path}"/config.json)
      global_vmess_ws_path=$(jq -r ".inbounds[${i}].transport.path" "${global_box_home_path}"/config.json)
      argo=$( get_internet_argo )
      if [ -z "${argo}" ]; then
        argo=$( get_internet_ip )
      else
        global_vmess_ws_port=443
      fi
    else
      echo_decorate "无法识别的客户端连接信息"
      exit_now 1
    fi
    i=$((i + 1))
  done
}

sing_box_config_save() {
  print_message "正在保存配置：${global_box_home_path}/config.json"
  inbounds_str=""
  if [ "$global_reality_enabled" = "Y" ]; then
    inbounds_str=$(cat <<EOF
${inbounds_str}{
			"tag": "reality-in",
			"type": "vless",
			"listen": "::",
			"listen_port": ${global_reality_port},
			"domain_strategy": "prefer_ipv4",
			"users": [{
				"uuid": "${global_reality_auth_password}",
				"flow": "xtls-rprx-vision"
			}],
			"tls": {
				"enabled": true,
				"server_name": "${global_reality_tls_sni}",
				"reality": {
					"enabled": true,
					"handshake": {
						"server": "${global_reality_tls_sni}",
						"server_port": 443
					},
					"private_key": "${global_reality_tls_private_key}",
					"short_id": [
						"${global_reality_tls_random}"
					]
				}
			}
		}
EOF
)
  fi

  if [ "$global_hysteria2_enabled" = "Y" ]; then
    if [ -n "$inbounds_str" ]; then
      inbounds_str="${inbounds_str}, "
    fi
    inbounds_str=$(cat <<EOF
${inbounds_str}{
			"tag": "hysteria2-in",
			"type": "hysteria2",
			"listen": "::",
			"listen_port": ${global_hysteria2_port},
			"domain_strategy": "prefer_ipv4",
			"obfs": {
				"type": "salamander",
				"password": "${global_hysteria2_obfs_password}"
			},
			"users": [{
				"password": "${global_hysteria2_auth_password}"
			}],
			"tls": {
				"enabled": true,
				"server_name": "${global_hysteria2_tls_sni}",
				"certificate_path": "${global_hysteria2_tls_public_key_path}",
				"key_path": "${global_hysteria2_tls_private_key_path}",
				"alpn": [
					"h3"
				]
			}
		}
EOF
)
  fi

  if [ "$global_vmess_ws_enabled" = "Y" ]; then
    if [ -n "$inbounds_str" ]; then
      inbounds_str="${inbounds_str}, "
    fi
    inbounds_str=$(cat <<EOF
${inbounds_str}{
			"tag": "vmess-ws-in",
			"type": "vmess",
			"listen": "::",
			"listen_port": ${global_vmess_ws_port},
			"domain_strategy": "prefer_ipv4",
			"users": [{
				"uuid": "${global_vmess_ws_auth_password}",
				"alterId": 0
			}],
			"transport": {
				"type": "ws",
				"path": "${global_vmess_ws_path}",
				"headers": {}
			}
		}
EOF
)
  fi

  #inbounds_str="[${inbounds_str}]"
  cat << EOF > "${global_box_home_path}"/config.json
{
	"log": {
		"disabled": false,
		"level": "info",
		"output": "${global_box_log_file}",
		"timestamp": true
	},
	"dns": {
		"strategy": "prefer_ipv4",
		"final": "us-dns",
		"servers": [
			{
				"tag": "us-dns",
				"address": "https://cloudflare-dns.com/dns-query",
				"address_resolver": "default-dns",
				"detour": "us-out"
			},{
				"tag": "default-dns",
				"address": "https://1.1.1.1/dns-query",
				"detour": "us-out"
			},{
				"tag": "block-dns",
				"address": "rcode://refused"
			}
		],
		"rules": [
			{
				"outbound": "any",
				"server": "default-dns"
			}
		]
	},
	"inbounds": [
		${inbounds_str}
	],
	"outbounds": [
		{
			"tag": "dns-out",
			"type": "dns"
		}, {
			"tag": "us-out",
			"type": "direct"
		}, {
			"tag": "cn-out",
			"type": "block"
		}, {
			"tag": "block-out",
			"type": "block"
		}
	],
	"route": {
		"auto_detect_interface": true,
		"final": "us-out",
		"rules": [
			{
				"protocol": "dns",
				"outbound": "dns-out"
			},{
				"rule_set": [
					"geoip-block"
				],
				"outbound": "block-out"
			},{
				"rule_set": [
					"geosite-block"
				],
				"outbound": "block-out"
			},{
				"rule_set": [
					"geoip-proxy-3rd",
					"geoip-proxy-custom"
				],
				"outbound": "us-out"
			},{
				"rule_set": [
					"geosite-proxy-3rd",
					"geosite-proxy-custom"
				],
				"outbound": "us-out"
			},{
				"rule_set": [
					"geoip-cn-3rd",
					"geoip-cn-custom"
				],
				"outbound": "cn-out"
			},{
				"rule_set": [
					"geosite-cn-3rd",
					"geosite-cn-custom"
				],
				"outbound": "cn-out"
			}
		],
		"rule_set": [
			{
				"tag": "geoip-block",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geoip-block.json",
				"update_interval": "1d",
				"download_detour": "us-out"
			},{
				"tag": "geoip-cn-3rd",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geoip-cn-3rd.json",
				"update_interval": "1d",
				"download_detour": "us-out"
			},{
				"tag": "geoip-cn-custom",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geoip-cn-custom.json",
				"update_interval": "1d",
				"download_detour": "us-out"
			},{
				"tag": "geoip-proxy-3rd",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geoip-proxy-3rd.json",
				"update_interval": "1d",
				"download_detour": "us-out"
			},{
				"tag": "geoip-proxy-custom",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geoip-proxy-custom.json",
				"update_interval": "1d",
				"download_detour": "us-out"
			},{
				"tag": "geosite-block",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geosite-block.json",
				"update_interval": "1d",
				"download_detour": "us-out"
			},{
				"tag": "geosite-cn-3rd",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geosite-cn-3rd.json",
				"update_interval": "1d",
				"download_detour": "us-out"
			},{
				"tag": "geosite-cn-custom",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geosite-cn-custom.json",
				"update_interval": "1d",
				"download_detour": "us-out"
			},{
				"tag": "geosite-proxy-3rd",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geosite-proxy-3rd.json",
				"update_interval": "1d",
				"download_detour": "us-out"
			},{
				"tag": "geosite-proxy-custom",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geosite-proxy-custom.json",
				"update_interval": "1d",
				"download_detour": "us-out"
			}
		]
	},
	"experimental": {
		"cache_file": {
			"enabled": true
		}
	}
}
EOF
# sing_box_config_save---------------end--
}

sing_box_config_show_box() {
  print_message "+-----------------------------------------------------------------------------+"
  print_message "| sing-box客户端配置参数：                                                    |"
  print_message "+-----------------------------------------------------------------------------+"
    cat << EOF
{
	"log": {
		"disabled": false,
		"level": "info",
		"timestamp": true
	},
	"dns": {
		"strategy": "ipv4_only",
		"final": "block-dns",
		"servers": [
			{
				"tag": "proxy-dns",
				"address": "https://cloudflare-dns.com/dns-query",
				"address_resolver": "default-dns",
				"detour": "proxy-out"
			},{
				"tag": "fakeip-dns",
				"address": "fakeip"
			},{
				"tag": "direct-dns",
				"address": "https://dns.alidns.com/dns-query",
				"address_resolver": "default-dns",
				"detour": "direct-out"
			},{
				"tag": "default-dns",
				"address": "https://223.5.5.5/dns-query",
				"detour": "direct-out"
			},{
				"tag": "block-dns",
				"address": "rcode://refused"
			}
		],
		"rules": [
			{
				"outbound": "any",
				"server": "default-dns"
			},{
				"clash_mode": "Global",
				"rewrite_ttl": 1,
				"server": "fakeip-dns"
			},{
				"clash_mode": "Direct",
				"server": "direct-dns"
			},{
				"rule_set": [
					"geosite-proxy-3rd",
					"geosite-proxy-custom"
				],
				"rewrite_ttl": 1,
				"server": "fakeip-dns"
			},{
				"rule_set": [
					"geosite-cn-3rd",
					"geosite-cn-custom"
				],
				"invert": false,
				"server": "direct-dns"
			},{
				"query_type": [
					"A",
					"AAAA"
				],
				"rewrite_ttl": 1,
				"server": "fakeip-dns"
			}
		],
		"fakeip": {
			"enabled": true,
			"inet4_range": "198.18.0.0/15",
			"inet6_range": "fc00::/18"
		},
		"independent_cache": true
	},
	"inbounds": [
		{
			"tag": "tun-in",
			"type": "tun",
			"interface_name": "boxtun0",
			"address": [
				"172.19.0.1/30",
				"fdfe:dcba:6789::1/126"
			],
			"auto_route": true,
			"strict_route": true,
			"route_address": [
				"0.0.0.0/1",
				"128.0.0.0/1",
				"::/1",
				"8000::/1"
			],
			"mtu": 1400,
			"stack": "mixed",
			"sniff": false,
			"sniff_override_destination": false,
			"platform": {
				"http_proxy": {
					"enabled": false,
					"server": "127.0.0.1",
					"server_port": 1080
				}
			}
		}
	],
	"outbounds": [
		{
			"tag": "reality-out",
			"type": "vless",
			"server": "${ip}",
			"server_port": ${global_reality_port},
			"uuid": "${global_reality_auth_password}",
			"flow": "xtls-rprx-vision",
			"packet_encoding": "xudp",
			"tls": {
				"enabled": true,
				"server_name": "${global_reality_tls_sni}",
				"utls": {
					"enabled": true,
					"fingerprint": "chrome"
				},
				"reality": {
					"enabled": true,
					"public_key": "${global_reality_tls_public_key}",
					"short_id": "${global_reality_tls_random}"
				}
			}
		},{
			"tag": "hysteria2-out",
			"type": "hysteria2",
			"server": "$ip",
			"server_port": ${global_hysteria2_port},
			"up_mbps": 100,
			"down_mbps": 100,
			"password": "${global_hysteria2_auth_password}",
			"obfs": {
				"type": "salamander",
				"password": "${global_hysteria2_obfs_password}"
			},
			"tls": {
				"enabled": true,
				"server_name": "${global_hysteria2_tls_sni}",
				"insecure": true,
				"alpn": [
					"h3"
				]
			}
		},{
			"tag": "vmess-ws-out",
			"type": "vmess",
			"server": "$argo",
			"server_port": ${global_vmess_ws_port},
			"uuid": "${global_vmess_ws_auth_password}",
			"alter_id": 0,
			"security": "auto",
			"tls": {
				"enabled": true,
				"server_name": "$argo",
				"insecure": true,
				"utls": {
					"enabled": true,
					"fingerprint": "chrome"
				}
			},
			"transport": {
				"type": "ws",
				"path": "${global_vmess_ws_path}",
				"headers": {
					"Host": ["$argo"]
				}
			}
		},{
			"tag": "urltest-out",
			"type": "urltest",
			"interrupt_exist_connections": true,
			"outbounds": [
				"reality-out",
				"hysteria2-out",
				"vmess-ws-out"
			]
		},{
			"tag": "proxy-out",
			"type": "selector",
			"interrupt_exist_connections": true,
			"outbounds": [
				"urltest-out",
				"reality-out",
				"hysteria2-out",
				"vmess-ws-out"
			],
			"default": "urltest-out"
		},{
			"tag": "download-out",
			"type": "selector",
			"interrupt_exist_connections": true,
			"outbounds": [
				"urltest-out"
			],
			"default": "urltest-out"
		},{
			"tag": "dns-out",
			"type": "dns"
		}, {
			"tag": "direct-out",
			"type": "direct"
		}, {
			"tag": "block-out",
			"type": "block"
		}
	],
	"route": {
		"auto_detect_interface": true,
		"final": "block-out",
		"rules": [
			{
				"type": "logical",
				"mode": "or",
				"rules": [
					{
						"protocol": "dns"
					},{
						"port": 53
					}
				],
				"outbound": "dns-out"
			},{
				"ip_version": 6,
				"outbound": "block-out"
			},{
				"clash_mode": "Global",
				"outbound": "proxy-out"
			},{
				"clash_mode": "Direct",
				"outbound": "direct-out"
			},{
				"type": "logical",
				"mode": "or",
				"rules": [
					{
						"port": 853
					},{
						"network": "udp",
						"port": 443
					},{
						"protocol": "stun"
					}
				],
				"outbound": "block-out"
			},{
				"rule_set": [
					"geo-lan"
				],
				"outbound": "direct-out"
			},{
				"rule_set": [
					"geoip-block"
				],
				"outbound": "block-out"
			},{
				"rule_set": [
					"geosite-block"
				],
				"outbound": "block-out"
			},{
				"ip_cidr": [
					"${ip}/32"
				],
				"outbound": "direct-out"
			},{
				"domain_suffix": [
					"others.urls"
				],
				"ip_cidr": [
					"5.6.7.8/32"
				],
				"outbound": "proxy-out"
			},{
				"rule_set": [
					"geoip-proxy-3rd",
					"geoip-proxy-custom"
				],
				"outbound": "proxy-out"
			},{
				"rule_set": [
					"geosite-proxy-3rd",
					"geosite-proxy-custom"
				],
				"outbound": "proxy-out"
			},{
				"rule_set": [
					"geoip-cn-3rd",
					"geoip-cn-custom"
				],
				"outbound": "direct-out"
			},{
				"rule_set": [
					"geosite-cn-3rd",
					"geosite-cn-custom"
				],
				"outbound": "direct-out"
			}
		],
		"rule_set": [
			{
				"tag": "geoip-block",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geoip-block.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			},{
				"tag": "geoip-cn-3rd",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geoip-cn-3rd.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			},{
				"tag": "geoip-cn-custom",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geoip-cn-custom.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			},{
				"tag": "geoip-proxy-3rd",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geoip-proxy-3rd.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			},{
				"tag": "geoip-proxy-custom",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geoip-proxy-custom.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			},{
				"tag": "geosite-block",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geosite-block.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			},{
				"tag": "geosite-cn-3rd",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geosite-cn-3rd.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			},{
				"tag": "geosite-cn-custom",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geosite-cn-custom.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			},{
				"tag": "geosite-proxy-3rd",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geosite-proxy-3rd.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			},{
				"tag": "geosite-proxy-custom",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geosite-proxy-custom.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			},{
				"tag": "geo-lan",
				"type": "remote",
				"format": "source",
				"url": "https://raw.githubusercontent.com/leo3587168/share-files/master/sbox/rules/geo-lan.json",
				"update_interval": "1d",
				"download_detour": "download-out"
			}
		]
	},
	"experimental": {
		"clash_api": {
			"external_controller": "",
			"default_mode": "Rule"
		},
		"cache_file": {
			"enabled": true
		}
	}
}
EOF
# sing_box_config_show_box ----------------end
}
sing_box_config_show_clash() {
  print_message "+-----------------------------------------------------------------------------+"
  print_message "| clash-meta配置参数：                                                        |"
  print_message "+-----------------------------------------------------------------------------+"
  # clash 域名通配符规则
  # 【*】：一次只能匹配一级域名
  # 【+】：类似 DOMAIN-SUFFIX, 可以一次性匹配多个级别，只能用于域名前缀匹配，＋.baidu.com 匹配 tieba.baidu.com 和 123.tieba.baidu.com 或者 baidu.com
  # 【.】：可以一次性匹配多个级别，只能用于域名前缀匹配，.baidu.com 匹配 tieba.baidu.com 和 123.tieba.baidu.com, 但不能匹配 baidu.com
  cat << EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
global-client-fingerprint: chrome
ipv6: false

tun:
  enable: true
  stack: mixed
  auto-route: true
  strict-route: true
  dns-hijack:
    - any:53
  auto-detect-interface: true

dns:
  enable: true
  listen: :53
  ipv6: false
  enhanced-mode: fake-ip
  #fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - '*.not-fakeip-domain'
  # 解析其他DNS里的包含的域名，必须是IP
  default-nameserver:
    - https://1.1.1.1/dns-query
  # 代理节点域名解析服务器，仅用于解析代理节点的域名
  proxy-server-nameserver:
    - https://223.5.5.5/dns-query
  nameserver:
    - localhost
    - 127.0.0.1
  direct-nameserver:
    - https://223.5.5.5/dns-query

  #enhanced-mode: redir-host
  #nameserver:
  #  - https://223.5.5.5/dns-query
  #fallback:
  #  - https://1.1.1.1/dns-query
  #fallback-filter:
  #  geoip: true
  #  geoip-code: CN
  #  ipcidr:
  #    - 240.0.0.0/4

sniffer:
  enable: false
  override-destination: false
  force-dns-mapping: false
  parse-pure-ip: false

rule-providers:
  geoip-block:
    type: http
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/leo3587168/share-files/master/clash/rules/geoip-block.txt"
    path: ./ruleset/geoip-block.yaml
    interval: 86400
  geoip-cn-3rd:
    type: http
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/leo3587168/share-files/master/clash/rules/geoip-cn-3rd.txt"
    path: ./ruleset/geoip-cn-3rd.yaml
    interval: 86400
  geoip-cn-custom:
    type: http
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/leo3587168/share-files/master/clash/rules/geoip-cn-custom.txt"
    path: ./ruleset/geoip-cn-custom.yaml
    interval: 86400
  geoip-proxy-3rd:
    type: http
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/leo3587168/share-files/master/clash/rules/geoip-proxy-3rd.txt"
    path: ./ruleset/geoip-proxy-3rd.yaml
    interval: 86400
  geoip-proxy-custom:
    type: http
    behavior: ipcidr
    url: "https://raw.githubusercontent.com/leo3587168/share-files/master/clash/rules/geoip-proxy-custom.txt"
    path: ./ruleset/geoip-proxy-custom.yaml
    interval: 86400
  geosite-block:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/leo3587168/share-files/master/clash/rules/geosite-block.txt"
    path: ./ruleset/geosite-block.yaml
    interval: 86400
  geosite-cn-3rd:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/leo3587168/share-files/master/clash/rules/geosite-cn-3rd.txt"
    path: ./ruleset/geosite-cn-3rd.yaml
    interval: 86400
  geosite-cn-custom:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/leo3587168/share-files/master/clash/rules/geosite-cn-custom.txt"
    path: ./ruleset/geosite-cn-custom.yaml
    interval: 86400
  geosite-proxy-3rd:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/leo3587168/share-files/master/clash/rules/geosite-proxy-3rd.txt"
    path: ./ruleset/geosite-proxy-3rd.yaml
    interval: 86400
  geosite-proxy-custom:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/leo3587168/share-files/master/clash/rules/geosite-proxy-custom.txt"
    path: ./ruleset/geosite-proxy-custom.yaml
    interval: 86400

proxies:
  - name: Reality
    type: vless
    server: $ip
    port: $global_reality_port
    uuid: $global_reality_auth_password
    network: tcp
    udp: true
    tls: true
    flow: xtls-rprx-vision
    servername: $global_reality_tls_sni
    client-fingerprint: chrome
    reality-opts:
      public-key: $global_reality_tls_public_key
      short-id: $global_reality_tls_random

  - name: Hysteria2
    type: hysteria2
    server: $ip
    port: $global_hysteria2_port
    # up和down均不写或为0则使用BBR流控
    # up: "30 Mbps" # 若不写单位，默认为 Mbps
    # down: "200 Mbps" # 若不写单位，默认为 Mbps
    password: $global_hysteria2_auth_password
    obfs: ${global_hysteria2_obfs_type}
    obfs-password: ${global_hysteria2_obfs_password}
    sni: $global_hysteria2_tls_sni
    skip-cert-verify: true
    alpn:
      - h3

  - name: Vmess
    type: vmess
    server: ${argo}
    port: ${global_vmess_ws_port}
    uuid: $global_vmess_ws_auth_password
    alterId: 0
    cipher: auto
    udp: true
    tls: true
    client-fingerprint: chrome
    skip-cert-verify: true
    #servername: ${argo}
    network: ws
    ws-opts:
      path: $global_vmess_ws_path
      #headers:
      #  Host: ${argo}

proxy-groups:
  - name: 节点选择
    type: select
    proxies:
      - 自动选择
      - Reality
      - Hysteria2
      - Vmess

  - name: 自动选择
    type: url-test #选出延迟最低的机场节点
    proxies:
      - Reality
      - Hysteria2
      - Vmess
    url: "http://www.gstatic.com/generate_204"
    interval: 300
    tolerance: 50

rules:
  - IP-CIDR,${ip}/32,DIRECT

  - RULE-SET,geoip-block,REJECT
  - RULE-SET,geosite-block,REJECT
  - RULE-SET,geoip-proxy-3rd,节点选择
  - RULE-SET,geoip-proxy-custom,节点选择
  - RULE-SET,geosite-proxy-3rd,节点选择
  - RULE-SET,geosite-proxy-custom,节点选择
  - RULE-SET,geoip-cn-3rd,DIRECT
  - RULE-SET,geoip-cn-custom,DIRECT
  - RULE-SET,geosite-cn-3rd,DIRECT
  - RULE-SET,geosite-cn-custom,DIRECT

  #- GEOIP,LAN,DIRECT
  #- GEOIP,CN,DIRECT
  #- MATCH,节点选择
  - MATCH,REJECT
EOF
# sing_box_config_show_clash-------------end
}

sing_box_config_show_base() {
  print_message "+-----------------------------------------------------------------------------+"
  print_message "| Reality 客户端连接配置：                                                    |"
  print_message "+-----------------------------------------------------------------------------+"
  print_message "vless://$global_reality_auth_password@$ip:$global_reality_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$global_reality_tls_sni&fp=chrome&pbk=$global_reality_tls_public_key&sid=$global_reality_tls_random&type=tcp&headerType=none#singbox-reality-${ip##*.}"
  print_message ""

  print_message "+-----------------------------------------------------------------------------+"
  print_message "| Hysteria2 客户端连接配置：                                                  |"
  print_message "+-----------------------------------------------------------------------------+"
  print_message  "hysteria2://$global_hysteria2_auth_password@$ip:$global_hysteria2_port?&obfs=${global_hysteria2_obfs_type}&obfs-password=${global_hysteria2_obfs_password}&insecure=1&sni=$global_hysteria2_tls_sni#singbox-hy2-${ip##*.}"
  print_message ""

  print_message "+-----------------------------------------------------------------------------+"
  print_message "| VMess Websocket 客户端连接配置（需额外手工搭配前置Https服务，比如NGinx）：  |"
  print_message "+-----------------------------------------------------------------------------+"
  #print_message 'vmess://'$(echo '{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$global_vmess_ws_auth_password'","net":"ws","path":"'$ws_path'","port":"443","ps":"sing-box-vmess-tls","tls":"tls","type":"none","v":"2"}' | base64 -w 0)
  # 端口 443 可改为 2053 2083 2087 2096 8443
  #{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$global_vmess_uuid'","net":"ws","path":"'$ws_path'","port":"443","ps":"sing-box-vmess-tls","tls":"tls","type":"none","v":"2"}
  # 端口 80 可改为 8080 8880 2052 2082 2086 2095
  #{"add":"speed.cloudflare.com","aid":"0","host":"'$argo'","id":"'$global_vmess_uuid'","net":"ws","path":"'$ws_path'","port":"80","ps":"sing-box-vmess","tls":"","type":"none","v":"2"}
  print_message 'vmess://'$(echo '{"add":"'$argo'","aid":"0","host":"'$argo'","id":"'$global_vmess_ws_auth_password'","net":"ws","path":"'$global_vmess_ws_path'","port":"'${global_vmess_ws_port}'","ps":"singbox-vmws-'${ip##*.}'","scy":"auto","tls":"tls","type":"none","v":"2"}' | base64 -w 0)
  print_message ""
}

sing_box_config_show() {
  ip=$(get_internet_ip)
  #argo=$(base64 --decode "${global_box_home_path}"/argo.txt.base64)
  argo="$ip"
  sing_box_config_show_base
  sing_box_config_show_box
  sing_box_config_show_clash
}

option_for_show_config(){
  sing_box_config_load
  sing_box_config_show
}

option_for_uninstall(){
  sing_box_uninstall
}

option_for_install(){
  while true; do
    if [ "$global_box_version" = "" ]; then
      printf "输入你要安装的 sing-box 版本号（默认：${DEFAULT_BOX_VERSION}；最新版本：latest），请输入："
      read -r text
      echo "w${text}w"
      if [ -z "$text" ]; then
        global_box_version="${DEFAULT_BOX_VERSION}"
        continue
      elif is_soft_version $text; then
        global_box_version="$text"
        continue
      else
        continue
      fi
    fi

    if [ "$global_reality_enabled" = "" ]; then
      printf "是否开启 Reality 协议【默认=${DEFAULT_REALITY_ENABLED}；Y=是，N=否】，请输入【Y/N】："
      read -r text
      if [ "$text" = "" ]; then
        global_reality_enabled=${DEFAULT_REALITY_ENABLED}
        continue
      elif [ "$text" = "Y" -o "$text" = "y" ]; then
        global_reality_enabled="Y"
        continue
      elif [ "$text" = "N" -o "$text" = "n" ]; then
        global_reality_enabled="N"
        continue
      else
        continue
      fi
    fi

    if [ "$global_reality_port" = "" ]; then
      printf "设置 Reality协议 端口号（默认：${DEFAULT_REALITY_PORT}），请输入【80~65535】："
      read -r text
      if [ -z "$text" ]; then
        global_reality_port="${DEFAULT_REALITY_PORT}"
        continue
      elif is_port $text; then
        global_reality_port="$text"
        continue
      else
        continue
      fi
    fi

    if [ "$global_reality_tls_sni" = "" ]; then
      printf "设置 Reality协议 伪装域名（默认：${DEFAULT_REALITY_SNI}），请输入："
      read -r text
      if [ -z "$text" ]; then
        global_reality_tls_sni="${DEFAULT_REALITY_SNI}"
        continue
      elif is_domain $text; then
        global_reality_tls_sni="$text"
        continue
      else
        continue
      fi
    fi

    if [ "$global_hysteria2_enabled" = "" ]; then
      printf "是否开启 Hysteria2 协议【默认=${DEFAULT_HYSTERIA2_ENABLED}；Y=是，N=否】，请输入【Y/N】："
      read -r text
      if [ "$text" = "" ]; then
        global_hysteria2_enabled=${DEFAULT_HYSTERIA2_ENABLED}
        continue
      elif [ "$text" = "Y" -o "$text" = "y" ]; then
        global_hysteria2_enabled="Y"
        continue
      elif [ "$text" = "N" -o "$text" = "n" ]; then
        global_hysteria2_enabled="N"
        continue
      else
        continue
      fi
    fi

    if [ "$global_hysteria2_port" = "" ]; then
      printf "设置 Hysteria2协议 端口号（默认：${DEFAULT_HYSTERIA2_PORT}），请输入【80~65535】："
      read -r text
      if [ -z "$text" ]; then
        global_hysteria2_port="${DEFAULT_HYSTERIA2_PORT}"
        continue
      elif is_port $text; then
        global_hysteria2_port="$text"
        continue
      else
        continue
      fi
    fi

    if [ "$global_hysteria2_tls_sni" = "" ]; then
      printf "设置 Hysteria2协议 自签证书域名（默认：${DEFAULT_HYSTERIA2_DOMAIN}），请输入："
      read -r text
      if [ -z "$text" ]; then
        global_hysteria2_tls_sni="${DEFAULT_HYSTERIA2_DOMAIN}"
        continue
      elif is_domain $text; then
        global_hysteria2_tls_sni="$text"
        continue
      else
        continue
      fi
    fi

    if [ "$global_vmess_ws_enabled" = "" ]; then
      printf "是否开启 VMess(Websocket) 协议【默认=${DEFAULT_VMESS_ENABLED}；Y=是，N=否】，请输入【Y/N】："
      read -r text
      if [ "$text" = "" ]; then
        global_vmess_ws_enabled=${DEFAULT_VMESS_ENABLED}
        continue
      elif [ "$text" = "Y" -o "$text" = "y" ]; then
        global_vmess_ws_enabled="Y"
        continue
      elif [ "$text" = "N" -o "$text" = "n" ]; then
        global_vmess_ws_enabled="N"
        continue
      else
        continue
      fi
    fi

    if [ "$global_vmess_ws_port" = "" ]; then
      printf "设置 VMess协议 端口号（默认：${DEFAULT_VMESS_PORT}），请输入【80~65535】："
      read -r text
      if [ -z "$text" ]; then
        global_vmess_ws_port="${DEFAULT_VMESS_PORT}"
        continue
      elif is_port $text; then
        global_vmess_ws_port="$text"
        continue
      else
        continue
      fi
    fi

    if [ "$global_vmess_ws_path" = "" ]; then
      printf "设置 VMess协议 websocket路径（默认：${DEFAULT_VMESS_WS_PATH}），请输入："
      read -r text
      if [ -z "$text" ]; then
        global_vmess_ws_path="${DEFAULT_VMESS_WS_PATH}"
        continue
      elif is_uri_path $text; then
        global_vmess_ws_path="$text"
        continue
      else
        continue
      fi
    fi

    break
  done

  if [ "$global_reality_enabled" = "Y" -o "$global_hysteria2_enabled" = "Y" -o "$global_vmess_ws_enabled" = "Y" ]; then
    sing_box_install
    sudo systemctl restart sing-box
  else
    return 1
  fi
}

params_unset_padding_default(){
  if [ -z "$global_box_version" ]; then
    global_box_version="${DEFAULT_BOX_VERSION}"
  fi
  if [ -z "$global_reality_enabled" ]; then
    global_reality_enabled="${DEFAULT_REALITY_ENABLED}"
  fi
  if [ -z "$global_reality_port" ]; then
    global_reality_port="${DEFAULT_REALITY_PORT}"
  fi
  if [ -z "$global_reality_tls_sni" ]; then
    global_reality_tls_sni="${DEFAULT_REALITY_SNI}"
  fi
  if [ -z "$global_hysteria2_enabled" ]; then
    global_hysteria2_enabled="${DEFAULT_HYSTERIA2_ENABLED}"
  fi
  if [ -z "$global_hysteria2_port" ]; then
    global_hysteria2_port="${DEFAULT_HYSTERIA2_PORT}"
  fi
  if [ -z "$global_hysteria2_tls_sni" ]; then
    global_hysteria2_tls_sni="${DEFAULT_HYSTERIA2_DOMAIN}"
  fi
  if [ -z "$global_vmess_ws_enabled" ]; then
    global_vmess_ws_enabled="${DEFAULT_VMESS_ENABLED}"
  fi
  if [ -z "$global_vmess_ws_port" ]; then
    global_vmess_ws_port="${DEFAULT_VMESS_PORT}"
  fi
  if [ -z "$global_vmess_ws_path" ]; then
    global_vmess_ws_path="${DEFAULT_VMESS_WS_PATH}"
  fi
  if [ -z "$global_cf_enabled" ]; then
    global_cf_enabled="${DEFAULT_CF_VERSION}"
  fi
}


# 主流程 --------开始-------------------------------
# install /opt/softs 1.10.7 Y 5443 itunes.apple.com Y 6443 bing.com Y 7443 /im/msg
# cloudflared
# 操作编码 -> Singbox 版本号(默认1.10.7：latest最新) -> Reality (是否开启、端口、伪装域名)-> Hysteria2（是否开启、端口、证书域名）-> vmess（是否开启、端口、WS路径） -> -> -> -> -> -> -> ->
option="$1"
install_path="$2"
global_box_version="$3"
global_reality_enabled="$4"
global_reality_port="$5"
global_reality_tls_sni="$6"
global_hysteria2_enabled="$7"
global_hysteria2_port="$8"
global_hysteria2_tls_sni="$9"
global_vmess_ws_enabled="$10"
global_vmess_ws_port="$11"
global_vmess_ws_path="$12"
global_cf_enabled="$13"
#if [ "$install_path" = "" ]; then
  #print_message "请指定sing-box安装的目录，比如 /opt/softs"
  #exit_now $global_code_failure
#fi
if [ -n "$install_path" ]; then
  if ! echo "$install_path" | grep -q '^/'; then
    print_message "sing-box 安装目录【$install_path】：必须以/开头，比如 /opt/softs"
    exit_now $global_code_failure
  else
    install_path=$(readlink -f "$install_path")
    global_box_home_path="${install_path}/singbox"
  fi
fi

package_jq_install

if [ "$option" = "install" ]; then
  # 静默安装方式，未设置的参数，填充默认值
  params_unset_padding_default
elif [ "$option" = "" ]; then
  # 用户交互模式，手工输入
  print_message "+--------------------------------------------------------------------+"
  print_message "| 请选择需要的操作选项：                                             |"
  print_message "+--------------------------------------------------------------------+"
  print_message "| 1. 安装 sing-box                                                   |"
  print_message "| 2. 卸载 sing-box                                                   |"
  print_message "| 3. 显示客户端连接参数                                              |"
  print_message "| 4. 退出                                                            |"
  print_message "+--------------------------------------------------------------------+"
  while true; do
    printf "请输入操作编号："
    read -r input
    if [ "$input" = "1" ]; then
      option="install"
      break
    elif [ "$input" = "2" ]; then
      option="uninstall"
      break
    elif [ "$input" = "3" ]; then
      option="showconfig"
      break
    elif [ "$input" = "4" ]; then
      exit_now 0
      break
    else
      continue
    fi
  done
fi


if [ "$option" = "install" ]; then
  if [ "$global_box_home_path" = "" ]; then
    global_box_home_path="/opt/softs/singbox"
  fi
else
  if [ "$global_box_home_path" = "" ]; then
    global_box_home_path=$( find_sing_box_hone_path )
  fi
  if [ "$global_box_home_path" = "" ]; then
    print_message "未找到sing-box程序：请确认指定的安装目录是否正确 ${global_box_home_path} ..."
    exit_now $global_code_failure
  fi
fi

env_init
# 选择对应的执行动作
case "$option" in
  install)
    env_init
    option_for_install
    option_for_show_config
    ;;
  uninstall)
    option_for_uninstall
    ;;
  showconfig)
    option_for_show_config
    ;;
  *)
    print_message "不支持的操作选项：$option"
    exit_now $global_code_failure
    ;;
esac

exit $?

