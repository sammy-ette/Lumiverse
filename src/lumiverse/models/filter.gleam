import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list

pub type SmartFilter {
  SmartFilter(
    id: Int,
    name: String,
    statements: List(SmartFilterStatement),
    combination: Int,
    sort_options: SmartFilterSortOptions,
    limit_to: Int,
    for_dashboard: Bool,
    order: Int,
  )
}

pub type SmartFilterStatement {
  SmartFilterStatement(comparison: Int, field: Int, value: String)
}

pub type SmartFilterSortOptions {
  SmartFilterSortOptions(sort_field: Int, ascending: Bool)
}

pub fn smart_filter_decoder(for_dashboard: Bool, order: Int) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use statements <- decode.field(
    "statements",
    decode.list(smart_filter_statement_decoder()),
  )
  use combination <- decode.field("combination", decode.int)
  use sort_options <- decode.field(
    "sortOptions",
    smart_filter_sort_options_decoder(),
  )
  use limit_to <- decode.field("limitTo", decode.int)
  decode.success(SmartFilter(
    id:,
    name:,
    statements:,
    combination:,
    sort_options:,
    limit_to:,
    for_dashboard:,
    order:,
  ))
}

fn smart_filter_statement_decoder() {
  use comparison <- decode.field("comparison", decode.int)
  use field <- decode.field("field", decode.int)
  use value <- decode.field("value", decode.string)
  decode.success(SmartFilterStatement(comparison:, field:, value:))
}

fn smart_filter_sort_options_decoder() {
  use sort_field <- decode.field("sortField", decode.int)
  use ascending <- decode.field("isAscending", decode.bool)
  decode.success(SmartFilterSortOptions(sort_field:, ascending:))
}

pub fn encode_smart_filter(filter: SmartFilter) {
  json.object([
    #("id", json.int(filter.id)),
    #("name", json.string(filter.name)),
    #(
      "statements",
      json.preprocessed_array(
        list.map(filter.statements, fn(stmt) {
          json.object([
            #("comparison", json.int(stmt.comparison)),
            #("field", json.int(stmt.field)),
            #("value", json.string(stmt.value)),
          ])
        }),
      ),
    ),
    #("combination", json.int(filter.combination)),
    #(
      "sortOptions",
      json.object([
        #("sortField", json.int(filter.sort_options.sort_field)),
        #("isAscending", json.bool(filter.sort_options.ascending)),
      ]),
    ),
    #("limitTo", json.int(filter.limit_to)),
  ])
}
