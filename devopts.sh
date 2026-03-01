#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
使用说明:
  ./devopts.sh up
  ./devopts.sh down
  ./devopts.sh restart
EOF
}

resolve_env_file() {
  if [ -f "${PROJECT_DIR}/.env.mac" ]; then
    echo "${PROJECT_DIR}/.env.mac"
    return
  fi
  if [ -f "${PROJECT_DIR}/.env.docker" ]; then
    echo "${PROJECT_DIR}/.env.docker"
    return
  fi
  echo "错误: 未找到 .env.mac（或 .env.docker）" >&2
  exit 1
}

resolve_compose_file() {
  if [ -f "${PROJECT_DIR}/docker-compose.mac.yaml" ]; then
    echo "${PROJECT_DIR}/docker-compose.mac.yaml"
    return
  fi
  if [ -f "${PROJECT_DIR}/docker-compose.mac.yml" ]; then
    echo "${PROJECT_DIR}/docker-compose.mac.yml"
    return
  fi
  if [ -f "${PROJECT_DIR}/docker-compose.mac.ymal" ]; then
    echo "${PROJECT_DIR}/docker-compose.mac.ymal"
    return
  fi
  echo "错误: 未找到 docker-compose.mac.yaml（或兼容文件名）" >&2
  exit 1
}

compose_cmd() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose "$@"
    return
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
    return
  fi
  echo "错误: 未找到 docker compose 或 docker-compose 命令" >&2
  exit 1
}

main() {
  local action="${1:-}"
  local env_file compose_file
  env_file="$(resolve_env_file)"
  compose_file="$(resolve_compose_file)"

  case "$action" in
    up)
      compose_cmd --env-file "$env_file" -f "$compose_file" up -d
      ;;
    down)
      compose_cmd --env-file "$env_file" -f "$compose_file" down
      ;;
    restart)
      compose_cmd --env-file "$env_file" -f "$compose_file" down
      compose_cmd --env-file "$env_file" -f "$compose_file" up -d
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
