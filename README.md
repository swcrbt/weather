# 🌦️ 天气应用

<div align='center'>
    <h1>🌦️ 天气</h1>
    <p><strong>支持多数据源、桌面小部件、农历显示的 Flutter 天气应用</strong></p>
</div>

<p align='center'>
    <a href='#功能特性'>功能特性</a> • 
    <a href='#技术架构'>技术架构</a> • 
    <a href='#快速开始'>快速开始</a> • 
    <a href='#配置说明'>配置说明</a> • 
    <a href='#api文档'>API文档</a>
</p>

---

## ✨ 功能特性

### 🌤️ 核心天气功能
- **实时天气** — 当前温度、湿度、风速、气压、能见度
- **逐小时预报** — 未来72小时逐小时天气预报
- **逐日预报** — 未来14天逐日天气预报
- **空气质量** — AQI指数、PM2.5、PM10、污染物详情
- **降水雷达** — 实时降水雷达地图
- **分钟级降水** — 未来2小时分钟级降水预报

### 🏠 桌面小部件（Android）
- **5x2 天气详情小部件** — 显示时间、农历、温度、AQI、5天预报
- **Material You 设计** — 支持动态颜色
- **自动刷新** — 后台定时更新数据
- **点击交互** — 点击打开应用

### 🌏 多数据源支持
- **Open-Meteo** — 全球天气数据（默认）
- **和风天气** — 国内天气数据（JWT认证）
- **智能切换** — 根据位置自动选择最优数据源

### 📅 特色功能
- **农历显示** — 小部件显示农历日期
- **降水预警** — 分钟级降水预警通知
- **多语言** — 支持38种语言
- **主题定制** — Material You、AMOLOED、自定义颜色

---

## 🏗️ 技术架构

### 项目结构

```
lib/
├── core/
│   ├── auth/              # JWT 认证
│   ├── config/            # 配置管理
│   ├── services/          # 核心服务
│   ├── utils/             # 工具类
│   └── weather/           # 天气相关工具
├── data/
│   ├── datasources/       # 数据源（Open-Meteo、和风天气）
│   ├── models/            # 数据模型
│   └── repositories/      # 数据仓库
├── features/
│   ├── cities/            # 城市管理
│   ├── forecast/          # 预报功能
│   ├── radar/             # 降水雷达
│   ├── settings/          # 设置
│   └── weather/           # 天气展示
└── i18n/                  # 国际化
```

### 技术栈

- **框架**: Flutter 3.x
- **状态管理**: Riverpod
- **数据库**: Isar
- **HTTP**: Dio
- **地图**: flutter_map
- **认证**: JWT (EdDSA)
- **本地化**: slang

---

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK >= 21
- iOS >= 12.0

### 安装依赖

```bash
flutter pub get
```

### 配置和风天气（可选）

1. 注册和风天气开发者账号：https://dev.qweather.com/
2. 创建项目并获取凭据 ID 和项目 ID
3. 在控制台添加 JWT 公钥
4. 更新 `lib/data/datasources/qweather_datasource.dart` 中的配置：

```dart
static const String _credentialId = 'YOUR_CREDENTIAL_ID';
static const String _projectId = 'YOUR_PROJECT_ID';
```

### 运行应用

```bash
# 开发模式
flutter run

# 发布模式
flutter build apk --release
flutter build ios --release
```

---

## ⚙️ 配置说明

### 和风天气 JWT 认证

#### 1. 生成 Ed25519 密钥对

```bash
# 生成私钥
openssl genpkey -algorithm Ed25519 -out assets/keys/private_key.pem

# 生成公钥
openssl pkey -in assets/keys/private_key.pem -pubout -out assets/keys/public_key.pem
```

#### 2. 配置凭据

在 `lib/data/datasources/qweather_datasource.dart` 中配置：

```dart
// 凭据 ID（kid）
static const String _credentialId = 'YOUR_CREDENTIAL_ID';

// 项目 ID（sub）
static const String _projectId = 'YOUR_PROJECT_ID';

// API Host
static const String _apiHost = 'your-host.qweatherapi.com';
```

#### 3. 安全注意事项

- **私钥** (`private_key.pem`) 已添加到 `.gitignore`，请勿提交到 Git
- **公钥** 需要上传到和风天气控制台
- 如果私钥泄露，请立即重新生成密钥对

---

## 📚 API 文档

### 和风天气数据源

#### 获取实时天气

```dart
final qweather = QWeatherDataSource();
final weather = await qweather.getCurrentWeather('101010100');
```

#### 获取7天预报

```dart
final forecast = await qweather.get7DayForecast('101010100');
```

#### 获取分钟级降水

```dart
final precipitation = await qweather.getMinutePrecipitation(39.9042, 116.4074);
```

#### 获取空气质量

```dart
final aqi = await qweather.getAirQuality('101010100');
```

### 小部件服务

#### 更新小部件数据

```dart
final service = HomeWidgetService(assetCacheService);
await service.updateFromIsar(isarInstance);
```

### 农历工具

```dart
// 获取当前农历日期
final lunarDate = LunarCalendar.getCurrentLunarDate();

// 获取指定日期的农历
final lunarDate = LunarCalendar.getLunarDateSimple(DateTime(2024, 1, 1));

// 获取生肖
final zodiac = LunarCalendar.getZodiac(2024);

// 获取干支纪年
final ganZhi = LunarCalendar.getGanZhi(2024);
```

### 降水预警服务

```dart
// 分析降水预警
final alert = PrecipitationAlertService.analyzePrecipitationAlert(data);

// 获取降水趋势
final trend = PrecipitationAlertService.getPrecipitationTrend(minutelyData);

// 生成图表数据
final chartData = PrecipitationAlertService.generateChartData(minutelyData);
```

---

## 📝 更新日志

### v1.0.0

- ✅ 添加和风天气数据源支持（JWT认证）
- ✅ 实现5x2桌面小部件（时间、农历、AQI、5天预报）
- ✅ 添加14天预报和72小时预报
- ✅ 实现降水雷达地图
- ✅ 添加分钟级降水预警
- ✅ 添加农历显示功能
- ✅ 增强小部件数据服务

---

## 🤝 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

---

## 📄 许可证

本项目基于 MIT 许可证开源 - 详见 [LICENSE](LICENSE) 文件

---

## 🙏 致谢

- [和风天气](https://www.qweather.com/) - 国内天气数据
- [Open-Meteo](https://open-meteo.com/) - 全球天气数据

---

<div align='center'>
    <p>Made with ❤️ using Flutter</p>
</div>
