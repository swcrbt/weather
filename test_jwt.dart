import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

void main() {
  // 配置
  const String credentialId = 'KNB28DQJ4P';
  const String privateKeyPath = 'assets/keys/private_key.pem';

  try {
    // 加载私钥
    final privateKeyBytes = File(privateKeyPath).readAsBytesSync();
    
    print('私钥长度: ${privateKeyBytes.length} bytes');
    print('私钥内容 (前50字符):');
    print(String.fromCharCodes(privateKeyBytes).substring(0, 50));
    
    // 创建 JWT
    final jwt = JWT(
      {
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'exp': DateTime.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        'sub': credentialId,
      },
      header: {
        'alg': 'EdDSA',
        'typ': 'JWT',
        'kid': credentialId,
      },
    );

    print('\nJWT Payload: ${jwt.payload}');
    print('JWT Header: ${jwt.header}');

    final token = jwt.sign(
      EdDSAPrivateKey(privateKeyBytes),
      algorithm: JWTAlgorithm.EdDSA,
    );

    print('\n✅ JWT Token 生成成功');
    print('Token: $token');
    
    // 验证 Token
    print('\n验证 Token...');
    try {
      final verifiedJwt = JWT.verify(token, EdDSAPublicKey(privateKeyBytes));
      print('✅ Token 验证成功');
      print('Payload: ${verifiedJwt.payload}');
    } catch (e) {
      print('❌ Token 验证失败: $e');
    }

  } catch (e, stackTrace) {
    print('\n❌ 错误：');
    print(e);
    print('\n堆栈跟踪：');
    print(stackTrace);
  }
}
