#!/bin/sh
set -e

global_code_failure=50
global_code_param_missing=11
global_code_param_invalid=12
global_code_no_access=41
global_code_not_found=44

print_message(){
  echo "$1"
}

command_exists() {
  # command -v $1 > /dev/null 2>&1
  command -v "$@" > /dev/null 2>&1
  # return $?
}

docker_running() {
  # 检测 docker 是否已安装
  if ! command_exists docker; then
    return $global_code_failure
  fi
  docker info > /dev/null 2>&1
  return $?
}

docker_start() {
  sudo systemctl restart docker
  if [ "$?" = "0" ]; then
    print_message "docker 启动成功"
    return 0
  else
    print_message "docker 启动失败：sudo systemctl restart docker"
    return $global_code_failure
  fi
}

# 检查镜像是否存在
nginx_image_exists() {
  if docker image inspect "$global_nginx_full_image" >/dev/null 2>&1; then
    return 0
  else
    return $global_code_not_found
  fi
}

nginx_image_pull() {
  print_message "正在拉取镜像：$global_nginx_full_image"
  docker pull "$global_nginx_full_image"
  return $?
}

nginx_container_create(){
  print_message "创建容器：docker run -d --name $global_nginx_container_name --restart unless-stopped --network host -v $global_nginx_home_path/html:/usr/share/nginx/html -v $global_nginx_home_path/conf:/etc/nginx $global_nginx_full_image"
  # -e TZ=Asia/Shanghai
  docker run -d --name "$global_nginx_container_name" --restart unless-stopped --network host -v "$global_nginx_home_path"/html:/usr/share/nginx/html -v "$global_nginx_home_path"/conf:/etc/nginx "$global_nginx_full_image"
}

nginx_config_default() {
  # 生成默认配置（映射到容器外，即宿主机目录）
  print_message "生成默认配置（映射到容器外，即宿主机目录：${global_nginx_home_path}）"
  docker run -it --rm -v "${global_nginx_home_path}"/conf:/opt/nginx/originals/tmp nginx:1.27.1 sh -c "cp -rp /etc/nginx/* /opt/nginx/originals/tmp"
  cp -rp "${global_nginx_home_path}"/conf/conf.d "${global_nginx_home_path}"/conf/sites
  rm -rf "${global_nginx_home_path}"/conf/sites/*
  if [ -f "${global_nginx_home_path}/conf/conf.d/default.conf" ]; then
    cp -p "${global_nginx_home_path}"/conf/conf.d/default.conf "${global_nginx_home_path}"/conf/sites/default.conf.bak
  fi
  cp -p "${global_nginx_home_path}"/conf/nginx.conf "${global_nginx_home_path}"/conf/nginx.conf.original.bak
  #if [ -f "${global_work_template_path}/nginx-main.conf" ]; then
  #  #cat /dev/null > "${global_nginx_home_path}"/conf/nginx.conf
  #  cat "${global_work_template_path}"/nginx-main.conf > "${global_nginx_home_path}"/conf/nginx.conf
  #fi
  echo "hello world, nginx !!!" > "${global_nginx_home_path}"/html/test.txt
}

nginx_config_main(){
  print_message "Nginx站点目录：${global_nginx_home_path}/html"
  print_message "Nginx配置目录：${global_nginx_home_path}/conf"
  print_message "Nginx默认SSL证书目录：${global_nginx_home_path}/conf/certs"
  print_message "Nginx主配置文件：${global_nginx_home_path}/conf/nginx.conf"

  cat << EOF > "${global_nginx_home_path}"/conf/nginx.conf
#========global====================================================================================
#user                                nobody nobody;
worker_processes                     auto;
worker_cpu_affinity                  auto;
worker_rlimit_nofile                 65535;

# [ debug | info | notice | warn | error | crit ]
error_log                            /var/log/nginx/error.log notice;
pid                                  /var/run/nginx.pid;

#========events====================================================================================
events {
    use                              epoll;
    # count per work processer
    worker_connections               65535;
    #accept_mutex                    on;
    multi_accept                     on;
}

http {
    include                          mime.types;
    default_type                     application/octet-stream;

    # zoro copy setting
    sendfile                         on;
    sendfile_max_chunk               128k;
    #send_lowat                      12000;
    tcp_nopush                       on;
    #tcp_nodelay                     on;

    # keepalive setting
    keepalive_timeout                30s;
    keepalive_requests               100;

    # client setting
    # buffers setting, get memery pagesize command: [getconf PAGESIZE]
    client_header_buffer_size        4k;
    large_client_header_buffers      4 8k;
    client_body_buffer_size          64k;
    client_max_body_size             10m;
    client_body_in_single_buffer     on;
    #client_body_temp_path           /path/to/tmp/client_body_temp;

    # proxy setting
    proxy_buffering                  on;
    proxy_buffer_size                4k;
    proxy_buffers                    64 8k;
    #proxy_temp_path                 /path/to/tmp/proxy_temp;
    #proxy_max_temp_file_size        512k;
    #proxy_temp_file_write_size      64k;
    #proxy_cache_path                /path/to/tmp/proxy_cache levels=1:2 keys_zone=cache_one:512m inactive=1d max_size=2g;

    # timeout setting
    client_header_timeout            10s;
    client_body_timeout              10s;
    send_timeout                     10s;
    proxy_connect_timeout            10s;
    proxy_send_timeout               10s;
    proxy_read_timeout               10s;
    #lingering_time                  10s;
    #lingering_timeout               10s;
    #reset_timedout_connection       on;

    # mod_gzip configurations
    gzip                             on;
    gzip_http_version                1.1;
    gzip_comp_level                  6;
    gzip_min_length                  1k;
    gzip_vary                        on;
    #gzip_proxied                    any;
    #gzip_disable                    msie6;
    gzip_buffers                     8 16k;
    gzip_types                       text/xml text/plain text/css application/javascript application/x-javascript application/xml application/json application/rss+xml;

    # limit setting: fight DDoS attack, tune the numbers below according your application!!!
    # usage 1: limit rate/qps, define a limit zone rule: key=\$binary_remote_addr, name=qps_limit_per_ip, memerysize=10m, speed=50 per second
    #limit_req_zone                   \$binary_remote_addr zone=qps_limit_per_ip:10m rate=100r/s;
    # apply a limit zone rule: use qps_limit_per_ip rule, allow burst=10 requests into queue
    #limit_req                        zone=qps_limit_per_ip burst=10;
    # usage 2: limit concurrent connection, define a limit zone: key=binary_remote_addr, name=conn_limit_per_ip, memerysize=10m
    #limit_conn_zone                  \$binary_remote_addr zone=conn_limit_per_ip:10m;
    #limit_conn                       conn_limit_per_ip 100;

    # optimize cache
    #open_file_cache                 max=10000 inactive=20s;
    #open_file_cache_valid           30s;
    #open_file_cache_min_uses        2;
    #open_file_cache_errors          on;

    # others setting
    server_tokens                    off;
    autoindex                        off;
    #log_not_found                   off;
    #server_names_hash_max_size      2048;
    #server_names_hash_bucket_size   128;

    # access log setting
    #log_format                      access '[\$time_iso8601][\$remote_addr][\$http_x_forwarded_for]'
    #                                    '[\$status][\$bytes_sent][\$request_time][\$upstream_response_time][\$http_origin][\$var_cors_origin][\$request_method:\$request_uri]';
    log_format                       access '[\$time_iso8601][\$remote_addr][\$http_x_forwarded_for]'
                                        '[status=\$status][\$bytes_sent][\$request_time][\$upstream_response_time][\$http_origin][\$var_cors_origin][\$var_connection_header][\$server_port \$request_method \$scheme:/\$request_uri]';

    #access_log                      /var/log/nginx/access.log access;
    access_log                       /dev/null access;

    #include /etc/nginx/conf.d/*.conf;

    # Separate the following into independent configurations and import them through include
    #========default.conf==========================================================================

    map \$http_upgrade \$var_connection_header {
        default "";
        "~.+\$" "upgrade";
        #condition2 value;
    }

    map \$http_origin \$var_cors_origin {
        default "";
        "~^http[s]?://(.+\.)?example\.com\$" \$http_origin;
        "~^http[s]?://(.+\.)?example\.cn\$" \$http_origin;
    }

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites/*.conf;
}
EOF
}

nginx_config_vmess_websocket(){
  print_message "Nginx配置：代理 vmess(websocket) 服务，但不启用：${global_nginx_home_path}/conf/sites/01_vmess_domain.conf.bak"
  cat << EOF > "${global_nginx_home_path}"/conf/sites/01_vmess_domain.conf.bak
# 说明：域名+端口不能被其他服务占用，如果被占用，需将此文件配置合并到 跟域名端口对应的配置文件中
# 1、vmess协议监听的端口【7443】、websocket uri路径【/im/msg】：替换为vmess协议对应的端口、uri路径
# 2、绑定域名【xxx.xxx】：绑定的域名，比如 google.com
# 3、上传域名证书到该目录【/opt/softs/nginx-web/conf/certs/】：xxx.xxx.pem、xxx.xxx.key
# 4、生效配置，去除.bak后缀：${global_nginx_home_path}/conf/sites/vmess_domain.conf.bak
# 5、重启nginx
upstream backend_vmess_websocket {
	ip_hash;
	server                       127.0.0.1:7443 weight=200 max_fails=1 fail_timeout=10s;
	keepalive                    100;
	#keepalived_requests         100;
	keepalive_timeout            60s;
}

server {
	listen                       80 http2;
	server_name                  xxx.xxx;
	return                       301 https://\$host\$request_uri;
}

server {
	listen                       443 ssl http2;
	server_name                  xxx.xxx;

	# SSL setting
	ssl_certificate              /etc/nginx/certs/xxx.xxx.pem;
	ssl_certificate_key          /etc/nginx/certs/xxx.xxx.key;

	ssl_protocols                TLSv1.2 TLSv1.3;
	ssl_session_cache            shared:SSL:10m;
	ssl_session_timeout          10m;
	ssl_ciphers                  HIGH:!aNULL:!MD5;
	ssl_prefer_server_ciphers    on;
	root                         /usr/share/nginx/html;

	# vmess
	location /im/msg {
		proxy_pass                           http://backend_vmess_websocket;

		proxy_redirect                       off;
		proxy_http_version                   1.1;
		proxy_set_header                     Host \$host;
		proxy_set_header                     X-Real-IP \$remote_addr;
		proxy_set_header                     X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header                     Upgrade \$http_upgrade;
		proxy_set_header                     Connection \$var_connection_header;
	}

	# static web：建议这里放静态站点伪装，或者直接代理lobe_chat
	location / {
		index                                index.html index.htm;
		root                                 /usr/share/nginx/html;
		#expires                             2d;
		#add_header Cache-Control            "public";
	}
}
EOF
}

nginx_config_open_webui(){
  print_message "Nginx配置: 代理 open_webui 服务，但不启用：${global_nginx_home_path}/conf/sites/02_open_webui_domain.conf.bak"
  cat << EOF > "${global_nginx_home_path}"/conf/sites/02_open_webui_domain.conf.bak
# 说明：域名+端口不能被其他服务占用，如果被占用，需将此文件配置合并到 跟域名端口对应的配置文件中
# 1、open_webui端口【3000】：替换为open_webui监听的端口
# 2、绑定域名【xxx.xxx】：绑定的域名，比如 google.com
# 3、上传域名证书到该目录【/opt/softs/nginx-web/conf/certs/】：xxx.xxx.pem、xxx.xxx.key
# 4、生效配置，去除.bak后缀：${global_nginx_home_path}/conf/sites/vmess_domain.conf.bak
# 5、重启nginx
#
# docker run -d --name open-webui --restart unless-stopped -p 3000:8080 -e ENABLE_OPENAI_API=True \
#           -e OPENAI_API_BASE_URL=https://api.deepseek.com/v1 -e OPENAI_API_KEY=xxx \
#           -v open-webui:/app/backend/data ghcr.io/open-webui/open-webui:main
#

upstream backend_open_webui {
	ip_hash;
	server                       127.0.0.1:3000 weight=200 max_fails=1 fail_timeout=10s;
	keepalive                    100;
	#keepalived_requests         100;
	keepalive_timeout            60s;
}

server {
	listen                       80 http2;
	server_name                  xxx.xxx;
	return                       301 https://\$host\$request_uri;
}

server {
	listen                       443 ssl http2;
	server_name                  xxx.xxx;

	# SSL setting
	ssl_certificate              /etc/nginx/certs/xxx.xxx.pem;
	ssl_certificate_key          /etc/nginx/certs/xxx.xxx.key;

	ssl_protocols                TLSv1.2 TLSv1.3;
	ssl_session_cache            shared:SSL:10m;
	ssl_session_timeout          10m;
	ssl_ciphers                  HIGH:!aNULL:!MD5;
	ssl_prefer_server_ciphers    on;
	root                         /usr/share/nginx/html;

  # chat api: websocket
	location /api/v1/chats/ {
		proxy_pass                           http://backend_open_webui;
		proxy_redirect                       off;
		# proxy_http_version                 1.1;
		proxy_set_header                     Host \$host;
		proxy_set_header                     X-Real-IP \$remote_addr;
		proxy_set_header                     X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header                     Upgrade \$http_upgrade;
		proxy_set_header                     Connection \$var_connection_header;

		# 不缓存，支持流式输出
		# 关闭缓存
		proxy_cache off;
		# 关闭代理缓冲
		proxy_buffering off;
		# 开启分块传输编码
		chunked_transfer_encoding on;
		# 开启TCP NOPUSH选项，禁止Nagle算法
		tcp_nopush on;
		# 开启TCP NODELAY选项，禁止延迟ACK算法
		tcp_nodelay on;
		# 设定keep-alive超时时间为65秒
		keepalive_timeout 300;
	}

	# default
	location / {
		proxy_pass                           http://backend_open_webui;
		proxy_redirect                       off;
		# proxy_http_version                 1.1;
		proxy_set_header                     Host \$host;
		proxy_set_header                     X-Real-IP \$remote_addr;
		proxy_set_header                     X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header                     Upgrade \$http_upgrade;
		proxy_set_header                     Connection \$var_connection_header;
	}
}
EOF
}

nginx_config_lobe_chat(){
  print_message "Nginx配置: 代理 lobe_chat 服务，但不启用：${global_nginx_home_path}/conf/sites/03_lobe_chat_domain.conf.bak"
  cat << EOF > "${global_nginx_home_path}"/conf/sites/03_lobe_chat_domain.conf.bak
# 说明：域名+端口不能被其他服务占用，如果被占用，需将此文件配置合并到 跟域名端口对应的配置文件中
# 1、lobe_chat端口【3210】：替换为lobe_chat监听的端口
# 2、绑定域名【xxx.xxx】：绑定的域名，比如 google.com
# 3、上传域名证书到该目录【/opt/softs/nginx-web/conf/certs/】：xxx.xxx.pem、xxx.xxx.key
# 4、生效配置，去除.bak后缀：${global_nginx_home_path}/conf/sites/vmess_domain.conf.bak
# 5、重启nginx
#
# openai 服务启动：
# docker run -d --name lobe-chat --restart unless-stopped -p 3210:3210 -e ACCESS_CODE=此处自定义你的登录密码 \
#           -e OPENAI_MODEL_LIST=-all,+gpt-4o,+gpt-4o-mini -e OPENAI_API_KEY=xxxx lobehub/lobe-chat
#
# deepseek 服务启动：
# docker run -d --name lobe-chat --restart unless-stopped -p 3210:3210 -e ACCESS_CODE=此处自定义你的登录密码 \
#           -e ENABLED_OPENAI=0 -e DEEPSEEK_MODEL_LIST=-all,+deepseek-reasoner \
#           -e DEEPSEEK_PROXY_URL=https://api.deepseek.com\
#           -e DEEPSEEK_API_KEY=xxxx lobehub/lobe-chat

upstream backend_lobe_chat {
	ip_hash;
	server                       127.0.0.1:3210 weight=200 max_fails=1 fail_timeout=10s;
	keepalive                    100;
	#keepalived_requests         100;
	keepalive_timeout            60s;
}

server {
	listen                       80 http2;
	server_name                  xxx.xxx;
	return                       301 https://\$host\$request_uri;
}

server {
	listen                       443 ssl http2;
	server_name                  xxx.xxx;

	# SSL setting
	ssl_certificate              /etc/nginx/certs/xxx.xxx.pem;
	ssl_certificate_key          /etc/nginx/certs/xxx.xxx.key;

	ssl_protocols                TLSv1.2 TLSv1.3;
	ssl_session_cache            shared:SSL:10m;
	ssl_session_timeout          10m;
	ssl_ciphers                  HIGH:!aNULL:!MD5;
	ssl_prefer_server_ciphers    on;
	root                         /usr/share/nginx/html;

	# default
	location / {
		proxy_pass                           http://backend_lobe_chat;
		proxy_redirect                       off;
		# proxy_http_version                 1.1;
		proxy_set_header                     Host \$host;
		proxy_set_header                     X-Real-IP \$remote_addr;
		proxy_set_header                     X-Forwarded-For \$proxy_add_x_forwarded_for;
		proxy_set_header                     Upgrade \$http_upgrade;
		proxy_set_header                     Connection \$var_connection_header;
	}
}
EOF
}

env_init() {
  if [ -e "$global_nginx_home_path" ]; then
    curr_time=$(date +"%Y%m%d_%H%M%S")
    backup_file="${global_nginx_home_path}_bak_${curr_time}"
    print_message "正在备份：$global_nginx_home_path  -> ${backup_file}"
    cp -rp "$global_nginx_home_path" "$backup_file"
  fi
  rm -rf "$global_nginx_home_path"
  mkdir -p "$global_nginx_home_path"
  #mkdir "$global_nginx_home_path"/{conf,logs,html,certbot,openssl,tmp}
  mkdir "$global_nginx_home_path"/conf
  mkdir "$global_nginx_home_path"/logs
  mkdir "$global_nginx_home_path"/html
  mkdir "$global_nginx_home_path"/tmp
  mkdir "$global_nginx_home_path"/conf/originals
  mkdir "$global_nginx_home_path"/conf/certs
}


# 主流程 ======= 开始 =======================
# 参数解析：版本号、安装目录
global_nginx_version="$1"
global_nginx_home_path="$2"
global_nginx_container_name="nginx-web"
if [ "$global_nginx_version" = "" ]; then
  global_nginx_version="1.27.1"
fi
global_nginx_full_image="nginx:${global_nginx_version}"
if [ "$global_nginx_home_path" = "" ]; then
  global_nginx_home_path="/opt/softs"
fi
global_nginx_home_path=$(readlink -f "$global_nginx_home_path")
global_nginx_home_path="${global_nginx_home_path}/nginx-web"

# 确保 docker 已安装
if ! command_exists docker; then
  print_message "docker 程序：未安装；如果使用tasks_run脚本自动执行，请在该任务前添加【docker_install latest】任务"
  exit $global_code_failure
fi

# 确保 docker 已运行
if ! docker_running; then
  print_message "docker 进程：未启动"
  docker_start
  if ! docker_running; then
    print_message "docker 进程：启动失败"
    exit $global_code_failure
  fi
  print_message "docker 进程：启动成功"
fi

# 检查容器是否存在
if docker inspect "$global_nginx_container_name" > /dev/null 2>&1; then
  # 检查容器运行状态
  container_status=$(docker inspect -f '{{.State.Running}}' "$global_nginx_container_name")
  print_message "nginx-web 容器：running=${container_status}"
  if [ ! "$container_status" = "true" ]; then
    docker start "$global_nginx_container_name"
  fi
  container_status=$(docker inspect -f '{{.State.Running}}' "$global_nginx_container_name")
  print_message "nginx-web 容器：running=${container_status}"
  exit 0
fi

# 如果镜像不存在，则拉取
if ! nginx_image_exists; then
  if ! nginx_image_pull; then
    print_message "拉取镜像失败：$global_nginx_full_image"
    exit $global_code_failure
  fi
  if ! nginx_image_exists; then
    print_message "拉取镜像失败：$global_nginx_full_image"
    exit $global_code_failure
  fi
fi

# 环境初始化
if ! env_init; then
  print_message "环境初始化失败"
fi

nginx_config_default
nginx_config_main
nginx_config_vmess_websocket
nginx_config_open_webui
nginx_config_lobe_chat
nginx_container_create
docker restart "$global_nginx_container_name"


# 返回脚本执行结果
code=$global_code_failure
if docker inspect "$global_nginx_container_name" > /dev/null 2>&1; then
  container_status=$(docker inspect -f '{{.State.Running}}' "$global_nginx_container_name")
  if [ "$container_status" = "true" ]; then
    code=0
  fi
fi
exit $code

