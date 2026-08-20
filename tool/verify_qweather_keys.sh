#!/usr/bin/env bash
# 构建时强校验：和风凭据与私钥必须齐备且可用，否则构建失败。
# 用法: tool/verify_qweather_keys.sh <credential_id> <project_id> <api_host>
set -euo pipefail

CREDENTIAL_ID="${1:-}"
PROJECT_ID="${2:-}"
API_HOST="${3:-}"
PRIVATE_KEY_PATH="assets/keys/private_key.pem"

fail() {
  echo "::error::和风凭据校验失败: $1" >&2
  exit 1
}

[ -n "$CREDENTIAL_ID" ] || fail "QWEATHER_CREDENTIAL_ID 未配置"
[ -n "$PROJECT_ID" ] || fail "QWEATHER_PROJECT_ID 未配置"
[ -n "$API_HOST" ] || fail "QWEATHER_API_HOST 未配置"
[ -f "$PRIVATE_KEY_PATH" ] || fail "私钥文件不存在: $PRIVATE_KEY_PATH"
[ -s "$PRIVATE_KEY_PATH" ] || fail "私钥文件为空: $PRIVATE_KEY_PATH"

command -v openssl >/dev/null 2>&1 || fail "找不到 openssl 命令"

# 私钥可解析且为 Ed25519
if ! openssl pkey -in "$PRIVATE_KEY_PATH" -text -noout 2>/dev/null | grep -q "ED25519"; then
  fail "私钥不是有效的 Ed25519 PEM: $PRIVATE_KEY_PATH"
fi

# 签名往返验证：能完成 Ed25519 签名的私钥才能为 JWT 所用
SIGN_INPUT="$(pwd)/.verify_qweather_sign_input.$$"
SIGN_OUTPUT="$(pwd)/.verify_qweather_sign_output.$$"
trap 'rm -f "$SIGN_INPUT" "$SIGN_OUTPUT"' EXIT
printf 'qweather-jwt-sign-check' > "$SIGN_INPUT"
if ! openssl pkeyutl -sign \
  -inkey "$PRIVATE_KEY_PATH" \
  -rawin -in "$SIGN_INPUT" \
  -out "$SIGN_OUTPUT" 2>/dev/null; then
  fail "私钥无法完成 Ed25519 签名"
fi
[ -s "$SIGN_OUTPUT" ] || fail "签名为空"

echo "✅ 和风凭据校验通过 (credential=$CREDENTIAL_ID)"