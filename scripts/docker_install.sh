#!/bin/sh
set -e

global_work_home_path="${HOME}/tasks_run"
global_work_temp_path="${global_work_home_path}/_temps_"
global_work_script_path="${global_work_home_path}/scripts"
mkdir -p "$global_work_home_path"
mkdir -p "$global_work_temp_path"
mkdir -p "$global_work_script_path"
global_code_failure=50
global_code_param_missing=11
global_code_param_invalid=12
global_code_no_access=41
global_code_not_found=44

#
# docker run -d --name lobe-chat --restart unless-stopped -p 3210:3210 -e ACCESS_CODE=此处自定义你的登录密码 \
#           -e OPENAI_MODEL_LIST=-all,+gpt-4o,+gpt-4o-mini -e OPENAI_API_KEY=xxxx lobehub/lobe-chat
#
# docker run -d --name lobe-chat --restart unless-stopped -p 3210:3210 -e ACCESS_CODE=此处自定义你的登录密码 \
#           -e ENABLED_OPENAI=0 -e DEEPSEEK_MODEL_LIST=-all,+deepseek-reasoner \
#           -e DEEPSEEK_PROXY_URL=https://api.deepseek.com\
#           -e DEEPSEEK_API_KEY=xxxx lobehub/lobe-chat
#
# docker run -d --name open-webui --restart unless-stopped -p 3000:8080 -e ENABLE_OPENAI_API=True \
#           -e OPENAI_API_BASE_URL=https://api.deepseek.com/v1 -e OPENAI_API_KEY=xxx \
#           -v open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main

print_message(){
  echo "$1"
}

command_exists() {
  # command -v $1 > /dev/null 2>&1
  command -v "$@" > /dev/null 2>&1
  # return $?
}

get_linux_name(){
  lsb_dist=""
  # ubuntu、debian、centos、fedora、arch、opensuse、amzn.....
  if [ -r /etc/os-release ]; then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
  fi
  # Returning an empty string here should be alright since the
  # case statements don't act unless you provide an actual value
  echo "$lsb_dist"
}

get_linux_fork(){
  # bookworm、bullseye、buster、stretch、jessie、、、
  dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
}

download_file(){
  file_name="$1"
  file_url="$2"
  # curl -fsSL https://get.docker.com -o install-docker.sh | sh
  curl -fL "$file_url" -o "${global_work_temp_path}/${file_name}"
  return $?
}

docker_running(){
  # 检测 docker 是否已安装
  if ! command_exists docker; then
    return $global_code_failure
  fi
  docker info > /dev/null 2>&1
  return $?
}

docker_install(){
  docker_version="$1"
  os_name=$( get_linux_name )
  code=0
  case "$os_name" in
    ubuntu)
      print_message "配置 docker 仓库"
      # 1、Set up Docker's apt repository.
      # Add Docker's official GPG key:
      sudo apt-get update
      sudo apt-get -y install ca-certificates curl
      sudo install -m 0755 -d /etc/apt/keyrings
      sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
      sudo chmod a+r /etc/apt/keyrings/docker.asc

      # Add the repository to Apt sources:
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update

      print_message "安装docker：$docker_version"
      # 2、安装：查看版本列表 ->   apt-cache madison docker-ce | awk '{ print $3 }'
      #VERSION_STRING=5:28.0.4-1~ubuntu.24.04~noble
      #sudo apt-get install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin
      if [ -z "$docker_version" ]; then
        VERSION_STRING=""
      elif [ "$docker_version" = "latest" ]; then
        VERSION_STRING=""
      else
        docker_version2=$(sudo apt-cache madison docker-ce | awk '{ print $3 }' | grep "$docker_version" | head -n 1)
        if [ "$docker_version2" = "" ]; then
          print_message "未找到匹配的版本：$docker_version"
          return $global_code_not_found
        fi
        VERSION_STRING="=$docker_version2"
      fi
      print_message "安装docker：sudo apt-get install -y "docker-ce$VERSION_STRING" "docker-ce-cli$VERSION_STRING" containerd.io"
      sudo apt-get install -y "docker-ce$VERSION_STRING" "docker-ce-cli$VERSION_STRING" containerd.io
      ;;
    debian)
      print_message "配置 docker 仓库"
      # 1、Set up Docker's apt repository.【$(. /etc/os-release && echo "$VERSION_CODENAME")】
      # Add Docker's official GPG key:
      sudo apt-get update
      sudo apt-get -y install ca-certificates curl
      sudo install -m 0755 -d /etc/apt/keyrings
      sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
      sudo chmod a+r /etc/apt/keyrings/docker.asc

      # Add the repository to Apt sources:
      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update

      print_message "安装docker：$docker_version"
      # 2、安装：查看版本列表 ->   apt-cache madison docker-ce | awk '{ print $3 }'
      #VERSION_STRING=5:28.0.4-1~debian.12~bookworm
      #sudo apt-get install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin
      if [ -z "$docker_version" ]; then
        VERSION_STRING=""
      elif [ "$docker_version" = "latest" ]; then
        VERSION_STRING=""
      else
        docker_version2=$(sudo apt-cache madison docker-ce | awk '{ print $3 }' | grep "$docker_version" | head -n 1)
        if [ "$docker_version2" = "" ]; then
          print_message "未找到匹配的版本：$docker_version"
          return $global_code_not_found
        fi
        VERSION_STRING="=$docker_version2"
      fi
      print_message "安装docker：sudo apt-get install -y "docker-ce$VERSION_STRING" "docker-ce-cli$VERSION_STRING" containerd.io"
      sudo apt-get install -y "docker-ce$VERSION_STRING" "docker-ce-cli$VERSION_STRING" containerd.io
      ;;
    centos|rocky)
      if command_exists dnf; then
        print_message "配置 docker 仓库"
        # 1、配置源：Set up the repository
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

        print_message "安装docker：$docker_version"
        # 2、安装：查看版本列表 ->   dnf list docker-ce --showduplicates | sort -r
        #VERSION_STRING=3:28.0.4-1.el9
        #sudo dnf install docker-ce-<VERSION_STRING> docker-ce-cli-<VERSION_STRING> containerd.io docker-buildx-plugin docker-compose-plugin
        if [ -z "$docker_version" ]; then
          VERSION_STRING=""
        elif [ "$docker_version" = "latest" ]; then
          VERSION_STRING=""
        else
          docker_version2=$(sudo dnf list docker-ce --showduplicates | sort -r | awk '{print $2}' | grep "$docker_version" | head -n 1)
          if [ "$docker_version2" = "" ]; then
            print_message "未找到匹配的版本：$docker_version"
            return $global_code_not_found
          fi
          docker_version2=${docker_version2#*:}     # 删除 `:` 前面的内容，得到 "19.03.13-3.el8"
          docker_version2=${docker_version2%-*}     # 删除 `-` 后面的内容，得到 "19.03.13"
          VERSION_STRING="-$docker_version2"
        fi
        print_message "安装docker：sudo dnf install -y "docker-ce$VERSION_STRING" "docker-ce-cli$VERSION_STRING" containerd.io"
        sudo dnf install -y "docker-ce$VERSION_STRING" "docker-ce-cli$VERSION_STRING" containerd.io

        print_message "配置开机启动 & 启动 docker"
        # 3、配置开机启动 & 启动
        sudo systemctl enable --now docker
      else
        print_message "安装docker基础依赖"
        # 1、安装基础依赖
        # sudo yum install -y yum-utils device-mapper-persistent-data lvm2
        sudo yum install -y yum-utils

        print_message "配置 docker 仓库"
        # 2、配置源：Set up the repository
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum makecache fast

        print_message "安装docker：$docker_version"
        # 2、安装：查看版本列表 ->   yum list docker-ce --showduplicates | sort -r
        #VERSION_STRING=3:28.0.4-1.el9
        # sudo yum install -y docker-ce-<VERSION_STRING> docker-ce-cli-<VERSION_STRING> containerd.io docker-buildx-plugin docker-compose-plugin
        if [ -z "$docker_version" ]; then
          VERSION_STRING=""
        elif [ "$docker_version" = "latest" ]; then
          VERSION_STRING=""
        else
          docker_version2=$(sudo yum list docker-ce --showduplicates | sort -r | awk '{print $2}' | grep "$docker_version" | head -n 1)
          if [ "$docker_version2" = "" ]; then
            print_message "未找到匹配的版本：$docker_version"
            return $global_code_not_found
          fi
          docker_version2=${docker_version2#*:}     # 删除 `:` 前面的内容，得到 "19.03.13-3.el8"
          docker_version2=${docker_version2%-*}     # 删除 `-` 后面的内容，得到 "19.03.13"
          VERSION_STRING="-$docker_version2"
        fi
        print_message "安装docker：sudo yum install -y "docker-ce$VERSION_STRING" "docker-ce-cli$VERSION_STRING" containerd.io"
        sudo yum install -y "docker-ce$VERSION_STRING" "docker-ce-cli$VERSION_STRING" containerd.io

        print_message "配置开机启动 & 启动 docker"
        # 3、配置开机启动 & 启动
        sudo systemctl enable --now docker
      fi
      ;;
    *)
      print_message "不支持该$os_name系统安装"
      return $global_code_failure
      ;;
  esac

  if [ $? -ne 0 -o $code -ne 0 ]; then
    print_message "docker 安装失败"
    return $global_code_failure
  else
    print_message "docker 安装成功"
    return 0
  fi
}


docker_config(){
  mkdir -p /etc/docker
  if [ ! -f "/etc/docker/daemon.json" ]; then
    # "registry-mirrors": ["https://xxx.mirror.aliyuncs.com"]
    cat << EOF > /etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "5"
    }
}
EOF
  fi
  # cat << EOF > /etc/docker/key.json
  # EOF

  # sudo systemctl disable docker.service docker.socket
  sudo systemctl enable docker
  if [ $? -ne 0 ]; then
    print_message "docker 配置失败：sudo systemctl enable docker"
    return $global_code_failure
  fi
  sudo systemctl daemon-reload
  if [ $? -ne 0 ]; then
    print_message "docker 配置失败：sudo systemctl daemon-reload"
    return $global_code_failure
  fi
  print_message "docker 配置成功"
}

docker_start(){
  sudo systemctl restart docker
  if [ $? -eq 0 ]; then
    print_message "docker 启动成功"
    return 0
  else
    print_message "docker 启动失败：sudo systemctl restart docker"
    return $global_code_failure
  fi
}

# 主流程 ======= 开始 =======================
# $0：脚本名称。
global_docker_version="$1"
# 检测 docker 是否已安装
if command_exists docker; then
  print_message "系统已安装docker，无需安装。如需重新安装，请请卸载旧版本。"
  if docker_running; then
    print_message "docker 正在运行"
    exit 0
  fi
  docker_start
  if ! docker_running; then
    print_message "docker 启动失败"
    exit $global_code_failure
  fi
fi

# 检测是否指定了版本号
if [ -z "$global_docker_version" ]; then
  if command_exists apt-get; then
    #sudo apt-get -y install ca-certificates curl >/dev/null
    print_message "安装依赖库：ca-certificates curl"
    sudo apt-get -y install ca-certificates curl
  fi
  print_message "docker版本号 未设置，默认安装最新版本"
  docker_install_script="get-docker.sh"
  download_file "$docker_install_script" https://get.docker.com
  if [ $? -ne 0 ]; then
    print_message "docker安装脚本 下载失败：https://get.docker.com"
    exit $global_code_failure
  fi
  # sh get-docker.sh --version=23.0.1 --mirror=阿里云
  sudo sh "${global_work_temp_path}"/"$docker_install_script"
  if ! command_exists docker; then
    print_message "docker 安装失败"
    exit $global_code_failure
  fi
  print_message "docker 安装成功"
else
  docker_install $global_docker_version
fi

if ! command_exists docker; then
  exit $global_code_failure
fi

docker_config
docker_start
docker_running
exit $?