import 'dart:convert';
import 'dart:io';

import 'package:dreamflow/data/df_crisis_config.dart';
import 'package:dreamflow/data/df_mood.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// M12：危机配置的解析、合并与拉取降级。
///
/// 这层的安全线必须钉死：底线词表和 12356 无论远端发生什么都得在——
/// 远端配置是「增强」，不是「依赖」。
void main() {
  Map<String, dynamic> payload({
    List<String>? words,
    List<Map<String, String>>? hotlines,
  }) =>
      <String, dynamic>{
        'words': words ??
            <String>['撑不下去了', '解脱'],
        'hotlines': hotlines ??
            <Map<String, String>>[
              <String, String>{'name': '北京心理援助热线', 'number': '010-82951332'},
        ],
      };

  http.Response okResp(Map<String, dynamic> row) => http.Response(
        jsonEncode(<Object>[row]),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );

  group('parseRemote（整包拒绝，不做部分采纳）', () {
    test('合法 payload 通过，词去重', () {
      final DfCrisisPayload? p = DfCrisisConfig.parseRemote(
        payload(words: <String>['解脱', '解脱', '撑不下去了']),
      );
      expect(p, isNotNull);
      expect(p!.words, <String>['解脱', '撑不下去了']);
      expect(p.hotlines.length, 1);
    });

    test('words 里混入单字词 → 拒绝（太短会误伤）', () {
      expect(
        DfCrisisConfig.parseRemote(payload(words: <String>['死'])),
        isNull,
      );
    });

    test('词超过 12 字 / 含空白 → 拒绝', () {
      expect(
        DfCrisisConfig.parseRemote(
          payload(words: <String>['这句话长得完全不像一个关键词了']),
        ),
        isNull,
      );
      expect(
        DfCrisisConfig.parseRemote(payload(words: <String>['不想 活'])),
        isNull,
      );
    });

    test('words 非法类型 / 空表 → 拒绝', () {
      expect(DfCrisisConfig.parseRemote(<String, dynamic>{
        'words': '不想活',
        'hotlines': <Object>[],
      }), isNull);
      expect(DfCrisisConfig.parseRemote(payload(words: <String>[])), isNull);
    });

    test('hotlines 为空 / 号码带字母 → 拒绝', () {
      expect(DfCrisisConfig.parseRemote(payload(hotlines: <Map<String, String>>[])),
          isNull);
      expect(
        DfCrisisConfig.parseRemote(
          payload(hotlines: <Map<String, String>>[
            <String, String>{'name': '假热线', 'number': 'call-110'},
          ]),
        ),
        isNull,
      );
    });

    test('payload 根本不是 Map → 拒绝', () {
      expect(DfCrisisConfig.parseRemote('not a map'), isNull);
    });
  });

  group('合并安全线', () {
    test('底线词不可移除：远端只给一个词，17 个底线词仍然全在', () {
      final List<String> merged = DfCrisisConfig.mergeWords(
        <String>['解脱'],
      );
      for (final String w in DfMood.crisisWords) {
        expect(merged.contains(w), isTrue, reason: '底线词 $w 丢了');
      }
      expect(merged.contains('解脱'), isTrue);
      expect(merged.first, DfMood.crisisWords.first);
    });

    test('底线热线不可移除，远端热线按号码追加去重', () {
      final List<DfHotline> merged = DfCrisisConfig.mergeHotlines(
        <DfHotline>[
          const DfHotline(name: '北京', number: '010-82951332'),
          const DfHotline(name: '重复的12356', number: '12356'),
        ],
      );
      expect(merged.length, 2);
      expect(merged.first.number, '12356');
      expect(merged.first.name, '全国心理援助热线');
    });
  });

  group('isCrisisWith', () {
    test('底线词照常命中', () {
      expect(DfMood.isCrisisWith('我想死', const <String>['解脱']), isTrue);
      expect(DfMood.isCrisisWith('今天挺好', const <String>['解脱']), isFalse);
    });

    test('追加词命中，且对空白做了归一化', () {
      expect(
        DfMood.isCrisisWith('感觉撑不下去了', const <String>['撑不下去了']),
        isTrue,
      );
      expect(
        DfMood.isCrisisWith('撑 不 下 去 了', const <String>['撑不下去了']),
        isTrue,
      );
      expect(DfMood.isCrisisWith('还行', const <String>['解脱']), isFalse);
    });
  });

  group('refresh（网络降级）', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('crisis_cfg'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<DfCrisisConfig> fresh() async {
      final DfCrisisConfig c = DfCrisisConfig.instance..resetForTest();
      return c;
    }

    test('200 + 合法 → 生效并写缓存', () async {
      final DfCrisisConfig c = await fresh();
      await c.refresh(
        client: MockClient(
          (http.Request r) async => okResp(<String, dynamic>{
            'version': 7,
            'payload': payload(),
          }),
        ),
        cacheDir: tmp,
      );
      expect(c.status, DfCrisisStatus.ready);
      expect(c.version, 7);
      expect(c.extraWords, <String>['撑不下去了', '解脱']);
      expect(File('${tmp.path}/crisis_config.json').existsSync(), isTrue);
    });

    test('200 + 非法 payload → 保持内置，不升级状态', () async {
      final DfCrisisConfig c = await fresh();
      await c.refresh(
        client: MockClient(
          (http.Request r) async => okResp(<String, dynamic>{
            'version': 8,
            'payload': <String, dynamic>{'words': '坏的', 'hotlines': <Object>[]},
          }),
        ),
        cacheDir: tmp,
      );
      expect(c.status, DfCrisisStatus.fallback);
      expect(c.extraWords, isEmpty);
    });

    test('500 / 抛异常 → 保持内置', () async {
      final DfCrisisConfig c = await fresh();
      await c.refresh(
        client: MockClient((http.Request r) async => http.Response('boom', 500)),
        cacheDir: tmp,
      );
      expect(c.status, DfCrisisStatus.fallback);
      expect(c.extraWords, isEmpty);
    });

    test('缓存往返：断网时 load() 恢复上次远端词表', () async {
      final DfCrisisConfig first = await fresh();
      await first.refresh(
        client: MockClient(
          (http.Request r) async => okResp(<String, dynamic>{
            'version': 9,
            'payload': payload(),
          }),
        ),
        cacheDir: tmp,
      );

      final DfCrisisConfig second = await fresh();
      await second.load(cacheDir: tmp);
      expect(second.status, DfCrisisStatus.fromCache);
      expect(second.version, 9);
      expect(second.extraWords, <String>['撑不下去了', '解脱']);
    });

    test('损坏的缓存被无视，退回内置', () async {
      File('${tmp.path}/crisis_config.json')
          .writeAsStringSync('{"payload": "垃圾"}');
      final DfCrisisConfig c = await fresh();
      await c.load(cacheDir: tmp);
      expect(c.extraWords, isEmpty);
      expect(c.status, DfCrisisStatus.idle);
    });
  });

  test('主热线恒为 12356', () {
    expect(DfCrisisConfig.instance.primaryHotline.number, '12356');
  });
}
