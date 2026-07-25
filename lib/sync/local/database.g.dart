// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AlarmsTable extends Alarms with TableInfo<$AlarmsTable, AlarmRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlarmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nativeIdMeta = const VerificationMeta(
    'nativeId',
  );
  @override
  late final GeneratedColumn<int> nativeId = GeneratedColumn<int>(
    'native_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduledTimeMeta = const VerificationMeta(
    'scheduledTime',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledTime =
      GeneratedColumn<DateTime>(
        'scheduled_time',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _exerciseModeMeta = const VerificationMeta(
    'exerciseMode',
  );
  @override
  late final GeneratedColumn<String> exerciseMode = GeneratedColumn<String>(
    'exercise_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requiredRepsMeta = const VerificationMeta(
    'requiredReps',
  );
  @override
  late final GeneratedColumn<int> requiredReps = GeneratedColumn<int>(
    'required_reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _penaltyMultiplierMeta = const VerificationMeta(
    'penaltyMultiplier',
  );
  @override
  late final GeneratedColumn<double> penaltyMultiplier =
      GeneratedColumn<double>(
        'penalty_multiplier',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1.0),
      );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _recurringDaysMeta = const VerificationMeta(
    'recurringDays',
  );
  @override
  late final GeneratedColumn<String> recurringDays = GeneratedColumn<String>(
    'recurring_days',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nativeId,
    scheduledTime,
    exerciseMode,
    requiredReps,
    penaltyMultiplier,
    isActive,
    recurringDays,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alarms';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlarmRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('native_id')) {
      context.handle(
        _nativeIdMeta,
        nativeId.isAcceptableOrUnknown(data['native_id']!, _nativeIdMeta),
      );
    }
    if (data.containsKey('scheduled_time')) {
      context.handle(
        _scheduledTimeMeta,
        scheduledTime.isAcceptableOrUnknown(
          data['scheduled_time']!,
          _scheduledTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledTimeMeta);
    }
    if (data.containsKey('exercise_mode')) {
      context.handle(
        _exerciseModeMeta,
        exerciseMode.isAcceptableOrUnknown(
          data['exercise_mode']!,
          _exerciseModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseModeMeta);
    }
    if (data.containsKey('required_reps')) {
      context.handle(
        _requiredRepsMeta,
        requiredReps.isAcceptableOrUnknown(
          data['required_reps']!,
          _requiredRepsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requiredRepsMeta);
    }
    if (data.containsKey('penalty_multiplier')) {
      context.handle(
        _penaltyMultiplierMeta,
        penaltyMultiplier.isAcceptableOrUnknown(
          data['penalty_multiplier']!,
          _penaltyMultiplierMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('recurring_days')) {
      context.handle(
        _recurringDaysMeta,
        recurringDays.isAcceptableOrUnknown(
          data['recurring_days']!,
          _recurringDaysMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlarmRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlarmRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nativeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}native_id'],
      ),
      scheduledTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_time'],
      )!,
      exerciseMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_mode'],
      )!,
      requiredReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}required_reps'],
      )!,
      penaltyMultiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}penalty_multiplier'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      recurringDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurring_days'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AlarmsTable createAlias(String alias) {
    return $AlarmsTable(attachedDatabase, alias);
  }
}

class AlarmRow extends DataClass implements Insertable<AlarmRow> {
  final String id;

  /// The `alarm` package's native int id, computed once (via
  /// `AlarmPayload.deriveNativeId` — a specified FNV-1a hash, not Dart's
  /// `String.hashCode`, which isn't guaranteed stable across SDK versions)
  /// and persisted here from that point on. Every later native operation
  /// (reschedule/cancel/dismiss) reads this column rather than recomputing,
  /// so the native-alarm mapping can't silently drift out from under an
  /// already-scheduled alarm after an app/SDK update. Nullable only for
  /// rows written before this column existed; backfilled on first touch.
  final int? nativeId;
  final DateTime scheduledTime;
  final String exerciseMode;
  final int requiredReps;
  final double penaltyMultiplier;
  final bool isActive;

  /// Comma-separated `DateTime.weekday` values (1=Monday..7=Sunday), or
  /// empty for a one-shot alarm. Text rather than a bitmask so the raw
  /// column is readable in a DB browser (plan discussion: "days-of-week"
  /// recurrence).
  final String recurringDays;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const AlarmRow({
    required this.id,
    this.nativeId,
    required this.scheduledTime,
    required this.exerciseMode,
    required this.requiredReps,
    required this.penaltyMultiplier,
    required this.isActive,
    required this.recurringDays,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || nativeId != null) {
      map['native_id'] = Variable<int>(nativeId);
    }
    map['scheduled_time'] = Variable<DateTime>(scheduledTime);
    map['exercise_mode'] = Variable<String>(exerciseMode);
    map['required_reps'] = Variable<int>(requiredReps);
    map['penalty_multiplier'] = Variable<double>(penaltyMultiplier);
    map['is_active'] = Variable<bool>(isActive);
    map['recurring_days'] = Variable<String>(recurringDays);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  AlarmsCompanion toCompanion(bool nullToAbsent) {
    return AlarmsCompanion(
      id: Value(id),
      nativeId: nativeId == null && nullToAbsent
          ? const Value.absent()
          : Value(nativeId),
      scheduledTime: Value(scheduledTime),
      exerciseMode: Value(exerciseMode),
      requiredReps: Value(requiredReps),
      penaltyMultiplier: Value(penaltyMultiplier),
      isActive: Value(isActive),
      recurringDays: Value(recurringDays),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory AlarmRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlarmRow(
      id: serializer.fromJson<String>(json['id']),
      nativeId: serializer.fromJson<int?>(json['nativeId']),
      scheduledTime: serializer.fromJson<DateTime>(json['scheduledTime']),
      exerciseMode: serializer.fromJson<String>(json['exerciseMode']),
      requiredReps: serializer.fromJson<int>(json['requiredReps']),
      penaltyMultiplier: serializer.fromJson<double>(json['penaltyMultiplier']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      recurringDays: serializer.fromJson<String>(json['recurringDays']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nativeId': serializer.toJson<int?>(nativeId),
      'scheduledTime': serializer.toJson<DateTime>(scheduledTime),
      'exerciseMode': serializer.toJson<String>(exerciseMode),
      'requiredReps': serializer.toJson<int>(requiredReps),
      'penaltyMultiplier': serializer.toJson<double>(penaltyMultiplier),
      'isActive': serializer.toJson<bool>(isActive),
      'recurringDays': serializer.toJson<String>(recurringDays),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  AlarmRow copyWith({
    String? id,
    Value<int?> nativeId = const Value.absent(),
    DateTime? scheduledTime,
    String? exerciseMode,
    int? requiredReps,
    double? penaltyMultiplier,
    bool? isActive,
    String? recurringDays,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => AlarmRow(
    id: id ?? this.id,
    nativeId: nativeId.present ? nativeId.value : this.nativeId,
    scheduledTime: scheduledTime ?? this.scheduledTime,
    exerciseMode: exerciseMode ?? this.exerciseMode,
    requiredReps: requiredReps ?? this.requiredReps,
    penaltyMultiplier: penaltyMultiplier ?? this.penaltyMultiplier,
    isActive: isActive ?? this.isActive,
    recurringDays: recurringDays ?? this.recurringDays,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AlarmRow copyWithCompanion(AlarmsCompanion data) {
    return AlarmRow(
      id: data.id.present ? data.id.value : this.id,
      nativeId: data.nativeId.present ? data.nativeId.value : this.nativeId,
      scheduledTime: data.scheduledTime.present
          ? data.scheduledTime.value
          : this.scheduledTime,
      exerciseMode: data.exerciseMode.present
          ? data.exerciseMode.value
          : this.exerciseMode,
      requiredReps: data.requiredReps.present
          ? data.requiredReps.value
          : this.requiredReps,
      penaltyMultiplier: data.penaltyMultiplier.present
          ? data.penaltyMultiplier.value
          : this.penaltyMultiplier,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      recurringDays: data.recurringDays.present
          ? data.recurringDays.value
          : this.recurringDays,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlarmRow(')
          ..write('id: $id, ')
          ..write('nativeId: $nativeId, ')
          ..write('scheduledTime: $scheduledTime, ')
          ..write('exerciseMode: $exerciseMode, ')
          ..write('requiredReps: $requiredReps, ')
          ..write('penaltyMultiplier: $penaltyMultiplier, ')
          ..write('isActive: $isActive, ')
          ..write('recurringDays: $recurringDays, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nativeId,
    scheduledTime,
    exerciseMode,
    requiredReps,
    penaltyMultiplier,
    isActive,
    recurringDays,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlarmRow &&
          other.id == this.id &&
          other.nativeId == this.nativeId &&
          other.scheduledTime == this.scheduledTime &&
          other.exerciseMode == this.exerciseMode &&
          other.requiredReps == this.requiredReps &&
          other.penaltyMultiplier == this.penaltyMultiplier &&
          other.isActive == this.isActive &&
          other.recurringDays == this.recurringDays &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class AlarmsCompanion extends UpdateCompanion<AlarmRow> {
  final Value<String> id;
  final Value<int?> nativeId;
  final Value<DateTime> scheduledTime;
  final Value<String> exerciseMode;
  final Value<int> requiredReps;
  final Value<double> penaltyMultiplier;
  final Value<bool> isActive;
  final Value<String> recurringDays;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const AlarmsCompanion({
    this.id = const Value.absent(),
    this.nativeId = const Value.absent(),
    this.scheduledTime = const Value.absent(),
    this.exerciseMode = const Value.absent(),
    this.requiredReps = const Value.absent(),
    this.penaltyMultiplier = const Value.absent(),
    this.isActive = const Value.absent(),
    this.recurringDays = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlarmsCompanion.insert({
    required String id,
    this.nativeId = const Value.absent(),
    required DateTime scheduledTime,
    required String exerciseMode,
    required int requiredReps,
    this.penaltyMultiplier = const Value.absent(),
    this.isActive = const Value.absent(),
    this.recurringDays = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scheduledTime = Value(scheduledTime),
       exerciseMode = Value(exerciseMode),
       requiredReps = Value(requiredReps),
       updatedAt = Value(updatedAt);
  static Insertable<AlarmRow> custom({
    Expression<String>? id,
    Expression<int>? nativeId,
    Expression<DateTime>? scheduledTime,
    Expression<String>? exerciseMode,
    Expression<int>? requiredReps,
    Expression<double>? penaltyMultiplier,
    Expression<bool>? isActive,
    Expression<String>? recurringDays,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nativeId != null) 'native_id': nativeId,
      if (scheduledTime != null) 'scheduled_time': scheduledTime,
      if (exerciseMode != null) 'exercise_mode': exerciseMode,
      if (requiredReps != null) 'required_reps': requiredReps,
      if (penaltyMultiplier != null) 'penalty_multiplier': penaltyMultiplier,
      if (isActive != null) 'is_active': isActive,
      if (recurringDays != null) 'recurring_days': recurringDays,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlarmsCompanion copyWith({
    Value<String>? id,
    Value<int?>? nativeId,
    Value<DateTime>? scheduledTime,
    Value<String>? exerciseMode,
    Value<int>? requiredReps,
    Value<double>? penaltyMultiplier,
    Value<bool>? isActive,
    Value<String>? recurringDays,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AlarmsCompanion(
      id: id ?? this.id,
      nativeId: nativeId ?? this.nativeId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      exerciseMode: exerciseMode ?? this.exerciseMode,
      requiredReps: requiredReps ?? this.requiredReps,
      penaltyMultiplier: penaltyMultiplier ?? this.penaltyMultiplier,
      isActive: isActive ?? this.isActive,
      recurringDays: recurringDays ?? this.recurringDays,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nativeId.present) {
      map['native_id'] = Variable<int>(nativeId.value);
    }
    if (scheduledTime.present) {
      map['scheduled_time'] = Variable<DateTime>(scheduledTime.value);
    }
    if (exerciseMode.present) {
      map['exercise_mode'] = Variable<String>(exerciseMode.value);
    }
    if (requiredReps.present) {
      map['required_reps'] = Variable<int>(requiredReps.value);
    }
    if (penaltyMultiplier.present) {
      map['penalty_multiplier'] = Variable<double>(penaltyMultiplier.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (recurringDays.present) {
      map['recurring_days'] = Variable<String>(recurringDays.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlarmsCompanion(')
          ..write('id: $id, ')
          ..write('nativeId: $nativeId, ')
          ..write('scheduledTime: $scheduledTime, ')
          ..write('exerciseMode: $exerciseMode, ')
          ..write('requiredReps: $requiredReps, ')
          ..write('penaltyMultiplier: $penaltyMultiplier, ')
          ..write('isActive: $isActive, ')
          ..write('recurringDays: $recurringDays, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alarmIdMeta = const VerificationMeta(
    'alarmId',
  );
  @override
  late final GeneratedColumn<String> alarmId = GeneratedColumn<String>(
    'alarm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exerciseModeMeta = const VerificationMeta(
    'exerciseMode',
  );
  @override
  late final GeneratedColumn<String> exerciseMode = GeneratedColumn<String>(
    'exercise_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsCompletedMeta = const VerificationMeta(
    'repsCompleted',
  );
  @override
  late final GeneratedColumn<int> repsCompleted = GeneratedColumn<int>(
    'reps_completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    alarmId,
    exerciseMode,
    repsCompleted,
    startedAt,
    completedAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('alarm_id')) {
      context.handle(
        _alarmIdMeta,
        alarmId.isAcceptableOrUnknown(data['alarm_id']!, _alarmIdMeta),
      );
    }
    if (data.containsKey('exercise_mode')) {
      context.handle(
        _exerciseModeMeta,
        exerciseMode.isAcceptableOrUnknown(
          data['exercise_mode']!,
          _exerciseModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseModeMeta);
    }
    if (data.containsKey('reps_completed')) {
      context.handle(
        _repsCompletedMeta,
        repsCompleted.isAcceptableOrUnknown(
          data['reps_completed']!,
          _repsCompletedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repsCompletedMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      alarmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alarm_id'],
      ),
      exerciseMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_mode'],
      )!,
      repsCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps_completed'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final String? alarmId;
  final String exerciseMode;
  final int repsCompleted;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const SessionRow({
    required this.id,
    this.alarmId,
    required this.exerciseMode,
    required this.repsCompleted,
    required this.startedAt,
    this.completedAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || alarmId != null) {
      map['alarm_id'] = Variable<String>(alarmId);
    }
    map['exercise_mode'] = Variable<String>(exerciseMode);
    map['reps_completed'] = Variable<int>(repsCompleted);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      alarmId: alarmId == null && nullToAbsent
          ? const Value.absent()
          : Value(alarmId),
      exerciseMode: Value(exerciseMode),
      repsCompleted: Value(repsCompleted),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      alarmId: serializer.fromJson<String?>(json['alarmId']),
      exerciseMode: serializer.fromJson<String>(json['exerciseMode']),
      repsCompleted: serializer.fromJson<int>(json['repsCompleted']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'alarmId': serializer.toJson<String?>(alarmId),
      'exerciseMode': serializer.toJson<String>(exerciseMode),
      'repsCompleted': serializer.toJson<int>(repsCompleted),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  SessionRow copyWith({
    String? id,
    Value<String?> alarmId = const Value.absent(),
    String? exerciseMode,
    int? repsCompleted,
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => SessionRow(
    id: id ?? this.id,
    alarmId: alarmId.present ? alarmId.value : this.alarmId,
    exerciseMode: exerciseMode ?? this.exerciseMode,
    repsCompleted: repsCompleted ?? this.repsCompleted,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      alarmId: data.alarmId.present ? data.alarmId.value : this.alarmId,
      exerciseMode: data.exerciseMode.present
          ? data.exerciseMode.value
          : this.exerciseMode,
      repsCompleted: data.repsCompleted.present
          ? data.repsCompleted.value
          : this.repsCompleted,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('alarmId: $alarmId, ')
          ..write('exerciseMode: $exerciseMode, ')
          ..write('repsCompleted: $repsCompleted, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    alarmId,
    exerciseMode,
    repsCompleted,
    startedAt,
    completedAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.alarmId == this.alarmId &&
          other.exerciseMode == this.exerciseMode &&
          other.repsCompleted == this.repsCompleted &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String?> alarmId;
  final Value<String> exerciseMode;
  final Value<int> repsCompleted;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.alarmId = const Value.absent(),
    this.exerciseMode = const Value.absent(),
    this.repsCompleted = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    this.alarmId = const Value.absent(),
    required String exerciseMode,
    required int repsCompleted,
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       exerciseMode = Value(exerciseMode),
       repsCompleted = Value(repsCompleted),
       startedAt = Value(startedAt),
       updatedAt = Value(updatedAt);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? alarmId,
    Expression<String>? exerciseMode,
    Expression<int>? repsCompleted,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (alarmId != null) 'alarm_id': alarmId,
      if (exerciseMode != null) 'exercise_mode': exerciseMode,
      if (repsCompleted != null) 'reps_completed': repsCompleted,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? alarmId,
    Value<String>? exerciseMode,
    Value<int>? repsCompleted,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      alarmId: alarmId ?? this.alarmId,
      exerciseMode: exerciseMode ?? this.exerciseMode,
      repsCompleted: repsCompleted ?? this.repsCompleted,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (alarmId.present) {
      map['alarm_id'] = Variable<String>(alarmId.value);
    }
    if (exerciseMode.present) {
      map['exercise_mode'] = Variable<String>(exerciseMode.value);
    }
    if (repsCompleted.present) {
      map['reps_completed'] = Variable<int>(repsCompleted.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('alarmId: $alarmId, ')
          ..write('exerciseMode: $exerciseMode, ')
          ..write('repsCompleted: $repsCompleted, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunsTable extends Runs with TableInfo<$RunsTable, RunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pointCountMeta = const VerificationMeta(
    'pointCount',
  );
  @override
  late final GeneratedColumn<int> pointCount = GeneratedColumn<int>(
    'point_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathGeoJsonMeta = const VerificationMeta(
    'pathGeoJson',
  );
  @override
  late final GeneratedColumn<String> pathGeoJson = GeneratedColumn<String>(
    'path_geo_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointTimestampsJsonMeta =
      const VerificationMeta('pointTimestampsJson');
  @override
  late final GeneratedColumn<String> pointTimestampsJson =
      GeneratedColumn<String>(
        'point_timestamps_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isClosedLoopMeta = const VerificationMeta(
    'isClosedLoop',
  );
  @override
  late final GeneratedColumn<bool> isClosedLoop = GeneratedColumn<bool>(
    'is_closed_loop',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_closed_loop" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _capturedAreaSqmMeta = const VerificationMeta(
    'capturedAreaSqm',
  );
  @override
  late final GeneratedColumn<double> capturedAreaSqm = GeneratedColumn<double>(
    'captured_area_sqm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _areaSqmMeta = const VerificationMeta(
    'areaSqm',
  );
  @override
  late final GeneratedColumn<double> areaSqm = GeneratedColumn<double>(
    'area_sqm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _integrityVerdictMeta = const VerificationMeta(
    'integrityVerdict',
  );
  @override
  late final GeneratedColumn<String> integrityVerdict = GeneratedColumn<String>(
    'integrity_verdict',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rejectedReasonMeta = const VerificationMeta(
    'rejectedReason',
  );
  @override
  late final GeneratedColumn<String> rejectedReason = GeneratedColumn<String>(
    'rejected_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    pointCount,
    pathGeoJson,
    pointTimestampsJson,
    isClosedLoop,
    capturedAreaSqm,
    areaSqm,
    integrityVerdict,
    rejectedReason,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('point_count')) {
      context.handle(
        _pointCountMeta,
        pointCount.isAcceptableOrUnknown(data['point_count']!, _pointCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pointCountMeta);
    }
    if (data.containsKey('path_geo_json')) {
      context.handle(
        _pathGeoJsonMeta,
        pathGeoJson.isAcceptableOrUnknown(
          data['path_geo_json']!,
          _pathGeoJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pathGeoJsonMeta);
    }
    if (data.containsKey('point_timestamps_json')) {
      context.handle(
        _pointTimestampsJsonMeta,
        pointTimestampsJson.isAcceptableOrUnknown(
          data['point_timestamps_json']!,
          _pointTimestampsJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_closed_loop')) {
      context.handle(
        _isClosedLoopMeta,
        isClosedLoop.isAcceptableOrUnknown(
          data['is_closed_loop']!,
          _isClosedLoopMeta,
        ),
      );
    }
    if (data.containsKey('captured_area_sqm')) {
      context.handle(
        _capturedAreaSqmMeta,
        capturedAreaSqm.isAcceptableOrUnknown(
          data['captured_area_sqm']!,
          _capturedAreaSqmMeta,
        ),
      );
    }
    if (data.containsKey('area_sqm')) {
      context.handle(
        _areaSqmMeta,
        areaSqm.isAcceptableOrUnknown(data['area_sqm']!, _areaSqmMeta),
      );
    }
    if (data.containsKey('integrity_verdict')) {
      context.handle(
        _integrityVerdictMeta,
        integrityVerdict.isAcceptableOrUnknown(
          data['integrity_verdict']!,
          _integrityVerdictMeta,
        ),
      );
    }
    if (data.containsKey('rejected_reason')) {
      context.handle(
        _rejectedReasonMeta,
        rejectedReason.isAcceptableOrUnknown(
          data['rejected_reason']!,
          _rejectedReasonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      pointCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}point_count'],
      )!,
      pathGeoJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path_geo_json'],
      )!,
      pointTimestampsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}point_timestamps_json'],
      ),
      isClosedLoop: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_closed_loop'],
      )!,
      capturedAreaSqm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}captured_area_sqm'],
      ),
      areaSqm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}area_sqm'],
      ),
      integrityVerdict: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}integrity_verdict'],
      ),
      rejectedReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rejected_reason'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $RunsTable createAlias(String alias) {
    return $RunsTable(attachedDatabase, alias);
  }
}

class RunRow extends DataClass implements Insertable<RunRow> {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int pointCount;
  final String pathGeoJson;

  /// JSON array of per-point ISO8601 capture timestamps, same order as
  /// `pathGeoJson`'s coordinates. Sent to `submit_run()`'s
  /// `p_point_timestamps` param so the server can validate per-segment
  /// speed (P0 anti-cheat finding — the RPC couldn't do this at all
  /// without per-point timing, since `pathGeoJson` alone carries no time
  /// information). Nullable for rows written before this column existed.
  final String? pointTimestampsJson;
  final bool isClosedLoop;

  /// This run's own captured polygon area — what `submit_run()` returns as
  /// `captured_area_sqm` (the celebration-UI "delta"), distinct from
  /// `areaSqm` (the user's total territory area after server-side merge).
  final double? capturedAreaSqm;
  final double? areaSqm;
  final String? integrityVerdict;
  final String? rejectedReason;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const RunRow({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.pointCount,
    required this.pathGeoJson,
    this.pointTimestampsJson,
    required this.isClosedLoop,
    this.capturedAreaSqm,
    this.areaSqm,
    this.integrityVerdict,
    this.rejectedReason,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['point_count'] = Variable<int>(pointCount);
    map['path_geo_json'] = Variable<String>(pathGeoJson);
    if (!nullToAbsent || pointTimestampsJson != null) {
      map['point_timestamps_json'] = Variable<String>(pointTimestampsJson);
    }
    map['is_closed_loop'] = Variable<bool>(isClosedLoop);
    if (!nullToAbsent || capturedAreaSqm != null) {
      map['captured_area_sqm'] = Variable<double>(capturedAreaSqm);
    }
    if (!nullToAbsent || areaSqm != null) {
      map['area_sqm'] = Variable<double>(areaSqm);
    }
    if (!nullToAbsent || integrityVerdict != null) {
      map['integrity_verdict'] = Variable<String>(integrityVerdict);
    }
    if (!nullToAbsent || rejectedReason != null) {
      map['rejected_reason'] = Variable<String>(rejectedReason);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  RunsCompanion toCompanion(bool nullToAbsent) {
    return RunsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      pointCount: Value(pointCount),
      pathGeoJson: Value(pathGeoJson),
      pointTimestampsJson: pointTimestampsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(pointTimestampsJson),
      isClosedLoop: Value(isClosedLoop),
      capturedAreaSqm: capturedAreaSqm == null && nullToAbsent
          ? const Value.absent()
          : Value(capturedAreaSqm),
      areaSqm: areaSqm == null && nullToAbsent
          ? const Value.absent()
          : Value(areaSqm),
      integrityVerdict: integrityVerdict == null && nullToAbsent
          ? const Value.absent()
          : Value(integrityVerdict),
      rejectedReason: rejectedReason == null && nullToAbsent
          ? const Value.absent()
          : Value(rejectedReason),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory RunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunRow(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      pointCount: serializer.fromJson<int>(json['pointCount']),
      pathGeoJson: serializer.fromJson<String>(json['pathGeoJson']),
      pointTimestampsJson: serializer.fromJson<String?>(
        json['pointTimestampsJson'],
      ),
      isClosedLoop: serializer.fromJson<bool>(json['isClosedLoop']),
      capturedAreaSqm: serializer.fromJson<double?>(json['capturedAreaSqm']),
      areaSqm: serializer.fromJson<double?>(json['areaSqm']),
      integrityVerdict: serializer.fromJson<String?>(json['integrityVerdict']),
      rejectedReason: serializer.fromJson<String?>(json['rejectedReason']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'pointCount': serializer.toJson<int>(pointCount),
      'pathGeoJson': serializer.toJson<String>(pathGeoJson),
      'pointTimestampsJson': serializer.toJson<String?>(pointTimestampsJson),
      'isClosedLoop': serializer.toJson<bool>(isClosedLoop),
      'capturedAreaSqm': serializer.toJson<double?>(capturedAreaSqm),
      'areaSqm': serializer.toJson<double?>(areaSqm),
      'integrityVerdict': serializer.toJson<String?>(integrityVerdict),
      'rejectedReason': serializer.toJson<String?>(rejectedReason),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  RunRow copyWith({
    String? id,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? pointCount,
    String? pathGeoJson,
    Value<String?> pointTimestampsJson = const Value.absent(),
    bool? isClosedLoop,
    Value<double?> capturedAreaSqm = const Value.absent(),
    Value<double?> areaSqm = const Value.absent(),
    Value<String?> integrityVerdict = const Value.absent(),
    Value<String?> rejectedReason = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => RunRow(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    pointCount: pointCount ?? this.pointCount,
    pathGeoJson: pathGeoJson ?? this.pathGeoJson,
    pointTimestampsJson: pointTimestampsJson.present
        ? pointTimestampsJson.value
        : this.pointTimestampsJson,
    isClosedLoop: isClosedLoop ?? this.isClosedLoop,
    capturedAreaSqm: capturedAreaSqm.present
        ? capturedAreaSqm.value
        : this.capturedAreaSqm,
    areaSqm: areaSqm.present ? areaSqm.value : this.areaSqm,
    integrityVerdict: integrityVerdict.present
        ? integrityVerdict.value
        : this.integrityVerdict,
    rejectedReason: rejectedReason.present
        ? rejectedReason.value
        : this.rejectedReason,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  RunRow copyWithCompanion(RunsCompanion data) {
    return RunRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      pointCount: data.pointCount.present
          ? data.pointCount.value
          : this.pointCount,
      pathGeoJson: data.pathGeoJson.present
          ? data.pathGeoJson.value
          : this.pathGeoJson,
      pointTimestampsJson: data.pointTimestampsJson.present
          ? data.pointTimestampsJson.value
          : this.pointTimestampsJson,
      isClosedLoop: data.isClosedLoop.present
          ? data.isClosedLoop.value
          : this.isClosedLoop,
      capturedAreaSqm: data.capturedAreaSqm.present
          ? data.capturedAreaSqm.value
          : this.capturedAreaSqm,
      areaSqm: data.areaSqm.present ? data.areaSqm.value : this.areaSqm,
      integrityVerdict: data.integrityVerdict.present
          ? data.integrityVerdict.value
          : this.integrityVerdict,
      rejectedReason: data.rejectedReason.present
          ? data.rejectedReason.value
          : this.rejectedReason,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pointCount: $pointCount, ')
          ..write('pathGeoJson: $pathGeoJson, ')
          ..write('pointTimestampsJson: $pointTimestampsJson, ')
          ..write('isClosedLoop: $isClosedLoop, ')
          ..write('capturedAreaSqm: $capturedAreaSqm, ')
          ..write('areaSqm: $areaSqm, ')
          ..write('integrityVerdict: $integrityVerdict, ')
          ..write('rejectedReason: $rejectedReason, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    pointCount,
    pathGeoJson,
    pointTimestampsJson,
    isClosedLoop,
    capturedAreaSqm,
    areaSqm,
    integrityVerdict,
    rejectedReason,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.pointCount == this.pointCount &&
          other.pathGeoJson == this.pathGeoJson &&
          other.pointTimestampsJson == this.pointTimestampsJson &&
          other.isClosedLoop == this.isClosedLoop &&
          other.capturedAreaSqm == this.capturedAreaSqm &&
          other.areaSqm == this.areaSqm &&
          other.integrityVerdict == this.integrityVerdict &&
          other.rejectedReason == this.rejectedReason &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class RunsCompanion extends UpdateCompanion<RunRow> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> pointCount;
  final Value<String> pathGeoJson;
  final Value<String?> pointTimestampsJson;
  final Value<bool> isClosedLoop;
  final Value<double?> capturedAreaSqm;
  final Value<double?> areaSqm;
  final Value<String?> integrityVerdict;
  final Value<String?> rejectedReason;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const RunsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.pointCount = const Value.absent(),
    this.pathGeoJson = const Value.absent(),
    this.pointTimestampsJson = const Value.absent(),
    this.isClosedLoop = const Value.absent(),
    this.capturedAreaSqm = const Value.absent(),
    this.areaSqm = const Value.absent(),
    this.integrityVerdict = const Value.absent(),
    this.rejectedReason = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required int pointCount,
    required String pathGeoJson,
    this.pointTimestampsJson = const Value.absent(),
    this.isClosedLoop = const Value.absent(),
    this.capturedAreaSqm = const Value.absent(),
    this.areaSqm = const Value.absent(),
    this.integrityVerdict = const Value.absent(),
    this.rejectedReason = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       pointCount = Value(pointCount),
       pathGeoJson = Value(pathGeoJson),
       updatedAt = Value(updatedAt);
  static Insertable<RunRow> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? pointCount,
    Expression<String>? pathGeoJson,
    Expression<String>? pointTimestampsJson,
    Expression<bool>? isClosedLoop,
    Expression<double>? capturedAreaSqm,
    Expression<double>? areaSqm,
    Expression<String>? integrityVerdict,
    Expression<String>? rejectedReason,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (pointCount != null) 'point_count': pointCount,
      if (pathGeoJson != null) 'path_geo_json': pathGeoJson,
      if (pointTimestampsJson != null)
        'point_timestamps_json': pointTimestampsJson,
      if (isClosedLoop != null) 'is_closed_loop': isClosedLoop,
      if (capturedAreaSqm != null) 'captured_area_sqm': capturedAreaSqm,
      if (areaSqm != null) 'area_sqm': areaSqm,
      if (integrityVerdict != null) 'integrity_verdict': integrityVerdict,
      if (rejectedReason != null) 'rejected_reason': rejectedReason,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? pointCount,
    Value<String>? pathGeoJson,
    Value<String?>? pointTimestampsJson,
    Value<bool>? isClosedLoop,
    Value<double?>? capturedAreaSqm,
    Value<double?>? areaSqm,
    Value<String?>? integrityVerdict,
    Value<String?>? rejectedReason,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return RunsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      pointCount: pointCount ?? this.pointCount,
      pathGeoJson: pathGeoJson ?? this.pathGeoJson,
      pointTimestampsJson: pointTimestampsJson ?? this.pointTimestampsJson,
      isClosedLoop: isClosedLoop ?? this.isClosedLoop,
      capturedAreaSqm: capturedAreaSqm ?? this.capturedAreaSqm,
      areaSqm: areaSqm ?? this.areaSqm,
      integrityVerdict: integrityVerdict ?? this.integrityVerdict,
      rejectedReason: rejectedReason ?? this.rejectedReason,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (pointCount.present) {
      map['point_count'] = Variable<int>(pointCount.value);
    }
    if (pathGeoJson.present) {
      map['path_geo_json'] = Variable<String>(pathGeoJson.value);
    }
    if (pointTimestampsJson.present) {
      map['point_timestamps_json'] = Variable<String>(
        pointTimestampsJson.value,
      );
    }
    if (isClosedLoop.present) {
      map['is_closed_loop'] = Variable<bool>(isClosedLoop.value);
    }
    if (capturedAreaSqm.present) {
      map['captured_area_sqm'] = Variable<double>(capturedAreaSqm.value);
    }
    if (areaSqm.present) {
      map['area_sqm'] = Variable<double>(areaSqm.value);
    }
    if (integrityVerdict.present) {
      map['integrity_verdict'] = Variable<String>(integrityVerdict.value);
    }
    if (rejectedReason.present) {
      map['rejected_reason'] = Variable<String>(rejectedReason.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pointCount: $pointCount, ')
          ..write('pathGeoJson: $pathGeoJson, ')
          ..write('pointTimestampsJson: $pointTimestampsJson, ')
          ..write('isClosedLoop: $isClosedLoop, ')
          ..write('capturedAreaSqm: $capturedAreaSqm, ')
          ..write('areaSqm: $areaSqm, ')
          ..write('integrityVerdict: $integrityVerdict, ')
          ..write('rejectedReason: $rejectedReason, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TerritoriesTable extends Territories
    with TableInfo<$TerritoriesTable, TerritoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TerritoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geoJsonMeta = const VerificationMeta(
    'geoJson',
  );
  @override
  late final GeneratedColumn<String> geoJson = GeneratedColumn<String>(
    'geo_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _areaSqmMeta = const VerificationMeta(
    'areaSqm',
  );
  @override
  late final GeneratedColumn<double> areaSqm = GeneratedColumn<double>(
    'area_sqm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    geoJson,
    areaSqm,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'territories';
  @override
  VerificationContext validateIntegrity(
    Insertable<TerritoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('geo_json')) {
      context.handle(
        _geoJsonMeta,
        geoJson.isAcceptableOrUnknown(data['geo_json']!, _geoJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_geoJsonMeta);
    }
    if (data.containsKey('area_sqm')) {
      context.handle(
        _areaSqmMeta,
        areaSqm.isAcceptableOrUnknown(data['area_sqm']!, _areaSqmMeta),
      );
    } else if (isInserting) {
      context.missing(_areaSqmMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TerritoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TerritoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      geoJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geo_json'],
      )!,
      areaSqm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}area_sqm'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TerritoriesTable createAlias(String alias) {
    return $TerritoriesTable(attachedDatabase, alias);
  }
}

class TerritoryRow extends DataClass implements Insertable<TerritoryRow> {
  final String id;
  final String ownerId;
  final String geoJson;
  final double areaSqm;
  final DateTime updatedAt;

  /// Local-only tombstone (mirrors the backend's soft-delete column, but
  /// this cache never round-trips it) — set when a refresh's bbox query no
  /// longer returns a previously-cached row inside that same bbox
  /// (decayed, captured to nothing, or otherwise removed server-side).
  /// Kept rather than hard-deleting immediately so a row that reappears in
  /// a later refresh (e.g. recaptured) can simply have this cleared.
  final DateTime? deletedAt;
  const TerritoryRow({
    required this.id,
    required this.ownerId,
    required this.geoJson,
    required this.areaSqm,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['geo_json'] = Variable<String>(geoJson);
    map['area_sqm'] = Variable<double>(areaSqm);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TerritoriesCompanion toCompanion(bool nullToAbsent) {
    return TerritoriesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      geoJson: Value(geoJson),
      areaSqm: Value(areaSqm),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TerritoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TerritoryRow(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      geoJson: serializer.fromJson<String>(json['geoJson']),
      areaSqm: serializer.fromJson<double>(json['areaSqm']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'geoJson': serializer.toJson<String>(geoJson),
      'areaSqm': serializer.toJson<double>(areaSqm),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  TerritoryRow copyWith({
    String? id,
    String? ownerId,
    String? geoJson,
    double? areaSqm,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => TerritoryRow(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    geoJson: geoJson ?? this.geoJson,
    areaSqm: areaSqm ?? this.areaSqm,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TerritoryRow copyWithCompanion(TerritoriesCompanion data) {
    return TerritoryRow(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      geoJson: data.geoJson.present ? data.geoJson.value : this.geoJson,
      areaSqm: data.areaSqm.present ? data.areaSqm.value : this.areaSqm,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TerritoryRow(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('geoJson: $geoJson, ')
          ..write('areaSqm: $areaSqm, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, ownerId, geoJson, areaSqm, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TerritoryRow &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.geoJson == this.geoJson &&
          other.areaSqm == this.areaSqm &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TerritoriesCompanion extends UpdateCompanion<TerritoryRow> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> geoJson;
  final Value<double> areaSqm;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TerritoriesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.geoJson = const Value.absent(),
    this.areaSqm = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TerritoriesCompanion.insert({
    required String id,
    required String ownerId,
    required String geoJson,
    required double areaSqm,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       geoJson = Value(geoJson),
       areaSqm = Value(areaSqm),
       updatedAt = Value(updatedAt);
  static Insertable<TerritoryRow> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? geoJson,
    Expression<double>? areaSqm,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (geoJson != null) 'geo_json': geoJson,
      if (areaSqm != null) 'area_sqm': areaSqm,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TerritoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? geoJson,
    Value<double>? areaSqm,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TerritoriesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      geoJson: geoJson ?? this.geoJson,
      areaSqm: areaSqm ?? this.areaSqm,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (geoJson.present) {
      map['geo_json'] = Variable<String>(geoJson.value);
    }
    if (areaSqm.present) {
      map['area_sqm'] = Variable<double>(areaSqm.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TerritoriesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('geoJson: $geoJson, ')
          ..write('areaSqm: $areaSqm, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, OutboxEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entityTableMeta = const VerificationMeta(
    'entityTable',
  );
  @override
  late final GeneratedColumn<String> entityTable = GeneratedColumn<String>(
    'entity_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorTypeMeta = const VerificationMeta(
    'errorType',
  );
  @override
  late final GeneratedColumn<String> errorType = GeneratedColumn<String>(
    'error_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxAttemptsMeta = const VerificationMeta(
    'maxAttempts',
  );
  @override
  late final GeneratedColumn<int> maxAttempts = GeneratedColumn<int>(
    'max_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityTable,
    entityId,
    operation,
    payload,
    createdAt,
    nextAttemptAt,
    attemptCount,
    errorType,
    lastError,
    maxAttempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity_table')) {
      context.handle(
        _entityTableMeta,
        entityTable.isAcceptableOrUnknown(
          data['entity_table']!,
          _entityTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityTableMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('error_type')) {
      context.handle(
        _errorTypeMeta,
        errorType.isAcceptableOrUnknown(data['error_type']!, _errorTypeMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('max_attempts')) {
      context.handle(
        _maxAttemptsMeta,
        maxAttempts.isAcceptableOrUnknown(
          data['max_attempts']!,
          _maxAttemptsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entityTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_table'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      errorType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_type'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      maxAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_attempts'],
      )!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class OutboxEntryRow extends DataClass implements Insertable<OutboxEntryRow> {
  final int id;
  final String entityTable;
  final String entityId;
  final String operation;
  final String payload;
  final DateTime createdAt;
  final DateTime nextAttemptAt;
  final int attemptCount;

  /// Dead-letter classification: `'transient'` (network/timeout — keep
  /// retrying with backoff) vs `'permanent'` (4xx/constraint violation —
  /// the same payload will never succeed, so `SyncWorker` stops retrying
  /// once `attemptCount` reaches [maxAttempts] and instead surfaces it via
  /// `SyncStatus.error`). Null until the first failure.
  final String? errorType;
  final String? lastError;
  final int maxAttempts;
  const OutboxEntryRow({
    required this.id,
    required this.entityTable,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.nextAttemptAt,
    required this.attemptCount,
    this.errorType,
    this.lastError,
    required this.maxAttempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity_table'] = Variable<String>(entityTable);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || errorType != null) {
      map['error_type'] = Variable<String>(errorType);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['max_attempts'] = Variable<int>(maxAttempts);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      entityTable: Value(entityTable),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: Value(payload),
      createdAt: Value(createdAt),
      nextAttemptAt: Value(nextAttemptAt),
      attemptCount: Value(attemptCount),
      errorType: errorType == null && nullToAbsent
          ? const Value.absent()
          : Value(errorType),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      maxAttempts: Value(maxAttempts),
    );
  }

  factory OutboxEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntryRow(
      id: serializer.fromJson<int>(json['id']),
      entityTable: serializer.fromJson<String>(json['entityTable']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      errorType: serializer.fromJson<String?>(json['errorType']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      maxAttempts: serializer.fromJson<int>(json['maxAttempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entityTable': serializer.toJson<String>(entityTable),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'errorType': serializer.toJson<String?>(errorType),
      'lastError': serializer.toJson<String?>(lastError),
      'maxAttempts': serializer.toJson<int>(maxAttempts),
    };
  }

  OutboxEntryRow copyWith({
    int? id,
    String? entityTable,
    String? entityId,
    String? operation,
    String? payload,
    DateTime? createdAt,
    DateTime? nextAttemptAt,
    int? attemptCount,
    Value<String?> errorType = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? maxAttempts,
  }) => OutboxEntryRow(
    id: id ?? this.id,
    entityTable: entityTable ?? this.entityTable,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    attemptCount: attemptCount ?? this.attemptCount,
    errorType: errorType.present ? errorType.value : this.errorType,
    lastError: lastError.present ? lastError.value : this.lastError,
    maxAttempts: maxAttempts ?? this.maxAttempts,
  );
  OutboxEntryRow copyWithCompanion(SyncOutboxCompanion data) {
    return OutboxEntryRow(
      id: data.id.present ? data.id.value : this.id,
      entityTable: data.entityTable.present
          ? data.entityTable.value
          : this.entityTable,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      errorType: data.errorType.present ? data.errorType.value : this.errorType,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      maxAttempts: data.maxAttempts.present
          ? data.maxAttempts.value
          : this.maxAttempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntryRow(')
          ..write('id: $id, ')
          ..write('entityTable: $entityTable, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('errorType: $errorType, ')
          ..write('lastError: $lastError, ')
          ..write('maxAttempts: $maxAttempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityTable,
    entityId,
    operation,
    payload,
    createdAt,
    nextAttemptAt,
    attemptCount,
    errorType,
    lastError,
    maxAttempts,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntryRow &&
          other.id == this.id &&
          other.entityTable == this.entityTable &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.attemptCount == this.attemptCount &&
          other.errorType == this.errorType &&
          other.lastError == this.lastError &&
          other.maxAttempts == this.maxAttempts);
}

class SyncOutboxCompanion extends UpdateCompanion<OutboxEntryRow> {
  final Value<int> id;
  final Value<String> entityTable;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<DateTime> nextAttemptAt;
  final Value<int> attemptCount;
  final Value<String?> errorType;
  final Value<String?> lastError;
  final Value<int> maxAttempts;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.entityTable = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.errorType = const Value.absent(),
    this.lastError = const Value.absent(),
    this.maxAttempts = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String entityTable,
    required String entityId,
    required String operation,
    required String payload,
    required DateTime createdAt,
    required DateTime nextAttemptAt,
    this.attemptCount = const Value.absent(),
    this.errorType = const Value.absent(),
    this.lastError = const Value.absent(),
    this.maxAttempts = const Value.absent(),
  }) : entityTable = Value(entityTable),
       entityId = Value(entityId),
       operation = Value(operation),
       payload = Value(payload),
       createdAt = Value(createdAt),
       nextAttemptAt = Value(nextAttemptAt);
  static Insertable<OutboxEntryRow> custom({
    Expression<int>? id,
    Expression<String>? entityTable,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<int>? attemptCount,
    Expression<String>? errorType,
    Expression<String>? lastError,
    Expression<int>? maxAttempts,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityTable != null) 'entity_table': entityTable,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (errorType != null) 'error_type': errorType,
      if (lastError != null) 'last_error': lastError,
      if (maxAttempts != null) 'max_attempts': maxAttempts,
    });
  }

  SyncOutboxCompanion copyWith({
    Value<int>? id,
    Value<String>? entityTable,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<DateTime>? nextAttemptAt,
    Value<int>? attemptCount,
    Value<String?>? errorType,
    Value<String?>? lastError,
    Value<int>? maxAttempts,
  }) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      entityTable: entityTable ?? this.entityTable,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      errorType: errorType ?? this.errorType,
      lastError: lastError ?? this.lastError,
      maxAttempts: maxAttempts ?? this.maxAttempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entityTable.present) {
      map['entity_table'] = Variable<String>(entityTable.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (errorType.present) {
      map['error_type'] = Variable<String>(errorType.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (maxAttempts.present) {
      map['max_attempts'] = Variable<int>(maxAttempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('entityTable: $entityTable, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('errorType: $errorType, ')
          ..write('lastError: $lastError, ')
          ..write('maxAttempts: $maxAttempts')
          ..write(')'))
        .toString();
  }
}

class $UserStatsTable extends UserStats
    with TableInfo<$UserStatsTable, UserStatsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _currentTaxMultiplierMeta =
      const VerificationMeta('currentTaxMultiplier');
  @override
  late final GeneratedColumn<double> currentTaxMultiplier =
      GeneratedColumn<double>(
        'current_tax_multiplier',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1.0),
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, currentTaxMultiplier, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserStatsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_tax_multiplier')) {
      context.handle(
        _currentTaxMultiplierMeta,
        currentTaxMultiplier.isAcceptableOrUnknown(
          data['current_tax_multiplier']!,
          _currentTaxMultiplierMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserStatsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserStatsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      currentTaxMultiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_tax_multiplier'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserStatsTable createAlias(String alias) {
    return $UserStatsTable(attachedDatabase, alias);
  }
}

class UserStatsRow extends DataClass implements Insertable<UserStatsRow> {
  /// Always `1` — this table only ever holds one row (single-user,
  /// on-device). Simpler than a nullable/singleton-lookup pattern.
  final int id;
  final double currentTaxMultiplier;
  final DateTime updatedAt;
  const UserStatsRow({
    required this.id,
    required this.currentTaxMultiplier,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['current_tax_multiplier'] = Variable<double>(currentTaxMultiplier);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserStatsCompanion toCompanion(bool nullToAbsent) {
    return UserStatsCompanion(
      id: Value(id),
      currentTaxMultiplier: Value(currentTaxMultiplier),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserStatsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserStatsRow(
      id: serializer.fromJson<int>(json['id']),
      currentTaxMultiplier: serializer.fromJson<double>(
        json['currentTaxMultiplier'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentTaxMultiplier': serializer.toJson<double>(currentTaxMultiplier),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserStatsRow copyWith({
    int? id,
    double? currentTaxMultiplier,
    DateTime? updatedAt,
  }) => UserStatsRow(
    id: id ?? this.id,
    currentTaxMultiplier: currentTaxMultiplier ?? this.currentTaxMultiplier,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserStatsRow copyWithCompanion(UserStatsCompanion data) {
    return UserStatsRow(
      id: data.id.present ? data.id.value : this.id,
      currentTaxMultiplier: data.currentTaxMultiplier.present
          ? data.currentTaxMultiplier.value
          : this.currentTaxMultiplier,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserStatsRow(')
          ..write('id: $id, ')
          ..write('currentTaxMultiplier: $currentTaxMultiplier, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, currentTaxMultiplier, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserStatsRow &&
          other.id == this.id &&
          other.currentTaxMultiplier == this.currentTaxMultiplier &&
          other.updatedAt == this.updatedAt);
}

class UserStatsCompanion extends UpdateCompanion<UserStatsRow> {
  final Value<int> id;
  final Value<double> currentTaxMultiplier;
  final Value<DateTime> updatedAt;
  const UserStatsCompanion({
    this.id = const Value.absent(),
    this.currentTaxMultiplier = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserStatsCompanion.insert({
    this.id = const Value.absent(),
    this.currentTaxMultiplier = const Value.absent(),
    required DateTime updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<UserStatsRow> custom({
    Expression<int>? id,
    Expression<double>? currentTaxMultiplier,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentTaxMultiplier != null)
        'current_tax_multiplier': currentTaxMultiplier,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserStatsCompanion copyWith({
    Value<int>? id,
    Value<double>? currentTaxMultiplier,
    Value<DateTime>? updatedAt,
  }) {
    return UserStatsCompanion(
      id: id ?? this.id,
      currentTaxMultiplier: currentTaxMultiplier ?? this.currentTaxMultiplier,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentTaxMultiplier.present) {
      map['current_tax_multiplier'] = Variable<double>(
        currentTaxMultiplier.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserStatsCompanion(')
          ..write('id: $id, ')
          ..write('currentTaxMultiplier: $currentTaxMultiplier, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RunCheckpointsTable extends RunCheckpoints
    with TableInfo<$RunCheckpointsTable, RunCheckpointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunCheckpointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointsJsonMeta = const VerificationMeta(
    'pointsJson',
  );
  @override
  late final GeneratedColumn<String> pointsJson = GeneratedColumn<String>(
    'points_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceMetersMeta = const VerificationMeta(
    'distanceMeters',
  );
  @override
  late final GeneratedColumn<double> distanceMeters = GeneratedColumn<double>(
    'distance_meters',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    startedAt,
    pointsJson,
    distanceMeters,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_checkpoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunCheckpointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('points_json')) {
      context.handle(
        _pointsJsonMeta,
        pointsJson.isAcceptableOrUnknown(data['points_json']!, _pointsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_pointsJsonMeta);
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
        _distanceMetersMeta,
        distanceMeters.isAcceptableOrUnknown(
          data['distance_meters']!,
          _distanceMetersMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_distanceMetersMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunCheckpointRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunCheckpointRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      pointsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}points_json'],
      )!,
      distanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_meters'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RunCheckpointsTable createAlias(String alias) {
    return $RunCheckpointsTable(attachedDatabase, alias);
  }
}

class RunCheckpointRow extends DataClass
    implements Insertable<RunCheckpointRow> {
  final int id;
  final String runId;
  final DateTime startedAt;

  /// JSON-encoded `List<TrackPoint>` — see `TrackPoint.toJson`.
  final String pointsJson;
  final double distanceMeters;
  final DateTime updatedAt;
  const RunCheckpointRow({
    required this.id,
    required this.runId,
    required this.startedAt,
    required this.pointsJson,
    required this.distanceMeters,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['run_id'] = Variable<String>(runId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['points_json'] = Variable<String>(pointsJson);
    map['distance_meters'] = Variable<double>(distanceMeters);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RunCheckpointsCompanion toCompanion(bool nullToAbsent) {
    return RunCheckpointsCompanion(
      id: Value(id),
      runId: Value(runId),
      startedAt: Value(startedAt),
      pointsJson: Value(pointsJson),
      distanceMeters: Value(distanceMeters),
      updatedAt: Value(updatedAt),
    );
  }

  factory RunCheckpointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunCheckpointRow(
      id: serializer.fromJson<int>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      pointsJson: serializer.fromJson<String>(json['pointsJson']),
      distanceMeters: serializer.fromJson<double>(json['distanceMeters']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'runId': serializer.toJson<String>(runId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'pointsJson': serializer.toJson<String>(pointsJson),
      'distanceMeters': serializer.toJson<double>(distanceMeters),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RunCheckpointRow copyWith({
    int? id,
    String? runId,
    DateTime? startedAt,
    String? pointsJson,
    double? distanceMeters,
    DateTime? updatedAt,
  }) => RunCheckpointRow(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    startedAt: startedAt ?? this.startedAt,
    pointsJson: pointsJson ?? this.pointsJson,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RunCheckpointRow copyWithCompanion(RunCheckpointsCompanion data) {
    return RunCheckpointRow(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      pointsJson: data.pointsJson.present
          ? data.pointsJson.value
          : this.pointsJson,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunCheckpointRow(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('startedAt: $startedAt, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, runId, startedAt, pointsJson, distanceMeters, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunCheckpointRow &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.startedAt == this.startedAt &&
          other.pointsJson == this.pointsJson &&
          other.distanceMeters == this.distanceMeters &&
          other.updatedAt == this.updatedAt);
}

class RunCheckpointsCompanion extends UpdateCompanion<RunCheckpointRow> {
  final Value<int> id;
  final Value<String> runId;
  final Value<DateTime> startedAt;
  final Value<String> pointsJson;
  final Value<double> distanceMeters;
  final Value<DateTime> updatedAt;
  const RunCheckpointsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.pointsJson = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  RunCheckpointsCompanion.insert({
    this.id = const Value.absent(),
    required String runId,
    required DateTime startedAt,
    required String pointsJson,
    required double distanceMeters,
    required DateTime updatedAt,
  }) : runId = Value(runId),
       startedAt = Value(startedAt),
       pointsJson = Value(pointsJson),
       distanceMeters = Value(distanceMeters),
       updatedAt = Value(updatedAt);
  static Insertable<RunCheckpointRow> custom({
    Expression<int>? id,
    Expression<String>? runId,
    Expression<DateTime>? startedAt,
    Expression<String>? pointsJson,
    Expression<double>? distanceMeters,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (startedAt != null) 'started_at': startedAt,
      if (pointsJson != null) 'points_json': pointsJson,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  RunCheckpointsCompanion copyWith({
    Value<int>? id,
    Value<String>? runId,
    Value<DateTime>? startedAt,
    Value<String>? pointsJson,
    Value<double>? distanceMeters,
    Value<DateTime>? updatedAt,
  }) {
    return RunCheckpointsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      startedAt: startedAt ?? this.startedAt,
      pointsJson: pointsJson ?? this.pointsJson,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (pointsJson.present) {
      map['points_json'] = Variable<String>(pointsJson.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<double>(distanceMeters.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunCheckpointsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('startedAt: $startedAt, ')
          ..write('pointsJson: $pointsJson, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityTableMeta = const VerificationMeta(
    'entityTable',
  );
  @override
  late final GeneratedColumn<String> entityTable = GeneratedColumn<String>(
    'entity_table',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPulledAtMeta = const VerificationMeta(
    'lastPulledAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPulledAt = GeneratedColumn<DateTime>(
    'last_pulled_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entityTable, lastPulledAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_table')) {
      context.handle(
        _entityTableMeta,
        entityTable.isAcceptableOrUnknown(
          data['entity_table']!,
          _entityTableMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_entityTableMeta);
    }
    if (data.containsKey('last_pulled_at')) {
      context.handle(
        _lastPulledAtMeta,
        lastPulledAt.isAcceptableOrUnknown(
          data['last_pulled_at']!,
          _lastPulledAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastPulledAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityTable};
  @override
  SyncMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaRow(
      entityTable: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_table'],
      )!,
      lastPulledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_pulled_at'],
      )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaRow extends DataClass implements Insertable<SyncMetaRow> {
  final String entityTable;
  final DateTime lastPulledAt;
  const SyncMetaRow({required this.entityTable, required this.lastPulledAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_table'] = Variable<String>(entityTable);
    map['last_pulled_at'] = Variable<DateTime>(lastPulledAt);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      entityTable: Value(entityTable),
      lastPulledAt: Value(lastPulledAt),
    );
  }

  factory SyncMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaRow(
      entityTable: serializer.fromJson<String>(json['entityTable']),
      lastPulledAt: serializer.fromJson<DateTime>(json['lastPulledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityTable': serializer.toJson<String>(entityTable),
      'lastPulledAt': serializer.toJson<DateTime>(lastPulledAt),
    };
  }

  SyncMetaRow copyWith({String? entityTable, DateTime? lastPulledAt}) =>
      SyncMetaRow(
        entityTable: entityTable ?? this.entityTable,
        lastPulledAt: lastPulledAt ?? this.lastPulledAt,
      );
  SyncMetaRow copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaRow(
      entityTable: data.entityTable.present
          ? data.entityTable.value
          : this.entityTable,
      lastPulledAt: data.lastPulledAt.present
          ? data.lastPulledAt.value
          : this.lastPulledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaRow(')
          ..write('entityTable: $entityTable, ')
          ..write('lastPulledAt: $lastPulledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entityTable, lastPulledAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaRow &&
          other.entityTable == this.entityTable &&
          other.lastPulledAt == this.lastPulledAt);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaRow> {
  final Value<String> entityTable;
  final Value<DateTime> lastPulledAt;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.entityTable = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String entityTable,
    required DateTime lastPulledAt,
    this.rowid = const Value.absent(),
  }) : entityTable = Value(entityTable),
       lastPulledAt = Value(lastPulledAt);
  static Insertable<SyncMetaRow> custom({
    Expression<String>? entityTable,
    Expression<DateTime>? lastPulledAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityTable != null) 'entity_table': entityTable,
      if (lastPulledAt != null) 'last_pulled_at': lastPulledAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? entityTable,
    Value<DateTime>? lastPulledAt,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      entityTable: entityTable ?? this.entityTable,
      lastPulledAt: lastPulledAt ?? this.lastPulledAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityTable.present) {
      map['entity_table'] = Variable<String>(entityTable.value);
    }
    if (lastPulledAt.present) {
      map['last_pulled_at'] = Variable<DateTime>(lastPulledAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('entityTable: $entityTable, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AlarmsTable alarms = $AlarmsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $RunsTable runs = $RunsTable(this);
  late final $TerritoriesTable territories = $TerritoriesTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $UserStatsTable userStats = $UserStatsTable(this);
  late final $RunCheckpointsTable runCheckpoints = $RunCheckpointsTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final Index syncOutboxNextAttemptAtIdx = Index(
    'sync_outbox_next_attempt_at_idx',
    'CREATE INDEX sync_outbox_next_attempt_at_idx ON sync_outbox (next_attempt_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    alarms,
    sessions,
    runs,
    territories,
    syncOutbox,
    userStats,
    runCheckpoints,
    syncMeta,
    syncOutboxNextAttemptAtIdx,
  ];
}

typedef $$AlarmsTableCreateCompanionBuilder =
    AlarmsCompanion Function({
      required String id,
      Value<int?> nativeId,
      required DateTime scheduledTime,
      required String exerciseMode,
      required int requiredReps,
      Value<double> penaltyMultiplier,
      Value<bool> isActive,
      Value<String> recurringDays,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$AlarmsTableUpdateCompanionBuilder =
    AlarmsCompanion Function({
      Value<String> id,
      Value<int?> nativeId,
      Value<DateTime> scheduledTime,
      Value<String> exerciseMode,
      Value<int> requiredReps,
      Value<double> penaltyMultiplier,
      Value<bool> isActive,
      Value<String> recurringDays,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$AlarmsTableFilterComposer
    extends Composer<_$AppDatabase, $AlarmsTable> {
  $$AlarmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nativeId => $composableBuilder(
    column: $table.nativeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledTime => $composableBuilder(
    column: $table.scheduledTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseMode => $composableBuilder(
    column: $table.exerciseMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requiredReps => $composableBuilder(
    column: $table.requiredReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get penaltyMultiplier => $composableBuilder(
    column: $table.penaltyMultiplier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurringDays => $composableBuilder(
    column: $table.recurringDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlarmsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlarmsTable> {
  $$AlarmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nativeId => $composableBuilder(
    column: $table.nativeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledTime => $composableBuilder(
    column: $table.scheduledTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseMode => $composableBuilder(
    column: $table.exerciseMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requiredReps => $composableBuilder(
    column: $table.requiredReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get penaltyMultiplier => $composableBuilder(
    column: $table.penaltyMultiplier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurringDays => $composableBuilder(
    column: $table.recurringDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlarmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlarmsTable> {
  $$AlarmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get nativeId =>
      $composableBuilder(column: $table.nativeId, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledTime => $composableBuilder(
    column: $table.scheduledTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exerciseMode => $composableBuilder(
    column: $table.exerciseMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get requiredReps => $composableBuilder(
    column: $table.requiredReps,
    builder: (column) => column,
  );

  GeneratedColumn<double> get penaltyMultiplier => $composableBuilder(
    column: $table.penaltyMultiplier,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get recurringDays => $composableBuilder(
    column: $table.recurringDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$AlarmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlarmsTable,
          AlarmRow,
          $$AlarmsTableFilterComposer,
          $$AlarmsTableOrderingComposer,
          $$AlarmsTableAnnotationComposer,
          $$AlarmsTableCreateCompanionBuilder,
          $$AlarmsTableUpdateCompanionBuilder,
          (AlarmRow, BaseReferences<_$AppDatabase, $AlarmsTable, AlarmRow>),
          AlarmRow,
          PrefetchHooks Function()
        > {
  $$AlarmsTableTableManager(_$AppDatabase db, $AlarmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlarmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlarmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlarmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> nativeId = const Value.absent(),
                Value<DateTime> scheduledTime = const Value.absent(),
                Value<String> exerciseMode = const Value.absent(),
                Value<int> requiredReps = const Value.absent(),
                Value<double> penaltyMultiplier = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> recurringDays = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmsCompanion(
                id: id,
                nativeId: nativeId,
                scheduledTime: scheduledTime,
                exerciseMode: exerciseMode,
                requiredReps: requiredReps,
                penaltyMultiplier: penaltyMultiplier,
                isActive: isActive,
                recurringDays: recurringDays,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> nativeId = const Value.absent(),
                required DateTime scheduledTime,
                required String exerciseMode,
                required int requiredReps,
                Value<double> penaltyMultiplier = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> recurringDays = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlarmsCompanion.insert(
                id: id,
                nativeId: nativeId,
                scheduledTime: scheduledTime,
                exerciseMode: exerciseMode,
                requiredReps: requiredReps,
                penaltyMultiplier: penaltyMultiplier,
                isActive: isActive,
                recurringDays: recurringDays,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlarmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlarmsTable,
      AlarmRow,
      $$AlarmsTableFilterComposer,
      $$AlarmsTableOrderingComposer,
      $$AlarmsTableAnnotationComposer,
      $$AlarmsTableCreateCompanionBuilder,
      $$AlarmsTableUpdateCompanionBuilder,
      (AlarmRow, BaseReferences<_$AppDatabase, $AlarmsTable, AlarmRow>),
      AlarmRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      required String id,
      Value<String?> alarmId,
      required String exerciseMode,
      required int repsCompleted,
      required DateTime startedAt,
      Value<DateTime?> completedAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<String> id,
      Value<String?> alarmId,
      Value<String> exerciseMode,
      Value<int> repsCompleted,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alarmId => $composableBuilder(
    column: $table.alarmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseMode => $composableBuilder(
    column: $table.exerciseMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repsCompleted => $composableBuilder(
    column: $table.repsCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alarmId => $composableBuilder(
    column: $table.alarmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseMode => $composableBuilder(
    column: $table.exerciseMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repsCompleted => $composableBuilder(
    column: $table.repsCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alarmId =>
      $composableBuilder(column: $table.alarmId, builder: (column) => column);

  GeneratedColumn<String> get exerciseMode => $composableBuilder(
    column: $table.exerciseMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repsCompleted => $composableBuilder(
    column: $table.repsCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (
            SessionRow,
            BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>,
          ),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> alarmId = const Value.absent(),
                Value<String> exerciseMode = const Value.absent(),
                Value<int> repsCompleted = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                alarmId: alarmId,
                exerciseMode: exerciseMode,
                repsCompleted: repsCompleted,
                startedAt: startedAt,
                completedAt: completedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> alarmId = const Value.absent(),
                required String exerciseMode,
                required int repsCompleted,
                required DateTime startedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                alarmId: alarmId,
                exerciseMode: exerciseMode,
                repsCompleted: repsCompleted,
                startedAt: startedAt,
                completedAt: completedAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $$RunsTableCreateCompanionBuilder =
    RunsCompanion Function({
      required String id,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      required int pointCount,
      required String pathGeoJson,
      Value<String?> pointTimestampsJson,
      Value<bool> isClosedLoop,
      Value<double?> capturedAreaSqm,
      Value<double?> areaSqm,
      Value<String?> integrityVerdict,
      Value<String?> rejectedReason,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$RunsTableUpdateCompanionBuilder =
    RunsCompanion Function({
      Value<String> id,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> pointCount,
      Value<String> pathGeoJson,
      Value<String?> pointTimestampsJson,
      Value<bool> isClosedLoop,
      Value<double?> capturedAreaSqm,
      Value<double?> areaSqm,
      Value<String?> integrityVerdict,
      Value<String?> rejectedReason,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$RunsTableFilterComposer extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pathGeoJson => $composableBuilder(
    column: $table.pathGeoJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pointTimestampsJson => $composableBuilder(
    column: $table.pointTimestampsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isClosedLoop => $composableBuilder(
    column: $table.isClosedLoop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get capturedAreaSqm => $composableBuilder(
    column: $table.capturedAreaSqm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get areaSqm => $composableBuilder(
    column: $table.areaSqm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get integrityVerdict => $composableBuilder(
    column: $table.integrityVerdict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rejectedReason => $composableBuilder(
    column: $table.rejectedReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RunsTableOrderingComposer extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pathGeoJson => $composableBuilder(
    column: $table.pathGeoJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pointTimestampsJson => $composableBuilder(
    column: $table.pointTimestampsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isClosedLoop => $composableBuilder(
    column: $table.isClosedLoop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get capturedAreaSqm => $composableBuilder(
    column: $table.capturedAreaSqm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get areaSqm => $composableBuilder(
    column: $table.areaSqm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get integrityVerdict => $composableBuilder(
    column: $table.integrityVerdict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rejectedReason => $composableBuilder(
    column: $table.rejectedReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get pointCount => $composableBuilder(
    column: $table.pointCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pathGeoJson => $composableBuilder(
    column: $table.pathGeoJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pointTimestampsJson => $composableBuilder(
    column: $table.pointTimestampsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isClosedLoop => $composableBuilder(
    column: $table.isClosedLoop,
    builder: (column) => column,
  );

  GeneratedColumn<double> get capturedAreaSqm => $composableBuilder(
    column: $table.capturedAreaSqm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get areaSqm =>
      $composableBuilder(column: $table.areaSqm, builder: (column) => column);

  GeneratedColumn<String> get integrityVerdict => $composableBuilder(
    column: $table.integrityVerdict,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rejectedReason => $composableBuilder(
    column: $table.rejectedReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$RunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunsTable,
          RunRow,
          $$RunsTableFilterComposer,
          $$RunsTableOrderingComposer,
          $$RunsTableAnnotationComposer,
          $$RunsTableCreateCompanionBuilder,
          $$RunsTableUpdateCompanionBuilder,
          (RunRow, BaseReferences<_$AppDatabase, $RunsTable, RunRow>),
          RunRow,
          PrefetchHooks Function()
        > {
  $$RunsTableTableManager(_$AppDatabase db, $RunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> pointCount = const Value.absent(),
                Value<String> pathGeoJson = const Value.absent(),
                Value<String?> pointTimestampsJson = const Value.absent(),
                Value<bool> isClosedLoop = const Value.absent(),
                Value<double?> capturedAreaSqm = const Value.absent(),
                Value<double?> areaSqm = const Value.absent(),
                Value<String?> integrityVerdict = const Value.absent(),
                Value<String?> rejectedReason = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                pointCount: pointCount,
                pathGeoJson: pathGeoJson,
                pointTimestampsJson: pointTimestampsJson,
                isClosedLoop: isClosedLoop,
                capturedAreaSqm: capturedAreaSqm,
                areaSqm: areaSqm,
                integrityVerdict: integrityVerdict,
                rejectedReason: rejectedReason,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                required int pointCount,
                required String pathGeoJson,
                Value<String?> pointTimestampsJson = const Value.absent(),
                Value<bool> isClosedLoop = const Value.absent(),
                Value<double?> capturedAreaSqm = const Value.absent(),
                Value<double?> areaSqm = const Value.absent(),
                Value<String?> integrityVerdict = const Value.absent(),
                Value<String?> rejectedReason = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                pointCount: pointCount,
                pathGeoJson: pathGeoJson,
                pointTimestampsJson: pointTimestampsJson,
                isClosedLoop: isClosedLoop,
                capturedAreaSqm: capturedAreaSqm,
                areaSqm: areaSqm,
                integrityVerdict: integrityVerdict,
                rejectedReason: rejectedReason,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunsTable,
      RunRow,
      $$RunsTableFilterComposer,
      $$RunsTableOrderingComposer,
      $$RunsTableAnnotationComposer,
      $$RunsTableCreateCompanionBuilder,
      $$RunsTableUpdateCompanionBuilder,
      (RunRow, BaseReferences<_$AppDatabase, $RunsTable, RunRow>),
      RunRow,
      PrefetchHooks Function()
    >;
typedef $$TerritoriesTableCreateCompanionBuilder =
    TerritoriesCompanion Function({
      required String id,
      required String ownerId,
      required String geoJson,
      required double areaSqm,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$TerritoriesTableUpdateCompanionBuilder =
    TerritoriesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> geoJson,
      Value<double> areaSqm,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$TerritoriesTableFilterComposer
    extends Composer<_$AppDatabase, $TerritoriesTable> {
  $$TerritoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geoJson => $composableBuilder(
    column: $table.geoJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get areaSqm => $composableBuilder(
    column: $table.areaSqm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TerritoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $TerritoriesTable> {
  $$TerritoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geoJson => $composableBuilder(
    column: $table.geoJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get areaSqm => $composableBuilder(
    column: $table.areaSqm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TerritoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TerritoriesTable> {
  $$TerritoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get geoJson =>
      $composableBuilder(column: $table.geoJson, builder: (column) => column);

  GeneratedColumn<double> get areaSqm =>
      $composableBuilder(column: $table.areaSqm, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TerritoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TerritoriesTable,
          TerritoryRow,
          $$TerritoriesTableFilterComposer,
          $$TerritoriesTableOrderingComposer,
          $$TerritoriesTableAnnotationComposer,
          $$TerritoriesTableCreateCompanionBuilder,
          $$TerritoriesTableUpdateCompanionBuilder,
          (
            TerritoryRow,
            BaseReferences<_$AppDatabase, $TerritoriesTable, TerritoryRow>,
          ),
          TerritoryRow,
          PrefetchHooks Function()
        > {
  $$TerritoriesTableTableManager(_$AppDatabase db, $TerritoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TerritoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TerritoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TerritoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> geoJson = const Value.absent(),
                Value<double> areaSqm = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TerritoriesCompanion(
                id: id,
                ownerId: ownerId,
                geoJson: geoJson,
                areaSqm: areaSqm,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String geoJson,
                required double areaSqm,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TerritoriesCompanion.insert(
                id: id,
                ownerId: ownerId,
                geoJson: geoJson,
                areaSqm: areaSqm,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TerritoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TerritoriesTable,
      TerritoryRow,
      $$TerritoriesTableFilterComposer,
      $$TerritoriesTableOrderingComposer,
      $$TerritoriesTableAnnotationComposer,
      $$TerritoriesTableCreateCompanionBuilder,
      $$TerritoriesTableUpdateCompanionBuilder,
      (
        TerritoryRow,
        BaseReferences<_$AppDatabase, $TerritoriesTable, TerritoryRow>,
      ),
      TerritoryRow,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxTableCreateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<int> id,
      required String entityTable,
      required String entityId,
      required String operation,
      required String payload,
      required DateTime createdAt,
      required DateTime nextAttemptAt,
      Value<int> attemptCount,
      Value<String?> errorType,
      Value<String?> lastError,
      Value<int> maxAttempts,
    });
typedef $$SyncOutboxTableUpdateCompanionBuilder =
    SyncOutboxCompanion Function({
      Value<int> id,
      Value<String> entityTable,
      Value<String> entityId,
      Value<String> operation,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<DateTime> nextAttemptAt,
      Value<int> attemptCount,
      Value<String?> errorType,
      Value<String?> lastError,
      Value<int> maxAttempts,
    });

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorType => $composableBuilder(
    column: $table.errorType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxAttempts => $composableBuilder(
    column: $table.maxAttempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorType => $composableBuilder(
    column: $table.errorType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxAttempts => $composableBuilder(
    column: $table.maxAttempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorType =>
      $composableBuilder(column: $table.errorType, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get maxAttempts => $composableBuilder(
    column: $table.maxAttempts,
    builder: (column) => column,
  );
}

class $$SyncOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxTable,
          OutboxEntryRow,
          $$SyncOutboxTableFilterComposer,
          $$SyncOutboxTableOrderingComposer,
          $$SyncOutboxTableAnnotationComposer,
          $$SyncOutboxTableCreateCompanionBuilder,
          $$SyncOutboxTableUpdateCompanionBuilder,
          (
            OutboxEntryRow,
            BaseReferences<_$AppDatabase, $SyncOutboxTable, OutboxEntryRow>,
          ),
          OutboxEntryRow,
          PrefetchHooks Function()
        > {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entityTable = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> errorType = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> maxAttempts = const Value.absent(),
              }) => SyncOutboxCompanion(
                id: id,
                entityTable: entityTable,
                entityId: entityId,
                operation: operation,
                payload: payload,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                attemptCount: attemptCount,
                errorType: errorType,
                lastError: lastError,
                maxAttempts: maxAttempts,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entityTable,
                required String entityId,
                required String operation,
                required String payload,
                required DateTime createdAt,
                required DateTime nextAttemptAt,
                Value<int> attemptCount = const Value.absent(),
                Value<String?> errorType = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> maxAttempts = const Value.absent(),
              }) => SyncOutboxCompanion.insert(
                id: id,
                entityTable: entityTable,
                entityId: entityId,
                operation: operation,
                payload: payload,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                attemptCount: attemptCount,
                errorType: errorType,
                lastError: lastError,
                maxAttempts: maxAttempts,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxTable,
      OutboxEntryRow,
      $$SyncOutboxTableFilterComposer,
      $$SyncOutboxTableOrderingComposer,
      $$SyncOutboxTableAnnotationComposer,
      $$SyncOutboxTableCreateCompanionBuilder,
      $$SyncOutboxTableUpdateCompanionBuilder,
      (
        OutboxEntryRow,
        BaseReferences<_$AppDatabase, $SyncOutboxTable, OutboxEntryRow>,
      ),
      OutboxEntryRow,
      PrefetchHooks Function()
    >;
typedef $$UserStatsTableCreateCompanionBuilder =
    UserStatsCompanion Function({
      Value<int> id,
      Value<double> currentTaxMultiplier,
      required DateTime updatedAt,
    });
typedef $$UserStatsTableUpdateCompanionBuilder =
    UserStatsCompanion Function({
      Value<int> id,
      Value<double> currentTaxMultiplier,
      Value<DateTime> updatedAt,
    });

class $$UserStatsTableFilterComposer
    extends Composer<_$AppDatabase, $UserStatsTable> {
  $$UserStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentTaxMultiplier => $composableBuilder(
    column: $table.currentTaxMultiplier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserStatsTable> {
  $$UserStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentTaxMultiplier => $composableBuilder(
    column: $table.currentTaxMultiplier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserStatsTable> {
  $$UserStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get currentTaxMultiplier => $composableBuilder(
    column: $table.currentTaxMultiplier,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserStatsTable,
          UserStatsRow,
          $$UserStatsTableFilterComposer,
          $$UserStatsTableOrderingComposer,
          $$UserStatsTableAnnotationComposer,
          $$UserStatsTableCreateCompanionBuilder,
          $$UserStatsTableUpdateCompanionBuilder,
          (
            UserStatsRow,
            BaseReferences<_$AppDatabase, $UserStatsTable, UserStatsRow>,
          ),
          UserStatsRow,
          PrefetchHooks Function()
        > {
  $$UserStatsTableTableManager(_$AppDatabase db, $UserStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> currentTaxMultiplier = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserStatsCompanion(
                id: id,
                currentTaxMultiplier: currentTaxMultiplier,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double> currentTaxMultiplier = const Value.absent(),
                required DateTime updatedAt,
              }) => UserStatsCompanion.insert(
                id: id,
                currentTaxMultiplier: currentTaxMultiplier,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserStatsTable,
      UserStatsRow,
      $$UserStatsTableFilterComposer,
      $$UserStatsTableOrderingComposer,
      $$UserStatsTableAnnotationComposer,
      $$UserStatsTableCreateCompanionBuilder,
      $$UserStatsTableUpdateCompanionBuilder,
      (
        UserStatsRow,
        BaseReferences<_$AppDatabase, $UserStatsTable, UserStatsRow>,
      ),
      UserStatsRow,
      PrefetchHooks Function()
    >;
typedef $$RunCheckpointsTableCreateCompanionBuilder =
    RunCheckpointsCompanion Function({
      Value<int> id,
      required String runId,
      required DateTime startedAt,
      required String pointsJson,
      required double distanceMeters,
      required DateTime updatedAt,
    });
typedef $$RunCheckpointsTableUpdateCompanionBuilder =
    RunCheckpointsCompanion Function({
      Value<int> id,
      Value<String> runId,
      Value<DateTime> startedAt,
      Value<String> pointsJson,
      Value<double> distanceMeters,
      Value<DateTime> updatedAt,
    });

class $$RunCheckpointsTableFilterComposer
    extends Composer<_$AppDatabase, $RunCheckpointsTable> {
  $$RunCheckpointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RunCheckpointsTableOrderingComposer
    extends Composer<_$AppDatabase, $RunCheckpointsTable> {
  $$RunCheckpointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RunCheckpointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunCheckpointsTable> {
  $$RunCheckpointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get pointsJson => $composableBuilder(
    column: $table.pointsJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RunCheckpointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunCheckpointsTable,
          RunCheckpointRow,
          $$RunCheckpointsTableFilterComposer,
          $$RunCheckpointsTableOrderingComposer,
          $$RunCheckpointsTableAnnotationComposer,
          $$RunCheckpointsTableCreateCompanionBuilder,
          $$RunCheckpointsTableUpdateCompanionBuilder,
          (
            RunCheckpointRow,
            BaseReferences<
              _$AppDatabase,
              $RunCheckpointsTable,
              RunCheckpointRow
            >,
          ),
          RunCheckpointRow,
          PrefetchHooks Function()
        > {
  $$RunCheckpointsTableTableManager(
    _$AppDatabase db,
    $RunCheckpointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunCheckpointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunCheckpointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunCheckpointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<String> pointsJson = const Value.absent(),
                Value<double> distanceMeters = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => RunCheckpointsCompanion(
                id: id,
                runId: runId,
                startedAt: startedAt,
                pointsJson: pointsJson,
                distanceMeters: distanceMeters,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String runId,
                required DateTime startedAt,
                required String pointsJson,
                required double distanceMeters,
                required DateTime updatedAt,
              }) => RunCheckpointsCompanion.insert(
                id: id,
                runId: runId,
                startedAt: startedAt,
                pointsJson: pointsJson,
                distanceMeters: distanceMeters,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RunCheckpointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunCheckpointsTable,
      RunCheckpointRow,
      $$RunCheckpointsTableFilterComposer,
      $$RunCheckpointsTableOrderingComposer,
      $$RunCheckpointsTableAnnotationComposer,
      $$RunCheckpointsTableCreateCompanionBuilder,
      $$RunCheckpointsTableUpdateCompanionBuilder,
      (
        RunCheckpointRow,
        BaseReferences<_$AppDatabase, $RunCheckpointsTable, RunCheckpointRow>,
      ),
      RunCheckpointRow,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder =
    SyncMetaCompanion Function({
      required String entityTable,
      required DateTime lastPulledAt,
      Value<int> rowid,
    });
typedef $$SyncMetaTableUpdateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<String> entityTable,
      Value<DateTime> lastPulledAt,
      Value<int> rowid,
    });

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityTable => $composableBuilder(
    column: $table.entityTable,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => column,
  );
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaRow,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaRow,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaRow>,
          ),
          SyncMetaRow,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entityTable = const Value.absent(),
                Value<DateTime> lastPulledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion(
                entityTable: entityTable,
                lastPulledAt: lastPulledAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entityTable,
                required DateTime lastPulledAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                entityTable: entityTable,
                lastPulledAt: lastPulledAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaRow,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (SyncMetaRow, BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaRow>),
      SyncMetaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AlarmsTableTableManager get alarms =>
      $$AlarmsTableTableManager(_db, _db.alarms);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$RunsTableTableManager get runs => $$RunsTableTableManager(_db, _db.runs);
  $$TerritoriesTableTableManager get territories =>
      $$TerritoriesTableTableManager(_db, _db.territories);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$UserStatsTableTableManager get userStats =>
      $$UserStatsTableTableManager(_db, _db.userStats);
  $$RunCheckpointsTableTableManager get runCheckpoints =>
      $$RunCheckpointsTableTableManager(_db, _db.runCheckpoints);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
}
