import 'package:flutter_test/flutter_test.dart';

import 'package:dreamflow/data/df_account.dart';
import 'package:dreamflow/data/df_greeting.dart';

/// M7：本机账号与首页招呼语。
///
/// 账号这层没有服务端，能验证的只有「状态迁移对不对」和「输入怎么被规范化」。
/// 落盘部分在测试环境里拿不到 path_provider，`_persist` 会静默失败 ——
/// 这正好把内存态和持久化分离开，测试只断言内存态。
void main() {
  // 测试环境没有 path_provider，关掉落盘只验状态机
  DfAccount.persistenceEnabled = false;

  group('用户名规范化', () {
    test('首尾空白被裁掉', () {
      expect(DfAccount.normalizeName('  林小满  '), '林小满');
    });

    test('连续空格压成一个', () {
      expect(DfAccount.normalizeName('林   小满'), '林 小满');
    });

    test('全空白 → null（不能拿空白当名字）', () {
      expect(DfAccount.normalizeName('   '), isNull);
      expect(DfAccount.normalizeName('\n\t'), isNull);
      expect(DfAccount.normalizeName(''), isNull);
    });

    test('超长按字符截断，不会切坏 emoji', () {
      final String long = '一' * 20;
      expect(DfAccount.normalizeName(long)!.runes.length, DfAccount.maxNameLength);

      // 4 个 emoji = 8 个 UTF-16 code unit，但只有 4 个字符，不该被截
      const String emoji = '🌙🌙🌙🌙';
      expect(DfAccount.normalizeName(emoji), emoji);
    });
  });

  group('登录 / 改名 / 退出', () {
    final DfAccount a = DfAccount.instance;

    setUp(() async {
      // 每个用例从「干净」开始：直接走登录，不依赖上一个用例的残留
      await a.signIn('初始名');
    });

    test('空名字登录失败，且不改变登录态', () async {
      await a.signOut();
      expect(await a.signIn('   '), isFalse);
      expect(a.signedIn, isFalse);
    });

    test('登录后 signedIn 为真，displayName 是用户名', () async {
      expect(a.signedIn, isTrue);
      expect(a.username, '初始名');
      expect(a.displayName, '初始名');
    });

    test('改名不重置加入时间', () async {
      final DateTime? joined = a.joinedAt;
      await a.rename('新名字');
      expect(a.username, '新名字');
      expect(a.joinedAt, joined);
      expect(a.joinedDay, 1);
    });

    test('改名成空串被拒绝，名字保持原样', () async {
      expect(await a.rename('  '), isFalse);
      expect(a.username, '初始名');
    });

    test('退出登录只摘标记，用户名还在（数据不丢）', () async {
      await a.signOut();
      expect(a.signedIn, isFalse);
      expect(a.username, '初始名');
      expect(a.displayName, '初始名');
    });

    test('头像取首字符', () async {
      await a.rename('林小满');
      expect(a.initial, '林');
    });
  });

  group('自定义头像（M9）', () {
    final DfAccount a = DfAccount.instance;

    setUp(() async {
      await a.signIn('初始名');
    });

    test('setAvatar 记下路径，界面上据此画图而不是首字符', () async {
      expect(a.avatarPath, isNull);
      await a.setAvatar('/data/media/avatar_1.jpg');
      expect(a.avatarPath, '/data/media/avatar_1.jpg');
    });

    test('换头像是替换：路径更新', () async {
      await a.setAvatar('/data/media/avatar_1.jpg');
      await a.setAvatar('/data/media/avatar_2.jpg');
      expect(a.avatarPath, '/data/media/avatar_2.jpg');
    });

    test('clearAvatar 回到默认（null = 首字符头像）', () async {
      await a.setAvatar('/data/media/avatar_1.jpg');
      await a.clearAvatar();
      expect(a.avatarPath, isNull);
    });

    test('clearAvatar 在没有自定义头像时是空操作，不发通知', () async {
      expect(a.avatarPath, isNull);
      int calls = 0;
      void listener() => calls++;
      a.addListener(listener);
      await a.clearAvatar();
      a.removeListener(listener);
      expect(calls, 0);
    });

    test('换头像会通知界面重绘', () async {
      int calls = 0;
      void listener() => calls++;
      a.addListener(listener);
      await a.setAvatar('/data/media/avatar_1.jpg');
      a.removeListener(listener);
      expect(calls, 1);
    });
  });

  group('招呼语', () {
    test('时段边界', () {
      expect(dfDayPart(DateTime(2026, 10, 28, 4, 59)), DfDayPart.lateNight);
      expect(dfDayPart(DateTime(2026, 10, 28, 5, 0)), DfDayPart.morning);
      expect(dfDayPart(DateTime(2026, 10, 28, 8, 59)), DfDayPart.morning);
      expect(dfDayPart(DateTime(2026, 10, 28, 9, 0)), DfDayPart.forenoon);
      expect(dfDayPart(DateTime(2026, 10, 28, 11, 59)), DfDayPart.forenoon);
      expect(dfDayPart(DateTime(2026, 10, 28, 12, 0)), DfDayPart.noon);
      expect(dfDayPart(DateTime(2026, 10, 28, 13, 59)), DfDayPart.noon);
      expect(dfDayPart(DateTime(2026, 10, 28, 14, 0)), DfDayPart.afternoon);
      expect(dfDayPart(DateTime(2026, 10, 28, 17, 59)), DfDayPart.afternoon);
      expect(dfDayPart(DateTime(2026, 10, 28, 18, 0)), DfDayPart.evening);
      expect(dfDayPart(DateTime(2026, 10, 28, 22, 59)), DfDayPart.evening);
      expect(dfDayPart(DateTime(2026, 10, 28, 23, 0)), DfDayPart.lateNight);
    });

    test('没名字就只有招呼语，不带多余的逗号', () {
      final DateTime t = DateTime(2026, 10, 28, 20, 0);
      expect(dfGreetingLine(null, t), '晚上好');
      expect(dfGreetingLine('', t), '晚上好');
      expect(dfGreetingLine('   ', t), '晚上好');
    });

    test('有名字拼成「晚上好，林小满」', () {
      final DateTime t = DateTime(2026, 10, 28, 20, 0);
      expect(dfGreetingLine('林小满', t), '晚上好，林小满');
    });

    test('白天走白天的招呼语', () {
      expect(
        dfGreetingLine('林小满', DateTime(2026, 10, 28, 9, 30)),
        '上午好，林小满',
      );
      expect(
        dfGreetingLine('林小满', DateTime(2026, 10, 28, 15, 0)),
        '下午好，林小满',
      );
    });

    test('每个时段都有副标题，且不重复', () {
      final Set<String> subs = <String>{
        for (final DfDayPart p in DfDayPart.values) dfGreetingSub(p),
      };
      expect(subs.length, DfDayPart.values.length);
    });
  });
}
