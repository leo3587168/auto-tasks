#!/bin/sh
####!/bin/sh
#set -e
#set -euo pipefail
#set -x
#trap 'echo -e "\n[ERROR] 在 ${BASH_SOURCE[0]} 第 $LINENO 行失败，退出码 $?\n调用栈:\n${BASH_LINENO[*]}" >&2' ERR

#sed "s/\${xxxxx}/$my_var/g" template.txt > output.txt
curr_script_path=$(readlink -f "$0")
curr_script_path=$(dirname "$curr_script_path")
#global_work_home_path="${HOME}/auto-tasks"
global_work_home_path="${curr_script_path}"
global_work_temp_path="${global_work_home_path}/_temps_"
global_work_script_path="${global_work_home_path}/scripts"
global_work_template_path="${HOME}/templates"
mkdir -p "$global_work_home_path"
mkdir -p "$global_work_temp_path"
mkdir -p "$global_work_script_path"
#declare -a global_tasks=()
global_tasks=""
global_tasks_count=0
global_tasks_sep="#########"

global_code_failure=50
global_code_param_missing=11
global_code_param_invalid=12
global_code_no_access=41
global_code_not_found=44


print_message(){
  # -eq/-ne/-gt/-lt/-ge/-le
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
  print_message "清理垃圾：${global_work_home_path}/_temps_"
  delete_file "${global_work_home_path}/_temps_"
}

exit_now(){
  code="$1"
  msg="$2"
  clean_up $code
  if [ $code -eq 0 ]; then
    print_message "任务结束：成功。"
  else
    print_message "任务结束：失败（error=$code, message=$msg）"
  fi
  exit $code
}

exit_on_code_failure(){
  code="$1"
  msg="$2"
  if [ $code -ne 0 ]; then
    exit_now "$code" "$msg"
  fi
  return 0
}

command_exists() {
  # command -v $1 > /dev/null 2>&1
  command -v "$@" > /dev/null 2>&1
  # return $?
}

shell_error_stop_disable() {
  #myfunc_with_e || true  # 即使 myfunc_with_e 失败，仍会继续执行
  # 保存子 Shell 启动时的初始选项（继承自父 Shell）
  original_opts="$(set +o)"
  set +e  # 临时禁用 set -e
  echo "$original_opts"
}

shell_option_set() {
  shell_opts="$1"
  if [ -z "$shell_opts" ]; then
    #return $global_code_failure
    exit_now $global_code_failure
  fi
  eval "$shell_opts"
  return $?
}

#if command -v systemctl >/dev/null; then
#  systemctl enable --now "$SERVICE_NAME"
#  systemctl restart "$SERVICE_NAME"
#else
#  service "$SERVICE_NAME" restart
#fi

systemctl_service_start(){
  srv_name="$1"
  if [ -z "$srv_name" ]; then
    return 0
  fi

  if sudo systemctl is-active "$srv_name" >/dev/null; then
    return 0
  fi
  sudo systemctl start "$srv_name"
  return $?
}

systemctl_service_stop(){
  srv_name="$1"
  if [ -z "$srv_name" ]; then
    return 0
  fi
  if sudo systemctl is-active "$srv_name" >/dev/null; then
    sudo systemctl stop "$srv_name"
    return $?
  fi
  return 0
}

systemctl_service_enable(){
  srv_name="$1"
  if [ -z "$srv_name" ]; then
    return 0
  fi
  # 禁用服务（仅当服务已启用时）
  if sudo systemctl is-enabled "$srv_name" >/dev/null; then
    return 0
  fi
  sudo systemctl enable "$srv_name"
  code=$?
  sudo systemctl daemon-reload
  return $code
}

systemctl_service_disable(){
  srv_name="$1"
  if [ -z "$srv_name" ]; then
    return 0
  fi
  # 禁用服务（仅当服务已启用时）
  if sudo systemctl is-enabled "$srv_name" >/dev/null; then
    sudo systemctl disable "$srv_name"
    code=$?
    sudo systemctl daemon-reload
    return $code
  fi
  return 0
}


file_executable_check(){
  org_path="$1"
  #todo real_path=$(readlink -f "$org_path")
  return 0
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
  curl -fL "$file_url" -o "${global_work_temp_path}/${file_name}"
  return $?
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
  # todo bookworm、bullseye、buster、stretch、jessie、、、
  dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
}

# 检查更新 软件源仓库
package_repository_update(){
  print_message "正在检查更新 软件源仓库 ..."
  if command_exists apt-get; then
    # Debian/Ubuntu 系 (APT)
    # 1、更新软件源列表（获取最新软件信息）
    sudo apt-get update
    # 2、升级已安装的软件包
    #sudo apt-get upgrade > /dev/null 2>&1
    # 3、清理旧版本（可选）
    #sudo apt-get clean > /dev/null 2>&1
  elif command_exists dnf; then
    # Red Hat/Fedora/CentOS 系 (DNF)
    # 1、检查可用更新（不自动应用）
    sudo dnf check-update
    # 2、执行更新
    #sudo dnf upgrade > /dev/null 2>&1
    # 3、清理缓存
    #sudo dnf clean all > /dev/null 2>&1
  elif command_exists yum; then
    # Red Hat/Fedora/CentOS 系 (YUM)
    # 1、检查可用更新（不自动应用）
    sudo yum check-update
    # 2、执行更新
    #sudo yum update > /dev/null 2>&1
    # 3、清理缓存
    #sudo yum clean all > /dev/null 2>&1
  else
    exit_now $global_code_failure "不支持的操作系统，无法检查更新软件源仓库！"
  fi
  return $?
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
  print_message "准备安装软件库列表：$pkgs"
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
      #sudo apt-get -y install "$pkg" > /dev/null 2>&1
      sudo apt-get -y install "$pkg"
    elif command_exists dnf; then
      #sudo dnf -y install "$pkg" > /dev/null 2>&1
      sudo dnf -y install "$pkg"
    elif command_exists yum; then
      #sudo yum -y install "$pkg" > /dev/null 2>&1
      sudo yum -y install "$pkg"
    else
      exit_now $global_code_failure "不支持的操作系统，无法安装！"
    fi
    code=$?
    if [ $code -ne 0 ]; then
      exit_now $global_code_failure "安装失败：$pkg ！"
    fi
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

tasks_show(){
  seq=0
  count="${global_tasks_count}"
  print_message ""
  print_message "**********************************************************************"
  print_message "待执行的任务序列如下（总共${count}步）："
  old_ifs="$IFS"
  IFS="$global_tasks_sep"
  set -- $global_tasks
  for task_item in "$@"; do
    if [ -z "$task_item" ]; then
      continue
    fi
    seq=$((seq+1))
    print_message "        任务 ${seq}: 【$task_item】"
  done
  #unset IFS  # 恢复默认分隔符
  IFS="$old_ifs"
}

tasks_process(){
  seq=0
  count="$global_tasks_count}"
  print_message ""
  print_message ""
  print_message ""
  outer_old_ifs="$IFS"
  IFS="$global_tasks_sep"
  set -- $global_tasks
  for task_item in "$@"; do
    if [ -z "$task_item" ]; then
      continue
    fi
    seq=$((seq+1))
    print_message "----------------------------------------------------------------------"
    print_message "===>>> 开始执行任务【${seq}/${count}】: $task_item"
    task_name=""
    task_args=""
    bash_task_name=""
    IFS="$outer_old_ifs"
    for item in $task_item; do # 注意这里变量不能加引号，否则不会分割
      if [ -z "$task_name" ]; then
        task_name="$item"
        continue
      fi
      if [ -z "$bash_task_name" ]; then
        if [ "$task_name" = "bash" -o "$task_name" = "sh" ]; then
          bash_task_name="$item"
          continue
        fi
      fi
      task_args="$task_args $item"
    done
    case "$task_name" in
      "sh")
        #bash /root/hello.sh 123 456 aa
        command_file="xxx"
        case "$bash_task_name" in
          /*) command_file="$bash_task_name" ;;
          *)  command_file="${global_work_script_path}/$bash_task_name" ;;
        esac
        #file_add_executable "${command_file}"
        sh $command_file ${task_args}
        ;;
      "bash")
        command_file="xxx"
        case "$bash_task_name" in
          /*) command_file="$bash_task_name" ;;
          *)  command_file="${global_work_script_path}/$bash_task_name" ;;
        esac
        #file_add_executable "${command_file}"
        bash $command_file ${task_args}
        ;;
      "repository_update")
        package_repository_update ${task_args}
        ;;
      "package_install")
        package_install ${task_args}
        ;;
      "package_uninstall")
        package_uninstall ${task_args}
        ;;
      *)
        command_file="xxx"
        case "$task_name" in
          /*)
            command_file="$task_name"
            ;;
          *)
            command_file="${global_work_script_path}/$task_name"
            case "$command_file" in
              *.sh)
                command_file="$command_file"
                ;;
              *)
                command_file="$command_file.sh"
                ;;
            esac
            ;;
        esac
        file_executable_add "${command_file}"
        "${command_file}" ${task_args}
        ;;
    esac
    code=$?
    if [ $code -ne 0 ]; then
      print_message "执行失败（任务${seq}/${count}）：error=$code"
      exit_now $code
    fi
    IFS="$global_tasks_sep"
  done
  IFS="$outer_old_ifs"
}

show_help(){
  help_text='''
  操作详细介绍：
    1、每行代表一个任务，多个任务之间按先后顺序执行；如果某个任务失败，后续任务不再执行
    2、安装 docker：【docker_install [版本号]】 docker_install 26.1、docker_install latest
    3、卸载 docker：【docker_uninstall】
    4、安装 nginx：【nginx_install [版本号]】，示例：nginx_install 1.27.1

    5、安装 singbox：【singbox install 安装目录 [版本号] 】
        默认安装：singbox install 指定安装目录
        自定义安装：
        singbox  install /opt/softs  1.10.7   Y           5443  itunes.apple.com Y            6443  bing.com Y            7443  /im/msg
        固定      安装命令 安装目录     版本号    reality开关  端口  伪装域名          hysteria2开关 端口  伪装域名  vmess协议开关  端口  websocket路径
    6、卸载singbox：【singbox uninstall 指定安装的目录】
    7、查看singbox配置：
        singbox showconfig 指定安装的目录
  '''
  print_message "$help_text"
}


# 主流程 ---- 开始 ----------------------------------------------------------
print_message "设置当前脚本工作目录：${global_work_home_path}"
if ! package_exists curl; then
  package_install "curl"
fi

params_tasks="$1"
if [ -n "$params_tasks" ]; then
  # apt-get -y install git && git clone https://github.com/leo3587168/auto-tasks.git && cd auto-tasks && chmod +x startup.sh && ./startup.sh "docker_install latest#########nginx_install 1.27.1#########singbox showconfig"
  global_tasks_count=0
  global_tasks=""
  old_ifs="$IFS"
  IFS="$global_tasks_sep"
  set -- $params_tasks
  for task_item in "$@"; do
    if [ -z "$task_item" ]; then
      continue
    fi
    global_tasks_count=$((global_tasks_count+1))
    global_tasks="${global_tasks}${global_tasks_sep}${task_item}"
  done
  #unset IFS  # 恢复默认分隔符
  IFS="$old_ifs"

  if [ $global_tasks_count -eq 0 ]; then
    exit_now $global_code_failure "没有指定任务"
  fi
  tasks_show
  tasks_process

  exit_now $? "执行完成"
fi

while true; do
  print_message ""
  print_message ""
  print_message ""
  print_message "**********************************************************************"
  print_message "**********************************************************************"
  print_message "**********************************************************************"
  print_message "*                                                                    *"
  print_message "*             支    持    的    任    务    序    列                 *"
  print_message "*                                                                    *"
  print_message "+-----------------+--------------------------------------------------+"
  print_message "*   任 务 名 称   |  任   务   示   例                               *"
  print_message "+-==================================================================-+"
  print_message "*  设置系统环境   | set_os_locale Asia/Shanghai zh_CN.utf8           *"
  print_message "+-----------------+--------------------------------------------------+"
  print_message "*   安装 docker   | docker_install latest                            *"
  print_message "+-----------------+--------------------------------------------------+"
  print_message "*   卸载 docker   | docker_uninstall                                 *"
  print_message "+-----------------+--------------------------------------------------+"
  print_message "*   安装 nginx    | nginx_install 1.27.1                             *"
  print_message "+-----------------+--------------------------------------------------+"
  print_message "*  安装 singbox   | singbox install                                  *"
  print_message "**********************************************************************"
  print_message "*  卸载 singbox   | singbox uninstall                                *"
  print_message "**********************************************************************"
  print_message "* 查看singbox配置 | singbox showconfig                               *"
  print_message "**********************************************************************"
  print_message ""
  print_message "输入你要执行的任务序列（顺序执行），每行代表一个任务。"
  print_message "输入ok(确认)，reset(重置)，exit(退出)，help(帮助)，请输入："
  global_tasks=""
  global_tasks_count=0
  while true; do
    read -r line
    # 删除行首尾空白字符，判断是否非空行
    #line=$(echo "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    if [ "$line" = "" ]; then
      continue
    fi
    if echo "$line" | grep -q '^#'; then
      continue
    fi
    if [ "$line" = "exit" -o "$line" = "EXIT" ]; then
      exit_now 0 "用户退出"
    fi
    if [ "$line" = "reset" -o "$line" = "RESET" ]; then
      global_tasks=""
      global_tasks_count=0
      break
    fi
    if [ "$line" = "help" -o "$line" = "HELP" ]; then
      show_help
      print_message ""
      print_message "还未添加任务，请重新输入任务列表："
      continue
    fi
    if [ "$line" = "ok" -o "$line" = "OK" ]; then
      if [ $global_tasks_count -eq 0 ]; then
        print_message "还未添加任务，请重新输入任务列表："
        continue
      fi
      break
    fi
    global_tasks_count=$((global_tasks_count + 1))
    global_tasks="${global_tasks}${global_tasks_sep}$line"
  done
  if [ $global_tasks_count -eq 0 ]; then
    continue
  fi
  tasks_show
  tasks_process
  break
done

exit_now 0 "执行完成"