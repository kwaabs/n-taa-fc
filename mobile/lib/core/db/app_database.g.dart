// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _contentHashMeta =
      const VerificationMeta('contentHash');
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
      'content_hash', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bundleFilenameMeta =
      const VerificationMeta('bundleFilename');
  @override
  late final GeneratedColumn<String> bundleFilename = GeneratedColumn<String>(
      'bundle_filename', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bundleSizeBytesMeta =
      const VerificationMeta('bundleSizeBytes');
  @override
  late final GeneratedColumn<int> bundleSizeBytes = GeneratedColumn<int>(
      'bundle_size_bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _downloadedAtMeta =
      const VerificationMeta('downloadedAt');
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
      'downloaded_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _areaOfInterestMeta =
      const VerificationMeta('areaOfInterest');
  @override
  late final GeneratedColumn<String> areaOfInterest = GeneratedColumn<String>(
      'area_of_interest', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        description,
        mode,
        status,
        version,
        contentHash,
        bundleFilename,
        bundleSizeBytes,
        downloadedAt,
        areaOfInterest,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(Insertable<Project> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('content_hash')) {
      context.handle(
          _contentHashMeta,
          contentHash.isAcceptableOrUnknown(
              data['content_hash']!, _contentHashMeta));
    }
    if (data.containsKey('bundle_filename')) {
      context.handle(
          _bundleFilenameMeta,
          bundleFilename.isAcceptableOrUnknown(
              data['bundle_filename']!, _bundleFilenameMeta));
    }
    if (data.containsKey('bundle_size_bytes')) {
      context.handle(
          _bundleSizeBytesMeta,
          bundleSizeBytes.isAcceptableOrUnknown(
              data['bundle_size_bytes']!, _bundleSizeBytesMeta));
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
          _downloadedAtMeta,
          downloadedAt.isAcceptableOrUnknown(
              data['downloaded_at']!, _downloadedAtMeta));
    }
    if (data.containsKey('area_of_interest')) {
      context.handle(
          _areaOfInterestMeta,
          areaOfInterest.isAcceptableOrUnknown(
              data['area_of_interest']!, _areaOfInterestMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      contentHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_hash']),
      bundleFilename: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}bundle_filename']),
      bundleSizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bundle_size_bytes']),
      downloadedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}downloaded_at']),
      areaOfInterest: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}area_of_interest']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String name;
  final String? description;
  final String mode;
  final String status;
  final int version;
  final String? contentHash;
  final String? bundleFilename;
  final int? bundleSizeBytes;
  final DateTime? downloadedAt;

  /// GeoJSON geometry string for the project Area of Interest (Polygon).
  final String? areaOfInterest;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Project(
      {required this.id,
      required this.name,
      this.description,
      required this.mode,
      required this.status,
      required this.version,
      this.contentHash,
      this.bundleFilename,
      this.bundleSizeBytes,
      this.downloadedAt,
      this.areaOfInterest,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['mode'] = Variable<String>(mode);
    map['status'] = Variable<String>(status);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    if (!nullToAbsent || bundleFilename != null) {
      map['bundle_filename'] = Variable<String>(bundleFilename);
    }
    if (!nullToAbsent || bundleSizeBytes != null) {
      map['bundle_size_bytes'] = Variable<int>(bundleSizeBytes);
    }
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    }
    if (!nullToAbsent || areaOfInterest != null) {
      map['area_of_interest'] = Variable<String>(areaOfInterest);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      mode: Value(mode),
      status: Value(status),
      version: Value(version),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      bundleFilename: bundleFilename == null && nullToAbsent
          ? const Value.absent()
          : Value(bundleFilename),
      bundleSizeBytes: bundleSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(bundleSizeBytes),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
      areaOfInterest: areaOfInterest == null && nullToAbsent
          ? const Value.absent()
          : Value(areaOfInterest),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Project.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      mode: serializer.fromJson<String>(json['mode']),
      status: serializer.fromJson<String>(json['status']),
      version: serializer.fromJson<int>(json['version']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      bundleFilename: serializer.fromJson<String?>(json['bundleFilename']),
      bundleSizeBytes: serializer.fromJson<int?>(json['bundleSizeBytes']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
      areaOfInterest: serializer.fromJson<String?>(json['areaOfInterest']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'mode': serializer.toJson<String>(mode),
      'status': serializer.toJson<String>(status),
      'version': serializer.toJson<int>(version),
      'contentHash': serializer.toJson<String?>(contentHash),
      'bundleFilename': serializer.toJson<String?>(bundleFilename),
      'bundleSizeBytes': serializer.toJson<int?>(bundleSizeBytes),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
      'areaOfInterest': serializer.toJson<String?>(areaOfInterest),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Project copyWith(
          {String? id,
          String? name,
          Value<String?> description = const Value.absent(),
          String? mode,
          String? status,
          int? version,
          Value<String?> contentHash = const Value.absent(),
          Value<String?> bundleFilename = const Value.absent(),
          Value<int?> bundleSizeBytes = const Value.absent(),
          Value<DateTime?> downloadedAt = const Value.absent(),
          Value<String?> areaOfInterest = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Project(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        mode: mode ?? this.mode,
        status: status ?? this.status,
        version: version ?? this.version,
        contentHash: contentHash.present ? contentHash.value : this.contentHash,
        bundleFilename:
            bundleFilename.present ? bundleFilename.value : this.bundleFilename,
        bundleSizeBytes: bundleSizeBytes.present
            ? bundleSizeBytes.value
            : this.bundleSizeBytes,
        downloadedAt:
            downloadedAt.present ? downloadedAt.value : this.downloadedAt,
        areaOfInterest:
            areaOfInterest.present ? areaOfInterest.value : this.areaOfInterest,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      mode: data.mode.present ? data.mode.value : this.mode,
      status: data.status.present ? data.status.value : this.status,
      version: data.version.present ? data.version.value : this.version,
      contentHash:
          data.contentHash.present ? data.contentHash.value : this.contentHash,
      bundleFilename: data.bundleFilename.present
          ? data.bundleFilename.value
          : this.bundleFilename,
      bundleSizeBytes: data.bundleSizeBytes.present
          ? data.bundleSizeBytes.value
          : this.bundleSizeBytes,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      areaOfInterest: data.areaOfInterest.present
          ? data.areaOfInterest.value
          : this.areaOfInterest,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('mode: $mode, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('contentHash: $contentHash, ')
          ..write('bundleFilename: $bundleFilename, ')
          ..write('bundleSizeBytes: $bundleSizeBytes, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('areaOfInterest: $areaOfInterest, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      description,
      mode,
      status,
      version,
      contentHash,
      bundleFilename,
      bundleSizeBytes,
      downloadedAt,
      areaOfInterest,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.mode == this.mode &&
          other.status == this.status &&
          other.version == this.version &&
          other.contentHash == this.contentHash &&
          other.bundleFilename == this.bundleFilename &&
          other.bundleSizeBytes == this.bundleSizeBytes &&
          other.downloadedAt == this.downloadedAt &&
          other.areaOfInterest == this.areaOfInterest &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String> mode;
  final Value<String> status;
  final Value<int> version;
  final Value<String?> contentHash;
  final Value<String?> bundleFilename;
  final Value<int?> bundleSizeBytes;
  final Value<DateTime?> downloadedAt;
  final Value<String?> areaOfInterest;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.mode = const Value.absent(),
    this.status = const Value.absent(),
    this.version = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.bundleFilename = const Value.absent(),
    this.bundleSizeBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.areaOfInterest = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String mode,
    required String status,
    this.version = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.bundleFilename = const Value.absent(),
    this.bundleSizeBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.areaOfInterest = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        mode = Value(mode),
        status = Value(status);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? mode,
    Expression<String>? status,
    Expression<int>? version,
    Expression<String>? contentHash,
    Expression<String>? bundleFilename,
    Expression<int>? bundleSizeBytes,
    Expression<DateTime>? downloadedAt,
    Expression<String>? areaOfInterest,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (mode != null) 'mode': mode,
      if (status != null) 'status': status,
      if (version != null) 'version': version,
      if (contentHash != null) 'content_hash': contentHash,
      if (bundleFilename != null) 'bundle_filename': bundleFilename,
      if (bundleSizeBytes != null) 'bundle_size_bytes': bundleSizeBytes,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (areaOfInterest != null) 'area_of_interest': areaOfInterest,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<String>? mode,
      Value<String>? status,
      Value<int>? version,
      Value<String?>? contentHash,
      Value<String?>? bundleFilename,
      Value<int?>? bundleSizeBytes,
      Value<DateTime?>? downloadedAt,
      Value<String?>? areaOfInterest,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      mode: mode ?? this.mode,
      status: status ?? this.status,
      version: version ?? this.version,
      contentHash: contentHash ?? this.contentHash,
      bundleFilename: bundleFilename ?? this.bundleFilename,
      bundleSizeBytes: bundleSizeBytes ?? this.bundleSizeBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      areaOfInterest: areaOfInterest ?? this.areaOfInterest,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (bundleFilename.present) {
      map['bundle_filename'] = Variable<String>(bundleFilename.value);
    }
    if (bundleSizeBytes.present) {
      map['bundle_size_bytes'] = Variable<int>(bundleSizeBytes.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (areaOfInterest.present) {
      map['area_of_interest'] = Variable<String>(areaOfInterest.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('mode: $mode, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('contentHash: $contentHash, ')
          ..write('bundleFilename: $bundleFilename, ')
          ..write('bundleSizeBytes: $bundleSizeBytes, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('areaOfInterest: $areaOfInterest, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FormsTable extends Forms with TableInfo<$FormsTable, Form> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FormsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _schemaMeta = const VerificationMeta('schema');
  @override
  late final GeneratedColumn<String> schema = GeneratedColumn<String>(
      'schema', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _downloadedAtMeta =
      const VerificationMeta('downloadedAt');
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
      'downloaded_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, projectId, name, description, version, schema, downloadedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'forms';
  @override
  VerificationContext validateIntegrity(Insertable<Form> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('schema')) {
      context.handle(_schemaMeta,
          schema.isAcceptableOrUnknown(data['schema']!, _schemaMeta));
    } else if (isInserting) {
      context.missing(_schemaMeta);
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
          _downloadedAtMeta,
          downloadedAt.isAcceptableOrUnknown(
              data['downloaded_at']!, _downloadedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Form map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Form(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      schema: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}schema'])!,
      downloadedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}downloaded_at'])!,
    );
  }

  @override
  $FormsTable createAlias(String alias) {
    return $FormsTable(attachedDatabase, alias);
  }
}

class Form extends DataClass implements Insertable<Form> {
  final String id;
  final String projectId;
  final String name;
  final String? description;
  final int version;
  final String schema;
  final DateTime downloadedAt;
  const Form(
      {required this.id,
      required this.projectId,
      required this.name,
      this.description,
      required this.version,
      required this.schema,
      required this.downloadedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['version'] = Variable<int>(version);
    map['schema'] = Variable<String>(schema);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  FormsCompanion toCompanion(bool nullToAbsent) {
    return FormsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      version: Value(version),
      schema: Value(schema),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory Form.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Form(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      version: serializer.fromJson<int>(json['version']),
      schema: serializer.fromJson<String>(json['schema']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'version': serializer.toJson<int>(version),
      'schema': serializer.toJson<String>(schema),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  Form copyWith(
          {String? id,
          String? projectId,
          String? name,
          Value<String?> description = const Value.absent(),
          int? version,
          String? schema,
          DateTime? downloadedAt}) =>
      Form(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        version: version ?? this.version,
        schema: schema ?? this.schema,
        downloadedAt: downloadedAt ?? this.downloadedAt,
      );
  Form copyWithCompanion(FormsCompanion data) {
    return Form(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      version: data.version.present ? data.version.value : this.version,
      schema: data.schema.present ? data.schema.value : this.schema,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Form(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('version: $version, ')
          ..write('schema: $schema, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, projectId, name, description, version, schema, downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Form &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.description == this.description &&
          other.version == this.version &&
          other.schema == this.schema &&
          other.downloadedAt == this.downloadedAt);
}

class FormsCompanion extends UpdateCompanion<Form> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> version;
  final Value<String> schema;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const FormsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.version = const Value.absent(),
    this.schema = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FormsCompanion.insert({
    required String id,
    required String projectId,
    required String name,
    this.description = const Value.absent(),
    this.version = const Value.absent(),
    required String schema,
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        name = Value(name),
        schema = Value(schema);
  static Insertable<Form> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? version,
    Expression<String>? schema,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (version != null) 'version': version,
      if (schema != null) 'schema': schema,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FormsCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? name,
      Value<String?>? description,
      Value<int>? version,
      Value<String>? schema,
      Value<DateTime>? downloadedAt,
      Value<int>? rowid}) {
    return FormsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      schema: schema ?? this.schema,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (schema.present) {
      map['schema'] = Variable<String>(schema.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FormsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('version: $version, ')
          ..write('schema: $schema, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LayersTable extends Layers with TableInfo<$LayersTable, Layer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _geometryTypeMeta =
      const VerificationMeta('geometryType');
  @override
  late final GeneratedColumn<String> geometryType = GeneratedColumn<String>(
      'geometry_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _formIdMeta = const VerificationMeta('formId');
  @override
  late final GeneratedColumn<String> formId = GeneratedColumn<String>(
      'form_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _styleMeta = const VerificationMeta('style');
  @override
  late final GeneratedColumn<String> style = GeneratedColumn<String>(
      'style', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dataSourceIdMeta =
      const VerificationMeta('dataSourceId');
  @override
  late final GeneratedColumn<String> dataSourceId = GeneratedColumn<String>(
      'data_source_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _downloadedAtMeta =
      const VerificationMeta('downloadedAt');
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
      'downloaded_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        name,
        geometryType,
        formId,
        style,
        dataSourceId,
        downloadedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'layers';
  @override
  VerificationContext validateIntegrity(Insertable<Layer> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('geometry_type')) {
      context.handle(
          _geometryTypeMeta,
          geometryType.isAcceptableOrUnknown(
              data['geometry_type']!, _geometryTypeMeta));
    } else if (isInserting) {
      context.missing(_geometryTypeMeta);
    }
    if (data.containsKey('form_id')) {
      context.handle(_formIdMeta,
          formId.isAcceptableOrUnknown(data['form_id']!, _formIdMeta));
    }
    if (data.containsKey('style')) {
      context.handle(
          _styleMeta, style.isAcceptableOrUnknown(data['style']!, _styleMeta));
    }
    if (data.containsKey('data_source_id')) {
      context.handle(
          _dataSourceIdMeta,
          dataSourceId.isAcceptableOrUnknown(
              data['data_source_id']!, _dataSourceIdMeta));
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
          _downloadedAtMeta,
          downloadedAt.isAcceptableOrUnknown(
              data['downloaded_at']!, _downloadedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Layer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Layer(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      geometryType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}geometry_type'])!,
      formId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}form_id']),
      style: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}style']),
      dataSourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_source_id']),
      downloadedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}downloaded_at'])!,
    );
  }

  @override
  $LayersTable createAlias(String alias) {
    return $LayersTable(attachedDatabase, alias);
  }
}

class Layer extends DataClass implements Insertable<Layer> {
  final String id;
  final String projectId;
  final String name;
  final String geometryType;
  final String? formId;
  final String? style;

  /// If this layer was imported from an external data source, this is its id.
  /// Used by D-phase to know where edits / deletes should be pushed back to.
  final String? dataSourceId;
  final DateTime downloadedAt;
  const Layer(
      {required this.id,
      required this.projectId,
      required this.name,
      required this.geometryType,
      this.formId,
      this.style,
      this.dataSourceId,
      required this.downloadedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['name'] = Variable<String>(name);
    map['geometry_type'] = Variable<String>(geometryType);
    if (!nullToAbsent || formId != null) {
      map['form_id'] = Variable<String>(formId);
    }
    if (!nullToAbsent || style != null) {
      map['style'] = Variable<String>(style);
    }
    if (!nullToAbsent || dataSourceId != null) {
      map['data_source_id'] = Variable<String>(dataSourceId);
    }
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  LayersCompanion toCompanion(bool nullToAbsent) {
    return LayersCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      geometryType: Value(geometryType),
      formId:
          formId == null && nullToAbsent ? const Value.absent() : Value(formId),
      style:
          style == null && nullToAbsent ? const Value.absent() : Value(style),
      dataSourceId: dataSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(dataSourceId),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory Layer.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Layer(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      geometryType: serializer.fromJson<String>(json['geometryType']),
      formId: serializer.fromJson<String?>(json['formId']),
      style: serializer.fromJson<String?>(json['style']),
      dataSourceId: serializer.fromJson<String?>(json['dataSourceId']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String>(name),
      'geometryType': serializer.toJson<String>(geometryType),
      'formId': serializer.toJson<String?>(formId),
      'style': serializer.toJson<String?>(style),
      'dataSourceId': serializer.toJson<String?>(dataSourceId),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  Layer copyWith(
          {String? id,
          String? projectId,
          String? name,
          String? geometryType,
          Value<String?> formId = const Value.absent(),
          Value<String?> style = const Value.absent(),
          Value<String?> dataSourceId = const Value.absent(),
          DateTime? downloadedAt}) =>
      Layer(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        name: name ?? this.name,
        geometryType: geometryType ?? this.geometryType,
        formId: formId.present ? formId.value : this.formId,
        style: style.present ? style.value : this.style,
        dataSourceId:
            dataSourceId.present ? dataSourceId.value : this.dataSourceId,
        downloadedAt: downloadedAt ?? this.downloadedAt,
      );
  Layer copyWithCompanion(LayersCompanion data) {
    return Layer(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      geometryType: data.geometryType.present
          ? data.geometryType.value
          : this.geometryType,
      formId: data.formId.present ? data.formId.value : this.formId,
      style: data.style.present ? data.style.value : this.style,
      dataSourceId: data.dataSourceId.present
          ? data.dataSourceId.value
          : this.dataSourceId,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Layer(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('geometryType: $geometryType, ')
          ..write('formId: $formId, ')
          ..write('style: $style, ')
          ..write('dataSourceId: $dataSourceId, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, name, geometryType, formId,
      style, dataSourceId, downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Layer &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.geometryType == this.geometryType &&
          other.formId == this.formId &&
          other.style == this.style &&
          other.dataSourceId == this.dataSourceId &&
          other.downloadedAt == this.downloadedAt);
}

class LayersCompanion extends UpdateCompanion<Layer> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> name;
  final Value<String> geometryType;
  final Value<String?> formId;
  final Value<String?> style;
  final Value<String?> dataSourceId;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const LayersCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.geometryType = const Value.absent(),
    this.formId = const Value.absent(),
    this.style = const Value.absent(),
    this.dataSourceId = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LayersCompanion.insert({
    required String id,
    required String projectId,
    required String name,
    required String geometryType,
    this.formId = const Value.absent(),
    this.style = const Value.absent(),
    this.dataSourceId = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        name = Value(name),
        geometryType = Value(geometryType);
  static Insertable<Layer> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<String>? geometryType,
    Expression<String>? formId,
    Expression<String>? style,
    Expression<String>? dataSourceId,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (geometryType != null) 'geometry_type': geometryType,
      if (formId != null) 'form_id': formId,
      if (style != null) 'style': style,
      if (dataSourceId != null) 'data_source_id': dataSourceId,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LayersCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? name,
      Value<String>? geometryType,
      Value<String?>? formId,
      Value<String?>? style,
      Value<String?>? dataSourceId,
      Value<DateTime>? downloadedAt,
      Value<int>? rowid}) {
    return LayersCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      geometryType: geometryType ?? this.geometryType,
      formId: formId ?? this.formId,
      style: style ?? this.style,
      dataSourceId: dataSourceId ?? this.dataSourceId,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (geometryType.present) {
      map['geometry_type'] = Variable<String>(geometryType.value);
    }
    if (formId.present) {
      map['form_id'] = Variable<String>(formId.value);
    }
    if (style.present) {
      map['style'] = Variable<String>(style.value);
    }
    if (dataSourceId.present) {
      map['data_source_id'] = Variable<String>(dataSourceId.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LayersCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('geometryType: $geometryType, ')
          ..write('formId: $formId, ')
          ..write('style: $style, ')
          ..write('dataSourceId: $dataSourceId, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChoiceListsTable extends ChoiceLists
    with TableInfo<$ChoiceListsTable, ChoiceList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChoiceListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _choicesMeta =
      const VerificationMeta('choices');
  @override
  late final GeneratedColumn<String> choices = GeneratedColumn<String>(
      'choices', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _downloadedAtMeta =
      const VerificationMeta('downloadedAt');
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
      'downloaded_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, projectId, name, choices, downloadedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'choice_lists';
  @override
  VerificationContext validateIntegrity(Insertable<ChoiceList> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('choices')) {
      context.handle(_choicesMeta,
          choices.isAcceptableOrUnknown(data['choices']!, _choicesMeta));
    } else if (isInserting) {
      context.missing(_choicesMeta);
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
          _downloadedAtMeta,
          downloadedAt.isAcceptableOrUnknown(
              data['downloaded_at']!, _downloadedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChoiceList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChoiceList(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      choices: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}choices'])!,
      downloadedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}downloaded_at'])!,
    );
  }

  @override
  $ChoiceListsTable createAlias(String alias) {
    return $ChoiceListsTable(attachedDatabase, alias);
  }
}

class ChoiceList extends DataClass implements Insertable<ChoiceList> {
  final String id;
  final String projectId;
  final String name;
  final String choices;
  final DateTime downloadedAt;
  const ChoiceList(
      {required this.id,
      required this.projectId,
      required this.name,
      required this.choices,
      required this.downloadedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['name'] = Variable<String>(name);
    map['choices'] = Variable<String>(choices);
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  ChoiceListsCompanion toCompanion(bool nullToAbsent) {
    return ChoiceListsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      choices: Value(choices),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory ChoiceList.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChoiceList(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      name: serializer.fromJson<String>(json['name']),
      choices: serializer.fromJson<String>(json['choices']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'name': serializer.toJson<String>(name),
      'choices': serializer.toJson<String>(choices),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  ChoiceList copyWith(
          {String? id,
          String? projectId,
          String? name,
          String? choices,
          DateTime? downloadedAt}) =>
      ChoiceList(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        name: name ?? this.name,
        choices: choices ?? this.choices,
        downloadedAt: downloadedAt ?? this.downloadedAt,
      );
  ChoiceList copyWithCompanion(ChoiceListsCompanion data) {
    return ChoiceList(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      name: data.name.present ? data.name.value : this.name,
      choices: data.choices.present ? data.choices.value : this.choices,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChoiceList(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('choices: $choices, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, name, choices, downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChoiceList &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.name == this.name &&
          other.choices == this.choices &&
          other.downloadedAt == this.downloadedAt);
}

class ChoiceListsCompanion extends UpdateCompanion<ChoiceList> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> name;
  final Value<String> choices;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const ChoiceListsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.name = const Value.absent(),
    this.choices = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChoiceListsCompanion.insert({
    required String id,
    required String projectId,
    required String name,
    required String choices,
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        name = Value(name),
        choices = Value(choices);
  static Insertable<ChoiceList> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? name,
    Expression<String>? choices,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (name != null) 'name': name,
      if (choices != null) 'choices': choices,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChoiceListsCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? name,
      Value<String>? choices,
      Value<DateTime>? downloadedAt,
      Value<int>? rowid}) {
    return ChoiceListsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      choices: choices ?? this.choices,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (choices.present) {
      map['choices'] = Variable<String>(choices.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChoiceListsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('name: $name, ')
          ..write('choices: $choices, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssignmentsTable extends Assignments
    with TableInfo<$AssignmentsTable, Assignment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssignmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _instructionsMeta =
      const VerificationMeta('instructions');
  @override
  late final GeneratedColumn<String> instructions = GeneratedColumn<String>(
      'instructions', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
      'priority', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dueDateMeta =
      const VerificationMeta('dueDate');
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
      'due_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _targetCountMeta =
      const VerificationMeta('targetCount');
  @override
  late final GeneratedColumn<int> targetCount = GeneratedColumn<int>(
      'target_count', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _areaMeta = const VerificationMeta('area');
  @override
  late final GeneratedColumn<String> area = GeneratedColumn<String>(
      'area', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _downloadedAtMeta =
      const VerificationMeta('downloadedAt');
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
      'downloaded_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        title,
        instructions,
        priority,
        dueDate,
        targetCount,
        status,
        area,
        downloadedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assignments';
  @override
  VerificationContext validateIntegrity(Insertable<Assignment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('instructions')) {
      context.handle(
          _instructionsMeta,
          instructions.isAcceptableOrUnknown(
              data['instructions']!, _instructionsMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    if (data.containsKey('due_date')) {
      context.handle(_dueDateMeta,
          dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta));
    }
    if (data.containsKey('target_count')) {
      context.handle(
          _targetCountMeta,
          targetCount.isAcceptableOrUnknown(
              data['target_count']!, _targetCountMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('area')) {
      context.handle(
          _areaMeta, area.isAcceptableOrUnknown(data['area']!, _areaMeta));
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
          _downloadedAtMeta,
          downloadedAt.isAcceptableOrUnknown(
              data['downloaded_at']!, _downloadedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Assignment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Assignment(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      instructions: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}instructions']),
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}priority']),
      dueDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}due_date']),
      targetCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}target_count']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      area: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}area']),
      downloadedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}downloaded_at'])!,
    );
  }

  @override
  $AssignmentsTable createAlias(String alias) {
    return $AssignmentsTable(attachedDatabase, alias);
  }
}

class Assignment extends DataClass implements Insertable<Assignment> {
  final String id;
  final String projectId;
  final String? title;
  final String? instructions;
  final String? priority;
  final DateTime? dueDate;
  final int? targetCount;
  final String status;
  final String? area;
  final DateTime downloadedAt;
  const Assignment(
      {required this.id,
      required this.projectId,
      this.title,
      this.instructions,
      this.priority,
      this.dueDate,
      this.targetCount,
      required this.status,
      this.area,
      required this.downloadedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || instructions != null) {
      map['instructions'] = Variable<String>(instructions);
    }
    if (!nullToAbsent || priority != null) {
      map['priority'] = Variable<String>(priority);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || targetCount != null) {
      map['target_count'] = Variable<int>(targetCount);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || area != null) {
      map['area'] = Variable<String>(area);
    }
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  AssignmentsCompanion toCompanion(bool nullToAbsent) {
    return AssignmentsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      instructions: instructions == null && nullToAbsent
          ? const Value.absent()
          : Value(instructions),
      priority: priority == null && nullToAbsent
          ? const Value.absent()
          : Value(priority),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      targetCount: targetCount == null && nullToAbsent
          ? const Value.absent()
          : Value(targetCount),
      status: Value(status),
      area: area == null && nullToAbsent ? const Value.absent() : Value(area),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory Assignment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Assignment(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      title: serializer.fromJson<String?>(json['title']),
      instructions: serializer.fromJson<String?>(json['instructions']),
      priority: serializer.fromJson<String?>(json['priority']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      targetCount: serializer.fromJson<int?>(json['targetCount']),
      status: serializer.fromJson<String>(json['status']),
      area: serializer.fromJson<String?>(json['area']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'title': serializer.toJson<String?>(title),
      'instructions': serializer.toJson<String?>(instructions),
      'priority': serializer.toJson<String?>(priority),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'targetCount': serializer.toJson<int?>(targetCount),
      'status': serializer.toJson<String>(status),
      'area': serializer.toJson<String?>(area),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  Assignment copyWith(
          {String? id,
          String? projectId,
          Value<String?> title = const Value.absent(),
          Value<String?> instructions = const Value.absent(),
          Value<String?> priority = const Value.absent(),
          Value<DateTime?> dueDate = const Value.absent(),
          Value<int?> targetCount = const Value.absent(),
          String? status,
          Value<String?> area = const Value.absent(),
          DateTime? downloadedAt}) =>
      Assignment(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        title: title.present ? title.value : this.title,
        instructions:
            instructions.present ? instructions.value : this.instructions,
        priority: priority.present ? priority.value : this.priority,
        dueDate: dueDate.present ? dueDate.value : this.dueDate,
        targetCount: targetCount.present ? targetCount.value : this.targetCount,
        status: status ?? this.status,
        area: area.present ? area.value : this.area,
        downloadedAt: downloadedAt ?? this.downloadedAt,
      );
  Assignment copyWithCompanion(AssignmentsCompanion data) {
    return Assignment(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      title: data.title.present ? data.title.value : this.title,
      instructions: data.instructions.present
          ? data.instructions.value
          : this.instructions,
      priority: data.priority.present ? data.priority.value : this.priority,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      targetCount:
          data.targetCount.present ? data.targetCount.value : this.targetCount,
      status: data.status.present ? data.status.value : this.status,
      area: data.area.present ? data.area.value : this.area,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Assignment(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('instructions: $instructions, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('targetCount: $targetCount, ')
          ..write('status: $status, ')
          ..write('area: $area, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, title, instructions, priority,
      dueDate, targetCount, status, area, downloadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Assignment &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.title == this.title &&
          other.instructions == this.instructions &&
          other.priority == this.priority &&
          other.dueDate == this.dueDate &&
          other.targetCount == this.targetCount &&
          other.status == this.status &&
          other.area == this.area &&
          other.downloadedAt == this.downloadedAt);
}

class AssignmentsCompanion extends UpdateCompanion<Assignment> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String?> title;
  final Value<String?> instructions;
  final Value<String?> priority;
  final Value<DateTime?> dueDate;
  final Value<int?> targetCount;
  final Value<String> status;
  final Value<String?> area;
  final Value<DateTime> downloadedAt;
  final Value<int> rowid;
  const AssignmentsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.title = const Value.absent(),
    this.instructions = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.targetCount = const Value.absent(),
    this.status = const Value.absent(),
    this.area = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssignmentsCompanion.insert({
    required String id,
    required String projectId,
    this.title = const Value.absent(),
    this.instructions = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.targetCount = const Value.absent(),
    this.status = const Value.absent(),
    this.area = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId);
  static Insertable<Assignment> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? title,
    Expression<String>? instructions,
    Expression<String>? priority,
    Expression<DateTime>? dueDate,
    Expression<int>? targetCount,
    Expression<String>? status,
    Expression<String>? area,
    Expression<DateTime>? downloadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (title != null) 'title': title,
      if (instructions != null) 'instructions': instructions,
      if (priority != null) 'priority': priority,
      if (dueDate != null) 'due_date': dueDate,
      if (targetCount != null) 'target_count': targetCount,
      if (status != null) 'status': status,
      if (area != null) 'area': area,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssignmentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String?>? title,
      Value<String?>? instructions,
      Value<String?>? priority,
      Value<DateTime?>? dueDate,
      Value<int?>? targetCount,
      Value<String>? status,
      Value<String?>? area,
      Value<DateTime>? downloadedAt,
      Value<int>? rowid}) {
    return AssignmentsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      targetCount: targetCount ?? this.targetCount,
      status: status ?? this.status,
      area: area ?? this.area,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (instructions.present) {
      map['instructions'] = Variable<String>(instructions.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (targetCount.present) {
      map['target_count'] = Variable<int>(targetCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (area.present) {
      map['area'] = Variable<String>(area.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssignmentsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('title: $title, ')
          ..write('instructions: $instructions, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('targetCount: $targetCount, ')
          ..write('status: $status, ')
          ..write('area: $area, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReferenceFeaturesTable extends ReferenceFeatures
    with TableInfo<$ReferenceFeaturesTable, ReferenceFeature> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReferenceFeaturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _layerIdMeta =
      const VerificationMeta('layerId');
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
      'layer_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _geometryMeta =
      const VerificationMeta('geometry');
  @override
  late final GeneratedColumn<String> geometry = GeneratedColumn<String>(
      'geometry', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attributesMeta =
      const VerificationMeta('attributes');
  @override
  late final GeneratedColumn<String> attributes = GeneratedColumn<String>(
      'attributes', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceRefMeta =
      const VerificationMeta('sourceRef');
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
      'source_ref', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dataSourceIdMeta =
      const VerificationMeta('dataSourceId');
  @override
  late final GeneratedColumn<String> dataSourceId = GeneratedColumn<String>(
      'data_source_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, projectId, layerId, geometry, attributes, sourceRef, dataSourceId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reference_features';
  @override
  VerificationContext validateIntegrity(Insertable<ReferenceFeature> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(_layerIdMeta,
          layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta));
    } else if (isInserting) {
      context.missing(_layerIdMeta);
    }
    if (data.containsKey('geometry')) {
      context.handle(_geometryMeta,
          geometry.isAcceptableOrUnknown(data['geometry']!, _geometryMeta));
    } else if (isInserting) {
      context.missing(_geometryMeta);
    }
    if (data.containsKey('attributes')) {
      context.handle(
          _attributesMeta,
          attributes.isAcceptableOrUnknown(
              data['attributes']!, _attributesMeta));
    } else if (isInserting) {
      context.missing(_attributesMeta);
    }
    if (data.containsKey('source_ref')) {
      context.handle(_sourceRefMeta,
          sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta));
    }
    if (data.containsKey('data_source_id')) {
      context.handle(
          _dataSourceIdMeta,
          dataSourceId.isAcceptableOrUnknown(
              data['data_source_id']!, _dataSourceIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReferenceFeature map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReferenceFeature(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      layerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}layer_id'])!,
      geometry: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}geometry'])!,
      attributes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attributes'])!,
      sourceRef: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_ref']),
      dataSourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_source_id']),
    );
  }

  @override
  $ReferenceFeaturesTable createAlias(String alias) {
    return $ReferenceFeaturesTable(attachedDatabase, alias);
  }
}

class ReferenceFeature extends DataClass
    implements Insertable<ReferenceFeature> {
  final String id;
  final String projectId;
  final String layerId;
  final String geometry;
  final String attributes;
  final String? sourceRef;

  /// Identifier of the external data source this row was imported from.
  /// Mirrors `layers.dataSourceId` — denormalized for easy access during edits.
  final String? dataSourceId;
  const ReferenceFeature(
      {required this.id,
      required this.projectId,
      required this.layerId,
      required this.geometry,
      required this.attributes,
      this.sourceRef,
      this.dataSourceId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['layer_id'] = Variable<String>(layerId);
    map['geometry'] = Variable<String>(geometry);
    map['attributes'] = Variable<String>(attributes);
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    if (!nullToAbsent || dataSourceId != null) {
      map['data_source_id'] = Variable<String>(dataSourceId);
    }
    return map;
  }

  ReferenceFeaturesCompanion toCompanion(bool nullToAbsent) {
    return ReferenceFeaturesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      layerId: Value(layerId),
      geometry: Value(geometry),
      attributes: Value(attributes),
      sourceRef: sourceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRef),
      dataSourceId: dataSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(dataSourceId),
    );
  }

  factory ReferenceFeature.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReferenceFeature(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      layerId: serializer.fromJson<String>(json['layerId']),
      geometry: serializer.fromJson<String>(json['geometry']),
      attributes: serializer.fromJson<String>(json['attributes']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
      dataSourceId: serializer.fromJson<String?>(json['dataSourceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'layerId': serializer.toJson<String>(layerId),
      'geometry': serializer.toJson<String>(geometry),
      'attributes': serializer.toJson<String>(attributes),
      'sourceRef': serializer.toJson<String?>(sourceRef),
      'dataSourceId': serializer.toJson<String?>(dataSourceId),
    };
  }

  ReferenceFeature copyWith(
          {String? id,
          String? projectId,
          String? layerId,
          String? geometry,
          String? attributes,
          Value<String?> sourceRef = const Value.absent(),
          Value<String?> dataSourceId = const Value.absent()}) =>
      ReferenceFeature(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        layerId: layerId ?? this.layerId,
        geometry: geometry ?? this.geometry,
        attributes: attributes ?? this.attributes,
        sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
        dataSourceId:
            dataSourceId.present ? dataSourceId.value : this.dataSourceId,
      );
  ReferenceFeature copyWithCompanion(ReferenceFeaturesCompanion data) {
    return ReferenceFeature(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      geometry: data.geometry.present ? data.geometry.value : this.geometry,
      attributes:
          data.attributes.present ? data.attributes.value : this.attributes,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
      dataSourceId: data.dataSourceId.present
          ? data.dataSourceId.value
          : this.dataSourceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReferenceFeature(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('layerId: $layerId, ')
          ..write('geometry: $geometry, ')
          ..write('attributes: $attributes, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('dataSourceId: $dataSourceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, projectId, layerId, geometry, attributes, sourceRef, dataSourceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceFeature &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.layerId == this.layerId &&
          other.geometry == this.geometry &&
          other.attributes == this.attributes &&
          other.sourceRef == this.sourceRef &&
          other.dataSourceId == this.dataSourceId);
}

class ReferenceFeaturesCompanion extends UpdateCompanion<ReferenceFeature> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> layerId;
  final Value<String> geometry;
  final Value<String> attributes;
  final Value<String?> sourceRef;
  final Value<String?> dataSourceId;
  final Value<int> rowid;
  const ReferenceFeaturesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.layerId = const Value.absent(),
    this.geometry = const Value.absent(),
    this.attributes = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.dataSourceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReferenceFeaturesCompanion.insert({
    required String id,
    required String projectId,
    required String layerId,
    required String geometry,
    required String attributes,
    this.sourceRef = const Value.absent(),
    this.dataSourceId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        layerId = Value(layerId),
        geometry = Value(geometry),
        attributes = Value(attributes);
  static Insertable<ReferenceFeature> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? layerId,
    Expression<String>? geometry,
    Expression<String>? attributes,
    Expression<String>? sourceRef,
    Expression<String>? dataSourceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (layerId != null) 'layer_id': layerId,
      if (geometry != null) 'geometry': geometry,
      if (attributes != null) 'attributes': attributes,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (dataSourceId != null) 'data_source_id': dataSourceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReferenceFeaturesCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? layerId,
      Value<String>? geometry,
      Value<String>? attributes,
      Value<String?>? sourceRef,
      Value<String?>? dataSourceId,
      Value<int>? rowid}) {
    return ReferenceFeaturesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      layerId: layerId ?? this.layerId,
      geometry: geometry ?? this.geometry,
      attributes: attributes ?? this.attributes,
      sourceRef: sourceRef ?? this.sourceRef,
      dataSourceId: dataSourceId ?? this.dataSourceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (geometry.present) {
      map['geometry'] = Variable<String>(geometry.value);
    }
    if (attributes.present) {
      map['attributes'] = Variable<String>(attributes.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (dataSourceId.present) {
      map['data_source_id'] = Variable<String>(dataSourceId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReferenceFeaturesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('layerId: $layerId, ')
          ..write('geometry: $geometry, ')
          ..write('attributes: $attributes, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('dataSourceId: $dataSourceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectedFeaturesTable extends CollectedFeatures
    with TableInfo<$CollectedFeaturesTable, CollectedFeature> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectedFeaturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientIdMeta =
      const VerificationMeta('clientId');
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
      'client_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES projects (id) ON DELETE CASCADE'));
  static const VerificationMeta _layerIdMeta =
      const VerificationMeta('layerId');
  @override
  late final GeneratedColumn<String> layerId = GeneratedColumn<String>(
      'layer_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _formIdMeta = const VerificationMeta('formId');
  @override
  late final GeneratedColumn<String> formId = GeneratedColumn<String>(
      'form_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _formVersionMeta =
      const VerificationMeta('formVersion');
  @override
  late final GeneratedColumn<int> formVersion = GeneratedColumn<int>(
      'form_version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _geometryMeta =
      const VerificationMeta('geometry');
  @override
  late final GeneratedColumn<String> geometry = GeneratedColumn<String>(
      'geometry', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attributesMeta =
      const VerificationMeta('attributes');
  @override
  late final GeneratedColumn<String> attributes = GeneratedColumn<String>(
      'attributes', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('draft'));
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _collectedAtMeta =
      const VerificationMeta('collectedAt');
  @override
  late final GeneratedColumn<DateTime> collectedAt = GeneratedColumn<DateTime>(
      'collected_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _syncAttemptsMeta =
      const VerificationMeta('syncAttempts');
  @override
  late final GeneratedColumn<int> syncAttempts = GeneratedColumn<int>(
      'sync_attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastSyncAttemptAtMeta =
      const VerificationMeta('lastSyncAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncAttemptAt =
      GeneratedColumn<DateTime>('last_sync_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _dataSourceIdMeta =
      const VerificationMeta('dataSourceId');
  @override
  late final GeneratedColumn<String> dataSourceId = GeneratedColumn<String>(
      'data_source_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _originalAttributesMeta =
      const VerificationMeta('originalAttributes');
  @override
  late final GeneratedColumn<String> originalAttributes =
      GeneratedColumn<String>('original_attributes', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _originalGeometryMeta =
      const VerificationMeta('originalGeometry');
  @override
  late final GeneratedColumn<String> originalGeometry = GeneratedColumn<String>(
      'original_geometry', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _sourceRefMeta =
      const VerificationMeta('sourceRef');
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
      'source_ref', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        clientId,
        projectId,
        layerId,
        formId,
        formVersion,
        geometry,
        attributes,
        status,
        serverId,
        collectedAt,
        updatedAt,
        syncedAt,
        lastError,
        syncStatus,
        syncAttempts,
        lastSyncAttemptAt,
        dataSourceId,
        originalAttributes,
        originalGeometry,
        deletedAt,
        sourceRef
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collected_features';
  @override
  VerificationContext validateIntegrity(Insertable<CollectedFeature> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('layer_id')) {
      context.handle(_layerIdMeta,
          layerId.isAcceptableOrUnknown(data['layer_id']!, _layerIdMeta));
    }
    if (data.containsKey('form_id')) {
      context.handle(_formIdMeta,
          formId.isAcceptableOrUnknown(data['form_id']!, _formIdMeta));
    } else if (isInserting) {
      context.missing(_formIdMeta);
    }
    if (data.containsKey('form_version')) {
      context.handle(
          _formVersionMeta,
          formVersion.isAcceptableOrUnknown(
              data['form_version']!, _formVersionMeta));
    }
    if (data.containsKey('geometry')) {
      context.handle(_geometryMeta,
          geometry.isAcceptableOrUnknown(data['geometry']!, _geometryMeta));
    }
    if (data.containsKey('attributes')) {
      context.handle(
          _attributesMeta,
          attributes.isAcceptableOrUnknown(
              data['attributes']!, _attributesMeta));
    } else if (isInserting) {
      context.missing(_attributesMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('collected_at')) {
      context.handle(
          _collectedAtMeta,
          collectedAt.isAcceptableOrUnknown(
              data['collected_at']!, _collectedAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('sync_attempts')) {
      context.handle(
          _syncAttemptsMeta,
          syncAttempts.isAcceptableOrUnknown(
              data['sync_attempts']!, _syncAttemptsMeta));
    }
    if (data.containsKey('last_sync_attempt_at')) {
      context.handle(
          _lastSyncAttemptAtMeta,
          lastSyncAttemptAt.isAcceptableOrUnknown(
              data['last_sync_attempt_at']!, _lastSyncAttemptAtMeta));
    }
    if (data.containsKey('data_source_id')) {
      context.handle(
          _dataSourceIdMeta,
          dataSourceId.isAcceptableOrUnknown(
              data['data_source_id']!, _dataSourceIdMeta));
    }
    if (data.containsKey('original_attributes')) {
      context.handle(
          _originalAttributesMeta,
          originalAttributes.isAcceptableOrUnknown(
              data['original_attributes']!, _originalAttributesMeta));
    }
    if (data.containsKey('original_geometry')) {
      context.handle(
          _originalGeometryMeta,
          originalGeometry.isAcceptableOrUnknown(
              data['original_geometry']!, _originalGeometryMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('source_ref')) {
      context.handle(_sourceRefMeta,
          sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientId};
  @override
  CollectedFeature map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectedFeature(
      clientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      layerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}layer_id']),
      formId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}form_id'])!,
      formVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}form_version'])!,
      geometry: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}geometry']),
      attributes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}attributes'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      collectedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}collected_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      syncAttempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sync_attempts'])!,
      lastSyncAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}last_sync_attempt_at']),
      dataSourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_source_id']),
      originalAttributes: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}original_attributes']),
      originalGeometry: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}original_geometry']),
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      sourceRef: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_ref']),
    );
  }

  @override
  $CollectedFeaturesTable createAlias(String alias) {
    return $CollectedFeaturesTable(attachedDatabase, alias);
  }
}

class CollectedFeature extends DataClass
    implements Insertable<CollectedFeature> {
  final String clientId;
  final String projectId;
  final String? layerId;
  final String formId;
  final int formVersion;
  final String? geometry;
  final String attributes;
  final String status;
  final String? serverId;
  final DateTime collectedAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  final String? lastError;

  /// pending | syncing | synced | failed | needs_attention
  final String syncStatus;
  final int syncAttempts;
  final DateTime? lastSyncAttemptAt;

  /// Set when this row represents an edit of a reference feature.
  /// Carries the data source id so reconciliation knows where to push back.
  final String? dataSourceId;

  /// JSON snapshot of the reference feature's attributes at the time of edit.
  /// Used by the backend to compute change_type and field-level diffs.
  final String? originalAttributes;

  /// GeoJSON snapshot of the reference feature's geometry at the time of edit.
  final String? originalGeometry;

  /// Tombstone marker. When set, this row represents a "mark deleted" action
  /// against the source feature identified by sourceRef + dataSourceId.
  /// Mobile rendering filters these out of the map view.
  final DateTime? deletedAt;

  /// External row id from the source data source (e.g., utility company's pole
  /// code "POLE-123"). Set when this collected row represents an EDIT of a
  /// reference feature. Carries through Phase B sync so backend can identify
  /// which source row to reconcile against.
  final String? sourceRef;
  const CollectedFeature(
      {required this.clientId,
      required this.projectId,
      this.layerId,
      required this.formId,
      required this.formVersion,
      this.geometry,
      required this.attributes,
      required this.status,
      this.serverId,
      required this.collectedAt,
      required this.updatedAt,
      this.syncedAt,
      this.lastError,
      required this.syncStatus,
      required this.syncAttempts,
      this.lastSyncAttemptAt,
      this.dataSourceId,
      this.originalAttributes,
      this.originalGeometry,
      this.deletedAt,
      this.sourceRef});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_id'] = Variable<String>(clientId);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || layerId != null) {
      map['layer_id'] = Variable<String>(layerId);
    }
    map['form_id'] = Variable<String>(formId);
    map['form_version'] = Variable<int>(formVersion);
    if (!nullToAbsent || geometry != null) {
      map['geometry'] = Variable<String>(geometry);
    }
    map['attributes'] = Variable<String>(attributes);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['collected_at'] = Variable<DateTime>(collectedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['sync_attempts'] = Variable<int>(syncAttempts);
    if (!nullToAbsent || lastSyncAttemptAt != null) {
      map['last_sync_attempt_at'] = Variable<DateTime>(lastSyncAttemptAt);
    }
    if (!nullToAbsent || dataSourceId != null) {
      map['data_source_id'] = Variable<String>(dataSourceId);
    }
    if (!nullToAbsent || originalAttributes != null) {
      map['original_attributes'] = Variable<String>(originalAttributes);
    }
    if (!nullToAbsent || originalGeometry != null) {
      map['original_geometry'] = Variable<String>(originalGeometry);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
    return map;
  }

  CollectedFeaturesCompanion toCompanion(bool nullToAbsent) {
    return CollectedFeaturesCompanion(
      clientId: Value(clientId),
      projectId: Value(projectId),
      layerId: layerId == null && nullToAbsent
          ? const Value.absent()
          : Value(layerId),
      formId: Value(formId),
      formVersion: Value(formVersion),
      geometry: geometry == null && nullToAbsent
          ? const Value.absent()
          : Value(geometry),
      attributes: Value(attributes),
      status: Value(status),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      collectedAt: Value(collectedAt),
      updatedAt: Value(updatedAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      syncStatus: Value(syncStatus),
      syncAttempts: Value(syncAttempts),
      lastSyncAttemptAt: lastSyncAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAttemptAt),
      dataSourceId: dataSourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(dataSourceId),
      originalAttributes: originalAttributes == null && nullToAbsent
          ? const Value.absent()
          : Value(originalAttributes),
      originalGeometry: originalGeometry == null && nullToAbsent
          ? const Value.absent()
          : Value(originalGeometry),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      sourceRef: sourceRef == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceRef),
    );
  }

  factory CollectedFeature.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectedFeature(
      clientId: serializer.fromJson<String>(json['clientId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      layerId: serializer.fromJson<String?>(json['layerId']),
      formId: serializer.fromJson<String>(json['formId']),
      formVersion: serializer.fromJson<int>(json['formVersion']),
      geometry: serializer.fromJson<String?>(json['geometry']),
      attributes: serializer.fromJson<String>(json['attributes']),
      status: serializer.fromJson<String>(json['status']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      collectedAt: serializer.fromJson<DateTime>(json['collectedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      syncAttempts: serializer.fromJson<int>(json['syncAttempts']),
      lastSyncAttemptAt:
          serializer.fromJson<DateTime?>(json['lastSyncAttemptAt']),
      dataSourceId: serializer.fromJson<String?>(json['dataSourceId']),
      originalAttributes:
          serializer.fromJson<String?>(json['originalAttributes']),
      originalGeometry: serializer.fromJson<String?>(json['originalGeometry']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientId': serializer.toJson<String>(clientId),
      'projectId': serializer.toJson<String>(projectId),
      'layerId': serializer.toJson<String?>(layerId),
      'formId': serializer.toJson<String>(formId),
      'formVersion': serializer.toJson<int>(formVersion),
      'geometry': serializer.toJson<String?>(geometry),
      'attributes': serializer.toJson<String>(attributes),
      'status': serializer.toJson<String>(status),
      'serverId': serializer.toJson<String?>(serverId),
      'collectedAt': serializer.toJson<DateTime>(collectedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'lastError': serializer.toJson<String?>(lastError),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'syncAttempts': serializer.toJson<int>(syncAttempts),
      'lastSyncAttemptAt': serializer.toJson<DateTime?>(lastSyncAttemptAt),
      'dataSourceId': serializer.toJson<String?>(dataSourceId),
      'originalAttributes': serializer.toJson<String?>(originalAttributes),
      'originalGeometry': serializer.toJson<String?>(originalGeometry),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'sourceRef': serializer.toJson<String?>(sourceRef),
    };
  }

  CollectedFeature copyWith(
          {String? clientId,
          String? projectId,
          Value<String?> layerId = const Value.absent(),
          String? formId,
          int? formVersion,
          Value<String?> geometry = const Value.absent(),
          String? attributes,
          String? status,
          Value<String?> serverId = const Value.absent(),
          DateTime? collectedAt,
          DateTime? updatedAt,
          Value<DateTime?> syncedAt = const Value.absent(),
          Value<String?> lastError = const Value.absent(),
          String? syncStatus,
          int? syncAttempts,
          Value<DateTime?> lastSyncAttemptAt = const Value.absent(),
          Value<String?> dataSourceId = const Value.absent(),
          Value<String?> originalAttributes = const Value.absent(),
          Value<String?> originalGeometry = const Value.absent(),
          Value<DateTime?> deletedAt = const Value.absent(),
          Value<String?> sourceRef = const Value.absent()}) =>
      CollectedFeature(
        clientId: clientId ?? this.clientId,
        projectId: projectId ?? this.projectId,
        layerId: layerId.present ? layerId.value : this.layerId,
        formId: formId ?? this.formId,
        formVersion: formVersion ?? this.formVersion,
        geometry: geometry.present ? geometry.value : this.geometry,
        attributes: attributes ?? this.attributes,
        status: status ?? this.status,
        serverId: serverId.present ? serverId.value : this.serverId,
        collectedAt: collectedAt ?? this.collectedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        lastError: lastError.present ? lastError.value : this.lastError,
        syncStatus: syncStatus ?? this.syncStatus,
        syncAttempts: syncAttempts ?? this.syncAttempts,
        lastSyncAttemptAt: lastSyncAttemptAt.present
            ? lastSyncAttemptAt.value
            : this.lastSyncAttemptAt,
        dataSourceId:
            dataSourceId.present ? dataSourceId.value : this.dataSourceId,
        originalAttributes: originalAttributes.present
            ? originalAttributes.value
            : this.originalAttributes,
        originalGeometry: originalGeometry.present
            ? originalGeometry.value
            : this.originalGeometry,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
      );
  CollectedFeature copyWithCompanion(CollectedFeaturesCompanion data) {
    return CollectedFeature(
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      layerId: data.layerId.present ? data.layerId.value : this.layerId,
      formId: data.formId.present ? data.formId.value : this.formId,
      formVersion:
          data.formVersion.present ? data.formVersion.value : this.formVersion,
      geometry: data.geometry.present ? data.geometry.value : this.geometry,
      attributes:
          data.attributes.present ? data.attributes.value : this.attributes,
      status: data.status.present ? data.status.value : this.status,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      collectedAt:
          data.collectedAt.present ? data.collectedAt.value : this.collectedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      syncAttempts: data.syncAttempts.present
          ? data.syncAttempts.value
          : this.syncAttempts,
      lastSyncAttemptAt: data.lastSyncAttemptAt.present
          ? data.lastSyncAttemptAt.value
          : this.lastSyncAttemptAt,
      dataSourceId: data.dataSourceId.present
          ? data.dataSourceId.value
          : this.dataSourceId,
      originalAttributes: data.originalAttributes.present
          ? data.originalAttributes.value
          : this.originalAttributes,
      originalGeometry: data.originalGeometry.present
          ? data.originalGeometry.value
          : this.originalGeometry,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectedFeature(')
          ..write('clientId: $clientId, ')
          ..write('projectId: $projectId, ')
          ..write('layerId: $layerId, ')
          ..write('formId: $formId, ')
          ..write('formVersion: $formVersion, ')
          ..write('geometry: $geometry, ')
          ..write('attributes: $attributes, ')
          ..write('status: $status, ')
          ..write('serverId: $serverId, ')
          ..write('collectedAt: $collectedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('lastError: $lastError, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncAttempts: $syncAttempts, ')
          ..write('lastSyncAttemptAt: $lastSyncAttemptAt, ')
          ..write('dataSourceId: $dataSourceId, ')
          ..write('originalAttributes: $originalAttributes, ')
          ..write('originalGeometry: $originalGeometry, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('sourceRef: $sourceRef')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        clientId,
        projectId,
        layerId,
        formId,
        formVersion,
        geometry,
        attributes,
        status,
        serverId,
        collectedAt,
        updatedAt,
        syncedAt,
        lastError,
        syncStatus,
        syncAttempts,
        lastSyncAttemptAt,
        dataSourceId,
        originalAttributes,
        originalGeometry,
        deletedAt,
        sourceRef
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectedFeature &&
          other.clientId == this.clientId &&
          other.projectId == this.projectId &&
          other.layerId == this.layerId &&
          other.formId == this.formId &&
          other.formVersion == this.formVersion &&
          other.geometry == this.geometry &&
          other.attributes == this.attributes &&
          other.status == this.status &&
          other.serverId == this.serverId &&
          other.collectedAt == this.collectedAt &&
          other.updatedAt == this.updatedAt &&
          other.syncedAt == this.syncedAt &&
          other.lastError == this.lastError &&
          other.syncStatus == this.syncStatus &&
          other.syncAttempts == this.syncAttempts &&
          other.lastSyncAttemptAt == this.lastSyncAttemptAt &&
          other.dataSourceId == this.dataSourceId &&
          other.originalAttributes == this.originalAttributes &&
          other.originalGeometry == this.originalGeometry &&
          other.deletedAt == this.deletedAt &&
          other.sourceRef == this.sourceRef);
}

class CollectedFeaturesCompanion extends UpdateCompanion<CollectedFeature> {
  final Value<String> clientId;
  final Value<String> projectId;
  final Value<String?> layerId;
  final Value<String> formId;
  final Value<int> formVersion;
  final Value<String?> geometry;
  final Value<String> attributes;
  final Value<String> status;
  final Value<String?> serverId;
  final Value<DateTime> collectedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> syncedAt;
  final Value<String?> lastError;
  final Value<String> syncStatus;
  final Value<int> syncAttempts;
  final Value<DateTime?> lastSyncAttemptAt;
  final Value<String?> dataSourceId;
  final Value<String?> originalAttributes;
  final Value<String?> originalGeometry;
  final Value<DateTime?> deletedAt;
  final Value<String?> sourceRef;
  final Value<int> rowid;
  const CollectedFeaturesCompanion({
    this.clientId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.layerId = const Value.absent(),
    this.formId = const Value.absent(),
    this.formVersion = const Value.absent(),
    this.geometry = const Value.absent(),
    this.attributes = const Value.absent(),
    this.status = const Value.absent(),
    this.serverId = const Value.absent(),
    this.collectedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncAttempts = const Value.absent(),
    this.lastSyncAttemptAt = const Value.absent(),
    this.dataSourceId = const Value.absent(),
    this.originalAttributes = const Value.absent(),
    this.originalGeometry = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollectedFeaturesCompanion.insert({
    required String clientId,
    required String projectId,
    this.layerId = const Value.absent(),
    required String formId,
    this.formVersion = const Value.absent(),
    this.geometry = const Value.absent(),
    required String attributes,
    this.status = const Value.absent(),
    this.serverId = const Value.absent(),
    this.collectedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.syncAttempts = const Value.absent(),
    this.lastSyncAttemptAt = const Value.absent(),
    this.dataSourceId = const Value.absent(),
    this.originalAttributes = const Value.absent(),
    this.originalGeometry = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.sourceRef = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : clientId = Value(clientId),
        projectId = Value(projectId),
        formId = Value(formId),
        attributes = Value(attributes);
  static Insertable<CollectedFeature> custom({
    Expression<String>? clientId,
    Expression<String>? projectId,
    Expression<String>? layerId,
    Expression<String>? formId,
    Expression<int>? formVersion,
    Expression<String>? geometry,
    Expression<String>? attributes,
    Expression<String>? status,
    Expression<String>? serverId,
    Expression<DateTime>? collectedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? syncedAt,
    Expression<String>? lastError,
    Expression<String>? syncStatus,
    Expression<int>? syncAttempts,
    Expression<DateTime>? lastSyncAttemptAt,
    Expression<String>? dataSourceId,
    Expression<String>? originalAttributes,
    Expression<String>? originalGeometry,
    Expression<DateTime>? deletedAt,
    Expression<String>? sourceRef,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (projectId != null) 'project_id': projectId,
      if (layerId != null) 'layer_id': layerId,
      if (formId != null) 'form_id': formId,
      if (formVersion != null) 'form_version': formVersion,
      if (geometry != null) 'geometry': geometry,
      if (attributes != null) 'attributes': attributes,
      if (status != null) 'status': status,
      if (serverId != null) 'server_id': serverId,
      if (collectedAt != null) 'collected_at': collectedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (lastError != null) 'last_error': lastError,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (syncAttempts != null) 'sync_attempts': syncAttempts,
      if (lastSyncAttemptAt != null) 'last_sync_attempt_at': lastSyncAttemptAt,
      if (dataSourceId != null) 'data_source_id': dataSourceId,
      if (originalAttributes != null) 'original_attributes': originalAttributes,
      if (originalGeometry != null) 'original_geometry': originalGeometry,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (sourceRef != null) 'source_ref': sourceRef,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollectedFeaturesCompanion copyWith(
      {Value<String>? clientId,
      Value<String>? projectId,
      Value<String?>? layerId,
      Value<String>? formId,
      Value<int>? formVersion,
      Value<String?>? geometry,
      Value<String>? attributes,
      Value<String>? status,
      Value<String?>? serverId,
      Value<DateTime>? collectedAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? syncedAt,
      Value<String?>? lastError,
      Value<String>? syncStatus,
      Value<int>? syncAttempts,
      Value<DateTime?>? lastSyncAttemptAt,
      Value<String?>? dataSourceId,
      Value<String?>? originalAttributes,
      Value<String?>? originalGeometry,
      Value<DateTime?>? deletedAt,
      Value<String?>? sourceRef,
      Value<int>? rowid}) {
    return CollectedFeaturesCompanion(
      clientId: clientId ?? this.clientId,
      projectId: projectId ?? this.projectId,
      layerId: layerId ?? this.layerId,
      formId: formId ?? this.formId,
      formVersion: formVersion ?? this.formVersion,
      geometry: geometry ?? this.geometry,
      attributes: attributes ?? this.attributes,
      status: status ?? this.status,
      serverId: serverId ?? this.serverId,
      collectedAt: collectedAt ?? this.collectedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      lastError: lastError ?? this.lastError,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastSyncAttemptAt: lastSyncAttemptAt ?? this.lastSyncAttemptAt,
      dataSourceId: dataSourceId ?? this.dataSourceId,
      originalAttributes: originalAttributes ?? this.originalAttributes,
      originalGeometry: originalGeometry ?? this.originalGeometry,
      deletedAt: deletedAt ?? this.deletedAt,
      sourceRef: sourceRef ?? this.sourceRef,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (layerId.present) {
      map['layer_id'] = Variable<String>(layerId.value);
    }
    if (formId.present) {
      map['form_id'] = Variable<String>(formId.value);
    }
    if (formVersion.present) {
      map['form_version'] = Variable<int>(formVersion.value);
    }
    if (geometry.present) {
      map['geometry'] = Variable<String>(geometry.value);
    }
    if (attributes.present) {
      map['attributes'] = Variable<String>(attributes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (collectedAt.present) {
      map['collected_at'] = Variable<DateTime>(collectedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (syncAttempts.present) {
      map['sync_attempts'] = Variable<int>(syncAttempts.value);
    }
    if (lastSyncAttemptAt.present) {
      map['last_sync_attempt_at'] = Variable<DateTime>(lastSyncAttemptAt.value);
    }
    if (dataSourceId.present) {
      map['data_source_id'] = Variable<String>(dataSourceId.value);
    }
    if (originalAttributes.present) {
      map['original_attributes'] = Variable<String>(originalAttributes.value);
    }
    if (originalGeometry.present) {
      map['original_geometry'] = Variable<String>(originalGeometry.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectedFeaturesCompanion(')
          ..write('clientId: $clientId, ')
          ..write('projectId: $projectId, ')
          ..write('layerId: $layerId, ')
          ..write('formId: $formId, ')
          ..write('formVersion: $formVersion, ')
          ..write('geometry: $geometry, ')
          ..write('attributes: $attributes, ')
          ..write('status: $status, ')
          ..write('serverId: $serverId, ')
          ..write('collectedAt: $collectedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('lastError: $lastError, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('syncAttempts: $syncAttempts, ')
          ..write('lastSyncAttemptAt: $lastSyncAttemptAt, ')
          ..write('dataSourceId: $dataSourceId, ')
          ..write('originalAttributes: $originalAttributes, ')
          ..write('originalGeometry: $originalGeometry, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FeatureAttachmentsTable extends FeatureAttachments
    with TableInfo<$FeatureAttachmentsTable, FeatureAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeatureAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientIdMeta =
      const VerificationMeta('clientId');
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
      'client_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _featureClientIdMeta =
      const VerificationMeta('featureClientId');
  @override
  late final GeneratedColumn<String> featureClientId = GeneratedColumn<String>(
      'feature_client_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fieldIdMeta =
      const VerificationMeta('fieldId');
  @override
  late final GeneratedColumn<String> fieldId = GeneratedColumn<String>(
      'field_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('photo'));
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _uploadUrlMeta =
      const VerificationMeta('uploadUrl');
  @override
  late final GeneratedColumn<String> uploadUrl = GeneratedColumn<String>(
      'upload_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _uploadAttemptsMeta =
      const VerificationMeta('uploadAttempts');
  @override
  late final GeneratedColumn<int> uploadAttempts = GeneratedColumn<int>(
      'upload_attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        clientId,
        featureClientId,
        projectId,
        fieldId,
        kind,
        localPath,
        mimeType,
        sizeBytes,
        status,
        serverId,
        uploadUrl,
        uploadAttempts,
        lastError,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feature_attachments';
  @override
  VerificationContext validateIntegrity(Insertable<FeatureAttachment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('feature_client_id')) {
      context.handle(
          _featureClientIdMeta,
          featureClientId.isAcceptableOrUnknown(
              data['feature_client_id']!, _featureClientIdMeta));
    } else if (isInserting) {
      context.missing(_featureClientIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('field_id')) {
      context.handle(_fieldIdMeta,
          fieldId.isAcceptableOrUnknown(data['field_id']!, _fieldIdMeta));
    } else if (isInserting) {
      context.missing(_fieldIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('upload_url')) {
      context.handle(_uploadUrlMeta,
          uploadUrl.isAcceptableOrUnknown(data['upload_url']!, _uploadUrlMeta));
    }
    if (data.containsKey('upload_attempts')) {
      context.handle(
          _uploadAttemptsMeta,
          uploadAttempts.isAcceptableOrUnknown(
              data['upload_attempts']!, _uploadAttemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientId};
  @override
  FeatureAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeatureAttachment(
      clientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_id'])!,
      featureClientId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}feature_client_id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      fieldId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}field_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path'])!,
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type']),
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      uploadUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}upload_url']),
      uploadAttempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}upload_attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $FeatureAttachmentsTable createAlias(String alias) {
    return $FeatureAttachmentsTable(attachedDatabase, alias);
  }
}

class FeatureAttachment extends DataClass
    implements Insertable<FeatureAttachment> {
  final String clientId;
  final String featureClientId;
  final String projectId;
  final String fieldId;
  final String kind;
  final String localPath;
  final String? mimeType;
  final int? sizeBytes;

  /// pending | uploading | uploaded | confirmed | failed
  final String status;

  /// Server-assigned UUID once /attachments returns it
  final String? serverId;

  /// Pre-signed PUT URL while we're uploading (transient)
  final String? uploadUrl;
  final int uploadAttempts;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FeatureAttachment(
      {required this.clientId,
      required this.featureClientId,
      required this.projectId,
      required this.fieldId,
      required this.kind,
      required this.localPath,
      this.mimeType,
      this.sizeBytes,
      required this.status,
      this.serverId,
      this.uploadUrl,
      required this.uploadAttempts,
      this.lastError,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_id'] = Variable<String>(clientId);
    map['feature_client_id'] = Variable<String>(featureClientId);
    map['project_id'] = Variable<String>(projectId);
    map['field_id'] = Variable<String>(fieldId);
    map['kind'] = Variable<String>(kind);
    map['local_path'] = Variable<String>(localPath);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    if (!nullToAbsent || uploadUrl != null) {
      map['upload_url'] = Variable<String>(uploadUrl);
    }
    map['upload_attempts'] = Variable<int>(uploadAttempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FeatureAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return FeatureAttachmentsCompanion(
      clientId: Value(clientId),
      featureClientId: Value(featureClientId),
      projectId: Value(projectId),
      fieldId: Value(fieldId),
      kind: Value(kind),
      localPath: Value(localPath),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      status: Value(status),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      uploadUrl: uploadUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadUrl),
      uploadAttempts: Value(uploadAttempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FeatureAttachment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeatureAttachment(
      clientId: serializer.fromJson<String>(json['clientId']),
      featureClientId: serializer.fromJson<String>(json['featureClientId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      fieldId: serializer.fromJson<String>(json['fieldId']),
      kind: serializer.fromJson<String>(json['kind']),
      localPath: serializer.fromJson<String>(json['localPath']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      status: serializer.fromJson<String>(json['status']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      uploadUrl: serializer.fromJson<String?>(json['uploadUrl']),
      uploadAttempts: serializer.fromJson<int>(json['uploadAttempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientId': serializer.toJson<String>(clientId),
      'featureClientId': serializer.toJson<String>(featureClientId),
      'projectId': serializer.toJson<String>(projectId),
      'fieldId': serializer.toJson<String>(fieldId),
      'kind': serializer.toJson<String>(kind),
      'localPath': serializer.toJson<String>(localPath),
      'mimeType': serializer.toJson<String?>(mimeType),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'status': serializer.toJson<String>(status),
      'serverId': serializer.toJson<String?>(serverId),
      'uploadUrl': serializer.toJson<String?>(uploadUrl),
      'uploadAttempts': serializer.toJson<int>(uploadAttempts),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FeatureAttachment copyWith(
          {String? clientId,
          String? featureClientId,
          String? projectId,
          String? fieldId,
          String? kind,
          String? localPath,
          Value<String?> mimeType = const Value.absent(),
          Value<int?> sizeBytes = const Value.absent(),
          String? status,
          Value<String?> serverId = const Value.absent(),
          Value<String?> uploadUrl = const Value.absent(),
          int? uploadAttempts,
          Value<String?> lastError = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      FeatureAttachment(
        clientId: clientId ?? this.clientId,
        featureClientId: featureClientId ?? this.featureClientId,
        projectId: projectId ?? this.projectId,
        fieldId: fieldId ?? this.fieldId,
        kind: kind ?? this.kind,
        localPath: localPath ?? this.localPath,
        mimeType: mimeType.present ? mimeType.value : this.mimeType,
        sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
        status: status ?? this.status,
        serverId: serverId.present ? serverId.value : this.serverId,
        uploadUrl: uploadUrl.present ? uploadUrl.value : this.uploadUrl,
        uploadAttempts: uploadAttempts ?? this.uploadAttempts,
        lastError: lastError.present ? lastError.value : this.lastError,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  FeatureAttachment copyWithCompanion(FeatureAttachmentsCompanion data) {
    return FeatureAttachment(
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      featureClientId: data.featureClientId.present
          ? data.featureClientId.value
          : this.featureClientId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      fieldId: data.fieldId.present ? data.fieldId.value : this.fieldId,
      kind: data.kind.present ? data.kind.value : this.kind,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      status: data.status.present ? data.status.value : this.status,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      uploadUrl: data.uploadUrl.present ? data.uploadUrl.value : this.uploadUrl,
      uploadAttempts: data.uploadAttempts.present
          ? data.uploadAttempts.value
          : this.uploadAttempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeatureAttachment(')
          ..write('clientId: $clientId, ')
          ..write('featureClientId: $featureClientId, ')
          ..write('projectId: $projectId, ')
          ..write('fieldId: $fieldId, ')
          ..write('kind: $kind, ')
          ..write('localPath: $localPath, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('status: $status, ')
          ..write('serverId: $serverId, ')
          ..write('uploadUrl: $uploadUrl, ')
          ..write('uploadAttempts: $uploadAttempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientId,
      featureClientId,
      projectId,
      fieldId,
      kind,
      localPath,
      mimeType,
      sizeBytes,
      status,
      serverId,
      uploadUrl,
      uploadAttempts,
      lastError,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeatureAttachment &&
          other.clientId == this.clientId &&
          other.featureClientId == this.featureClientId &&
          other.projectId == this.projectId &&
          other.fieldId == this.fieldId &&
          other.kind == this.kind &&
          other.localPath == this.localPath &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.status == this.status &&
          other.serverId == this.serverId &&
          other.uploadUrl == this.uploadUrl &&
          other.uploadAttempts == this.uploadAttempts &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FeatureAttachmentsCompanion extends UpdateCompanion<FeatureAttachment> {
  final Value<String> clientId;
  final Value<String> featureClientId;
  final Value<String> projectId;
  final Value<String> fieldId;
  final Value<String> kind;
  final Value<String> localPath;
  final Value<String?> mimeType;
  final Value<int?> sizeBytes;
  final Value<String> status;
  final Value<String?> serverId;
  final Value<String?> uploadUrl;
  final Value<int> uploadAttempts;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FeatureAttachmentsCompanion({
    this.clientId = const Value.absent(),
    this.featureClientId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.fieldId = const Value.absent(),
    this.kind = const Value.absent(),
    this.localPath = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.status = const Value.absent(),
    this.serverId = const Value.absent(),
    this.uploadUrl = const Value.absent(),
    this.uploadAttempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeatureAttachmentsCompanion.insert({
    required String clientId,
    required String featureClientId,
    required String projectId,
    required String fieldId,
    this.kind = const Value.absent(),
    required String localPath,
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.status = const Value.absent(),
    this.serverId = const Value.absent(),
    this.uploadUrl = const Value.absent(),
    this.uploadAttempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : clientId = Value(clientId),
        featureClientId = Value(featureClientId),
        projectId = Value(projectId),
        fieldId = Value(fieldId),
        localPath = Value(localPath);
  static Insertable<FeatureAttachment> custom({
    Expression<String>? clientId,
    Expression<String>? featureClientId,
    Expression<String>? projectId,
    Expression<String>? fieldId,
    Expression<String>? kind,
    Expression<String>? localPath,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<String>? status,
    Expression<String>? serverId,
    Expression<String>? uploadUrl,
    Expression<int>? uploadAttempts,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (featureClientId != null) 'feature_client_id': featureClientId,
      if (projectId != null) 'project_id': projectId,
      if (fieldId != null) 'field_id': fieldId,
      if (kind != null) 'kind': kind,
      if (localPath != null) 'local_path': localPath,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (status != null) 'status': status,
      if (serverId != null) 'server_id': serverId,
      if (uploadUrl != null) 'upload_url': uploadUrl,
      if (uploadAttempts != null) 'upload_attempts': uploadAttempts,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeatureAttachmentsCompanion copyWith(
      {Value<String>? clientId,
      Value<String>? featureClientId,
      Value<String>? projectId,
      Value<String>? fieldId,
      Value<String>? kind,
      Value<String>? localPath,
      Value<String?>? mimeType,
      Value<int?>? sizeBytes,
      Value<String>? status,
      Value<String?>? serverId,
      Value<String?>? uploadUrl,
      Value<int>? uploadAttempts,
      Value<String?>? lastError,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return FeatureAttachmentsCompanion(
      clientId: clientId ?? this.clientId,
      featureClientId: featureClientId ?? this.featureClientId,
      projectId: projectId ?? this.projectId,
      fieldId: fieldId ?? this.fieldId,
      kind: kind ?? this.kind,
      localPath: localPath ?? this.localPath,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      status: status ?? this.status,
      serverId: serverId ?? this.serverId,
      uploadUrl: uploadUrl ?? this.uploadUrl,
      uploadAttempts: uploadAttempts ?? this.uploadAttempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (featureClientId.present) {
      map['feature_client_id'] = Variable<String>(featureClientId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (fieldId.present) {
      map['field_id'] = Variable<String>(fieldId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (uploadUrl.present) {
      map['upload_url'] = Variable<String>(uploadUrl.value);
    }
    if (uploadAttempts.present) {
      map['upload_attempts'] = Variable<int>(uploadAttempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeatureAttachmentsCompanion(')
          ..write('clientId: $clientId, ')
          ..write('featureClientId: $featureClientId, ')
          ..write('projectId: $projectId, ')
          ..write('fieldId: $fieldId, ')
          ..write('kind: $kind, ')
          ..write('localPath: $localPath, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('status: $status, ')
          ..write('serverId: $serverId, ')
          ..write('uploadUrl: $uploadUrl, ')
          ..write('uploadAttempts: $uploadAttempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRunsTable extends SyncRuns with TableInfo<$SyncRunsTable, SyncRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _triggerMeta =
      const VerificationMeta('trigger');
  @override
  late final GeneratedColumn<String> trigger = GeneratedColumn<String>(
      'trigger', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _featuresAttemptedMeta =
      const VerificationMeta('featuresAttempted');
  @override
  late final GeneratedColumn<int> featuresAttempted = GeneratedColumn<int>(
      'features_attempted', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _featuresSucceededMeta =
      const VerificationMeta('featuresSucceeded');
  @override
  late final GeneratedColumn<int> featuresSucceeded = GeneratedColumn<int>(
      'features_succeeded', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _featuresFailedMeta =
      const VerificationMeta('featuresFailed');
  @override
  late final GeneratedColumn<int> featuresFailed = GeneratedColumn<int>(
      'features_failed', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _attachmentsAttemptedMeta =
      const VerificationMeta('attachmentsAttempted');
  @override
  late final GeneratedColumn<int> attachmentsAttempted = GeneratedColumn<int>(
      'attachments_attempted', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _attachmentsSucceededMeta =
      const VerificationMeta('attachmentsSucceeded');
  @override
  late final GeneratedColumn<int> attachmentsSucceeded = GeneratedColumn<int>(
      'attachments_succeeded', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _attachmentsFailedMeta =
      const VerificationMeta('attachmentsFailed');
  @override
  late final GeneratedColumn<int> attachmentsFailed = GeneratedColumn<int>(
      'attachments_failed', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('running'));
  static const VerificationMeta _summaryMeta =
      const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
      'summary', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        trigger,
        startedAt,
        endedAt,
        featuresAttempted,
        featuresSucceeded,
        featuresFailed,
        attachmentsAttempted,
        attachmentsSucceeded,
        attachmentsFailed,
        status,
        summary
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_runs';
  @override
  VerificationContext validateIntegrity(Insertable<SyncRun> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    }
    if (data.containsKey('trigger')) {
      context.handle(_triggerMeta,
          trigger.isAcceptableOrUnknown(data['trigger']!, _triggerMeta));
    } else if (isInserting) {
      context.missing(_triggerMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('features_attempted')) {
      context.handle(
          _featuresAttemptedMeta,
          featuresAttempted.isAcceptableOrUnknown(
              data['features_attempted']!, _featuresAttemptedMeta));
    }
    if (data.containsKey('features_succeeded')) {
      context.handle(
          _featuresSucceededMeta,
          featuresSucceeded.isAcceptableOrUnknown(
              data['features_succeeded']!, _featuresSucceededMeta));
    }
    if (data.containsKey('features_failed')) {
      context.handle(
          _featuresFailedMeta,
          featuresFailed.isAcceptableOrUnknown(
              data['features_failed']!, _featuresFailedMeta));
    }
    if (data.containsKey('attachments_attempted')) {
      context.handle(
          _attachmentsAttemptedMeta,
          attachmentsAttempted.isAcceptableOrUnknown(
              data['attachments_attempted']!, _attachmentsAttemptedMeta));
    }
    if (data.containsKey('attachments_succeeded')) {
      context.handle(
          _attachmentsSucceededMeta,
          attachmentsSucceeded.isAcceptableOrUnknown(
              data['attachments_succeeded']!, _attachmentsSucceededMeta));
    }
    if (data.containsKey('attachments_failed')) {
      context.handle(
          _attachmentsFailedMeta,
          attachmentsFailed.isAcceptableOrUnknown(
              data['attachments_failed']!, _attachmentsFailedMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta,
          summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRun(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id']),
      trigger: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}trigger'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at']),
      featuresAttempted: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}features_attempted'])!,
      featuresSucceeded: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}features_succeeded'])!,
      featuresFailed: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}features_failed'])!,
      attachmentsAttempted: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}attachments_attempted'])!,
      attachmentsSucceeded: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}attachments_succeeded'])!,
      attachmentsFailed: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}attachments_failed'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      summary: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary']),
    );
  }

  @override
  $SyncRunsTable createAlias(String alias) {
    return $SyncRunsTable(attachedDatabase, alias);
  }
}

class SyncRun extends DataClass implements Insertable<SyncRun> {
  final String id;
  final String? projectId;
  final String trigger;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int featuresAttempted;
  final int featuresSucceeded;
  final int featuresFailed;
  final int attachmentsAttempted;
  final int attachmentsSucceeded;
  final int attachmentsFailed;

  /// success | partial | failed | running
  final String status;
  final String? summary;
  const SyncRun(
      {required this.id,
      this.projectId,
      required this.trigger,
      required this.startedAt,
      this.endedAt,
      required this.featuresAttempted,
      required this.featuresSucceeded,
      required this.featuresFailed,
      required this.attachmentsAttempted,
      required this.attachmentsSucceeded,
      required this.attachmentsFailed,
      required this.status,
      this.summary});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    map['trigger'] = Variable<String>(trigger);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['features_attempted'] = Variable<int>(featuresAttempted);
    map['features_succeeded'] = Variable<int>(featuresSucceeded);
    map['features_failed'] = Variable<int>(featuresFailed);
    map['attachments_attempted'] = Variable<int>(attachmentsAttempted);
    map['attachments_succeeded'] = Variable<int>(attachmentsSucceeded);
    map['attachments_failed'] = Variable<int>(attachmentsFailed);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    return map;
  }

  SyncRunsCompanion toCompanion(bool nullToAbsent) {
    return SyncRunsCompanion(
      id: Value(id),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      trigger: Value(trigger),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      featuresAttempted: Value(featuresAttempted),
      featuresSucceeded: Value(featuresSucceeded),
      featuresFailed: Value(featuresFailed),
      attachmentsAttempted: Value(attachmentsAttempted),
      attachmentsSucceeded: Value(attachmentsSucceeded),
      attachmentsFailed: Value(attachmentsFailed),
      status: Value(status),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
    );
  }

  factory SyncRun.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRun(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      trigger: serializer.fromJson<String>(json['trigger']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      featuresAttempted: serializer.fromJson<int>(json['featuresAttempted']),
      featuresSucceeded: serializer.fromJson<int>(json['featuresSucceeded']),
      featuresFailed: serializer.fromJson<int>(json['featuresFailed']),
      attachmentsAttempted:
          serializer.fromJson<int>(json['attachmentsAttempted']),
      attachmentsSucceeded:
          serializer.fromJson<int>(json['attachmentsSucceeded']),
      attachmentsFailed: serializer.fromJson<int>(json['attachmentsFailed']),
      status: serializer.fromJson<String>(json['status']),
      summary: serializer.fromJson<String?>(json['summary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String?>(projectId),
      'trigger': serializer.toJson<String>(trigger),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'featuresAttempted': serializer.toJson<int>(featuresAttempted),
      'featuresSucceeded': serializer.toJson<int>(featuresSucceeded),
      'featuresFailed': serializer.toJson<int>(featuresFailed),
      'attachmentsAttempted': serializer.toJson<int>(attachmentsAttempted),
      'attachmentsSucceeded': serializer.toJson<int>(attachmentsSucceeded),
      'attachmentsFailed': serializer.toJson<int>(attachmentsFailed),
      'status': serializer.toJson<String>(status),
      'summary': serializer.toJson<String?>(summary),
    };
  }

  SyncRun copyWith(
          {String? id,
          Value<String?> projectId = const Value.absent(),
          String? trigger,
          DateTime? startedAt,
          Value<DateTime?> endedAt = const Value.absent(),
          int? featuresAttempted,
          int? featuresSucceeded,
          int? featuresFailed,
          int? attachmentsAttempted,
          int? attachmentsSucceeded,
          int? attachmentsFailed,
          String? status,
          Value<String?> summary = const Value.absent()}) =>
      SyncRun(
        id: id ?? this.id,
        projectId: projectId.present ? projectId.value : this.projectId,
        trigger: trigger ?? this.trigger,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
        featuresAttempted: featuresAttempted ?? this.featuresAttempted,
        featuresSucceeded: featuresSucceeded ?? this.featuresSucceeded,
        featuresFailed: featuresFailed ?? this.featuresFailed,
        attachmentsAttempted: attachmentsAttempted ?? this.attachmentsAttempted,
        attachmentsSucceeded: attachmentsSucceeded ?? this.attachmentsSucceeded,
        attachmentsFailed: attachmentsFailed ?? this.attachmentsFailed,
        status: status ?? this.status,
        summary: summary.present ? summary.value : this.summary,
      );
  SyncRun copyWithCompanion(SyncRunsCompanion data) {
    return SyncRun(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      trigger: data.trigger.present ? data.trigger.value : this.trigger,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      featuresAttempted: data.featuresAttempted.present
          ? data.featuresAttempted.value
          : this.featuresAttempted,
      featuresSucceeded: data.featuresSucceeded.present
          ? data.featuresSucceeded.value
          : this.featuresSucceeded,
      featuresFailed: data.featuresFailed.present
          ? data.featuresFailed.value
          : this.featuresFailed,
      attachmentsAttempted: data.attachmentsAttempted.present
          ? data.attachmentsAttempted.value
          : this.attachmentsAttempted,
      attachmentsSucceeded: data.attachmentsSucceeded.present
          ? data.attachmentsSucceeded.value
          : this.attachmentsSucceeded,
      attachmentsFailed: data.attachmentsFailed.present
          ? data.attachmentsFailed.value
          : this.attachmentsFailed,
      status: data.status.present ? data.status.value : this.status,
      summary: data.summary.present ? data.summary.value : this.summary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRun(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('trigger: $trigger, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('featuresAttempted: $featuresAttempted, ')
          ..write('featuresSucceeded: $featuresSucceeded, ')
          ..write('featuresFailed: $featuresFailed, ')
          ..write('attachmentsAttempted: $attachmentsAttempted, ')
          ..write('attachmentsSucceeded: $attachmentsSucceeded, ')
          ..write('attachmentsFailed: $attachmentsFailed, ')
          ..write('status: $status, ')
          ..write('summary: $summary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      projectId,
      trigger,
      startedAt,
      endedAt,
      featuresAttempted,
      featuresSucceeded,
      featuresFailed,
      attachmentsAttempted,
      attachmentsSucceeded,
      attachmentsFailed,
      status,
      summary);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRun &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.trigger == this.trigger &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.featuresAttempted == this.featuresAttempted &&
          other.featuresSucceeded == this.featuresSucceeded &&
          other.featuresFailed == this.featuresFailed &&
          other.attachmentsAttempted == this.attachmentsAttempted &&
          other.attachmentsSucceeded == this.attachmentsSucceeded &&
          other.attachmentsFailed == this.attachmentsFailed &&
          other.status == this.status &&
          other.summary == this.summary);
}

class SyncRunsCompanion extends UpdateCompanion<SyncRun> {
  final Value<String> id;
  final Value<String?> projectId;
  final Value<String> trigger;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> featuresAttempted;
  final Value<int> featuresSucceeded;
  final Value<int> featuresFailed;
  final Value<int> attachmentsAttempted;
  final Value<int> attachmentsSucceeded;
  final Value<int> attachmentsFailed;
  final Value<String> status;
  final Value<String?> summary;
  final Value<int> rowid;
  const SyncRunsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.trigger = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.featuresAttempted = const Value.absent(),
    this.featuresSucceeded = const Value.absent(),
    this.featuresFailed = const Value.absent(),
    this.attachmentsAttempted = const Value.absent(),
    this.attachmentsSucceeded = const Value.absent(),
    this.attachmentsFailed = const Value.absent(),
    this.status = const Value.absent(),
    this.summary = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRunsCompanion.insert({
    required String id,
    this.projectId = const Value.absent(),
    required String trigger,
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.featuresAttempted = const Value.absent(),
    this.featuresSucceeded = const Value.absent(),
    this.featuresFailed = const Value.absent(),
    this.attachmentsAttempted = const Value.absent(),
    this.attachmentsSucceeded = const Value.absent(),
    this.attachmentsFailed = const Value.absent(),
    this.status = const Value.absent(),
    this.summary = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        trigger = Value(trigger);
  static Insertable<SyncRun> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? trigger,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? featuresAttempted,
    Expression<int>? featuresSucceeded,
    Expression<int>? featuresFailed,
    Expression<int>? attachmentsAttempted,
    Expression<int>? attachmentsSucceeded,
    Expression<int>? attachmentsFailed,
    Expression<String>? status,
    Expression<String>? summary,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (trigger != null) 'trigger': trigger,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (featuresAttempted != null) 'features_attempted': featuresAttempted,
      if (featuresSucceeded != null) 'features_succeeded': featuresSucceeded,
      if (featuresFailed != null) 'features_failed': featuresFailed,
      if (attachmentsAttempted != null)
        'attachments_attempted': attachmentsAttempted,
      if (attachmentsSucceeded != null)
        'attachments_succeeded': attachmentsSucceeded,
      if (attachmentsFailed != null) 'attachments_failed': attachmentsFailed,
      if (status != null) 'status': status,
      if (summary != null) 'summary': summary,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRunsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? projectId,
      Value<String>? trigger,
      Value<DateTime>? startedAt,
      Value<DateTime?>? endedAt,
      Value<int>? featuresAttempted,
      Value<int>? featuresSucceeded,
      Value<int>? featuresFailed,
      Value<int>? attachmentsAttempted,
      Value<int>? attachmentsSucceeded,
      Value<int>? attachmentsFailed,
      Value<String>? status,
      Value<String?>? summary,
      Value<int>? rowid}) {
    return SyncRunsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      trigger: trigger ?? this.trigger,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      featuresAttempted: featuresAttempted ?? this.featuresAttempted,
      featuresSucceeded: featuresSucceeded ?? this.featuresSucceeded,
      featuresFailed: featuresFailed ?? this.featuresFailed,
      attachmentsAttempted: attachmentsAttempted ?? this.attachmentsAttempted,
      attachmentsSucceeded: attachmentsSucceeded ?? this.attachmentsSucceeded,
      attachmentsFailed: attachmentsFailed ?? this.attachmentsFailed,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (trigger.present) {
      map['trigger'] = Variable<String>(trigger.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (featuresAttempted.present) {
      map['features_attempted'] = Variable<int>(featuresAttempted.value);
    }
    if (featuresSucceeded.present) {
      map['features_succeeded'] = Variable<int>(featuresSucceeded.value);
    }
    if (featuresFailed.present) {
      map['features_failed'] = Variable<int>(featuresFailed.value);
    }
    if (attachmentsAttempted.present) {
      map['attachments_attempted'] = Variable<int>(attachmentsAttempted.value);
    }
    if (attachmentsSucceeded.present) {
      map['attachments_succeeded'] = Variable<int>(attachmentsSucceeded.value);
    }
    if (attachmentsFailed.present) {
      map['attachments_failed'] = Variable<int>(attachmentsFailed.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRunsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('trigger: $trigger, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('featuresAttempted: $featuresAttempted, ')
          ..write('featuresSucceeded: $featuresSucceeded, ')
          ..write('featuresFailed: $featuresFailed, ')
          ..write('attachmentsAttempted: $attachmentsAttempted, ')
          ..write('attachmentsSucceeded: $attachmentsSucceeded, ')
          ..write('attachmentsFailed: $attachmentsFailed, ')
          ..write('status: $status, ')
          ..write('summary: $summary, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncErrorsTable extends SyncErrors
    with TableInfo<$SyncErrorsTable, SyncError> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncErrorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _syncRunIdMeta =
      const VerificationMeta('syncRunId');
  @override
  late final GeneratedColumn<String> syncRunId = GeneratedColumn<String>(
      'sync_run_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sync_runs (id) ON DELETE CASCADE'));
  static const VerificationMeta _featureClientIdMeta =
      const VerificationMeta('featureClientId');
  @override
  late final GeneratedColumn<String> featureClientId = GeneratedColumn<String>(
      'feature_client_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attachmentClientIdMeta =
      const VerificationMeta('attachmentClientId');
  @override
  late final GeneratedColumn<String> attachmentClientId =
      GeneratedColumn<String>('attachment_client_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _errorCodeMeta =
      const VerificationMeta('errorCode');
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
      'error_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _errorMessageMeta =
      const VerificationMeta('errorMessage');
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
      'error_message', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _httpStatusMeta =
      const VerificationMeta('httpStatus');
  @override
  late final GeneratedColumn<int> httpStatus = GeneratedColumn<int>(
      'http_status', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        syncRunId,
        featureClientId,
        attachmentClientId,
        errorCode,
        errorMessage,
        httpStatus,
        occurredAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_errors';
  @override
  VerificationContext validateIntegrity(Insertable<SyncError> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sync_run_id')) {
      context.handle(
          _syncRunIdMeta,
          syncRunId.isAcceptableOrUnknown(
              data['sync_run_id']!, _syncRunIdMeta));
    } else if (isInserting) {
      context.missing(_syncRunIdMeta);
    }
    if (data.containsKey('feature_client_id')) {
      context.handle(
          _featureClientIdMeta,
          featureClientId.isAcceptableOrUnknown(
              data['feature_client_id']!, _featureClientIdMeta));
    }
    if (data.containsKey('attachment_client_id')) {
      context.handle(
          _attachmentClientIdMeta,
          attachmentClientId.isAcceptableOrUnknown(
              data['attachment_client_id']!, _attachmentClientIdMeta));
    }
    if (data.containsKey('error_code')) {
      context.handle(_errorCodeMeta,
          errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta));
    } else if (isInserting) {
      context.missing(_errorCodeMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
          _errorMessageMeta,
          errorMessage.isAcceptableOrUnknown(
              data['error_message']!, _errorMessageMeta));
    }
    if (data.containsKey('http_status')) {
      context.handle(
          _httpStatusMeta,
          httpStatus.isAcceptableOrUnknown(
              data['http_status']!, _httpStatusMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncError map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncError(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      syncRunId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_run_id'])!,
      featureClientId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}feature_client_id']),
      attachmentClientId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}attachment_client_id']),
      errorCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_code'])!,
      errorMessage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}error_message']),
      httpStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}http_status']),
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
    );
  }

  @override
  $SyncErrorsTable createAlias(String alias) {
    return $SyncErrorsTable(attachedDatabase, alias);
  }
}

class SyncError extends DataClass implements Insertable<SyncError> {
  final String id;
  final String syncRunId;
  final String? featureClientId;
  final String? attachmentClientId;
  final String errorCode;
  final String? errorMessage;
  final int? httpStatus;
  final DateTime occurredAt;
  const SyncError(
      {required this.id,
      required this.syncRunId,
      this.featureClientId,
      this.attachmentClientId,
      required this.errorCode,
      this.errorMessage,
      this.httpStatus,
      required this.occurredAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sync_run_id'] = Variable<String>(syncRunId);
    if (!nullToAbsent || featureClientId != null) {
      map['feature_client_id'] = Variable<String>(featureClientId);
    }
    if (!nullToAbsent || attachmentClientId != null) {
      map['attachment_client_id'] = Variable<String>(attachmentClientId);
    }
    map['error_code'] = Variable<String>(errorCode);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || httpStatus != null) {
      map['http_status'] = Variable<int>(httpStatus);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    return map;
  }

  SyncErrorsCompanion toCompanion(bool nullToAbsent) {
    return SyncErrorsCompanion(
      id: Value(id),
      syncRunId: Value(syncRunId),
      featureClientId: featureClientId == null && nullToAbsent
          ? const Value.absent()
          : Value(featureClientId),
      attachmentClientId: attachmentClientId == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentClientId),
      errorCode: Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      httpStatus: httpStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(httpStatus),
      occurredAt: Value(occurredAt),
    );
  }

  factory SyncError.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncError(
      id: serializer.fromJson<String>(json['id']),
      syncRunId: serializer.fromJson<String>(json['syncRunId']),
      featureClientId: serializer.fromJson<String?>(json['featureClientId']),
      attachmentClientId:
          serializer.fromJson<String?>(json['attachmentClientId']),
      errorCode: serializer.fromJson<String>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      httpStatus: serializer.fromJson<int?>(json['httpStatus']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'syncRunId': serializer.toJson<String>(syncRunId),
      'featureClientId': serializer.toJson<String?>(featureClientId),
      'attachmentClientId': serializer.toJson<String?>(attachmentClientId),
      'errorCode': serializer.toJson<String>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'httpStatus': serializer.toJson<int?>(httpStatus),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  SyncError copyWith(
          {String? id,
          String? syncRunId,
          Value<String?> featureClientId = const Value.absent(),
          Value<String?> attachmentClientId = const Value.absent(),
          String? errorCode,
          Value<String?> errorMessage = const Value.absent(),
          Value<int?> httpStatus = const Value.absent(),
          DateTime? occurredAt}) =>
      SyncError(
        id: id ?? this.id,
        syncRunId: syncRunId ?? this.syncRunId,
        featureClientId: featureClientId.present
            ? featureClientId.value
            : this.featureClientId,
        attachmentClientId: attachmentClientId.present
            ? attachmentClientId.value
            : this.attachmentClientId,
        errorCode: errorCode ?? this.errorCode,
        errorMessage:
            errorMessage.present ? errorMessage.value : this.errorMessage,
        httpStatus: httpStatus.present ? httpStatus.value : this.httpStatus,
        occurredAt: occurredAt ?? this.occurredAt,
      );
  SyncError copyWithCompanion(SyncErrorsCompanion data) {
    return SyncError(
      id: data.id.present ? data.id.value : this.id,
      syncRunId: data.syncRunId.present ? data.syncRunId.value : this.syncRunId,
      featureClientId: data.featureClientId.present
          ? data.featureClientId.value
          : this.featureClientId,
      attachmentClientId: data.attachmentClientId.present
          ? data.attachmentClientId.value
          : this.attachmentClientId,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      httpStatus:
          data.httpStatus.present ? data.httpStatus.value : this.httpStatus,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncError(')
          ..write('id: $id, ')
          ..write('syncRunId: $syncRunId, ')
          ..write('featureClientId: $featureClientId, ')
          ..write('attachmentClientId: $attachmentClientId, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('httpStatus: $httpStatus, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, syncRunId, featureClientId,
      attachmentClientId, errorCode, errorMessage, httpStatus, occurredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncError &&
          other.id == this.id &&
          other.syncRunId == this.syncRunId &&
          other.featureClientId == this.featureClientId &&
          other.attachmentClientId == this.attachmentClientId &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.httpStatus == this.httpStatus &&
          other.occurredAt == this.occurredAt);
}

class SyncErrorsCompanion extends UpdateCompanion<SyncError> {
  final Value<String> id;
  final Value<String> syncRunId;
  final Value<String?> featureClientId;
  final Value<String?> attachmentClientId;
  final Value<String> errorCode;
  final Value<String?> errorMessage;
  final Value<int?> httpStatus;
  final Value<DateTime> occurredAt;
  final Value<int> rowid;
  const SyncErrorsCompanion({
    this.id = const Value.absent(),
    this.syncRunId = const Value.absent(),
    this.featureClientId = const Value.absent(),
    this.attachmentClientId = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.httpStatus = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncErrorsCompanion.insert({
    required String id,
    required String syncRunId,
    this.featureClientId = const Value.absent(),
    this.attachmentClientId = const Value.absent(),
    required String errorCode,
    this.errorMessage = const Value.absent(),
    this.httpStatus = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        syncRunId = Value(syncRunId),
        errorCode = Value(errorCode);
  static Insertable<SyncError> custom({
    Expression<String>? id,
    Expression<String>? syncRunId,
    Expression<String>? featureClientId,
    Expression<String>? attachmentClientId,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<int>? httpStatus,
    Expression<DateTime>? occurredAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (syncRunId != null) 'sync_run_id': syncRunId,
      if (featureClientId != null) 'feature_client_id': featureClientId,
      if (attachmentClientId != null)
        'attachment_client_id': attachmentClientId,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (httpStatus != null) 'http_status': httpStatus,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncErrorsCompanion copyWith(
      {Value<String>? id,
      Value<String>? syncRunId,
      Value<String?>? featureClientId,
      Value<String?>? attachmentClientId,
      Value<String>? errorCode,
      Value<String?>? errorMessage,
      Value<int?>? httpStatus,
      Value<DateTime>? occurredAt,
      Value<int>? rowid}) {
    return SyncErrorsCompanion(
      id: id ?? this.id,
      syncRunId: syncRunId ?? this.syncRunId,
      featureClientId: featureClientId ?? this.featureClientId,
      attachmentClientId: attachmentClientId ?? this.attachmentClientId,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      httpStatus: httpStatus ?? this.httpStatus,
      occurredAt: occurredAt ?? this.occurredAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (syncRunId.present) {
      map['sync_run_id'] = Variable<String>(syncRunId.value);
    }
    if (featureClientId.present) {
      map['feature_client_id'] = Variable<String>(featureClientId.value);
    }
    if (attachmentClientId.present) {
      map['attachment_client_id'] = Variable<String>(attachmentClientId.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (httpStatus.present) {
      map['http_status'] = Variable<int>(httpStatus.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncErrorsCompanion(')
          ..write('id: $id, ')
          ..write('syncRunId: $syncRunId, ')
          ..write('featureClientId: $featureClientId, ')
          ..write('attachmentClientId: $attachmentClientId, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('httpStatus: $httpStatus, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $FormsTable forms = $FormsTable(this);
  late final $LayersTable layers = $LayersTable(this);
  late final $ChoiceListsTable choiceLists = $ChoiceListsTable(this);
  late final $AssignmentsTable assignments = $AssignmentsTable(this);
  late final $ReferenceFeaturesTable referenceFeatures =
      $ReferenceFeaturesTable(this);
  late final $CollectedFeaturesTable collectedFeatures =
      $CollectedFeaturesTable(this);
  late final $FeatureAttachmentsTable featureAttachments =
      $FeatureAttachmentsTable(this);
  late final $SyncRunsTable syncRuns = $SyncRunsTable(this);
  late final $SyncErrorsTable syncErrors = $SyncErrorsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        projects,
        forms,
        layers,
        choiceLists,
        assignments,
        referenceFeatures,
        collectedFeatures,
        featureAttachments,
        syncRuns,
        syncErrors
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('forms', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('layers', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('choice_lists', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('assignments', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('reference_features', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('projects',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('collected_features', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sync_runs',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('sync_errors', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$ProjectsTableCreateCompanionBuilder = ProjectsCompanion Function({
  required String id,
  required String name,
  Value<String?> description,
  required String mode,
  required String status,
  Value<int> version,
  Value<String?> contentHash,
  Value<String?> bundleFilename,
  Value<int?> bundleSizeBytes,
  Value<DateTime?> downloadedAt,
  Value<String?> areaOfInterest,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$ProjectsTableUpdateCompanionBuilder = ProjectsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> description,
  Value<String> mode,
  Value<String> status,
  Value<int> version,
  Value<String?> contentHash,
  Value<String?> bundleFilename,
  Value<int?> bundleSizeBytes,
  Value<DateTime?> downloadedAt,
  Value<String?> areaOfInterest,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ProjectsTableReferences
    extends BaseReferences<_$AppDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FormsTable, List<Form>> _formsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.forms,
          aliasName: $_aliasNameGenerator(db.projects.id, db.forms.projectId));

  $$FormsTableProcessedTableManager get formsRefs {
    final manager = $$FormsTableTableManager($_db, $_db.forms)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_formsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$LayersTable, List<Layer>> _layersRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.layers,
          aliasName: $_aliasNameGenerator(db.projects.id, db.layers.projectId));

  $$LayersTableProcessedTableManager get layersRefs {
    final manager = $$LayersTableTableManager($_db, $_db.layers)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_layersRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ChoiceListsTable, List<ChoiceList>>
      _choiceListsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.choiceLists,
          aliasName:
              $_aliasNameGenerator(db.projects.id, db.choiceLists.projectId));

  $$ChoiceListsTableProcessedTableManager get choiceListsRefs {
    final manager = $$ChoiceListsTableTableManager($_db, $_db.choiceLists)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_choiceListsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$AssignmentsTable, List<Assignment>>
      _assignmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.assignments,
          aliasName:
              $_aliasNameGenerator(db.projects.id, db.assignments.projectId));

  $$AssignmentsTableProcessedTableManager get assignmentsRefs {
    final manager = $$AssignmentsTableTableManager($_db, $_db.assignments)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_assignmentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ReferenceFeaturesTable, List<ReferenceFeature>>
      _referenceFeaturesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.referenceFeatures,
              aliasName: $_aliasNameGenerator(
                  db.projects.id, db.referenceFeatures.projectId));

  $$ReferenceFeaturesTableProcessedTableManager get referenceFeaturesRefs {
    final manager = $$ReferenceFeaturesTableTableManager(
            $_db, $_db.referenceFeatures)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_referenceFeaturesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$CollectedFeaturesTable, List<CollectedFeature>>
      _collectedFeaturesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.collectedFeatures,
              aliasName: $_aliasNameGenerator(
                  db.projects.id, db.collectedFeatures.projectId));

  $$CollectedFeaturesTableProcessedTableManager get collectedFeaturesRefs {
    final manager = $$CollectedFeaturesTableTableManager(
            $_db, $_db.collectedFeatures)
        .filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_collectedFeaturesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bundleFilename => $composableBuilder(
      column: $table.bundleFilename,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bundleSizeBytes => $composableBuilder(
      column: $table.bundleSizeBytes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get areaOfInterest => $composableBuilder(
      column: $table.areaOfInterest,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> formsRefs(
      Expression<bool> Function($$FormsTableFilterComposer f) f) {
    final $$FormsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.forms,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FormsTableFilterComposer(
              $db: $db,
              $table: $db.forms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> layersRefs(
      Expression<bool> Function($$LayersTableFilterComposer f) f) {
    final $$LayersTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.layers,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LayersTableFilterComposer(
              $db: $db,
              $table: $db.layers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> choiceListsRefs(
      Expression<bool> Function($$ChoiceListsTableFilterComposer f) f) {
    final $$ChoiceListsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.choiceLists,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChoiceListsTableFilterComposer(
              $db: $db,
              $table: $db.choiceLists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> assignmentsRefs(
      Expression<bool> Function($$AssignmentsTableFilterComposer f) f) {
    final $$AssignmentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.assignments,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssignmentsTableFilterComposer(
              $db: $db,
              $table: $db.assignments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> referenceFeaturesRefs(
      Expression<bool> Function($$ReferenceFeaturesTableFilterComposer f) f) {
    final $$ReferenceFeaturesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.referenceFeatures,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ReferenceFeaturesTableFilterComposer(
              $db: $db,
              $table: $db.referenceFeatures,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> collectedFeaturesRefs(
      Expression<bool> Function($$CollectedFeaturesTableFilterComposer f) f) {
    final $$CollectedFeaturesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.collectedFeatures,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CollectedFeaturesTableFilterComposer(
              $db: $db,
              $table: $db.collectedFeatures,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bundleFilename => $composableBuilder(
      column: $table.bundleFilename,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bundleSizeBytes => $composableBuilder(
      column: $table.bundleSizeBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get areaOfInterest => $composableBuilder(
      column: $table.areaOfInterest,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
      column: $table.contentHash, builder: (column) => column);

  GeneratedColumn<String> get bundleFilename => $composableBuilder(
      column: $table.bundleFilename, builder: (column) => column);

  GeneratedColumn<int> get bundleSizeBytes => $composableBuilder(
      column: $table.bundleSizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => column);

  GeneratedColumn<String> get areaOfInterest => $composableBuilder(
      column: $table.areaOfInterest, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> formsRefs<T extends Object>(
      Expression<T> Function($$FormsTableAnnotationComposer a) f) {
    final $$FormsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.forms,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$FormsTableAnnotationComposer(
              $db: $db,
              $table: $db.forms,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> layersRefs<T extends Object>(
      Expression<T> Function($$LayersTableAnnotationComposer a) f) {
    final $$LayersTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.layers,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LayersTableAnnotationComposer(
              $db: $db,
              $table: $db.layers,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> choiceListsRefs<T extends Object>(
      Expression<T> Function($$ChoiceListsTableAnnotationComposer a) f) {
    final $$ChoiceListsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.choiceLists,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ChoiceListsTableAnnotationComposer(
              $db: $db,
              $table: $db.choiceLists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> assignmentsRefs<T extends Object>(
      Expression<T> Function($$AssignmentsTableAnnotationComposer a) f) {
    final $$AssignmentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.assignments,
        getReferencedColumn: (t) => t.projectId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AssignmentsTableAnnotationComposer(
              $db: $db,
              $table: $db.assignments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> referenceFeaturesRefs<T extends Object>(
      Expression<T> Function($$ReferenceFeaturesTableAnnotationComposer a) f) {
    final $$ReferenceFeaturesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.referenceFeatures,
            getReferencedColumn: (t) => t.projectId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ReferenceFeaturesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.referenceFeatures,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> collectedFeaturesRefs<T extends Object>(
      Expression<T> Function($$CollectedFeaturesTableAnnotationComposer a) f) {
    final $$CollectedFeaturesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.collectedFeatures,
            getReferencedColumn: (t) => t.projectId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$CollectedFeaturesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.collectedFeatures,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$ProjectsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (Project, $$ProjectsTableReferences),
    Project,
    PrefetchHooks Function(
        {bool formsRefs,
        bool layersRefs,
        bool choiceListsRefs,
        bool assignmentsRefs,
        bool referenceFeaturesRefs,
        bool collectedFeaturesRefs})> {
  $$ProjectsTableTableManager(_$AppDatabase db, $ProjectsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String?> contentHash = const Value.absent(),
            Value<String?> bundleFilename = const Value.absent(),
            Value<int?> bundleSizeBytes = const Value.absent(),
            Value<DateTime?> downloadedAt = const Value.absent(),
            Value<String?> areaOfInterest = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion(
            id: id,
            name: name,
            description: description,
            mode: mode,
            status: status,
            version: version,
            contentHash: contentHash,
            bundleFilename: bundleFilename,
            bundleSizeBytes: bundleSizeBytes,
            downloadedAt: downloadedAt,
            areaOfInterest: areaOfInterest,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> description = const Value.absent(),
            required String mode,
            required String status,
            Value<int> version = const Value.absent(),
            Value<String?> contentHash = const Value.absent(),
            Value<String?> bundleFilename = const Value.absent(),
            Value<int?> bundleSizeBytes = const Value.absent(),
            Value<DateTime?> downloadedAt = const Value.absent(),
            Value<String?> areaOfInterest = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ProjectsCompanion.insert(
            id: id,
            name: name,
            description: description,
            mode: mode,
            status: status,
            version: version,
            contentHash: contentHash,
            bundleFilename: bundleFilename,
            bundleSizeBytes: bundleSizeBytes,
            downloadedAt: downloadedAt,
            areaOfInterest: areaOfInterest,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$ProjectsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {formsRefs = false,
              layersRefs = false,
              choiceListsRefs = false,
              assignmentsRefs = false,
              referenceFeaturesRefs = false,
              collectedFeaturesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (formsRefs) db.forms,
                if (layersRefs) db.layers,
                if (choiceListsRefs) db.choiceLists,
                if (assignmentsRefs) db.assignments,
                if (referenceFeaturesRefs) db.referenceFeatures,
                if (collectedFeaturesRefs) db.collectedFeatures
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (formsRefs)
                    await $_getPrefetchedData<Project, $ProjectsTable, Form>(
                        currentTable: table,
                        referencedTable:
                            $$ProjectsTableReferences._formsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableReferences(db, table, p0).formsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items),
                  if (layersRefs)
                    await $_getPrefetchedData<Project, $ProjectsTable, Layer>(
                        currentTable: table,
                        referencedTable:
                            $$ProjectsTableReferences._layersRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableReferences(db, table, p0).layersRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items),
                  if (choiceListsRefs)
                    await $_getPrefetchedData<Project, $ProjectsTable,
                            ChoiceList>(
                        currentTable: table,
                        referencedTable:
                            $$ProjectsTableReferences._choiceListsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableReferences(db, table, p0)
                                .choiceListsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items),
                  if (assignmentsRefs)
                    await $_getPrefetchedData<Project, $ProjectsTable,
                            Assignment>(
                        currentTable: table,
                        referencedTable:
                            $$ProjectsTableReferences._assignmentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableReferences(db, table, p0)
                                .assignmentsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items),
                  if (referenceFeaturesRefs)
                    await $_getPrefetchedData<Project, $ProjectsTable,
                            ReferenceFeature>(
                        currentTable: table,
                        referencedTable: $$ProjectsTableReferences
                            ._referenceFeaturesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableReferences(db, table, p0)
                                .referenceFeaturesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items),
                  if (collectedFeaturesRefs)
                    await $_getPrefetchedData<Project, $ProjectsTable,
                            CollectedFeature>(
                        currentTable: table,
                        referencedTable: $$ProjectsTableReferences
                            ._collectedFeaturesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ProjectsTableReferences(db, table, p0)
                                .collectedFeaturesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.projectId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ProjectsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ProjectsTable,
    Project,
    $$ProjectsTableFilterComposer,
    $$ProjectsTableOrderingComposer,
    $$ProjectsTableAnnotationComposer,
    $$ProjectsTableCreateCompanionBuilder,
    $$ProjectsTableUpdateCompanionBuilder,
    (Project, $$ProjectsTableReferences),
    Project,
    PrefetchHooks Function(
        {bool formsRefs,
        bool layersRefs,
        bool choiceListsRefs,
        bool assignmentsRefs,
        bool referenceFeaturesRefs,
        bool collectedFeaturesRefs})>;
typedef $$FormsTableCreateCompanionBuilder = FormsCompanion Function({
  required String id,
  required String projectId,
  required String name,
  Value<String?> description,
  Value<int> version,
  required String schema,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});
typedef $$FormsTableUpdateCompanionBuilder = FormsCompanion Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> name,
  Value<String?> description,
  Value<int> version,
  Value<String> schema,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});

final class $$FormsTableReferences
    extends BaseReferences<_$AppDatabase, $FormsTable, Form> {
  $$FormsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.forms.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$FormsTableFilterComposer extends Composer<_$AppDatabase, $FormsTable> {
  $$FormsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get schema => $composableBuilder(
      column: $table.schema, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => ColumnFilters(column));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FormsTableOrderingComposer
    extends Composer<_$AppDatabase, $FormsTable> {
  $$FormsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get schema => $composableBuilder(
      column: $table.schema, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt,
      builder: (column) => ColumnOrderings(column));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableOrderingComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FormsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FormsTable> {
  $$FormsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get schema =>
      $composableBuilder(column: $table.schema, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$FormsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FormsTable,
    Form,
    $$FormsTableFilterComposer,
    $$FormsTableOrderingComposer,
    $$FormsTableAnnotationComposer,
    $$FormsTableCreateCompanionBuilder,
    $$FormsTableUpdateCompanionBuilder,
    (Form, $$FormsTableReferences),
    Form,
    PrefetchHooks Function({bool projectId})> {
  $$FormsTableTableManager(_$AppDatabase db, $FormsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FormsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FormsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FormsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> schema = const Value.absent(),
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FormsCompanion(
            id: id,
            projectId: projectId,
            name: name,
            description: description,
            version: version,
            schema: schema,
            downloadedAt: downloadedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String name,
            Value<String?> description = const Value.absent(),
            Value<int> version = const Value.absent(),
            required String schema,
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FormsCompanion.insert(
            id: id,
            projectId: projectId,
            name: name,
            description: description,
            version: version,
            schema: schema,
            downloadedAt: downloadedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$FormsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable: $$FormsTableReferences._projectIdTable(db),
                    referencedColumn:
                        $$FormsTableReferences._projectIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$FormsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FormsTable,
    Form,
    $$FormsTableFilterComposer,
    $$FormsTableOrderingComposer,
    $$FormsTableAnnotationComposer,
    $$FormsTableCreateCompanionBuilder,
    $$FormsTableUpdateCompanionBuilder,
    (Form, $$FormsTableReferences),
    Form,
    PrefetchHooks Function({bool projectId})>;
typedef $$LayersTableCreateCompanionBuilder = LayersCompanion Function({
  required String id,
  required String projectId,
  required String name,
  required String geometryType,
  Value<String?> formId,
  Value<String?> style,
  Value<String?> dataSourceId,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});
typedef $$LayersTableUpdateCompanionBuilder = LayersCompanion Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> name,
  Value<String> geometryType,
  Value<String?> formId,
  Value<String?> style,
  Value<String?> dataSourceId,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});

final class $$LayersTableReferences
    extends BaseReferences<_$AppDatabase, $LayersTable, Layer> {
  $$LayersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) => db.projects
      .createAlias($_aliasNameGenerator(db.layers.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$LayersTableFilterComposer
    extends Composer<_$AppDatabase, $LayersTable> {
  $$LayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get geometryType => $composableBuilder(
      column: $table.geometryType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get formId => $composableBuilder(
      column: $table.formId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get style => $composableBuilder(
      column: $table.style, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataSourceId => $composableBuilder(
      column: $table.dataSourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => ColumnFilters(column));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LayersTableOrderingComposer
    extends Composer<_$AppDatabase, $LayersTable> {
  $$LayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get geometryType => $composableBuilder(
      column: $table.geometryType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get formId => $composableBuilder(
      column: $table.formId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get style => $composableBuilder(
      column: $table.style, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataSourceId => $composableBuilder(
      column: $table.dataSourceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt,
      builder: (column) => ColumnOrderings(column));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableOrderingComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $LayersTable> {
  $$LayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get geometryType => $composableBuilder(
      column: $table.geometryType, builder: (column) => column);

  GeneratedColumn<String> get formId =>
      $composableBuilder(column: $table.formId, builder: (column) => column);

  GeneratedColumn<String> get style =>
      $composableBuilder(column: $table.style, builder: (column) => column);

  GeneratedColumn<String> get dataSourceId => $composableBuilder(
      column: $table.dataSourceId, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LayersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LayersTable,
    Layer,
    $$LayersTableFilterComposer,
    $$LayersTableOrderingComposer,
    $$LayersTableAnnotationComposer,
    $$LayersTableCreateCompanionBuilder,
    $$LayersTableUpdateCompanionBuilder,
    (Layer, $$LayersTableReferences),
    Layer,
    PrefetchHooks Function({bool projectId})> {
  $$LayersTableTableManager(_$AppDatabase db, $LayersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> geometryType = const Value.absent(),
            Value<String?> formId = const Value.absent(),
            Value<String?> style = const Value.absent(),
            Value<String?> dataSourceId = const Value.absent(),
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LayersCompanion(
            id: id,
            projectId: projectId,
            name: name,
            geometryType: geometryType,
            formId: formId,
            style: style,
            dataSourceId: dataSourceId,
            downloadedAt: downloadedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String name,
            required String geometryType,
            Value<String?> formId = const Value.absent(),
            Value<String?> style = const Value.absent(),
            Value<String?> dataSourceId = const Value.absent(),
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LayersCompanion.insert(
            id: id,
            projectId: projectId,
            name: name,
            geometryType: geometryType,
            formId: formId,
            style: style,
            dataSourceId: dataSourceId,
            downloadedAt: downloadedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$LayersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$LayersTableReferences._projectIdTable(db),
                    referencedColumn:
                        $$LayersTableReferences._projectIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$LayersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LayersTable,
    Layer,
    $$LayersTableFilterComposer,
    $$LayersTableOrderingComposer,
    $$LayersTableAnnotationComposer,
    $$LayersTableCreateCompanionBuilder,
    $$LayersTableUpdateCompanionBuilder,
    (Layer, $$LayersTableReferences),
    Layer,
    PrefetchHooks Function({bool projectId})>;
typedef $$ChoiceListsTableCreateCompanionBuilder = ChoiceListsCompanion
    Function({
  required String id,
  required String projectId,
  required String name,
  required String choices,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});
typedef $$ChoiceListsTableUpdateCompanionBuilder = ChoiceListsCompanion
    Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> name,
  Value<String> choices,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});

final class $$ChoiceListsTableReferences
    extends BaseReferences<_$AppDatabase, $ChoiceListsTable, ChoiceList> {
  $$ChoiceListsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
          $_aliasNameGenerator(db.choiceLists.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ChoiceListsTableFilterComposer
    extends Composer<_$AppDatabase, $ChoiceListsTable> {
  $$ChoiceListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get choices => $composableBuilder(
      column: $table.choices, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => ColumnFilters(column));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ChoiceListsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChoiceListsTable> {
  $$ChoiceListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get choices => $composableBuilder(
      column: $table.choices, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt,
      builder: (column) => ColumnOrderings(column));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableOrderingComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ChoiceListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChoiceListsTable> {
  $$ChoiceListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get choices =>
      $composableBuilder(column: $table.choices, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ChoiceListsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChoiceListsTable,
    ChoiceList,
    $$ChoiceListsTableFilterComposer,
    $$ChoiceListsTableOrderingComposer,
    $$ChoiceListsTableAnnotationComposer,
    $$ChoiceListsTableCreateCompanionBuilder,
    $$ChoiceListsTableUpdateCompanionBuilder,
    (ChoiceList, $$ChoiceListsTableReferences),
    ChoiceList,
    PrefetchHooks Function({bool projectId})> {
  $$ChoiceListsTableTableManager(_$AppDatabase db, $ChoiceListsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChoiceListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChoiceListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChoiceListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> choices = const Value.absent(),
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChoiceListsCompanion(
            id: id,
            projectId: projectId,
            name: name,
            choices: choices,
            downloadedAt: downloadedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String name,
            required String choices,
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChoiceListsCompanion.insert(
            id: id,
            projectId: projectId,
            name: name,
            choices: choices,
            downloadedAt: downloadedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ChoiceListsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$ChoiceListsTableReferences._projectIdTable(db),
                    referencedColumn:
                        $$ChoiceListsTableReferences._projectIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ChoiceListsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChoiceListsTable,
    ChoiceList,
    $$ChoiceListsTableFilterComposer,
    $$ChoiceListsTableOrderingComposer,
    $$ChoiceListsTableAnnotationComposer,
    $$ChoiceListsTableCreateCompanionBuilder,
    $$ChoiceListsTableUpdateCompanionBuilder,
    (ChoiceList, $$ChoiceListsTableReferences),
    ChoiceList,
    PrefetchHooks Function({bool projectId})>;
typedef $$AssignmentsTableCreateCompanionBuilder = AssignmentsCompanion
    Function({
  required String id,
  required String projectId,
  Value<String?> title,
  Value<String?> instructions,
  Value<String?> priority,
  Value<DateTime?> dueDate,
  Value<int?> targetCount,
  Value<String> status,
  Value<String?> area,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});
typedef $$AssignmentsTableUpdateCompanionBuilder = AssignmentsCompanion
    Function({
  Value<String> id,
  Value<String> projectId,
  Value<String?> title,
  Value<String?> instructions,
  Value<String?> priority,
  Value<DateTime?> dueDate,
  Value<int?> targetCount,
  Value<String> status,
  Value<String?> area,
  Value<DateTime> downloadedAt,
  Value<int> rowid,
});

final class $$AssignmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AssignmentsTable, Assignment> {
  $$AssignmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
          $_aliasNameGenerator(db.assignments.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AssignmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AssignmentsTable> {
  $$AssignmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get instructions => $composableBuilder(
      column: $table.instructions, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get targetCount => $composableBuilder(
      column: $table.targetCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get area => $composableBuilder(
      column: $table.area, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => ColumnFilters(column));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AssignmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AssignmentsTable> {
  $$AssignmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get instructions => $composableBuilder(
      column: $table.instructions,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get priority => $composableBuilder(
      column: $table.priority, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get targetCount => $composableBuilder(
      column: $table.targetCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get area => $composableBuilder(
      column: $table.area, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt,
      builder: (column) => ColumnOrderings(column));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableOrderingComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AssignmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssignmentsTable> {
  $$AssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get instructions => $composableBuilder(
      column: $table.instructions, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get targetCount => $composableBuilder(
      column: $table.targetCount, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get area =>
      $composableBuilder(column: $table.area, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
      column: $table.downloadedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AssignmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AssignmentsTable,
    Assignment,
    $$AssignmentsTableFilterComposer,
    $$AssignmentsTableOrderingComposer,
    $$AssignmentsTableAnnotationComposer,
    $$AssignmentsTableCreateCompanionBuilder,
    $$AssignmentsTableUpdateCompanionBuilder,
    (Assignment, $$AssignmentsTableReferences),
    Assignment,
    PrefetchHooks Function({bool projectId})> {
  $$AssignmentsTableTableManager(_$AppDatabase db, $AssignmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssignmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssignmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssignmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> instructions = const Value.absent(),
            Value<String?> priority = const Value.absent(),
            Value<DateTime?> dueDate = const Value.absent(),
            Value<int?> targetCount = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> area = const Value.absent(),
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AssignmentsCompanion(
            id: id,
            projectId: projectId,
            title: title,
            instructions: instructions,
            priority: priority,
            dueDate: dueDate,
            targetCount: targetCount,
            status: status,
            area: area,
            downloadedAt: downloadedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            Value<String?> title = const Value.absent(),
            Value<String?> instructions = const Value.absent(),
            Value<String?> priority = const Value.absent(),
            Value<DateTime?> dueDate = const Value.absent(),
            Value<int?> targetCount = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> area = const Value.absent(),
            Value<DateTime> downloadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AssignmentsCompanion.insert(
            id: id,
            projectId: projectId,
            title: title,
            instructions: instructions,
            priority: priority,
            dueDate: dueDate,
            targetCount: targetCount,
            status: status,
            area: area,
            downloadedAt: downloadedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AssignmentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$AssignmentsTableReferences._projectIdTable(db),
                    referencedColumn:
                        $$AssignmentsTableReferences._projectIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AssignmentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AssignmentsTable,
    Assignment,
    $$AssignmentsTableFilterComposer,
    $$AssignmentsTableOrderingComposer,
    $$AssignmentsTableAnnotationComposer,
    $$AssignmentsTableCreateCompanionBuilder,
    $$AssignmentsTableUpdateCompanionBuilder,
    (Assignment, $$AssignmentsTableReferences),
    Assignment,
    PrefetchHooks Function({bool projectId})>;
typedef $$ReferenceFeaturesTableCreateCompanionBuilder
    = ReferenceFeaturesCompanion Function({
  required String id,
  required String projectId,
  required String layerId,
  required String geometry,
  required String attributes,
  Value<String?> sourceRef,
  Value<String?> dataSourceId,
  Value<int> rowid,
});
typedef $$ReferenceFeaturesTableUpdateCompanionBuilder
    = ReferenceFeaturesCompanion Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> layerId,
  Value<String> geometry,
  Value<String> attributes,
  Value<String?> sourceRef,
  Value<String?> dataSourceId,
  Value<int> rowid,
});

final class $$ReferenceFeaturesTableReferences extends BaseReferences<
    _$AppDatabase, $ReferenceFeaturesTable, ReferenceFeature> {
  $$ReferenceFeaturesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
          $_aliasNameGenerator(db.referenceFeatures.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ReferenceFeaturesTableFilterComposer
    extends Composer<_$AppDatabase, $ReferenceFeaturesTable> {
  $$ReferenceFeaturesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get layerId => $composableBuilder(
      column: $table.layerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get geometry => $composableBuilder(
      column: $table.geometry, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attributes => $composableBuilder(
      column: $table.attributes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceRef => $composableBuilder(
      column: $table.sourceRef, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataSourceId => $composableBuilder(
      column: $table.dataSourceId, builder: (column) => ColumnFilters(column));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReferenceFeaturesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReferenceFeaturesTable> {
  $$ReferenceFeaturesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get layerId => $composableBuilder(
      column: $table.layerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get geometry => $composableBuilder(
      column: $table.geometry, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attributes => $composableBuilder(
      column: $table.attributes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceRef => $composableBuilder(
      column: $table.sourceRef, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataSourceId => $composableBuilder(
      column: $table.dataSourceId,
      builder: (column) => ColumnOrderings(column));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableOrderingComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReferenceFeaturesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReferenceFeaturesTable> {
  $$ReferenceFeaturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get layerId =>
      $composableBuilder(column: $table.layerId, builder: (column) => column);

  GeneratedColumn<String> get geometry =>
      $composableBuilder(column: $table.geometry, builder: (column) => column);

  GeneratedColumn<String> get attributes => $composableBuilder(
      column: $table.attributes, builder: (column) => column);

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  GeneratedColumn<String> get dataSourceId => $composableBuilder(
      column: $table.dataSourceId, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ReferenceFeaturesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReferenceFeaturesTable,
    ReferenceFeature,
    $$ReferenceFeaturesTableFilterComposer,
    $$ReferenceFeaturesTableOrderingComposer,
    $$ReferenceFeaturesTableAnnotationComposer,
    $$ReferenceFeaturesTableCreateCompanionBuilder,
    $$ReferenceFeaturesTableUpdateCompanionBuilder,
    (ReferenceFeature, $$ReferenceFeaturesTableReferences),
    ReferenceFeature,
    PrefetchHooks Function({bool projectId})> {
  $$ReferenceFeaturesTableTableManager(
      _$AppDatabase db, $ReferenceFeaturesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReferenceFeaturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReferenceFeaturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReferenceFeaturesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> layerId = const Value.absent(),
            Value<String> geometry = const Value.absent(),
            Value<String> attributes = const Value.absent(),
            Value<String?> sourceRef = const Value.absent(),
            Value<String?> dataSourceId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReferenceFeaturesCompanion(
            id: id,
            projectId: projectId,
            layerId: layerId,
            geometry: geometry,
            attributes: attributes,
            sourceRef: sourceRef,
            dataSourceId: dataSourceId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String layerId,
            required String geometry,
            required String attributes,
            Value<String?> sourceRef = const Value.absent(),
            Value<String?> dataSourceId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReferenceFeaturesCompanion.insert(
            id: id,
            projectId: projectId,
            layerId: layerId,
            geometry: geometry,
            attributes: attributes,
            sourceRef: sourceRef,
            dataSourceId: dataSourceId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ReferenceFeaturesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$ReferenceFeaturesTableReferences._projectIdTable(db),
                    referencedColumn: $$ReferenceFeaturesTableReferences
                        ._projectIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ReferenceFeaturesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReferenceFeaturesTable,
    ReferenceFeature,
    $$ReferenceFeaturesTableFilterComposer,
    $$ReferenceFeaturesTableOrderingComposer,
    $$ReferenceFeaturesTableAnnotationComposer,
    $$ReferenceFeaturesTableCreateCompanionBuilder,
    $$ReferenceFeaturesTableUpdateCompanionBuilder,
    (ReferenceFeature, $$ReferenceFeaturesTableReferences),
    ReferenceFeature,
    PrefetchHooks Function({bool projectId})>;
typedef $$CollectedFeaturesTableCreateCompanionBuilder
    = CollectedFeaturesCompanion Function({
  required String clientId,
  required String projectId,
  Value<String?> layerId,
  required String formId,
  Value<int> formVersion,
  Value<String?> geometry,
  required String attributes,
  Value<String> status,
  Value<String?> serverId,
  Value<DateTime> collectedAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> syncedAt,
  Value<String?> lastError,
  Value<String> syncStatus,
  Value<int> syncAttempts,
  Value<DateTime?> lastSyncAttemptAt,
  Value<String?> dataSourceId,
  Value<String?> originalAttributes,
  Value<String?> originalGeometry,
  Value<DateTime?> deletedAt,
  Value<String?> sourceRef,
  Value<int> rowid,
});
typedef $$CollectedFeaturesTableUpdateCompanionBuilder
    = CollectedFeaturesCompanion Function({
  Value<String> clientId,
  Value<String> projectId,
  Value<String?> layerId,
  Value<String> formId,
  Value<int> formVersion,
  Value<String?> geometry,
  Value<String> attributes,
  Value<String> status,
  Value<String?> serverId,
  Value<DateTime> collectedAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> syncedAt,
  Value<String?> lastError,
  Value<String> syncStatus,
  Value<int> syncAttempts,
  Value<DateTime?> lastSyncAttemptAt,
  Value<String?> dataSourceId,
  Value<String?> originalAttributes,
  Value<String?> originalGeometry,
  Value<DateTime?> deletedAt,
  Value<String?> sourceRef,
  Value<int> rowid,
});

final class $$CollectedFeaturesTableReferences extends BaseReferences<
    _$AppDatabase, $CollectedFeaturesTable, CollectedFeature> {
  $$CollectedFeaturesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$AppDatabase db) =>
      db.projects.createAlias(
          $_aliasNameGenerator(db.collectedFeatures.projectId, db.projects.id));

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager($_db, $_db.projects)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CollectedFeaturesTableFilterComposer
    extends Composer<_$AppDatabase, $CollectedFeaturesTable> {
  $$CollectedFeaturesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get layerId => $composableBuilder(
      column: $table.layerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get formId => $composableBuilder(
      column: $table.formId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get formVersion => $composableBuilder(
      column: $table.formVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get geometry => $composableBuilder(
      column: $table.geometry, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attributes => $composableBuilder(
      column: $table.attributes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get collectedAt => $composableBuilder(
      column: $table.collectedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncAttempts => $composableBuilder(
      column: $table.syncAttempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncAttemptAt => $composableBuilder(
      column: $table.lastSyncAttemptAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataSourceId => $composableBuilder(
      column: $table.dataSourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalAttributes => $composableBuilder(
      column: $table.originalAttributes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get originalGeometry => $composableBuilder(
      column: $table.originalGeometry,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceRef => $composableBuilder(
      column: $table.sourceRef, builder: (column) => ColumnFilters(column));

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableFilterComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CollectedFeaturesTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectedFeaturesTable> {
  $$CollectedFeaturesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get layerId => $composableBuilder(
      column: $table.layerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get formId => $composableBuilder(
      column: $table.formId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get formVersion => $composableBuilder(
      column: $table.formVersion, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get geometry => $composableBuilder(
      column: $table.geometry, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attributes => $composableBuilder(
      column: $table.attributes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get collectedAt => $composableBuilder(
      column: $table.collectedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncAttempts => $composableBuilder(
      column: $table.syncAttempts,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncAttemptAt => $composableBuilder(
      column: $table.lastSyncAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataSourceId => $composableBuilder(
      column: $table.dataSourceId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalAttributes => $composableBuilder(
      column: $table.originalAttributes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get originalGeometry => $composableBuilder(
      column: $table.originalGeometry,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceRef => $composableBuilder(
      column: $table.sourceRef, builder: (column) => ColumnOrderings(column));

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableOrderingComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CollectedFeaturesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectedFeaturesTable> {
  $$CollectedFeaturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get layerId =>
      $composableBuilder(column: $table.layerId, builder: (column) => column);

  GeneratedColumn<String> get formId =>
      $composableBuilder(column: $table.formId, builder: (column) => column);

  GeneratedColumn<int> get formVersion => $composableBuilder(
      column: $table.formVersion, builder: (column) => column);

  GeneratedColumn<String> get geometry =>
      $composableBuilder(column: $table.geometry, builder: (column) => column);

  GeneratedColumn<String> get attributes => $composableBuilder(
      column: $table.attributes, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<DateTime> get collectedAt => $composableBuilder(
      column: $table.collectedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<int> get syncAttempts => $composableBuilder(
      column: $table.syncAttempts, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAttemptAt => $composableBuilder(
      column: $table.lastSyncAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get dataSourceId => $composableBuilder(
      column: $table.dataSourceId, builder: (column) => column);

  GeneratedColumn<String> get originalAttributes => $composableBuilder(
      column: $table.originalAttributes, builder: (column) => column);

  GeneratedColumn<String> get originalGeometry => $composableBuilder(
      column: $table.originalGeometry, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.projectId,
        referencedTable: $db.projects,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ProjectsTableAnnotationComposer(
              $db: $db,
              $table: $db.projects,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CollectedFeaturesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CollectedFeaturesTable,
    CollectedFeature,
    $$CollectedFeaturesTableFilterComposer,
    $$CollectedFeaturesTableOrderingComposer,
    $$CollectedFeaturesTableAnnotationComposer,
    $$CollectedFeaturesTableCreateCompanionBuilder,
    $$CollectedFeaturesTableUpdateCompanionBuilder,
    (CollectedFeature, $$CollectedFeaturesTableReferences),
    CollectedFeature,
    PrefetchHooks Function({bool projectId})> {
  $$CollectedFeaturesTableTableManager(
      _$AppDatabase db, $CollectedFeaturesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectedFeaturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectedFeaturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectedFeaturesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientId = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String?> layerId = const Value.absent(),
            Value<String> formId = const Value.absent(),
            Value<int> formVersion = const Value.absent(),
            Value<String?> geometry = const Value.absent(),
            Value<String> attributes = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<DateTime> collectedAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncAttempts = const Value.absent(),
            Value<DateTime?> lastSyncAttemptAt = const Value.absent(),
            Value<String?> dataSourceId = const Value.absent(),
            Value<String?> originalAttributes = const Value.absent(),
            Value<String?> originalGeometry = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> sourceRef = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CollectedFeaturesCompanion(
            clientId: clientId,
            projectId: projectId,
            layerId: layerId,
            formId: formId,
            formVersion: formVersion,
            geometry: geometry,
            attributes: attributes,
            status: status,
            serverId: serverId,
            collectedAt: collectedAt,
            updatedAt: updatedAt,
            syncedAt: syncedAt,
            lastError: lastError,
            syncStatus: syncStatus,
            syncAttempts: syncAttempts,
            lastSyncAttemptAt: lastSyncAttemptAt,
            dataSourceId: dataSourceId,
            originalAttributes: originalAttributes,
            originalGeometry: originalGeometry,
            deletedAt: deletedAt,
            sourceRef: sourceRef,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientId,
            required String projectId,
            Value<String?> layerId = const Value.absent(),
            required String formId,
            Value<int> formVersion = const Value.absent(),
            Value<String?> geometry = const Value.absent(),
            required String attributes,
            Value<String> status = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<DateTime> collectedAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> syncAttempts = const Value.absent(),
            Value<DateTime?> lastSyncAttemptAt = const Value.absent(),
            Value<String?> dataSourceId = const Value.absent(),
            Value<String?> originalAttributes = const Value.absent(),
            Value<String?> originalGeometry = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<String?> sourceRef = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CollectedFeaturesCompanion.insert(
            clientId: clientId,
            projectId: projectId,
            layerId: layerId,
            formId: formId,
            formVersion: formVersion,
            geometry: geometry,
            attributes: attributes,
            status: status,
            serverId: serverId,
            collectedAt: collectedAt,
            updatedAt: updatedAt,
            syncedAt: syncedAt,
            lastError: lastError,
            syncStatus: syncStatus,
            syncAttempts: syncAttempts,
            lastSyncAttemptAt: lastSyncAttemptAt,
            dataSourceId: dataSourceId,
            originalAttributes: originalAttributes,
            originalGeometry: originalGeometry,
            deletedAt: deletedAt,
            sourceRef: sourceRef,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$CollectedFeaturesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (projectId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.projectId,
                    referencedTable:
                        $$CollectedFeaturesTableReferences._projectIdTable(db),
                    referencedColumn: $$CollectedFeaturesTableReferences
                        ._projectIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CollectedFeaturesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CollectedFeaturesTable,
    CollectedFeature,
    $$CollectedFeaturesTableFilterComposer,
    $$CollectedFeaturesTableOrderingComposer,
    $$CollectedFeaturesTableAnnotationComposer,
    $$CollectedFeaturesTableCreateCompanionBuilder,
    $$CollectedFeaturesTableUpdateCompanionBuilder,
    (CollectedFeature, $$CollectedFeaturesTableReferences),
    CollectedFeature,
    PrefetchHooks Function({bool projectId})>;
typedef $$FeatureAttachmentsTableCreateCompanionBuilder
    = FeatureAttachmentsCompanion Function({
  required String clientId,
  required String featureClientId,
  required String projectId,
  required String fieldId,
  Value<String> kind,
  required String localPath,
  Value<String?> mimeType,
  Value<int?> sizeBytes,
  Value<String> status,
  Value<String?> serverId,
  Value<String?> uploadUrl,
  Value<int> uploadAttempts,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$FeatureAttachmentsTableUpdateCompanionBuilder
    = FeatureAttachmentsCompanion Function({
  Value<String> clientId,
  Value<String> featureClientId,
  Value<String> projectId,
  Value<String> fieldId,
  Value<String> kind,
  Value<String> localPath,
  Value<String?> mimeType,
  Value<int?> sizeBytes,
  Value<String> status,
  Value<String?> serverId,
  Value<String?> uploadUrl,
  Value<int> uploadAttempts,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$FeatureAttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $FeatureAttachmentsTable> {
  $$FeatureAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get featureClientId => $composableBuilder(
      column: $table.featureClientId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fieldId => $composableBuilder(
      column: $table.fieldId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uploadUrl => $composableBuilder(
      column: $table.uploadUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get uploadAttempts => $composableBuilder(
      column: $table.uploadAttempts,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$FeatureAttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $FeatureAttachmentsTable> {
  $$FeatureAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get featureClientId => $composableBuilder(
      column: $table.featureClientId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fieldId => $composableBuilder(
      column: $table.fieldId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uploadUrl => $composableBuilder(
      column: $table.uploadUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get uploadAttempts => $composableBuilder(
      column: $table.uploadAttempts,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$FeatureAttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeatureAttachmentsTable> {
  $$FeatureAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get featureClientId => $composableBuilder(
      column: $table.featureClientId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get fieldId =>
      $composableBuilder(column: $table.fieldId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get uploadUrl =>
      $composableBuilder(column: $table.uploadUrl, builder: (column) => column);

  GeneratedColumn<int> get uploadAttempts => $composableBuilder(
      column: $table.uploadAttempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FeatureAttachmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FeatureAttachmentsTable,
    FeatureAttachment,
    $$FeatureAttachmentsTableFilterComposer,
    $$FeatureAttachmentsTableOrderingComposer,
    $$FeatureAttachmentsTableAnnotationComposer,
    $$FeatureAttachmentsTableCreateCompanionBuilder,
    $$FeatureAttachmentsTableUpdateCompanionBuilder,
    (
      FeatureAttachment,
      BaseReferences<_$AppDatabase, $FeatureAttachmentsTable, FeatureAttachment>
    ),
    FeatureAttachment,
    PrefetchHooks Function()> {
  $$FeatureAttachmentsTableTableManager(
      _$AppDatabase db, $FeatureAttachmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeatureAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeatureAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeatureAttachmentsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientId = const Value.absent(),
            Value<String> featureClientId = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> fieldId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> localPath = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<int?> sizeBytes = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<String?> uploadUrl = const Value.absent(),
            Value<int> uploadAttempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FeatureAttachmentsCompanion(
            clientId: clientId,
            featureClientId: featureClientId,
            projectId: projectId,
            fieldId: fieldId,
            kind: kind,
            localPath: localPath,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            status: status,
            serverId: serverId,
            uploadUrl: uploadUrl,
            uploadAttempts: uploadAttempts,
            lastError: lastError,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientId,
            required String featureClientId,
            required String projectId,
            required String fieldId,
            Value<String> kind = const Value.absent(),
            required String localPath,
            Value<String?> mimeType = const Value.absent(),
            Value<int?> sizeBytes = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<String?> uploadUrl = const Value.absent(),
            Value<int> uploadAttempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FeatureAttachmentsCompanion.insert(
            clientId: clientId,
            featureClientId: featureClientId,
            projectId: projectId,
            fieldId: fieldId,
            kind: kind,
            localPath: localPath,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            status: status,
            serverId: serverId,
            uploadUrl: uploadUrl,
            uploadAttempts: uploadAttempts,
            lastError: lastError,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FeatureAttachmentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FeatureAttachmentsTable,
    FeatureAttachment,
    $$FeatureAttachmentsTableFilterComposer,
    $$FeatureAttachmentsTableOrderingComposer,
    $$FeatureAttachmentsTableAnnotationComposer,
    $$FeatureAttachmentsTableCreateCompanionBuilder,
    $$FeatureAttachmentsTableUpdateCompanionBuilder,
    (
      FeatureAttachment,
      BaseReferences<_$AppDatabase, $FeatureAttachmentsTable, FeatureAttachment>
    ),
    FeatureAttachment,
    PrefetchHooks Function()>;
typedef $$SyncRunsTableCreateCompanionBuilder = SyncRunsCompanion Function({
  required String id,
  Value<String?> projectId,
  required String trigger,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<int> featuresAttempted,
  Value<int> featuresSucceeded,
  Value<int> featuresFailed,
  Value<int> attachmentsAttempted,
  Value<int> attachmentsSucceeded,
  Value<int> attachmentsFailed,
  Value<String> status,
  Value<String?> summary,
  Value<int> rowid,
});
typedef $$SyncRunsTableUpdateCompanionBuilder = SyncRunsCompanion Function({
  Value<String> id,
  Value<String?> projectId,
  Value<String> trigger,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<int> featuresAttempted,
  Value<int> featuresSucceeded,
  Value<int> featuresFailed,
  Value<int> attachmentsAttempted,
  Value<int> attachmentsSucceeded,
  Value<int> attachmentsFailed,
  Value<String> status,
  Value<String?> summary,
  Value<int> rowid,
});

final class $$SyncRunsTableReferences
    extends BaseReferences<_$AppDatabase, $SyncRunsTable, SyncRun> {
  $$SyncRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SyncErrorsTable, List<SyncError>>
      _syncErrorsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.syncErrors,
          aliasName:
              $_aliasNameGenerator(db.syncRuns.id, db.syncErrors.syncRunId));

  $$SyncErrorsTableProcessedTableManager get syncErrorsRefs {
    final manager = $$SyncErrorsTableTableManager($_db, $_db.syncErrors)
        .filter((f) => f.syncRunId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncErrorsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SyncRunsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get trigger => $composableBuilder(
      column: $table.trigger, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get featuresAttempted => $composableBuilder(
      column: $table.featuresAttempted,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get featuresSucceeded => $composableBuilder(
      column: $table.featuresSucceeded,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get featuresFailed => $composableBuilder(
      column: $table.featuresFailed,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attachmentsAttempted => $composableBuilder(
      column: $table.attachmentsAttempted,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attachmentsSucceeded => $composableBuilder(
      column: $table.attachmentsSucceeded,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attachmentsFailed => $composableBuilder(
      column: $table.attachmentsFailed,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnFilters(column));

  Expression<bool> syncErrorsRefs(
      Expression<bool> Function($$SyncErrorsTableFilterComposer f) f) {
    final $$SyncErrorsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.syncErrors,
        getReferencedColumn: (t) => t.syncRunId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SyncErrorsTableFilterComposer(
              $db: $db,
              $table: $db.syncErrors,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SyncRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get trigger => $composableBuilder(
      column: $table.trigger, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get featuresAttempted => $composableBuilder(
      column: $table.featuresAttempted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get featuresSucceeded => $composableBuilder(
      column: $table.featuresSucceeded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get featuresFailed => $composableBuilder(
      column: $table.featuresFailed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attachmentsAttempted => $composableBuilder(
      column: $table.attachmentsAttempted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attachmentsSucceeded => $composableBuilder(
      column: $table.attachmentsSucceeded,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attachmentsFailed => $composableBuilder(
      column: $table.attachmentsFailed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summary => $composableBuilder(
      column: $table.summary, builder: (column) => ColumnOrderings(column));
}

class $$SyncRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get trigger =>
      $composableBuilder(column: $table.trigger, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get featuresAttempted => $composableBuilder(
      column: $table.featuresAttempted, builder: (column) => column);

  GeneratedColumn<int> get featuresSucceeded => $composableBuilder(
      column: $table.featuresSucceeded, builder: (column) => column);

  GeneratedColumn<int> get featuresFailed => $composableBuilder(
      column: $table.featuresFailed, builder: (column) => column);

  GeneratedColumn<int> get attachmentsAttempted => $composableBuilder(
      column: $table.attachmentsAttempted, builder: (column) => column);

  GeneratedColumn<int> get attachmentsSucceeded => $composableBuilder(
      column: $table.attachmentsSucceeded, builder: (column) => column);

  GeneratedColumn<int> get attachmentsFailed => $composableBuilder(
      column: $table.attachmentsFailed, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  Expression<T> syncErrorsRefs<T extends Object>(
      Expression<T> Function($$SyncErrorsTableAnnotationComposer a) f) {
    final $$SyncErrorsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.syncErrors,
        getReferencedColumn: (t) => t.syncRunId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SyncErrorsTableAnnotationComposer(
              $db: $db,
              $table: $db.syncErrors,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SyncRunsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncRunsTable,
    SyncRun,
    $$SyncRunsTableFilterComposer,
    $$SyncRunsTableOrderingComposer,
    $$SyncRunsTableAnnotationComposer,
    $$SyncRunsTableCreateCompanionBuilder,
    $$SyncRunsTableUpdateCompanionBuilder,
    (SyncRun, $$SyncRunsTableReferences),
    SyncRun,
    PrefetchHooks Function({bool syncErrorsRefs})> {
  $$SyncRunsTableTableManager(_$AppDatabase db, $SyncRunsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> projectId = const Value.absent(),
            Value<String> trigger = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> endedAt = const Value.absent(),
            Value<int> featuresAttempted = const Value.absent(),
            Value<int> featuresSucceeded = const Value.absent(),
            Value<int> featuresFailed = const Value.absent(),
            Value<int> attachmentsAttempted = const Value.absent(),
            Value<int> attachmentsSucceeded = const Value.absent(),
            Value<int> attachmentsFailed = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> summary = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncRunsCompanion(
            id: id,
            projectId: projectId,
            trigger: trigger,
            startedAt: startedAt,
            endedAt: endedAt,
            featuresAttempted: featuresAttempted,
            featuresSucceeded: featuresSucceeded,
            featuresFailed: featuresFailed,
            attachmentsAttempted: attachmentsAttempted,
            attachmentsSucceeded: attachmentsSucceeded,
            attachmentsFailed: attachmentsFailed,
            status: status,
            summary: summary,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> projectId = const Value.absent(),
            required String trigger,
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> endedAt = const Value.absent(),
            Value<int> featuresAttempted = const Value.absent(),
            Value<int> featuresSucceeded = const Value.absent(),
            Value<int> featuresFailed = const Value.absent(),
            Value<int> attachmentsAttempted = const Value.absent(),
            Value<int> attachmentsSucceeded = const Value.absent(),
            Value<int> attachmentsFailed = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> summary = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncRunsCompanion.insert(
            id: id,
            projectId: projectId,
            trigger: trigger,
            startedAt: startedAt,
            endedAt: endedAt,
            featuresAttempted: featuresAttempted,
            featuresSucceeded: featuresSucceeded,
            featuresFailed: featuresFailed,
            attachmentsAttempted: attachmentsAttempted,
            attachmentsSucceeded: attachmentsSucceeded,
            attachmentsFailed: attachmentsFailed,
            status: status,
            summary: summary,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$SyncRunsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({syncErrorsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (syncErrorsRefs) db.syncErrors],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (syncErrorsRefs)
                    await $_getPrefetchedData<SyncRun, $SyncRunsTable,
                            SyncError>(
                        currentTable: table,
                        referencedTable:
                            $$SyncRunsTableReferences._syncErrorsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SyncRunsTableReferences(db, table, p0)
                                .syncErrorsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.syncRunId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SyncRunsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncRunsTable,
    SyncRun,
    $$SyncRunsTableFilterComposer,
    $$SyncRunsTableOrderingComposer,
    $$SyncRunsTableAnnotationComposer,
    $$SyncRunsTableCreateCompanionBuilder,
    $$SyncRunsTableUpdateCompanionBuilder,
    (SyncRun, $$SyncRunsTableReferences),
    SyncRun,
    PrefetchHooks Function({bool syncErrorsRefs})>;
typedef $$SyncErrorsTableCreateCompanionBuilder = SyncErrorsCompanion Function({
  required String id,
  required String syncRunId,
  Value<String?> featureClientId,
  Value<String?> attachmentClientId,
  required String errorCode,
  Value<String?> errorMessage,
  Value<int?> httpStatus,
  Value<DateTime> occurredAt,
  Value<int> rowid,
});
typedef $$SyncErrorsTableUpdateCompanionBuilder = SyncErrorsCompanion Function({
  Value<String> id,
  Value<String> syncRunId,
  Value<String?> featureClientId,
  Value<String?> attachmentClientId,
  Value<String> errorCode,
  Value<String?> errorMessage,
  Value<int?> httpStatus,
  Value<DateTime> occurredAt,
  Value<int> rowid,
});

final class $$SyncErrorsTableReferences
    extends BaseReferences<_$AppDatabase, $SyncErrorsTable, SyncError> {
  $$SyncErrorsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SyncRunsTable _syncRunIdTable(_$AppDatabase db) =>
      db.syncRuns.createAlias(
          $_aliasNameGenerator(db.syncErrors.syncRunId, db.syncRuns.id));

  $$SyncRunsTableProcessedTableManager get syncRunId {
    final $_column = $_itemColumn<String>('sync_run_id')!;

    final manager = $$SyncRunsTableTableManager($_db, $_db.syncRuns)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_syncRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$SyncErrorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncErrorsTable> {
  $$SyncErrorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get featureClientId => $composableBuilder(
      column: $table.featureClientId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get attachmentClientId => $composableBuilder(
      column: $table.attachmentClientId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorCode => $composableBuilder(
      column: $table.errorCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get httpStatus => $composableBuilder(
      column: $table.httpStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  $$SyncRunsTableFilterComposer get syncRunId {
    final $$SyncRunsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.syncRunId,
        referencedTable: $db.syncRuns,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SyncRunsTableFilterComposer(
              $db: $db,
              $table: $db.syncRuns,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SyncErrorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncErrorsTable> {
  $$SyncErrorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get featureClientId => $composableBuilder(
      column: $table.featureClientId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get attachmentClientId => $composableBuilder(
      column: $table.attachmentClientId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorCode => $composableBuilder(
      column: $table.errorCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get httpStatus => $composableBuilder(
      column: $table.httpStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  $$SyncRunsTableOrderingComposer get syncRunId {
    final $$SyncRunsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.syncRunId,
        referencedTable: $db.syncRuns,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SyncRunsTableOrderingComposer(
              $db: $db,
              $table: $db.syncRuns,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SyncErrorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncErrorsTable> {
  $$SyncErrorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get featureClientId => $composableBuilder(
      column: $table.featureClientId, builder: (column) => column);

  GeneratedColumn<String> get attachmentClientId => $composableBuilder(
      column: $table.attachmentClientId, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
      column: $table.errorMessage, builder: (column) => column);

  GeneratedColumn<int> get httpStatus => $composableBuilder(
      column: $table.httpStatus, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  $$SyncRunsTableAnnotationComposer get syncRunId {
    final $$SyncRunsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.syncRunId,
        referencedTable: $db.syncRuns,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SyncRunsTableAnnotationComposer(
              $db: $db,
              $table: $db.syncRuns,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SyncErrorsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncErrorsTable,
    SyncError,
    $$SyncErrorsTableFilterComposer,
    $$SyncErrorsTableOrderingComposer,
    $$SyncErrorsTableAnnotationComposer,
    $$SyncErrorsTableCreateCompanionBuilder,
    $$SyncErrorsTableUpdateCompanionBuilder,
    (SyncError, $$SyncErrorsTableReferences),
    SyncError,
    PrefetchHooks Function({bool syncRunId})> {
  $$SyncErrorsTableTableManager(_$AppDatabase db, $SyncErrorsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncErrorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncErrorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncErrorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> syncRunId = const Value.absent(),
            Value<String?> featureClientId = const Value.absent(),
            Value<String?> attachmentClientId = const Value.absent(),
            Value<String> errorCode = const Value.absent(),
            Value<String?> errorMessage = const Value.absent(),
            Value<int?> httpStatus = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncErrorsCompanion(
            id: id,
            syncRunId: syncRunId,
            featureClientId: featureClientId,
            attachmentClientId: attachmentClientId,
            errorCode: errorCode,
            errorMessage: errorMessage,
            httpStatus: httpStatus,
            occurredAt: occurredAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String syncRunId,
            Value<String?> featureClientId = const Value.absent(),
            Value<String?> attachmentClientId = const Value.absent(),
            required String errorCode,
            Value<String?> errorMessage = const Value.absent(),
            Value<int?> httpStatus = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncErrorsCompanion.insert(
            id: id,
            syncRunId: syncRunId,
            featureClientId: featureClientId,
            attachmentClientId: attachmentClientId,
            errorCode: errorCode,
            errorMessage: errorMessage,
            httpStatus: httpStatus,
            occurredAt: occurredAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SyncErrorsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({syncRunId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (syncRunId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.syncRunId,
                    referencedTable:
                        $$SyncErrorsTableReferences._syncRunIdTable(db),
                    referencedColumn:
                        $$SyncErrorsTableReferences._syncRunIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$SyncErrorsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncErrorsTable,
    SyncError,
    $$SyncErrorsTableFilterComposer,
    $$SyncErrorsTableOrderingComposer,
    $$SyncErrorsTableAnnotationComposer,
    $$SyncErrorsTableCreateCompanionBuilder,
    $$SyncErrorsTableUpdateCompanionBuilder,
    (SyncError, $$SyncErrorsTableReferences),
    SyncError,
    PrefetchHooks Function({bool syncRunId})>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$FormsTableTableManager get forms =>
      $$FormsTableTableManager(_db, _db.forms);
  $$LayersTableTableManager get layers =>
      $$LayersTableTableManager(_db, _db.layers);
  $$ChoiceListsTableTableManager get choiceLists =>
      $$ChoiceListsTableTableManager(_db, _db.choiceLists);
  $$AssignmentsTableTableManager get assignments =>
      $$AssignmentsTableTableManager(_db, _db.assignments);
  $$ReferenceFeaturesTableTableManager get referenceFeatures =>
      $$ReferenceFeaturesTableTableManager(_db, _db.referenceFeatures);
  $$CollectedFeaturesTableTableManager get collectedFeatures =>
      $$CollectedFeaturesTableTableManager(_db, _db.collectedFeatures);
  $$FeatureAttachmentsTableTableManager get featureAttachments =>
      $$FeatureAttachmentsTableTableManager(_db, _db.featureAttachments);
  $$SyncRunsTableTableManager get syncRuns =>
      $$SyncRunsTableTableManager(_db, _db.syncRuns);
  $$SyncErrorsTableTableManager get syncErrors =>
      $$SyncErrorsTableTableManager(_db, _db.syncErrors);
}
