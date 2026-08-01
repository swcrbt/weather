import 'dart:convert';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// JWT 认证管理器
/// 用于和风天气 API 的 JWT 认证
class JWTAuthManager {
  JWTAuthManager({
    required this.credentialId,
    required this.privateKeyPem,
  });

  final String credentialId;
  final String privateKeyPem;

  /// 生成 JWT Token
  /// 用于和风天气 API 请求认证
  String generateToken() {
    // 创建 JWT
    final jwt = JWT(
      {
        // JWT 标准声明
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        // 和风天气特定声明
        'sub': credentialId,
      },
      header: {
        'alg': 'EdDSA',
        'typ': 'JWT',
        'kid': credentialId,
      },
    );

    // 使用 Ed25519 私钥签名
    final token = jwt.sign(
      EdDSAPrivateKey(privateKeyPem),
      algorithm: JWTAlgorithm.EdDSA,
    );

    return token;
  }

  /// 获取认证头
  Map<String, String> getAuthHeaders() {
    final token = generateToken();
    return {
      'Authorization': 'Bearer $token',
    };
  }
}
