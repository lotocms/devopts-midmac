#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${PROJECT_DIR}/.env.docker"

error() {
  echo "错误: $*" >&2
  exit 1
}

info() {
  echo "[devopts-init] $*"
}

trim() {
  local s="$1"
  s="$(echo "$s" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  s="${s%\"}"
  s="${s#\"}"
  s="${s%\'}"
  s="${s#\'}"
  echo "$s"
}

ensure_dir_rw() {
  local dir="$1"
  mkdir -p "$dir"

  if [ ! -r "$dir" ] || [ ! -w "$dir" ]; then
    error "目录无读写权限: $dir"
  fi

  local probe="${dir}/.devopts_rw_test_$$"
  if ! touch "$probe" 2>/dev/null; then
    error "目录不可写: $dir"
  fi
  rm -f "$probe"
}

ensure_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    info "目录已存在，跳过: $dir"
  else
    mkdir -p "$dir"
    info "已创建: $dir"
  fi
  ensure_dir_rw "$dir"
}

copy_if_conf_new() {
  local conf_dir="$1"
  local src_file="$2"
  local target_file="$3"

  if [ ! -d "$conf_dir" ]; then
    mkdir -p "$conf_dir"
    ensure_dir_rw "$conf_dir"
    cp "$src_file" "$target_file"
    info "已初始化配置: $target_file"
    return
  fi

  ensure_dir_rw "$conf_dir"
  info "已存在，跳过配置初始化: $conf_dir"
}

main() {
  local os
  os="$(uname -s)"
  case "$os" in
    Darwin|Linux) ;;
    *)
      error "仅支持 macOS 或 Linux，当前系统: $os"
      ;;
  esac

  if ! command -v docker >/dev/null 2>&1; then
    echo "未检测到 Docker，请先安装 Docker 后再执行本脚本。"
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    error "Docker 已安装但当前不可用，请先启动 Docker 服务后重试"
  fi

  local docker_network="xai-network"
  if docker network inspect "$docker_network" >/dev/null 2>&1; then
    echo "Docker 网络已存在: $docker_network，继续执行初始化。"
  else
    if docker network create "$docker_network" >/dev/null 2>&1; then
      echo "Docker 网络创建成功: $docker_network"
    else
      error "创建 Docker 网络失败: $docker_network"
    fi
  fi

  [ -f "$ENV_FILE" ] || error ".env.docker 不存在: $ENV_FILE"

  local line raw_value volume_base
  line="$(grep -E '^[[:space:]]*DEVOPTS_VOLUME_BASE[[:space:]]*=' "$ENV_FILE" | tail -n1 || true)"
  [ -n "$line" ] || error ".env.docker 未配置 DEVOPTS_VOLUME_BASE"

  raw_value="${line#*=}"
  volume_base="$(trim "$raw_value")"
  [ -n "$volume_base" ] || error "DEVOPTS_VOLUME_BASE 为空"

  if [[ "$volume_base" != /* ]]; then
    volume_base="${PROJECT_DIR}/${volume_base}"
  fi

  info "DEVOPTS_VOLUME_BASE=${volume_base}"
  ensure_dir_rw "$volume_base"

  # mysql8 volumes
  local mysql8_base="${volume_base}/mysql8"
  ensure_dir "$mysql8_base"
  ensure_dir "${mysql8_base}/data"
  ensure_dir "${mysql8_base}/log"
  ensure_dir "${mysql8_base}/share"
  ensure_dir "${mysql8_base}/init"

  local mysql_tmpl="${PROJECT_DIR}/template/mysql8/my.cnf"
  if [ ! -f "$mysql_tmpl" ] && [ -f "${PROJECT_DIR}/template/mysql/my.cnf" ]; then
    mysql_tmpl="${PROJECT_DIR}/template/mysql/my.cnf"
  fi
  [ -f "$mysql_tmpl" ] || error "找不到 mysql 模板文件: template/mysql8/my.cnf"
  copy_if_conf_new "${mysql8_base}/conf" "$mysql_tmpl" "${mysql8_base}/conf/my.cnf"

  # redis volumes
  local redis_base="${volume_base}/redis"
  ensure_dir "$redis_base"
  ensure_dir "${redis_base}/data"

  local redis_conf_dir="${redis_base}/conf"
  if [ ! -d "$redis_conf_dir" ]; then
    mkdir -p "$redis_conf_dir"
    ensure_dir_rw "$redis_conf_dir"
    [ -f "${PROJECT_DIR}/template/redis/redis.conf" ] || error "找不到 redis 模板: template/redis/redis.conf"
    cp "${PROJECT_DIR}/template/redis/redis.conf" "${redis_conf_dir}/redis.conf"
    if [ -f "${PROJECT_DIR}/template/redis/live.conf" ]; then
      cp "${PROJECT_DIR}/template/redis/live.conf" "${redis_conf_dir}/live.conf"
    fi
    info "已初始化配置: ${redis_conf_dir}"
  else
    ensure_dir_rw "$redis_conf_dir"
    info "已存在，跳过配置初始化: ${redis_conf_dir}"
  fi

  # postgres volumes
  local postgres_base="${volume_base}/postgresdb"
  ensure_dir "$postgres_base"
  ensure_dir "${postgres_base}/data"

  info "初始化完成"
}

main "$@"
