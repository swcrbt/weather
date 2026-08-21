# Open-Meteo API 文档

Open-Meteo 是开源免费的天气 API，无需注册、无需 API Key。本项目使用其中三个接口：

| API | 端点 | 项目用途 |
|-----|------|----------|
| 天气预报 API | `https://api.open-meteo.com/v1/forecast` | 实时天气、逐小时/逐日预报、15 分钟降水 |
| 地理编码 API | `https://geocoding-api.open-meteo.com/v1/search` | 城市搜索 |
| 空气质量 API | `https://air-quality-api.open-meteo.com/v1/air-quality` | 空气质量与污染物预报 |

对应实现：`lib/data/datasources/open_meteo_datasource.dart`、`lib/data/datasources/air_quality_remote_datasource.dart`。

> 官方文档：<https://open-meteo.com/en/docs>、<https://open-meteo.com/en/docs/geocoding-api>、<https://open-meteo.com/en/docs/air-quality-api>

---

## 许可与使用限制

- 数据许可为 **CC BY 4.0**：可免费商用转发与再创作，但**必须署名**（在使用天气数据的位置附近提供指向 Open-Meteo 的链接）。
- 免费非商业用途限制：**每天 10,000 次、每小时 5,000 次、每分钟 600 次** API 调用；滥用可能被直接封禁 IP。
- 商业用途需订阅，使用 `customer-api.open-meteo.com` 域名并携带 `apikey` 参数，接口语法与免费版一致。
- 承诺 API 稳定性：只新增可选参数，不会新增必填参数。

---

## 1. 天气预报 API（Weather Forecast API）

### 请求

```
GET https://api.open-meteo.com/v1/forecast?latitude=39.9042&longitude=116.4074&hourly=temperature_2m&daily=temperature_2m_max,temperature_2m_min&timezone=auto
```

### URL 参数

| 参数 | 格式 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `latitude`, `longitude` | 浮点数 | 是 | - | WGS84 坐标；多个坐标可用逗号分隔批量请求 |
| `hourly` | 字符串数组 | 否 | - | 逐小时变量列表，逗号分隔 |
| `minutely_15` | 字符串数组 | 否 | - | 15 分钟分辨率变量列表 |
| `current` | 字符串数组 | 否 | - | 当前实况变量列表 |
| `daily` | 字符串数组 | 否 | - | 逐日聚合变量列表 |
| `forecast_days` | 整数 (0-16) | 否 | 7 | 预报天数，最多 16 天 |
| `forecast_minutely_15` | 整数 (>0) | 否 | - | 15 分钟数据的时间步数（以当前时刻为基准） |
| `past_days` | 整数 (0-92) | 否 | 0 | 同时返回过去 1-92 天数据 |
| `past_hours` / `forecast_hours` | 整数 (>0) | 否 | - | 以小时为单位精细控制时间范围 |
| `start_date` / `end_date` | `yyyy-mm-dd` | 否 | - | 指定时间区间 |
| `timezone` | 字符串 | 否 | GMT | IANA 时区名；`auto` 表示按坐标自动解析本地时区 |
| `timeformat` | 字符串 | 否 | `iso8601` | 可选 `unixtime`（GMT+0 秒级时间戳） |
| `temperature_unit` | 字符串 | 否 | `celsius` | 可选 `fahrenheit` |
| `wind_speed_unit` | 字符串 | 否 | `kmh` | 可选 `ms`、`mph`、`kn` |
| `precipitation_unit` | 字符串 | 否 | `mm` | 可选 `inch` |
| `models` | 字符串数组 | 否 | best_match | 手动指定天气模型（如 `ecmwf_ifs`、`gfs_seamless`、`icon_seamless` 等） |
| `cell_selection` | 字符串 | 否 | `land` | 网格单元选择策略：`land`（相近海拔陆地）、`sea`、`nearest` |
| `elevation` | 浮点数 | 否 | - | 手动指定海拔 |
| `tilt` / `azimuth` | 浮点数 | 否 | 0 | 计算 `global_tilted_irradiance` 用的面板倾角/方位角 |
| `apikey` | 字符串 | 否 | - | 仅商业订阅访问客户域名时需要 |

### 本项目实际请求参数

`OpenMeteoWeatherSource` 中固定使用的参数（见 `_weatherParams` / `_minutelyParams`）：

```text
hourly=temperature_2m,relativehumidity_2m,apparent_temperature,precipitation,rain,
       weathercode,surface_pressure,visibility,evapotranspiration,windspeed_10m,
       winddirection_10m,windgusts_10m,cloudcover,uv_index,dewpoint_2m,
       precipitation_probability,shortwave_radiation
daily=weathercode,temperature_2m_max,temperature_2m_min,apparent_temperature_max,
      apparent_temperature_min,sunrise,sunset,precipitation_sum,
      precipitation_probability_max,windspeed_10m_max,windgusts_10m_max,
      uv_index_max,rain_sum,winddirection_10m_dominant
forecast_days=12&past_days=1&timezone=auto
```

需要分钟级降水时追加：

```text
minutely_15=precipitation,rain,showers,precipitation_probability
forecast_minutely_15=24
```

> **旧版变量名**：项目使用的 `weathercode`、`windspeed_10m`、`winddirection_10m`、
> `windgusts_10m`、`cloudcover`、`relativehumidity_2m`、`dewpoint_2m` 是旧命名，
> 官方 API 至今仍接受（已实测）。新版官方命名为 snake_case：`weather_code`、
> `wind_speed_10m`、`wind_direction_10m`、`wind_gusts_10m`、`cloud_cover`、
> `relative_humidity_2m`、`dew_point_2m`。新增代码建议使用新命名。

### 响应结构

```json
{
  "latitude": 39.875,
  "longitude": 116.375,
  "elevation": 48.0,
  "generationtime_ms": 2.2,
  "utc_offset_seconds": 28800,
  "timezone": "Asia/Shanghai",
  "timezone_abbreviation": "GMT+8",
  "hourly_units": { "time": "iso8601", "temperature_2m": "°C", "...": "..." },
  "hourly": {
    "time": ["2024-01-01T00:00", "2024-01-01T01:00", "..."],
    "temperature_2m": [1.2, 1.0, "..."]
  },
  "daily_units": { "time": "iso8601", "temperature_2m_max": "°C" },
  "daily": {
    "time": ["2024-01-01", "..."],
    "temperature_2m_max": [5.0, "..."]
  },
  "minutely_15_units": { "time": "iso8601", "precipitation": "mm" },
  "minutely_15": {
    "time": ["2024-01-01T12:00", "..."],
    "precipitation": [0.0, "..."]
  }
}
```

| 字段 | 说明 |
|------|------|
| `latitude`, `longitude` | 实际使用的天气网格单元中心坐标（可能与请求坐标相差几公里） |
| `elevation` | 网格单元海拔（米） |
| `generationtime_ms` | 响应生成耗时（毫秒），用于性能监控 |
| `utc_offset_seconds` | 由 `timezone` 参数产生的时区偏移秒数 |
| `timezone`, `timezone_abbreviation` | 时区标识（如 `Asia/Shanghai`）及缩写 |
| `hourly` / `daily` / `minutely_15` | 每个请求的变量对应一个浮点数组，外加 `time` 时间戳数组 |
| `hourly_units` / `daily_units` / `minutely_15_units` | 对应各变量的单位 |

### 本项目使用的变量

**hourly（逐小时）**

| 变量 | 有效时间 | 单位 | 说明 |
|------|----------|------|------|
| `temperature_2m` | 瞬时 | °C | 2 米气温 |
| `relativehumidity_2m` | 瞬时 | % | 2 米相对湿度 |
| `apparent_temperature` | 瞬时 | °C | 体感温度（综合风寒、湿度、太阳辐射） |
| `precipitation` | 前一小时累计 | mm | 总降水（雨、阵雨、雪） |
| `rain` | 前一小时累计 | mm | 大尺度天气系统降雨 |
| `weathercode` | 瞬时 | WMO 码 | 天气现象代码，见下表 |
| `surface_pressure` | 瞬时 | hPa | 地表气压 |
| `visibility` | 瞬时 | m | 能见度 |
| `evapotranspiration` | 前一小时累计 | mm | 蒸散发 |
| `windspeed_10m` | 瞬时 | km/h | 10 米风速 |
| `winddirection_10m` | 瞬时 | ° | 10 米风向 |
| `windgusts_10m` | 前一小时最大 | km/h | 10 米阵风 |
| `cloudcover` | 瞬时 | % | 总云量 |
| `uv_index` | 前一小时平均 | 指数 | 紫外线指数 |
| `dewpoint_2m` | 瞬时 | °C | 2 米露点温度 |
| `precipitation_probability` | 前一小时概率 | % | 降水概率（>0.1 mm，基于 0.25° 集合模型） |
| `shortwave_radiation` | 前一小时平均 | W/m² | 短波太阳辐射（水平面总辐照） |

**daily（逐日）**

| 变量 | 单位 | 说明 |
|------|------|------|
| `weathercode` | WMO 码 | 当日主导天气现象代码 |
| `temperature_2m_max` / `temperature_2m_min` | °C | 最高/最低气温 |
| `apparent_temperature_max` / `apparent_temperature_min` | °C | 最高/最低体感温度 |
| `sunrise` / `sunset` | iso8601 | 日出/日落时间 |
| `precipitation_sum` | mm | 当日总降水 |
| `precipitation_probability_max` | % | 当日最大降水概率 |
| `windspeed_10m_max` | km/h | 当日最大风速 |
| `windgusts_10m_max` | km/h | 当日最大阵风 |
| `uv_index_max` | 指数 | 当日最大紫外线指数 |
| `rain_sum` | mm | 当日总降雨（不含雪） |
| `winddirection_10m_dominant` | ° | 当日主导风向 |

**minutely_15（15 分钟）**

| 变量 | 单位 | 说明 |
|------|------|------|
| `precipitation` | mm | 15 分钟总降水 |
| `rain` | mm | 15 分钟降雨 |
| `showers` | mm | 15 分钟对流性阵雨 |
| `precipitation_probability` | % | 15 分钟降水概率 |

> 官方还提供大量其他变量：多层风速/风向/气温（20-200 m）、气压层变量
> （1000-10 hPa）、辐射分量（direct/diffuse/global_tilted）、土壤温湿度、
> 雪深、CAPE、闪电潜力、`is_day`、`sunshine_duration` 等，完整列表见官方文档。

### WMO 天气现象代码

`weathercode` 取值（与 Open-Meteo 服务端源码 `WeatherCode` 枚举一致）：

| 代码 | 含义 | 代码 | 含义 |
|------|------|------|------|
| 0 | 晴 | 61 | 小雨 |
| 1 | 大部晴朗 | 63 | 中雨 |
| 2 | 多云（局部多云） | 65 | 大雨 |
| 3 | 阴 | 66 | 小冻雨 |
| 45 | 雾 | 67 | 中到大冻雨 |
| 48 | 雾凇（沉积霜雾） | 71 | 小雪 |
| 51 | 小毛毛雨 | 73 | 中雪 |
| 53 | 中毛毛雨 | 75 | 大雪 |
| 55 | 大毛毛雨 | 77 | 米雪（雪粒） |
| 56 | 小冻毛毛雨 | 80 | 小阵雨 |
| 57 | 中到大冻毛毛雨 | 81 | 中阵雨 |
| 82 | 大阵雨 | 95 | 雷暴（小到中等） |
| 85 | 小阵雪 | 96 | 雷暴伴小冰雹 |
| 86 | 大阵雪 | 99 | 雷暴伴强冰雹 |

### 错误处理

参数错误时返回 HTTP 400 与 JSON 错误对象（实测）：

```json
{ "error": true, "reason": "Latitude must be in range of -90 to 90°. Given: 300.0." }
```

---

## 2. 地理编码 API（Geocoding API）

### 请求

```
GET https://geocoding-api.open-meteo.com/v1/search?name=北京&count=5&language=zh&format=json
```

本项目在 `OpenMeteoWeatherSource.searchCities` 中使用：`count=5`，`language` 跟随应用语言。

### URL 参数

| 参数 | 格式 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `name` | 字符串 | 是 | - | 地名或邮编；可在逗号后追加国家或一级行政区缩小范围，如 `Paris, France`、`Los Angeles, CA` |
| `count` | 整数 | 否 | 10 | 返回结果数，最多 100；国家/行政区过滤先于数量限制生效 |
| `format` | 字符串 | 否 | `json` | 另支持 `protobuf` |
| `language` | 字符串 | 否 | `en` | 结果本地化语言（小写）；无翻译时回退英文或本地名 |
| `countryCode` | 字符串 | 否 | - | ISO-3166-1 alpha2 国家码过滤 |
| `apikey` | 字符串 | 否 | - | 仅商业订阅使用客户域名时需要 |

**匹配规则**：地名 ≥3 个字符时做归一化前缀匹配（大小写、变音符号不敏感）；
逗号后的国家/行政区限定词必须精确匹配（支持国家全名、ISO 两字母码、一级行政区
名称及缩写）。空查询和单字符查询无结果。

### 响应结构

```json
{
  "results": [
    {
      "id": 1816670,
      "name": "北京",
      "latitude": 39.9075,
      "longitude": 116.39723,
      "elevation": 49.0,
      "feature_code": "PPLC",
      "country_code": "CN",
      "admin1_id": 2038349,
      "admin2_id": 11876380,
      "timezone": "Asia/Shanghai",
      "population": 18960744,
      "country_id": 1814991,
      "country": "中国",
      "admin1": "北京市",
      "admin2": "北京市"
    }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `id` | 地点唯一 ID，可通过 `/v1/get?id=...` 反查 |
| `name` | 地名，按 `language` 参数本地化 |
| `latitude`, `longitude` | WGS84 坐标 |
| `elevation` | 海拔（米） |
| `timezone` | IANA 时区 |
| `feature_code` | 地点类型（GeoNames 定义，如 `PPLC` 首都） |
| `country_code` / `country` / `country_id` | 国家码、国家名、国家 ID |
| `population` | 人口 |
| `postcodes` | 邮编列表 |
| `admin1`~`admin4` 及 `*_id` | 各级行政区名称与 ID（无数据的字段省略） |

### 错误处理

参数错误返回 HTTP 400（实测）：

```json
{ "error": true, "reason": "Parameter count must be between 1 and 100." }
```

---

## 3. 空气质量 API（Air Quality API）

基于哥白尼大气监测服务（CAMS）：欧洲区 11 km 分辨率（每小时更新，4 天预报）与
全球 45 km 分辨率（每 12 小时更新，5 天预报），两个域不耦合，结果可能不同。

### 请求

本项目在 `AirQualityRemoteDatasource` 中使用：

```
GET https://air-quality-api.open-meteo.com/v1/air-quality
    ?hourly=european_aqi,us_aqi,pm2_5,pm10,ozone,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide
    &forecast_days=7&timezone=auto
    &latitude=39.9042&longitude=116.4074
```

空气质量为可选数据：网络或解析失败时返回 null，不阻塞天气更新。

### URL 参数

| 参数 | 格式 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `latitude`, `longitude` | 浮点数 | 是 | - | WGS84 坐标，可逗号分隔批量请求 |
| `hourly` | 字符串数组 | 否 | - | 逐小时变量列表 |
| `current` | 字符串数组 | 否 | - | 当前实况变量列表（基于 15 分钟数据） |
| `domains` | 字符串 | 否 | `auto` | `auto` / `cams_europe` / `cams_global` |
| `timezone` | 字符串 | 否 | GMT | 同预报 API，支持 `auto` |
| `timeformat` | 字符串 | 否 | `iso8601` | 可选 `unixtime` |
| `past_days` | 整数 (0-92) | 否 | 0 | 返回过去天数 |
| `forecast_days` | 整数 (0-7) | 否 | 5 | 预报天数，最多 7 天 |
| `past_hours` / `forecast_hours` | 整数 (>0) | 否 | - | 小时级时间范围控制 |
| `start_date` / `end_date`、`start_hour` / `end_hour` | 字符串 | 否 | - | 指定时间区间 |
| `cell_selection` | 字符串 | 否 | `land` | `land` / `sea` / `nearest` |
| `apikey` | 字符串 | 否 | - | 仅商业订阅使用客户域名时需要 |

### 逐小时变量

| 变量 | 单位 | 说明 |
|------|------|------|
| `pm10`, `pm2_5` | μg/m³ | 近地面（10 m）颗粒物 |
| `carbon_monoxide`, `nitrogen_dioxide`, `sulphur_dioxide`, `ozone` | μg/m³ | 近地面气体污染物 |
| `carbon_dioxide` | ppm | 近地面 CO₂ |
| `ammonia` | μg/m³ | 氨（仅欧洲） |
| `methane` | μg/m³ | 甲烷 |
| `dust` | μg/m³ | 撒哈拉沙尘 |
| `aerosol_optical_depth` | 无量纲 | 550 nm 气溶胶光学厚度（霾指标） |
| `uv_index`, `uv_index_clear_sky` | 指数 | 紫外线指数（考虑云量 / 晴空） |
| `alder_pollen`, `birch_pollen`, `grass_pollen`, `mugwort_pollen`, `olive_pollen`, `ragweed_pollen` | Grains/m³ | 花粉浓度（仅欧洲花粉季，4 天预报） |
| `european_aqi`（含 `_pm2_5`/`_pm10`/`_nitrogen_dioxide`/`_ozone`/`_sulphur_dioxide` 分项） | 欧洲 AQI | 综合指数取各分项最大值：0-20 优、20-40 良、40-60 中、60-80 差、80-100 很差、>100 极差 |
| `us_aqi`（含 `_pm2_5`/`_pm10`/`_nitrogen_dioxide`/`_ozone`/`_sulphur_dioxide`/`_carbon_monoxide` 分项） | 美国 AQI | 综合指数取各分项最大值：0-50 优、51-100 良、101-150 敏感人群不健康、151-200 不健康、201-300 很不健康、301-500 危险 |

### 响应结构

```json
{
  "latitude": 52.52,
  "longitude": 13.419,
  "elevation": 44.812,
  "generationtime_ms": 2.2119,
  "utc_offset_seconds": 0,
  "timezone": "Europe/Berlin",
  "timezone_abbreviation": "CEST",
  "hourly_units": { "time": "iso8601", "pm10": "μg/m³" },
  "hourly": {
    "time": ["2022-07-01T00:00", "2022-07-01T01:00", "..."],
    "pm10": [1.0, 1.7, "..."]
  }
}
```

字段含义与预报 API 相同（网格单元坐标、海拔、生成耗时、时区信息、`hourly` 数据与单位）。

### 错误处理

与其他接口一致，HTTP 400 返回 `{"error": true, "reason": "..."}`。

---

## 参考链接

- 天气预报 API：<https://open-meteo.com/en/docs>
- 地理编码 API：<https://open-meteo.com/en/docs/geocoding-api>
- 空气质量 API：<https://open-meteo.com/en/docs/air-quality-api>
- 使用条款：<https://open-meteo.com/en/terms>
- 许可（CC BY 4.0）：<https://open-meteo.com/en/licence>
- 服务端源码（AGPLv3）：<https://github.com/open-meteo/open-meteo>
