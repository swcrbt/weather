# API 使用文档

## 和风天气数据源 (QWeatherDataSource)

### 初始化

```dart
import 'package:rain/data/datasources/qweather_datasource.dart';

final qweather = QWeatherDataSource();
```

### API 方法

#### 1. 获取实时天气

```dart
Future<Map<String, dynamic>> getCurrentWeather(String locationId)
```

**参数：**
- `locationId` - 城市ID，如 `'101010100'`（北京）

**返回：**
```json
{
  "code": "200",
  "updateTime": "2024-01-01T12:00+08:00",
  "now": {
    "temp": "25",
    "feelsLike": "28",
    "icon": "100",
    "text": "晴",
    "windDir": "东南风",
    "windScale": "3",
    "humidity": "60",
    "pressure": "1010"
  }
}
```

**示例：**
```dart
final weather = await qweather.getCurrentWeather('101010100');
print('温度: ${weather['now']['temp']}°C');
```

---

#### 2. 获取7天预报

```dart
Future<Map<String, dynamic>> get7DayForecast(String locationId)
```

**参数：**
- `locationId` - 城市ID

**返回：**
```json
{
  "code": "200",
  "daily": [
    {
      "fxDate": "2024-01-01",
      "tempMax": "28",
      "tempMin": "18",
      "textDay": "晴",
      "textNight": "多云"
    }
  ]
}
```

**示例：**
```dart
final forecast = await qweather.get7DayForecast('101010100');
for (var day in forecast['daily']) {
  print('${day['fxDate']}: ${day['tempMin']}°C - ${day['tempMax']}°C');
}
```

---

#### 3. 获取分钟级降水预报

```dart
Future<Map<String, dynamic>> getMinutePrecipitation(double lat, double lon)
```

**参数：**
- `lat` - 纬度
- `lon` - 经度

**返回：**
```json
{
  "code": "200",
  "minutely": [
    {
      "fxTime": "2024-01-01T12:00+08:00",
      "precip": "0.5",
      "type": "rain"
    }
  ]
}
```

**示例：**
```dart
final precip = await qweather.getMinutePrecipitation(39.9042, 116.4074);
```

---

#### 4. 获取空气质量

```dart
Future<Map<String, dynamic>> getAirQuality(String locationId)
```

**参数：**
- `locationId` - 城市ID

**返回：**
```json
{
  "code": "200",
  "now": {
    "aqi": "85",
    "category": "良",
    "pm2p5": "35",
    "pm10": "60"
  }
}
```

**示例：**
```dart
final aqi = await qweather.getAirQuality('101010100');
print('AQI: ${aqi['now']['aqi']}');
```

---

#### 5. 搜索城市

```dart
Future<List<Map<String, dynamic>>> searchCities(String query)
```

**参数：**
- `query` - 城市名称，如 `'北京'`

**返回：**
```json
[
  {
    "name": "北京",
    "id": "101010100",
    "lat": "39.9042",
    "lon": "116.4074"
  }
]
```

**示例：**
```dart
final cities = await qweather.searchCities('北京');
```

---

## 农历工具 (LunarCalendar)

### 方法

#### 获取当前农历日期

```dart
static String getCurrentLunarDate()
```

**返回：** 农历日期，如 `'正月初一'`

**示例：**
```dart
final lunarDate = LunarCalendar.getCurrentLunarDate();
print('农历: $lunarDate');
```

---

#### 获取指定日期的农历

```dart
static String getLunarDateSimple(DateTime date)
```

**参数：**
- `date` - 公历日期

**返回：** 农历日期

**示例：**
```dart
final lunarDate = LunarCalendar.getLunarDateSimple(DateTime(2024, 1, 1));
```

---

#### 获取生肖

```dart
static String getZodiac(int year)
```

**参数：**
- `year` - 年份

**返回：** 生肖，如 `'龙'`

**示例：**
```dart
final zodiac = LunarCalendar.getZodiac(2024);
```

---

#### 获取干支纪年

```dart
static String getGanZhi(int year)
```

**参数：**
- `year` - 年份

**返回：** 干支，如 `'甲辰'`

**示例：**
```dart
final ganZhi = LunarCalendar.getGanZhi(2024);
```

---

## 降水预警服务 (PrecipitationAlertService)

### 方法

#### 分析降水预警

```dart
static String? analyzePrecipitationAlert(Map<String, dynamic> data)
```

**参数：**
- `data` - 分钟级降水数据

**返回：** 预警信息，如 `'15分钟后开始下小雨'`

**示例：**
```dart
final alert = PrecipitationAlertService.analyzePrecipitationAlert(precipData);
if (alert != null) {
  print('预警: $alert');
}
```

---

#### 获取降水趋势

```dart
static String getPrecipitationTrend(List<dynamic> minutely)
```

**参数：**
- `minutely` - 分钟级降水数据列表

**返回：** 趋势，如 `'增强'`、`'减弱'`、`'持续'`

**示例：**
```dart
final trend = PrecipitationAlertService.getPrecipitationTrend(minutelyData);
```

---

#### 生成图表数据

```dart
static List<int> generateChartData(List<dynamic> minutely)
```

**参数：**
- `minutely` - 分钟级降水数据列表

**返回：** 降水强度数组（0-100）

**示例：**
```dart
final chartData = PrecipitationAlertService.generateChartData(minutelyData);
```

---

## 小部件服务 (HomeWidgetService)

### 方法

#### 更新小部件数据

```dart
Future<bool> updateFromIsar(Isar isar, {Settings? settings})
```

**参数：**
- `isar` - Isar 数据库实例
- `settings` - 可选的设置

**返回：** 是否更新成功

**示例：**
```dart
final service = HomeWidgetService(assetCacheService);
final success = await service.updateFromIsar(isar);
```

---

#### 从磁盘更新（后台任务）

```dart
static Future<bool> updateFromDisk()
```

**示例：**
```dart
await HomeWidgetService.updateFromDisk();
```

---

## 配置常量

### 和风天气配置

```dart
// lib/data/datasources/qweather_datasource.dart

static const String _credentialId = 'YOUR_CREDENTIAL_ID';  // 凭据 ID
static const String _projectId = 'YOUR_PROJECT_ID';        // 项目 ID
static const String _apiHost = 'your-host.qweatherapi.com'; // API Host
```

---

## 错误码

### 和风天气 API 错误码

| 错误码 | 说明 |
|--------|------|
| 200 | 请求成功 |
| 400 | 请求参数错误 |
| 401 | 认证失败（JWT 无效） |
| 403 | 无权限访问 |
| 404 | 资源不存在 |
| 429 | 请求过于频繁 |
| 500 | 服务器内部错误 |

---

## 注意事项

1. **JWT Token 有效期**：15分钟
2. **API 请求频率限制**：请参考和风天气官方文档
3. **私钥安全**：请勿将 `private_key.pem` 提交到 Git
4. **gzip 压缩**：API 响应使用 gzip 压缩，已自动解压
