/// 农历转换工具类
/// 支持公历到农历的转换
class LunarCalendar {
  /// 农历月份名称
  static const List<String> _lunarMonths = [
    '正', '二', '三', '四', '五', '六',
    '七', '八', '九', '十', '冬', '腊'
  ];

  /// 农历日期名称
  static const List<String> _lunarDays = [
    '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
    '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
    '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十'
  ];

  /// 天干
  static const List<String> _heavenlyStems = [
    '甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'
  ];

  /// 地支
  static const List<String> _earthlyBranches = [
    '子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'
  ];

  /// 生肖
  static const List<String> _zodiacAnimals = [
    '鼠', '牛', '虎', '兔', '龙', '蛇',
    '马', '羊', '猴', '鸡', '狗', '猪'
  ];

  /// 将公历日期转换为农历
  /// 
  /// 由于农历计算复杂，这里使用简化的算法
  /// 对于精确计算，建议使用第三方库如 lunar
  static String solarToLunar(DateTime date) {
    // 使用基准日期 1900-01-31 作为农历1900年正月初一
    final baseDate = DateTime(1900, 1, 31);
    final diff = date.difference(baseDate).inDays;
    
    if (diff < 0) {
      return '日期太早';
    }

    // 简化的农历计算
    // 这里使用近似算法，实际应用建议使用完整的农历表
    final lunarYear = date.year;
    final isLeapYear = _isLeapYear(lunarYear);
    
    // 计算农历年份（简化）
    final yearDiff = lunarYear - 1900;
    final yearStem = _heavenlyStems[(yearDiff + 6) % 10];  // 1900年是庚子年
    final yearBranch = _earthlyBranches[(yearDiff + 0) % 12];
    final yearGanZhi = '$yearStem$yearBranch';
    
    // 计算农历月份（简化，基于节气）
    // 实际上农历月份根据节气确定，这里使用近似值
    int lunarMonth;
    if (date.month < 2) {
      lunarMonth = 11;  // 冬月
    } else if (date.month < 4) {
      lunarMonth = 12;  // 腊月
    } else if (date.month < 5) {
      lunarMonth = 1;   // 正月
    } else if (date.month < 6) {
      lunarMonth = 2;   // 二月
    } else if (date.month < 7) {
      lunarMonth = 3;   // 三月
    } else if (date.month < 8) {
      lunarMonth = 4;   // 四月
    } else if (date.month < 9) {
      lunarMonth = 5;   // 五月
    } else if (date.month < 10) {
      lunarMonth = 6;   // 六月
    } else if (date.month < 11) {
      lunarMonth = 7;   // 七月
    } else if (date.month < 12) {
      lunarMonth = 8;   // 八月
    } else {
      lunarMonth = 9;   // 九月
    }

    // 计算农历日期（简化）
    // 实际计算需要考虑朔望月长度（29.53天）
    final dayOfMonth = date.day;
    int lunarDay;
    if (dayOfMonth <= 10) {
      lunarDay = dayOfMonth + 20;  // 简化处理
    } else {
      lunarDay = dayOfMonth - 10;
    }
    
    // 确保日期在有效范围内
    lunarDay = lunarDay.clamp(1, 30);

    return '${_lunarMonths[lunarMonth - 1]}月${_lunarDays[lunarDay - 1]}';
  }

  /// 获取生肖
  static String getZodiac(int year) {
    final index = (year - 4) % 12;
    return _zodiacAnimals[index];
  }

  /// 获取干支纪年
  static String getGanZhi(int year) {
    final yearDiff = year - 1900;
    final stem = _heavenlyStems[(yearDiff + 6) % 10];
    final branch = _earthlyBranches[(yearDiff + 0) % 12];
    return '$stem$branch';
  }

  /// 判断是否为闰年
  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// 获取当前农历日期（简化版）
  static String getCurrentLunarDate() {
    return solarToLunar(DateTime.now());
  }

  /// 获取指定日期的农历日期（简化版）
  /// 
  /// 注意：这是一个简化实现，精确计算需要完整的农历数据表
  /// 建议使用第三方库如 https://pub.dev/packages/lunar
  static String getLunarDateSimple(DateTime date) {
    return solarToLunar(date);
  }
}
