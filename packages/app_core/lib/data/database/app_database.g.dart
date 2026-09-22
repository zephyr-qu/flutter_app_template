// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DbArticlesTable extends DbArticles
    with TableInfo<$DbArticlesTable, DbArticle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DbArticlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, body];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'db_articles';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbArticle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbArticle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbArticle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
    );
  }

  @override
  $DbArticlesTable createAlias(String alias) {
    return $DbArticlesTable(attachedDatabase, alias);
  }
}

class DbArticle extends DataClass implements Insertable<DbArticle> {
  final int id;
  final String title;
  final String body;
  const DbArticle({required this.id, required this.title, required this.body});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    return map;
  }

  DbArticlesCompanion toCompanion(bool nullToAbsent) {
    return DbArticlesCompanion(
      id: Value(id),
      title: Value(title),
      body: Value(body),
    );
  }

  factory DbArticle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbArticle(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
    };
  }

  DbArticle copyWith({int? id, String? title, String? body}) => DbArticle(
    id: id ?? this.id,
    title: title ?? this.title,
    body: body ?? this.body,
  );
  DbArticle copyWithCompanion(DbArticlesCompanion data) {
    return DbArticle(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbArticle(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, body);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbArticle &&
          other.id == this.id &&
          other.title == this.title &&
          other.body == this.body);
}

class DbArticlesCompanion extends UpdateCompanion<DbArticle> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> body;
  const DbArticlesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
  });
  DbArticlesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String body,
  }) : title = Value(title),
       body = Value(body);
  static Insertable<DbArticle> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? body,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
    });
  }

  DbArticlesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? body,
  }) {
    return DbArticlesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DbArticlesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DbArticlesTable dbArticles = $DbArticlesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [dbArticles];
}

typedef $$DbArticlesTableCreateCompanionBuilder = DbArticlesCompanion Function({
  Value<int> id,
  required String title,
  required String body,
});
typedef $$DbArticlesTableUpdateCompanionBuilder = DbArticlesCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> body,
});

class $$DbArticlesTableFilterComposer
    extends Composer<_$AppDatabase, $DbArticlesTable> {
  $$DbArticlesTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DbArticlesTableOrderingComposer
    extends Composer<_$AppDatabase, $DbArticlesTable> {
  $$DbArticlesTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DbArticlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DbArticlesTable> {
  $$DbArticlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $$DbArticlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DbArticlesTable,
          DbArticle,
          $$DbArticlesTableFilterComposer,
          $$DbArticlesTableOrderingComposer,
          $$DbArticlesTableAnnotationComposer,
          $$DbArticlesTableCreateCompanionBuilder,
          $$DbArticlesTableUpdateCompanionBuilder,
          (
            DbArticle,
            BaseReferences<_$AppDatabase, $DbArticlesTable, DbArticle>,
          ),
          DbArticle,
          PrefetchHooks Function()
        > {
  $$DbArticlesTableTableManager(_$AppDatabase db, $DbArticlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DbArticlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DbArticlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DbArticlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> body = const Value.absent(),
          }) => DbArticlesCompanion(id: id, title: title, body: body),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            required String body,
          }) => DbArticlesCompanion.insert(id: id, title: title, body: body),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DbArticlesTable, DbArticle>(table),
                  BaseReferences<_$AppDatabase, $DbArticlesTable, DbArticle>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DbArticlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DbArticlesTable,
      DbArticle,
      $$DbArticlesTableFilterComposer,
      $$DbArticlesTableOrderingComposer,
      $$DbArticlesTableAnnotationComposer,
      $$DbArticlesTableCreateCompanionBuilder,
      $$DbArticlesTableUpdateCompanionBuilder,
      (DbArticle, BaseReferences<_$AppDatabase, $DbArticlesTable, DbArticle>),
      DbArticle,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DbArticlesTableTableManager get dbArticles =>
      $$DbArticlesTableTableManager(_db, _db.dbArticles);
}
