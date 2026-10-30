/// 首页招呼语（M7）
///
/// 以前首页写死「晚安，刘同学」—— 名字不对，白天进来也不对。
/// 现在按时段给招呼语，再拼上用户名：
///
/// | 时段 | 招呼语 |
/// |------|--------|
/// | 00:00–04:59 | 夜深了 |
/// | 05:00–08:59 | 早上好 |
/// | 09:00–11:59 | 上午好 |
/// | 12:00–13:59 | 中午好 |
/// | 14:00–17:59 | 下午好 |
/// | 18:00–22:59 | 晚上好 |
/// | 23:00–23:59 | 夜深了 |
///
/// 为什么夜里 23 点之后改口叫「夜深了」而不是「晚上好」：
/// 这个点打开助眠 App 的人不需要被问候，需要的是被理解。
library;

enum DfDayPart { lateNight, morning, forenoon, noon, afternoon, evening }

/// 当前处于哪个时段。[now] 显式传入，测试才不用改系统时间。
DfDayPart dfDayPart(DateTime now) {
  final int h = now.hour;
  if (h < 5) return DfDayPart.lateNight;
  if (h < 9) return DfDayPart.morning;
  if (h < 12) return DfDayPart.forenoon;
  if (h < 14) return DfDayPart.noon;
  if (h < 18) return DfDayPart.afternoon;
  if (h < 23) return DfDayPart.evening;
  return DfDayPart.lateNight;
}

/// 只有招呼语本身，不带名字
String dfGreeting(DfDayPart part) {
  switch (part) {
    case DfDayPart.lateNight:
      return '夜深了';
    case DfDayPart.morning:
      return '早上好';
    case DfDayPart.forenoon:
      return '上午好';
    case DfDayPart.noon:
      return '中午好';
    case DfDayPart.afternoon:
      return '下午好';
    case DfDayPart.evening:
      return '晚上好';
  }
}

/// 副标题：和招呼语同一时段，说一句贴合当下的话。
String dfGreetingSub(DfDayPart part) {
  switch (part) {
    case DfDayPart.lateNight:
      return '让梦洄陪你，慢慢沉入夜里';
    case DfDayPart.morning:
      return '刚醒也没关系，先在这里坐一会儿';
    case DfDayPart.forenoon:
      return '新的一天，从一句真话开始';
    case DfDayPart.noon:
      return '忙到一半，也可以停一停';
    case DfDayPart.afternoon:
      return '把心里的事放一放，随时回来';
    case DfDayPart.evening:
      return '今天辛苦了，说两句再睡';
  }
}

/// 完整的一行：「晚上好，林小满」；没有名字就只有「晚上好」。
String dfGreetingLine(String? name, DateTime now) {
  final String g = dfGreeting(dfDayPart(now));
  final String n = name?.trim() ?? '';
  if (n.isEmpty) return g;
  return '$g，$n';
}
