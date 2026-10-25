// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $MoodRecordsTable extends MoodRecords
    with TableInfo<$MoodRecordsTable, MoodRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MoodRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _moodLabelMeta =
      const VerificationMeta('moodLabel');
  @override
  late final GeneratedColumn<String> moodLabel = GeneratedColumn<String>(
      'mood_label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _intensityMeta =
      const VerificationMeta('intensity');
  @override
  late final GeneratedColumn<int> intensity = GeneratedColumn<int>(
      'intensity', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('chat'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, moodLabel, intensity, source, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mood_records';
  @override
  VerificationContext validateIntegrity(Insertable<MoodRecord> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mood_label')) {
      context.handle(_moodLabelMeta,
          moodLabel.isAcceptableOrUnknown(data['mood_label']!, _moodLabelMeta));
    } else if (isInserting) {
      context.missing(_moodLabelMeta);
    }
    if (data.containsKey('intensity')) {
      context.handle(_intensityMeta,
          intensity.isAcceptableOrUnknown(data['intensity']!, _intensityMeta));
    } else if (isInserting) {
      context.missing(_intensityMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MoodRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MoodRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      moodLabel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mood_label'])!,
      intensity: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}intensity'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $MoodRecordsTable createAlias(String alias) {
    return $MoodRecordsTable(attachedDatabase, alias);
  }
}

class MoodRecord extends DataClass implements Insertable<MoodRecord> {
  final int id;
  final String moodLabel;
  final int intensity;
  final String source;
  final DateTime createdAt;
  const MoodRecord(
      {required this.id,
      required this.moodLabel,
      required this.intensity,
      required this.source,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mood_label'] = Variable<String>(moodLabel);
    map['intensity'] = Variable<int>(intensity);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MoodRecordsCompanion toCompanion(bool nullToAbsent) {
    return MoodRecordsCompanion(
      id: Value(id),
      moodLabel: Value(moodLabel),
      intensity: Value(intensity),
      source: Value(source),
      createdAt: Value(createdAt),
    );
  }

  factory MoodRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MoodRecord(
      id: serializer.fromJson<int>(json['id']),
      moodLabel: serializer.fromJson<String>(json['moodLabel']),
      intensity: serializer.fromJson<int>(json['intensity']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'moodLabel': serializer.toJson<String>(moodLabel),
      'intensity': serializer.toJson<int>(intensity),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  MoodRecord copyWith(
          {int? id,
          String? moodLabel,
          int? intensity,
          String? source,
          DateTime? createdAt}) =>
      MoodRecord(
        id: id ?? this.id,
        moodLabel: moodLabel ?? this.moodLabel,
        intensity: intensity ?? this.intensity,
        source: source ?? this.source,
        createdAt: createdAt ?? this.createdAt,
      );
  MoodRecord copyWithCompanion(MoodRecordsCompanion data) {
    return MoodRecord(
      id: data.id.present ? data.id.value : this.id,
      moodLabel: data.moodLabel.present ? data.moodLabel.value : this.moodLabel,
      intensity: data.intensity.present ? data.intensity.value : this.intensity,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MoodRecord(')
          ..write('id: $id, ')
          ..write('moodLabel: $moodLabel, ')
          ..write('intensity: $intensity, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, moodLabel, intensity, source, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MoodRecord &&
          other.id == this.id &&
          other.moodLabel == this.moodLabel &&
          other.intensity == this.intensity &&
          other.source == this.source &&
          other.createdAt == this.createdAt);
}

class MoodRecordsCompanion extends UpdateCompanion<MoodRecord> {
  final Value<int> id;
  final Value<String> moodLabel;
  final Value<int> intensity;
  final Value<String> source;
  final Value<DateTime> createdAt;
  const MoodRecordsCompanion({
    this.id = const Value.absent(),
    this.moodLabel = const Value.absent(),
    this.intensity = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MoodRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String moodLabel,
    required int intensity,
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : moodLabel = Value(moodLabel),
        intensity = Value(intensity);
  static Insertable<MoodRecord> custom({
    Expression<int>? id,
    Expression<String>? moodLabel,
    Expression<int>? intensity,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (moodLabel != null) 'mood_label': moodLabel,
      if (intensity != null) 'intensity': intensity,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MoodRecordsCompanion copyWith(
      {Value<int>? id,
      Value<String>? moodLabel,
      Value<int>? intensity,
      Value<String>? source,
      Value<DateTime>? createdAt}) {
    return MoodRecordsCompanion(
      id: id ?? this.id,
      moodLabel: moodLabel ?? this.moodLabel,
      intensity: intensity ?? this.intensity,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (moodLabel.present) {
      map['mood_label'] = Variable<String>(moodLabel.value);
    }
    if (intensity.present) {
      map['intensity'] = Variable<int>(intensity.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MoodRecordsCompanion(')
          ..write('id: $id, ')
          ..write('moodLabel: $moodLabel, ')
          ..write('intensity: $intensity, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SleepSessionsTable extends SleepSessions
    with TableInfo<$SleepSessionsTable, SleepSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SleepSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
      'score', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _deepMinutesMeta =
      const VerificationMeta('deepMinutes');
  @override
  late final GeneratedColumn<int> deepMinutes = GeneratedColumn<int>(
      'deep_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _awakeningsMeta =
      const VerificationMeta('awakenings');
  @override
  late final GeneratedColumn<int> awakenings = GeneratedColumn<int>(
      'awakenings', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, startedAt, endedAt, score, deepMinutes, awakenings, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sleep_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<SleepSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('score')) {
      context.handle(
          _scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    }
    if (data.containsKey('deep_minutes')) {
      context.handle(
          _deepMinutesMeta,
          deepMinutes.isAcceptableOrUnknown(
              data['deep_minutes']!, _deepMinutesMeta));
    }
    if (data.containsKey('awakenings')) {
      context.handle(
          _awakeningsMeta,
          awakenings.isAcceptableOrUnknown(
              data['awakenings']!, _awakeningsMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SleepSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SleepSession(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at']),
      score: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}score']),
      deepMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deep_minutes'])!,
      awakenings: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}awakenings'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
    );
  }

  @override
  $SleepSessionsTable createAlias(String alias) {
    return $SleepSessionsTable(attachedDatabase, alias);
  }
}

class SleepSession extends DataClass implements Insertable<SleepSession> {
  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? score;
  final int deepMinutes;
  final int awakenings;
  final String? note;
  const SleepSession(
      {required this.id,
      required this.startedAt,
      this.endedAt,
      this.score,
      required this.deepMinutes,
      required this.awakenings,
      this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<int>(score);
    }
    map['deep_minutes'] = Variable<int>(deepMinutes);
    map['awakenings'] = Variable<int>(awakenings);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  SleepSessionsCompanion toCompanion(bool nullToAbsent) {
    return SleepSessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      score:
          score == null && nullToAbsent ? const Value.absent() : Value(score),
      deepMinutes: Value(deepMinutes),
      awakenings: Value(awakenings),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory SleepSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SleepSession(
      id: serializer.fromJson<int>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      score: serializer.fromJson<int?>(json['score']),
      deepMinutes: serializer.fromJson<int>(json['deepMinutes']),
      awakenings: serializer.fromJson<int>(json['awakenings']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'score': serializer.toJson<int?>(score),
      'deepMinutes': serializer.toJson<int>(deepMinutes),
      'awakenings': serializer.toJson<int>(awakenings),
      'note': serializer.toJson<String?>(note),
    };
  }

  SleepSession copyWith(
          {int? id,
          DateTime? startedAt,
          Value<DateTime?> endedAt = const Value.absent(),
          Value<int?> score = const Value.absent(),
          int? deepMinutes,
          int? awakenings,
          Value<String?> note = const Value.absent()}) =>
      SleepSession(
        id: id ?? this.id,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
        score: score.present ? score.value : this.score,
        deepMinutes: deepMinutes ?? this.deepMinutes,
        awakenings: awakenings ?? this.awakenings,
        note: note.present ? note.value : this.note,
      );
  SleepSession copyWithCompanion(SleepSessionsCompanion data) {
    return SleepSession(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      score: data.score.present ? data.score.value : this.score,
      deepMinutes:
          data.deepMinutes.present ? data.deepMinutes.value : this.deepMinutes,
      awakenings:
          data.awakenings.present ? data.awakenings.value : this.awakenings,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SleepSession(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('score: $score, ')
          ..write('deepMinutes: $deepMinutes, ')
          ..write('awakenings: $awakenings, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, startedAt, endedAt, score, deepMinutes, awakenings, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SleepSession &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.score == this.score &&
          other.deepMinutes == this.deepMinutes &&
          other.awakenings == this.awakenings &&
          other.note == this.note);
}

class SleepSessionsCompanion extends UpdateCompanion<SleepSession> {
  final Value<int> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int?> score;
  final Value<int> deepMinutes;
  final Value<int> awakenings;
  final Value<String?> note;
  const SleepSessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.score = const Value.absent(),
    this.deepMinutes = const Value.absent(),
    this.awakenings = const Value.absent(),
    this.note = const Value.absent(),
  });
  SleepSessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.score = const Value.absent(),
    this.deepMinutes = const Value.absent(),
    this.awakenings = const Value.absent(),
    this.note = const Value.absent(),
  }) : startedAt = Value(startedAt);
  static Insertable<SleepSession> custom({
    Expression<int>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? score,
    Expression<int>? deepMinutes,
    Expression<int>? awakenings,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (score != null) 'score': score,
      if (deepMinutes != null) 'deep_minutes': deepMinutes,
      if (awakenings != null) 'awakenings': awakenings,
      if (note != null) 'note': note,
    });
  }

  SleepSessionsCompanion copyWith(
      {Value<int>? id,
      Value<DateTime>? startedAt,
      Value<DateTime?>? endedAt,
      Value<int?>? score,
      Value<int>? deepMinutes,
      Value<int>? awakenings,
      Value<String?>? note}) {
    return SleepSessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      score: score ?? this.score,
      deepMinutes: deepMinutes ?? this.deepMinutes,
      awakenings: awakenings ?? this.awakenings,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (deepMinutes.present) {
      map['deep_minutes'] = Variable<int>(deepMinutes.value);
    }
    if (awakenings.present) {
      map['awakenings'] = Variable<int>(awakenings.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SleepSessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('score: $score, ')
          ..write('deepMinutes: $deepMinutes, ')
          ..write('awakenings: $awakenings, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

abstract class _$DreamFlowDb extends GeneratedDatabase {
  _$DreamFlowDb(QueryExecutor e) : super(e);
  $DreamFlowDbManager get managers => $DreamFlowDbManager(this);
  late final $MoodRecordsTable moodRecords = $MoodRecordsTable(this);
  late final $SleepSessionsTable sleepSessions = $SleepSessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [moodRecords, sleepSessions];
}

typedef $$MoodRecordsTableCreateCompanionBuilder = MoodRecordsCompanion
    Function({
  Value<int> id,
  required String moodLabel,
  required int intensity,
  Value<String> source,
  Value<DateTime> createdAt,
});
typedef $$MoodRecordsTableUpdateCompanionBuilder = MoodRecordsCompanion
    Function({
  Value<int> id,
  Value<String> moodLabel,
  Value<int> intensity,
  Value<String> source,
  Value<DateTime> createdAt,
});

class $$MoodRecordsTableFilterComposer
    extends Composer<_$DreamFlowDb, $MoodRecordsTable> {
  $$MoodRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get moodLabel => $composableBuilder(
      column: $table.moodLabel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get intensity => $composableBuilder(
      column: $table.intensity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$MoodRecordsTableOrderingComposer
    extends Composer<_$DreamFlowDb, $MoodRecordsTable> {
  $$MoodRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get moodLabel => $composableBuilder(
      column: $table.moodLabel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get intensity => $composableBuilder(
      column: $table.intensity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$MoodRecordsTableAnnotationComposer
    extends Composer<_$DreamFlowDb, $MoodRecordsTable> {
  $$MoodRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get moodLabel =>
      $composableBuilder(column: $table.moodLabel, builder: (column) => column);

  GeneratedColumn<int> get intensity =>
      $composableBuilder(column: $table.intensity, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MoodRecordsTableTableManager extends RootTableManager<
    _$DreamFlowDb,
    $MoodRecordsTable,
    MoodRecord,
    $$MoodRecordsTableFilterComposer,
    $$MoodRecordsTableOrderingComposer,
    $$MoodRecordsTableAnnotationComposer,
    $$MoodRecordsTableCreateCompanionBuilder,
    $$MoodRecordsTableUpdateCompanionBuilder,
    (MoodRecord, BaseReferences<_$DreamFlowDb, $MoodRecordsTable, MoodRecord>),
    MoodRecord,
    PrefetchHooks Function()> {
  $$MoodRecordsTableTableManager(_$DreamFlowDb db, $MoodRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MoodRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MoodRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MoodRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> moodLabel = const Value.absent(),
            Value<int> intensity = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              MoodRecordsCompanion(
            id: id,
            moodLabel: moodLabel,
            intensity: intensity,
            source: source,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String moodLabel,
            required int intensity,
            Value<String> source = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              MoodRecordsCompanion.insert(
            id: id,
            moodLabel: moodLabel,
            intensity: intensity,
            source: source,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MoodRecordsTable, MoodRecord>(table),
                    BaseReferences<_$DreamFlowDb, $MoodRecordsTable,
                        MoodRecord>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MoodRecordsTableProcessedTableManager = ProcessedTableManager<
    _$DreamFlowDb,
    $MoodRecordsTable,
    MoodRecord,
    $$MoodRecordsTableFilterComposer,
    $$MoodRecordsTableOrderingComposer,
    $$MoodRecordsTableAnnotationComposer,
    $$MoodRecordsTableCreateCompanionBuilder,
    $$MoodRecordsTableUpdateCompanionBuilder,
    (MoodRecord, BaseReferences<_$DreamFlowDb, $MoodRecordsTable, MoodRecord>),
    MoodRecord,
    PrefetchHooks Function()>;
typedef $$SleepSessionsTableCreateCompanionBuilder = SleepSessionsCompanion
    Function({
  Value<int> id,
  required DateTime startedAt,
  Value<DateTime?> endedAt,
  Value<int?> score,
  Value<int> deepMinutes,
  Value<int> awakenings,
  Value<String?> note,
});
typedef $$SleepSessionsTableUpdateCompanionBuilder = SleepSessionsCompanion
    Function({
  Value<int> id,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<int?> score,
  Value<int> deepMinutes,
  Value<int> awakenings,
  Value<String?> note,
});

class $$SleepSessionsTableFilterComposer
    extends Composer<_$DreamFlowDb, $SleepSessionsTable> {
  $$SleepSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deepMinutes => $composableBuilder(
      column: $table.deepMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get awakenings => $composableBuilder(
      column: $table.awakenings, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$SleepSessionsTableOrderingComposer
    extends Composer<_$DreamFlowDb, $SleepSessionsTable> {
  $$SleepSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deepMinutes => $composableBuilder(
      column: $table.deepMinutes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get awakenings => $composableBuilder(
      column: $table.awakenings, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$SleepSessionsTableAnnotationComposer
    extends Composer<_$DreamFlowDb, $SleepSessionsTable> {
  $$SleepSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get deepMinutes => $composableBuilder(
      column: $table.deepMinutes, builder: (column) => column);

  GeneratedColumn<int> get awakenings => $composableBuilder(
      column: $table.awakenings, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$SleepSessionsTableTableManager extends RootTableManager<
    _$DreamFlowDb,
    $SleepSessionsTable,
    SleepSession,
    $$SleepSessionsTableFilterComposer,
    $$SleepSessionsTableOrderingComposer,
    $$SleepSessionsTableAnnotationComposer,
    $$SleepSessionsTableCreateCompanionBuilder,
    $$SleepSessionsTableUpdateCompanionBuilder,
    (
      SleepSession,
      BaseReferences<_$DreamFlowDb, $SleepSessionsTable, SleepSession>
    ),
    SleepSession,
    PrefetchHooks Function()> {
  $$SleepSessionsTableTableManager(_$DreamFlowDb db, $SleepSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SleepSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SleepSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SleepSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> endedAt = const Value.absent(),
            Value<int?> score = const Value.absent(),
            Value<int> deepMinutes = const Value.absent(),
            Value<int> awakenings = const Value.absent(),
            Value<String?> note = const Value.absent(),
          }) =>
              SleepSessionsCompanion(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            score: score,
            deepMinutes: deepMinutes,
            awakenings: awakenings,
            note: note,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required DateTime startedAt,
            Value<DateTime?> endedAt = const Value.absent(),
            Value<int?> score = const Value.absent(),
            Value<int> deepMinutes = const Value.absent(),
            Value<int> awakenings = const Value.absent(),
            Value<String?> note = const Value.absent(),
          }) =>
              SleepSessionsCompanion.insert(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            score: score,
            deepMinutes: deepMinutes,
            awakenings: awakenings,
            note: note,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SleepSessionsTable, SleepSession>(table),
                    BaseReferences<_$DreamFlowDb, $SleepSessionsTable,
                        SleepSession>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SleepSessionsTableProcessedTableManager = ProcessedTableManager<
    _$DreamFlowDb,
    $SleepSessionsTable,
    SleepSession,
    $$SleepSessionsTableFilterComposer,
    $$SleepSessionsTableOrderingComposer,
    $$SleepSessionsTableAnnotationComposer,
    $$SleepSessionsTableCreateCompanionBuilder,
    $$SleepSessionsTableUpdateCompanionBuilder,
    (
      SleepSession,
      BaseReferences<_$DreamFlowDb, $SleepSessionsTable, SleepSession>
    ),
    SleepSession,
    PrefetchHooks Function()>;

class $DreamFlowDbManager {
  final _$DreamFlowDb _db;
  $DreamFlowDbManager(this._db);
  $$MoodRecordsTableTableManager get moodRecords =>
      $$MoodRecordsTableTableManager(_db, _db.moodRecords);
  $$SleepSessionsTableTableManager get sleepSessions =>
      $$SleepSessionsTableTableManager(_db, _db.sleepSessions);
}
