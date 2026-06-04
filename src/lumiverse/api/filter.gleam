import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list

pub type SmartFilter {
  SmartFilter(
    id: Int,
    name: String,
    statements: List(Statement),
    combination: Combination,
    sort_options: SortOptions,
    limit_to: Int,
    for_dashboard: Bool,
    order: Int,
    entity_type: EntityType,
  )
}

pub type Statement {
  Statement(comparison: Comparison, field: Field, value: String)
}

fn statement_to_json(statement: Statement) -> json.Json {
  let Statement(comparison:, field:, value:) = statement
  json.object([
    #("comparison", comparison_to_json(comparison)),
    #("field", field_to_json(field)),
    #("value", json.string(value)),
  ])
}

fn smart_filter_statement_decoder() {
  use comparison <- decode.field("comparison", comparison_decoder())
  use field <- decode.field("field", field_decoder())
  use value <- decode.field("value", decode.string)
  decode.success(Statement(comparison:, field:, value:))
}

pub type Comparison {
  Equal
  GreaterThan
  GreaterThanOrEqual
  LessThan
  LessThanOrEqual
  Contains
  MustContains
  Matches
  DoesNotContain
  DoesNotEqual
  BeginsWith
  EndsWith
  IsBefore
  IsAfter
  IsInLast
  IsNotInLast
  IsEmpty
  IsNotEmpty
}

fn comparison_to_json(comparison: Comparison) -> json.Json {
  case comparison {
    Equal -> json.int(0)
    GreaterThan -> json.int(1)
    GreaterThanOrEqual -> json.int(2)
    LessThan -> json.int(3)
    LessThanOrEqual -> json.int(4)
    Contains -> json.int(5)
    MustContains -> json.int(6)
    Matches -> json.int(7)
    DoesNotContain -> json.int(8)
    DoesNotEqual -> json.int(9)
    BeginsWith -> json.int(10)
    EndsWith -> json.int(11)
    IsBefore -> json.int(12)
    IsAfter -> json.int(13)
    IsInLast -> json.int(14)
    IsNotInLast -> json.int(15)
    IsEmpty -> json.int(16)
    IsNotEmpty -> json.int(17)
  }
}

fn comparison_decoder() -> decode.Decoder(Comparison) {
  use variant <- decode.then(decode.int)
  case variant {
    0 -> decode.success(Equal)
    1 -> decode.success(GreaterThan)
    2 -> decode.success(GreaterThanOrEqual)
    3 -> decode.success(LessThan)
    4 -> decode.success(LessThanOrEqual)
    5 -> decode.success(Contains)
    6 -> decode.success(MustContains)
    7 -> decode.success(Matches)
    8 -> decode.success(DoesNotContain)
    9 -> decode.success(DoesNotEqual)
    10 -> decode.success(BeginsWith)
    11 -> decode.success(EndsWith)
    12 -> decode.success(IsBefore)
    13 -> decode.success(IsAfter)
    14 -> decode.success(IsInLast)
    15 -> decode.success(IsNotInLast)
    16 -> decode.success(IsEmpty)
    17 -> decode.success(IsNotEmpty)
    _ -> decode.failure(Equal, "Comparison")
  }
}

pub type Field {
  Summary
  SeriesName
  PublicationStatus
  Languages
  AgeRating
  FieldUserRating
  Tags
  CollectionTags
  Translators
  Characters
  Publisher
  Editor
  CoverArtist
  Letterer
  Colorist
  Inker
  Penciller
  Writers
  Genres
  Libraries
  FieldReadProgress
  Formats
  FieldReleaseYear
  ReadTime
  Path
  FilePath
  WantToRead
  ReadingDate
  FieldAverageRating
  Imprint
  Team
  Location
  ReadLast
  FileSize
}

fn field_to_json(field: Field) -> json.Json {
  case field {
    Summary -> json.int(0)
    SeriesName -> json.int(1)
    PublicationStatus -> json.int(2)
    Languages -> json.int(3)
    AgeRating -> json.int(4)
    FieldUserRating -> json.int(5)
    Tags -> json.int(6)
    CollectionTags -> json.int(7)
    Translators -> json.int(8)
    Characters -> json.int(9)
    Publisher -> json.int(10)
    Editor -> json.int(11)
    CoverArtist -> json.int(12)
    Letterer -> json.int(13)
    Colorist -> json.int(14)
    Inker -> json.int(15)
    Penciller -> json.int(16)
    Writers -> json.int(17)
    Genres -> json.int(18)
    Libraries -> json.int(19)
    FieldReadProgress -> json.int(20)
    Formats -> json.int(21)
    FieldReleaseYear -> json.int(22)
    ReadTime -> json.int(23)
    Path -> json.int(24)
    FilePath -> json.int(25)
    WantToRead -> json.int(26)
    ReadingDate -> json.int(27)
    FieldAverageRating -> json.int(28)
    Imprint -> json.int(29)
    Team -> json.int(30)
    Location -> json.int(31)
    ReadLast -> json.int(32)
    FileSize -> json.int(33)
  }
}

fn field_decoder() -> decode.Decoder(Field) {
  use variant <- decode.then(decode.int)
  case variant {
    0 -> decode.success(Summary)
    1 -> decode.success(SeriesName)
    2 -> decode.success(PublicationStatus)
    3 -> decode.success(Languages)
    4 -> decode.success(AgeRating)
    5 -> decode.success(FieldUserRating)
    6 -> decode.success(Tags)
    7 -> decode.success(CollectionTags)
    8 -> decode.success(Translators)
    9 -> decode.success(Characters)
    10 -> decode.success(Publisher)
    11 -> decode.success(Editor)
    12 -> decode.success(CoverArtist)
    13 -> decode.success(Letterer)
    14 -> decode.success(Colorist)
    15 -> decode.success(Inker)
    16 -> decode.success(Penciller)
    17 -> decode.success(Writers)
    18 -> decode.success(Genres)
    19 -> decode.success(Libraries)
    20 -> decode.success(FieldReadProgress)
    21 -> decode.success(Formats)
    22 -> decode.success(FieldReleaseYear)
    23 -> decode.success(ReadTime)
    24 -> decode.success(Path)
    25 -> decode.success(FilePath)
    26 -> decode.success(WantToRead)
    27 -> decode.success(ReadingDate)
    28 -> decode.success(FieldAverageRating)
    29 -> decode.success(Imprint)
    30 -> decode.success(Team)
    31 -> decode.success(Location)
    32 -> decode.success(ReadLast)
    33 -> decode.success(FileSize)
    _ -> decode.failure(Summary, "Field")
  }
}

pub type SortOptions {
  SortOptions(sort_field: SortField, ascending: Bool)
}

fn sort_options_to_json(sort_options: SortOptions) -> json.Json {
  let SortOptions(sort_field:, ascending:) = sort_options
  json.object([
    #("sort_field", sort_field_to_json(sort_field)),
    #("ascending", json.bool(ascending)),
  ])
}

fn smart_filter_sort_options_decoder() {
  use sort_field <- decode.field("sortField", sort_field_decoder())
  use ascending <- decode.field("isAscending", decode.bool)
  decode.success(SortOptions(sort_field:, ascending:))
}

pub type SortField {
  SortName
  CreatedDate
  LastModifiedDate
  LastChapterAdded
  TimeToRead
  ReleaseYear
  ReadProgress
  AverageRating
  Random
  UserRating
  UnreadChapterCount
}

fn sort_field_to_json(sort_field: SortField) -> json.Json {
  case sort_field {
    SortName -> json.int(1)
    CreatedDate -> json.int(2)
    LastModifiedDate -> json.int(3)
    LastChapterAdded -> json.int(4)
    TimeToRead -> json.int(5)
    ReleaseYear -> json.int(6)
    ReadProgress -> json.int(7)
    AverageRating -> json.int(8)
    Random -> json.int(9)
    UserRating -> json.int(10)
    UnreadChapterCount -> json.int(11)
  }
}

fn sort_field_decoder() -> decode.Decoder(SortField) {
  use variant <- decode.then(decode.int)
  case variant {
    1 -> decode.success(SortName)
    2 -> decode.success(CreatedDate)
    3 -> decode.success(LastModifiedDate)
    4 -> decode.success(LastChapterAdded)
    5 -> decode.success(TimeToRead)
    6 -> decode.success(ReleaseYear)
    7 -> decode.success(ReadProgress)
    8 -> decode.success(AverageRating)
    9 -> decode.success(Random)
    10 -> decode.success(UserRating)
    11 -> decode.success(UnreadChapterCount)
    _ -> decode.failure(SortName, "SortField")
  }
}

pub type Combination {
  Or
  And
}

fn combination_to_json(combination: Combination) -> json.Json {
  case combination {
    Or -> json.int(0)
    And -> json.int(1)
  }
}

fn combination_decoder() -> decode.Decoder(Combination) {
  use variant <- decode.then(decode.int)
  case variant {
    0 -> decode.success(Or)
    1 -> decode.success(And)
    num -> decode.failure(Or, num |> int.to_string)
  }
}

pub type EntityType {
  Series
  ReadingList
  Person
  Annotation
}

fn entity_type_to_json(entity_type: EntityType) -> json.Json {
  case entity_type {
    Series -> json.int(0)
    ReadingList -> json.int(1)
    Person -> json.int(2)
    Annotation -> json.int(3)
  }
}

fn entity_type_decoder() -> decode.Decoder(EntityType) {
  use variant <- decode.then(decode.int)
  case variant {
    0 -> decode.success(Series)
    1 -> decode.success(ReadingList)
    2 -> decode.success(Person)
    3 -> decode.success(Annotation)
    _ -> decode.failure(Series, "EntityType")
  }
}

pub fn smart_filter_decoder(for_dashboard: Bool, order: Int) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use statements <- decode.field(
    "statements",
    decode.list(smart_filter_statement_decoder()),
  )
  use combination <- decode.field("combination", combination_decoder())
  use sort_options <- decode.field(
    "sortOptions",
    smart_filter_sort_options_decoder(),
  )
  use limit_to <- decode.field("limitTo", decode.int)
  use entity_type <- decode.field("entityType", entity_type_decoder())
  decode.success(SmartFilter(
    id:,
    name:,
    statements:,
    combination:,
    sort_options:,
    limit_to:,
    for_dashboard:,
    order:,
    entity_type:,
  ))
}

pub fn encode_smart_filter(filter: SmartFilter) {
  json.object([
    #("id", json.int(filter.id)),
    #("name", json.string(filter.name)),
    #(
      "statements",
      json.preprocessed_array(list.map(filter.statements, statement_to_json)),
    ),
    #("combination", combination_to_json(filter.combination)),
    #("sortOptions", sort_options_to_json(filter.sort_options)),
    #("entityType", entity_type_to_json(filter.entity_type)),
    #("limitTo", json.int(filter.limit_to)),
  ])
}
