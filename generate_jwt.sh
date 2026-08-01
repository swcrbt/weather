#!/bin/bash

# 配置
kid="KNB28DQJ4P"
sub="34KXEK29E5"
private_key_path="assets/keys/private_key.pem"

# 设置 iat 和 exp
iat=$(( $(date +%s) - 30 ))
exp=$((iat + 900))

# base64url 编码的 header 和 payload
header_base64=$(printf '{"alg":"EdDSA","kid":"%s"}' "$kid" | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')
payload_base64=$(printf '{"sub":"%s","iat":%d,"exp":%d}' "$sub" "$iat" "$exp" | openssl base64 -e | tr -d '=' | tr '/+' '_-' | tr -d '\n')
header_payload="${header_base64}.${payload_base64}"

# 保存临时文件用于 Ed25519 签名
tmp_file=$(mktemp)
echo -n "$header_payload" > "$tmp_file"

# 使用 Ed25519 签名
signature=$(openssl pkeyutl -sign -inkey "$private_key_path" -rawin -in "$tmp_file" | openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')

# 删除临时文件
rm -f "$tmp_file"

# 生成 JWT
jwt="${header_payload}.${signature}"

# 输出 Token
echo "$jwt"
