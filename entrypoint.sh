#!/bin/bash

# 重定输出到日志文件
if [ -n "${MCP_VM_SERVER_LOG_PATH}" ]; then
    touch "${MCP_VM_SERVER_LOG_PATH}"
    chown user:user "${MCP_VM_SERVER_LOG_PATH}"
    exec &> >(tee -a "${MCP_VM_SERVER_LOG_PATH}")
fi

PROFILE="${MCP_VM_PROFILE:-all}"
# 统一镜像入口：默认走 all，命中 ci profile 时尽早转发到专用入口。
echo "entrypoint(all): MCP_VM_PROFILE=${PROFILE} ENABLE_CI_SERVER=${ENABLE_CI_SERVER:-true} WAIT_PORTS=${WAIT_PORTS:-<empty>}"
case "${PROFILE}" in
  all)
    ;;
  ci)
    echo "entrypoint(all): routing to ci entrypoint ${RUNTIME_PATH}/entrypoint_ci.sh"
    exec "${RUNTIME_PATH}/entrypoint_ci.sh" "$@"
    ;;
  *)
    echo "Unknown MCP_VM_PROFILE=${PROFILE}" >&2
    exit 1
    ;;
esac

normalize_wait_ports() {
  local wait_ports="${WAIT_PORTS:-8091}"
  local original_wait_ports="${WAIT_PORTS:-<empty>}"

  # all 模式下 nginx 默认等待 8091；如果启用了 CI server，再补上 9999。
  if [ "${ENABLE_CI_SERVER:-true}" = "true" ]; then
    case ",${wait_ports}," in
      *,9999,*)
        ;;
      *)
        wait_ports="${wait_ports},9999"
        ;;
    esac
  fi

  export WAIT_PORTS="${wait_ports}"
  echo "entrypoint(all): normalized WAIT_PORTS from ${original_wait_ports} to ${WAIT_PORTS}"
}

normalize_wait_ports

create_symlink() {
  local target_path="$1"
  local link_path="$2"
  echo "create_symlink: target_path=$target_path ; link_path=$link_path"

  if [ -d "$link_path" ]; then
      echo "错误: $link_path 是目录" >&2
  elif [ -f "$link_path" ]; then
      echo "错误: $link_path 是文件" >&2
  elif [ -L "$link_path" ]; then
      echo "错误: $link_path 已存在符号链接" >&2
  else
      echo "创建符号链接: $target_path -> $link_path"
      ln -sfT "$target_path" "$link_path"
  fi
}

USER_HOME=/home/user
LARK_CLI_DOWNLOADED_PATH=/usr/local/bin/lark-cli-downloaded
LARK_CLI_TMP_PATH=/tmp/lark-cli.download.tmp
LARK_CLI_DONE_PATH=/tmp/lark_cli_done
# 命令入口软链路径，由 resolve_lark_cli_alias() 根据 LARK_CLI_ALIAS 动态设置
LARK_CLI_LINK_PATH=

log_lark_cli() {
  echo "$@" >&2
}

resolve_lark_cli_alias() {
  # LARK_CLI_ALIAS 为空时保留默认命令名 lark-cli
  local alias="${LARK_CLI_ALIAS:-lark-cli}"
  # 仅允许字母/数字/下划线/中划线，防止拼进 /usr/local/bin 路径时发生路径穿越
  if [[ ! "$alias" =~ ^[A-Za-z0-9_-]+$ ]]; then
    log_lark_cli "LARK_CLI_ALIAS is invalid, fallback to default lark-cli: $alias"
    alias="lark-cli"
  fi
  LARK_CLI_LINK_PATH="/usr/local/bin/${alias}"
  log_lark_cli "lark cli command alias resolved: $alias -> $LARK_CLI_LINK_PATH"
}

replace_symlink() {
  local target_path="$1"
  local link_path="$2"

  log_lark_cli "replace_symlink: target_path=$target_path ; link_path=$link_path"
  ln -sfT "$target_path" "$link_path"
}

validate_lark_cli_url() {
  local url="$1"

  if [[ ! "$url" =~ ^https?://[^[:space:]]+$ ]]; then
    log_lark_cli "LARK_CLI_URL is invalid, abort lark cli initialization: $url"
    return 1
  fi
  return 0
}

get_lark_cli() {
  local url="${LARK_CLI_URL}"
  local attempt=1

  rm -f "$LARK_CLI_TMP_PATH"

  if [ -z "$url" ]; then
    log_lark_cli "LARK_CLI_URL is empty, skip lark cli installation"
    return 1
  fi

  validate_lark_cli_url "$url" || return 1

  log_lark_cli "start downloading lark cli from LARK_CLI_URL: $url"
  while [ $attempt -le 3 ]; do
    rm -f "$LARK_CLI_TMP_PATH"
    if curl --noproxy '*' -fL --connect-timeout 1 --max-time 5 "$url" -o "$LARK_CLI_TMP_PATH"; then
      if [ ! -s "$LARK_CLI_TMP_PATH" ]; then
        log_lark_cli "downloaded lark cli is empty, abort lark cli initialization"
        rm -f "$LARK_CLI_TMP_PATH"
        return 1
      fi

      if ! mv "$LARK_CLI_TMP_PATH" "$LARK_CLI_DOWNLOADED_PATH"; then
        log_lark_cli "move downloaded lark cli failed, abort lark cli initialization"
        rm -f "$LARK_CLI_TMP_PATH"
        return 1
      fi
      log_lark_cli "download lark cli success: $LARK_CLI_DOWNLOADED_PATH"
      printf '%s\n' "$LARK_CLI_DOWNLOADED_PATH"
      return 0
    fi

    log_lark_cli "download lark cli failed, retrying: attempt=${attempt}/3"
    rm -f "$LARK_CLI_TMP_PATH"
    attempt=$((attempt + 1))
    if [ $attempt -le 3 ]; then
      sleep 1
    fi
  done

  log_lark_cli "download lark cli failed after 3 attempts, abort lark cli initialization"
  return 1
}

init_lark_cli() {
  local selected_path

  rm -f "$LARK_CLI_DONE_PATH"

  resolve_lark_cli_alias

  if ! selected_path="$(get_lark_cli)"; then
    log_lark_cli "lark cli installation skipped or failed, abort lark cli initialization"
    return 0
  fi

  if [ ! -f "$selected_path" ]; then
    log_lark_cli "selected lark cli binary not found: $selected_path"
    return 1
  fi

  if ! chown user:user "$selected_path"; then
    log_lark_cli "chown lark cli binary failed: $selected_path"
    return 1
  fi
  if ! chmod 700 "$selected_path"; then
    log_lark_cli "chmod lark cli binary failed: $selected_path"
    return 1
  fi
  if ! replace_symlink "$selected_path" "$LARK_CLI_LINK_PATH"; then
    log_lark_cli "replace lark cli symlink failed: $LARK_CLI_LINK_PATH"
    return 1
  fi
  if ! touch "$LARK_CLI_DONE_PATH"; then
    log_lark_cli "touch $LARK_CLI_DONE_PATH failed"
    return 1
  fi
  log_lark_cli "touch $LARK_CLI_DONE_PATH success"
  log_lark_cli "using lark cli binary: $selected_path (command: $LARK_CLI_LINK_PATH)"
}

init_http_proxy() {
  # 如果传入了PROXY环境变量，则使用PROXY作为代理
  if [ -n "$PROXY" ]; then
    echo "PROXY=${PROXY}, init_http_proxy"
    local no_proxy_value="localhost,127.0.0.1,::1"

    if [ -n "$NO_PROXY_DOMAINS" ]; then
      no_proxy_value="${no_proxy_value},${NO_PROXY_DOMAINS}"
      echo "NO_PROXY_DOMAINS=${NO_PROXY_DOMAINS}"
    fi

    echo "export http_proxy=\"${PROXY}\"" >> ${USER_HOME}/.bashrc
    echo "export https_proxy=\"${PROXY}\"" >> ${USER_HOME}/.bashrc
    echo "export HTTP_PROXY=\"${PROXY}\"" >> ${USER_HOME}/.bashrc
    echo "export HTTPS_PROXY=\"${PROXY}\"" >> ${USER_HOME}/.bashrc
    echo "export no_proxy=\"${no_proxy_value}\"" >> ${USER_HOME}/.bashrc
    echo "export NO_PROXY=\"${no_proxy_value}\"" >> ${USER_HOME}/.bashrc

    . ${USER_HOME}/.bashrc
  fi
}

init_browser_config() {
  echo "init_browser_config"

  echo "export BROWSER_EXTRA_ARGS=\"${BROWSER_EXTRA_ARGS} --disable-sync\"" >> /root/.bashrc
}

init_workspace() {
  echo "init_workspace"

  # 用于浏览器Cookie读写
  mkdir -p /home/user/.config/browser/Default/customCookie
  chown user:user /home/user/.config
  chown user:user /home/user/.config/browser
  chown user:user /home/user/.config/browser/Default
  chown user:user /home/user/.config/browser/Default/customCookie

  WORKSPACE=/home/user/.super_doubao/super-doubao-runtime/workspace
  # 处理动态session目录
  if [ -n "${SESSION_ID}" ]; then
      echo "SESSION_ID = ${SESSION_ID}"
      mkdir -p /sandboxdata/workspace/file && mkdir -p /sandboxdata/workspace/code
      chown user:user "/sandboxdata/workspace/file" && chmod 777 "/sandboxdata/workspace/file"
      chown user:user "/sandboxdata/workspace/code" && chmod 777 "/sandboxdata/workspace/code"
      create_symlink "/sandboxdata/workspace/file" ${WORKSPACE}
      chown -h user:user /home/user/.super_doubao/super-doubao-runtime/workspace
      # 创建Download目录
      mkdir -p ${DOWNLOADS_PATH} && chown -R user:user ${DOWNLOADS_PATH} && chmod 777 ${DOWNLOADS_PATH}
      mv /mnt /mnt.backup && create_symlink "/sandboxdata/workspace/code" /mnt
      chown -h user:user /mnt
  else
      echo "SESSION_ID is empty"
      mkdir -p ${WORKSPACE} && chmod 777 ${WORKSPACE}
  fi
}

download_skills() {
  local skills_dir="${RUNTIME_PATH}/skills"
  local workspace_skills="${WORKSPACE}/skills"
  (
    mkdir -p "$skills_dir"
    chmod 777 "$skills_dir"
    create_symlink "$skills_dir" "$workspace_skills"
    local tmp_file="/tmp/skills.zip"

    if [ -f "/sandboxdata/workspace/skills.zip" ]; then
      mv "/sandboxdata/workspace/skills.zip" "$tmp_file"
      if unzip -o "$tmp_file" -d "$skills_dir"; then
        rm -f "$tmp_file"
        echo "load skills done"
        return
      else
        rm -f "$tmp_file"
        echo "unzip skills.zip failed, fallback to curl download"
      fi
    else
      echo "/sandboxdata/workspace/skills.zip not found, fallback to curl download"
    fi

    if [ -z "$SKILLS_DOWNLOAD_URL" ] || [ -z "$SKILLS_DOWNLOAD_TOKEN" ]; then
      echo "SKILLS_DOWNLOAD_URL or SKILLS_DOWNLOAD_TOKEN is empty, skip skills download"
      return
    fi

    local curl_args=(--noproxy '*' -fL -H "Authorization: ${SKILLS_DOWNLOAD_TOKEN}" "$SKILLS_DOWNLOAD_URL" -o "$tmp_file")

    if [ -n "${PPE_ENV}" ]; then
      curl_args+=(-H "X-Use-Ppe: 1" -H "X-Tt-Env: ${PPE_ENV}")
    fi

    if [ -n "${CLUSTER_ENV}" ]; then
      curl_args+=(-H "cluster: ${CLUSTER_ENV}")
    fi

    printf '%q ' curl "${curl_args[@]}"
    echo
    local attempt=1
    while [ $attempt -le 5 ]; do
      if curl "${curl_args[@]}"; then
        if unzip -o "$tmp_file" -d "$skills_dir"; then
          rm -f "$tmp_file"
          echo "download skills done"
          break
        fi
      fi
      rm -f "$tmp_file"
      attempt=$((attempt + 1))
      sleep 1
    done
  )
}


init_workspace

init_http_proxy

download_skills

init_lark_cli

init_browser_config

/hijack_proxy/start.sh &
echo "hijack proxy start script submitted asynchronously, pid=$!"

# nginx
envsubst '${VM_SERVER_PORT} ${CI_PYTHON_SERVER_PORT}' < /tmp/nginx.mcp_vm_server.conf.template > /opt/gem/nginx/nginx.mcp_vm_server.conf

# 启动 aio & gem browser
/opt/gem/run.sh &
RUN_GEM_PID=$!
echo "start gem. pid=$RUN_GEM_PID"


# 转发信号给子进程
forward_signal() {
  sig="$1"
  echo "Entrypoint received SIG$sig, forwarding..."
  kill "-$sig" -"$child_pid" 2>/dev/null
}

trap 'forward_signal TERM' SIGTERM
trap 'forward_signal INT'  SIGINT
trap 'forward_signal QUIT' SIGQUIT

wait "$RUN_GEM_PID"
