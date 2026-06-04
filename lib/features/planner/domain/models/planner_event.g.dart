// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'planner_event.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPlannerEventCollection on Isar {
  IsarCollection<PlannerEvent> get plannerEvents => this.collection();
}

const PlannerEventSchema = CollectionSchema(
  name: r'PlannerEvent',
  id: -8507074845697967445,
  properties: {
    r'colorHex': PropertySchema(
      id: 0,
      name: r'colorHex',
      type: IsarType.string,
    ),
    r'endTime': PropertySchema(
      id: 1,
      name: r'endTime',
      type: IsarType.dateTime,
    ),
    r'isCompleted': PropertySchema(
      id: 2,
      name: r'isCompleted',
      type: IsarType.bool,
    ),
    r'questionIds': PropertySchema(
      id: 3,
      name: r'questionIds',
      type: IsarType.longList,
    ),
    r'sessionType': PropertySchema(
      id: 4,
      name: r'sessionType',
      type: IsarType.byte,
      enumMap: _PlannerEventsessionTypeEnumValueMap,
    ),
    r'startTime': PropertySchema(
      id: 5,
      name: r'startTime',
      type: IsarType.dateTime,
    ),
    r'title': PropertySchema(
      id: 6,
      name: r'title',
      type: IsarType.string,
    )
  },
  estimateSize: _plannerEventEstimateSize,
  serialize: _plannerEventSerialize,
  deserialize: _plannerEventDeserialize,
  deserializeProp: _plannerEventDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _plannerEventGetId,
  getLinks: _plannerEventGetLinks,
  attach: _plannerEventAttach,
  version: '3.1.0+1',
);

int _plannerEventEstimateSize(
  PlannerEvent object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.colorHex;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.questionIds;
    if (value != null) {
      bytesCount += 3 + value.length * 8;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _plannerEventSerialize(
  PlannerEvent object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.colorHex);
  writer.writeDateTime(offsets[1], object.endTime);
  writer.writeBool(offsets[2], object.isCompleted);
  writer.writeLongList(offsets[3], object.questionIds);
  writer.writeByte(offsets[4], object.sessionType.index);
  writer.writeDateTime(offsets[5], object.startTime);
  writer.writeString(offsets[6], object.title);
}

PlannerEvent _plannerEventDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PlannerEvent();
  object.colorHex = reader.readStringOrNull(offsets[0]);
  object.endTime = reader.readDateTime(offsets[1]);
  object.id = id;
  object.isCompleted = reader.readBool(offsets[2]);
  object.questionIds = reader.readLongList(offsets[3]);
  object.sessionType =
      _PlannerEventsessionTypeValueEnumMap[reader.readByteOrNull(offsets[4])] ??
          SessionType.study;
  object.startTime = reader.readDateTime(offsets[5]);
  object.title = reader.readString(offsets[6]);
  return object;
}

P _plannerEventDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readLongList(offset)) as P;
    case 4:
      return (_PlannerEventsessionTypeValueEnumMap[
              reader.readByteOrNull(offset)] ??
          SessionType.study) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _PlannerEventsessionTypeEnumValueMap = {
  'study': 0,
  'revision': 1,
  'mock': 2,
};
const _PlannerEventsessionTypeValueEnumMap = {
  0: SessionType.study,
  1: SessionType.revision,
  2: SessionType.mock,
};

Id _plannerEventGetId(PlannerEvent object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _plannerEventGetLinks(PlannerEvent object) {
  return [];
}

void _plannerEventAttach(
    IsarCollection<dynamic> col, Id id, PlannerEvent object) {
  object.id = id;
}

extension PlannerEventQueryWhereSort
    on QueryBuilder<PlannerEvent, PlannerEvent, QWhere> {
  QueryBuilder<PlannerEvent, PlannerEvent, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PlannerEventQueryWhere
    on QueryBuilder<PlannerEvent, PlannerEvent, QWhereClause> {
  QueryBuilder<PlannerEvent, PlannerEvent, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension PlannerEventQueryFilter
    on QueryBuilder<PlannerEvent, PlannerEvent, QFilterCondition> {
  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'colorHex',
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'colorHex',
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'colorHex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'colorHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'colorHex',
        value: '',
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      colorHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'colorHex',
        value: '',
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      endTimeEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'endTime',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      endTimeGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'endTime',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      endTimeLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'endTime',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      endTimeBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'endTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      isCompletedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isCompleted',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'questionIds',
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'questionIds',
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'questionIds',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsElementGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'questionIds',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsElementLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'questionIds',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsElementBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'questionIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'questionIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'questionIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'questionIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'questionIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'questionIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      questionIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'questionIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      sessionTypeEqualTo(SessionType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionType',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      sessionTypeGreaterThan(
    SessionType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sessionType',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      sessionTypeLessThan(
    SessionType value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sessionType',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      sessionTypeBetween(
    SessionType lower,
    SessionType upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sessionType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      startTimeEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'startTime',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      startTimeGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'startTime',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      startTimeLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'startTime',
        value: value,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      startTimeBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'startTime',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }
}

extension PlannerEventQueryObject
    on QueryBuilder<PlannerEvent, PlannerEvent, QFilterCondition> {}

extension PlannerEventQueryLinks
    on QueryBuilder<PlannerEvent, PlannerEvent, QFilterCondition> {}

extension PlannerEventQuerySortBy
    on QueryBuilder<PlannerEvent, PlannerEvent, QSortBy> {
  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> sortByColorHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> sortByColorHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> sortByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> sortByEndTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> sortByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy>
      sortByIsCompletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> sortBySessionType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionType', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy>
      sortBySessionTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionType', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> sortByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> sortByStartTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension PlannerEventQuerySortThenBy
    on QueryBuilder<PlannerEvent, PlannerEvent, QSortThenBy> {
  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenByColorHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenByColorHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenByEndTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endTime', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy>
      thenByIsCompletedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isCompleted', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenBySessionType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionType', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy>
      thenBySessionTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionType', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenByStartTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startTime', Sort.desc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension PlannerEventQueryWhereDistinct
    on QueryBuilder<PlannerEvent, PlannerEvent, QDistinct> {
  QueryBuilder<PlannerEvent, PlannerEvent, QDistinct> distinctByColorHex(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'colorHex', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QDistinct> distinctByEndTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endTime');
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QDistinct> distinctByIsCompleted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isCompleted');
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QDistinct> distinctByQuestionIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'questionIds');
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QDistinct> distinctBySessionType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionType');
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QDistinct> distinctByStartTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startTime');
    });
  }

  QueryBuilder<PlannerEvent, PlannerEvent, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }
}

extension PlannerEventQueryProperty
    on QueryBuilder<PlannerEvent, PlannerEvent, QQueryProperty> {
  QueryBuilder<PlannerEvent, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PlannerEvent, String?, QQueryOperations> colorHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'colorHex');
    });
  }

  QueryBuilder<PlannerEvent, DateTime, QQueryOperations> endTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endTime');
    });
  }

  QueryBuilder<PlannerEvent, bool, QQueryOperations> isCompletedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isCompleted');
    });
  }

  QueryBuilder<PlannerEvent, List<int>?, QQueryOperations>
      questionIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'questionIds');
    });
  }

  QueryBuilder<PlannerEvent, SessionType, QQueryOperations>
      sessionTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionType');
    });
  }

  QueryBuilder<PlannerEvent, DateTime, QQueryOperations> startTimeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startTime');
    });
  }

  QueryBuilder<PlannerEvent, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }
}
