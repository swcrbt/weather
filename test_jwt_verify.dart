import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

void main() {
  // 配置
  const String credentialId = 'KNB28DQJ4P';
  const String projectId = '34KXEK29E5';
  const String privateKeyPath = 'assets/keys/private_key.pem';

  try {
    // 加载私钥
    final privateKeyBytes = File(privateKeyPath).readAsBytesSync();
    
    // 创建 JWT（按照和风天气文档格式）
    final jwt = JWT(
      {
        'sub': projectId,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 30,
        'exp': DateTime.now().add(Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000,
      },
      header: {
        'alg': 'EdDSA',
        'kid': credentialId,
      },
    );

    final token = jwt.sign(
      EdDSAPrivateKey(privateKeyBytes),
      algorithm: JWTAlgorithm.EdDSA,
    );

    print('JWT Token:');
    print(token);
    print('');
    
    // 解析 Token 查看内容
    final parts = token.split('.');
    print('Header (Base64URL decoded):');
    print(utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))));
    print('');
    print('Payload (Base64URL decoded):');
    print(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    print('');
    print('Signature length: ${parts[2].length}');

  } catch (e) {
    print('错误: $e');
  }
}
