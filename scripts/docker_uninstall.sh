#!/bin/sh
#set -e

global_code_failure=50

print_message(){
  echo "$1"
}

command_exists() {
  # command -v $1 > /dev/null 2>&1
  command -v "$@" > /dev/null 2>&1
  # return $?
}

# 检查 软件库 是否已安装
package_exists() {
  pkgs="$1"
  if [ -z "$pkgs" ]; then
    print_message "软件库名称不能为空！"
    return $global_code_param_missing
  fi
  #for ((i=0; i<${#arr[@]}; i++)); do
  for pkg in $pkgs; do
    if [ -z "$pkg" ]; then
      continue
    fi
    if command_exists dpkg; then
        # Debian/Ubuntu 使用 dpkg 检查
        sudo dpkg -s "$pkg" > /dev/null 2>&1
    elif command_exists dnf; then
        # Fedora/CentOS 8+ 使用 dnf 检查
        sudo dnf list installed "$pkg" > /dev/null 2>&1
    elif command_exists yum; then
        # CentOS 7 使用 yum 检查
        sudo yum list installed "$pkg" > /dev/null 2>&1
    else
        exit_now $global_code_failure "不支持的操作系统，无法安装！"
    fi
    code=$?
    if [ $code -ne 0 ]; then
      # 0：表示已经安装该，非0：表示未安装
      return $code
    fi
  done
  return 0
}

# 安装软件库
package_install(){
  pkgs="$1"
  if [ -z "$pkgs" ]; then
    print_message "软件库名称不能为空！"
    return $global_code_param_missing
  fi
  print_message "准备安装软件库：$pkgs"
  #for ((i=0; i<${#arr[@]}; i++)); do
  for pkg in $pkgs; do
    if [ -z "$pkg" ]; then
      continue
    fi
    print_message "正在安装：$pkg"
    # 检查包是否已安装
    if package_exists "$pkg"; then
        continue
    fi

    if command_exists apt-get; then
      sudo apt-get -y install "$pkg" > /dev/null 2>&1
    elif command_exists dnf; then
      sudo dnf -y install "$pkg" > /dev/null 2>&1
    elif command_exists yum; then
      sudo yum -y install "$pkg" > /dev/null 2>&1
    else
      exit_now $global_code_failure "不支持的操作系统，无法安装！"
    fi
    code=$?
    if [ $code -ne 0 ]; then
      exit_now $global_code_failure "安装失败：$pkg ！"
    fi
    print_message "成功安装：$pkg"
  done
  return 0
}

# 卸载软件库
package_uninstall(){
  pkgs="$1"
  if [ -z "$pkgs" ]; then
    print_message "软件库名称不能为空！"
    return $global_code_param_missing
  fi
  #for ((i=0; i<${#arr[@]}; i++)); do
  for pkg in $pkgs; do
    if [ -z "$pkg" ]; then
      continue
    fi
    print_message "正在卸载：$pkg"
    # 检查包是否已安装
    if ! package_exists "$pkg"; then
        continue
    fi

    if command_exists apt-get; then
      sudo apt-get -y purge $pkg > /dev/null 2>&1
    elif command_exists dnf; then
      sudo dnf -y remove "$pkg" > /dev/null 2>&1
    elif command_exists yum; then
      sudo yum -y remove "$pkg" > /dev/null 2>&1
    else
      exit_now $global_code_failure "不支持的操作系统，无法卸载！"
    fi
  done
  return $?
}

docker_uninstall(){
  # docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
  package_uninstall "docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras"

  # ubuntu 早期版本的卸载
  #package_uninstall "docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc"
  # debian 早期版本的卸载
  #package_uninstall "docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc"
  # centos 早期版本的卸载
  #package_uninstall "docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine"

  print_message "清理 Docker残余文件：/var/lib/docker/*、/var/lib/containerd/*、docker.list、docker.asc、daemon.json等"
  sudo rm -rf /var/lib/docker
  sudo rm -rf /var/lib/containerd
  sudo rm -f /etc/docker/daemon.json

  # ubuntu、debian
  sudo rm -f /etc/apt/sources.list.d/docker.list
  sudo rm -f /etc/apt/keyrings/docker.asc
  print_message "docker 卸载完成。"
}


# 主流程 ======= 开始 =======================
# 通过 Docker 停止所有容器（不依赖 systemd）
if command_exists docker; then
  print_message "关闭 docker容器 ..."
  docker stop $(docker ps -q) || true
fi

# 停止服务（仅当服务正在运行时）
if sudo systemctl is-active docker >/dev/null 2>&1; then
  print_message "关闭 docker进程 ..."
  sudo systemctl stop docker
fi

# 禁用服务（仅当服务已启用时）
if sudo systemctl is-enabled docker >/dev/null 2>&1; then
  print_message "禁用 docker进程 开机自启动配置 ..."
  sudo systemctl disable docker
  sudo systemctl daemon-reload
fi

docker_uninstall
print_message "docker 卸载完成。"
exit 0