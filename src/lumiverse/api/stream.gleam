import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleam/option
import lumiverse/api/account
import lumiverse/api/api
import lumiverse/api/series
import rsvp

pub type DashboardRow {
  DashboardRow(
    id: Int,
    name: String,
    provided: Bool,
    order: Int,
    stream_type: StreamType,
    visible: Bool,
    smart_filter_encoded: option.Option(String),
    //smart_filter_id: String,
  )
}

fn dashboard_row_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use provided <- decode.field("isProvided", decode.bool)
  use order <- decode.field("order", decode.int)
  use stream_type <- decode.field(
    "streamType",
    decode.new_primitive_decoder("StreamType", dynamic_streamtype),
  )
  use visible <- decode.field("visible", decode.bool)
  use smart_filter_encoded <- decode.optional_field(
    "smartFilterEncoded",
    option.None,
    decode.new_primitive_decoder("Option", fn(from: dynamic.Dynamic) {
      case decode.run(from, decode.string) {
        Ok(x) -> Ok(option.Some(x))
        Error(_) -> Ok(option.None)
      }
    }),
  )
  decode.success(DashboardRow(
    id:,
    name:,
    provided:,
    order:,
    stream_type:,
    visible:,
    smart_filter_encoded:,
  ))
}

pub type StreamType {
  OnDeck
  RecentlyUpdated
  NewlyAdded
  SmartFilter
  MoreInGenre
  Unknown
  Invalid
}

pub fn dynamic_streamtype(
  from: dynamic.Dynamic,
) -> Result(StreamType, StreamType) {
  let streamtype = decode.run(from, decode.int)
  case streamtype {
    Ok(num) ->
      case num {
        // https://github.com/Kareadita/Kavita/blob/97ffdd097504ff9896f626bc7e0deb0c6e743d9d/UI/Web/src/app/_models/dashboard/stream-type.enum.ts
        1 -> Ok(OnDeck)
        2 -> Ok(RecentlyUpdated)
        3 -> Ok(NewlyAdded)
        4 -> Ok(SmartFilter)
        5 -> Ok(MoreInGenre)
        _ -> Error(Unknown)
      }
    Error(_) -> Error(Invalid)
  }
}

pub type SeriesList {
  SeriesList(items: List(series.SeriesMinimal), title: String, idx: Int)
}

pub fn dashboard_series_list_decoder(order: Int, title: String) {
  fn(from: dynamic.Dynamic) {
    case decode.run(from, decode.list(series.minimal_decoder())) {
      Ok(series) -> Ok(SeriesList(items: series, title: title, idx: order))
      Error(_) -> Error(SeriesList(items: [], title:, idx: order))
    }
  }
}

pub fn dashboard_recently_updated_decoder(order: Int, title: String) {
  fn(from: dynamic.Dynamic) {
    case decode.run(from, decode.list(series.recently_updated_decoder())) {
      Ok(series) -> Ok(SeriesList(items: series, title: title, idx: order))
      Error(_) -> Error(SeriesList(items: [], title:, idx: order))
    }
  }
}

pub fn dashboard(resp: api.Response(List(DashboardRow), a)) {
  let assert Ok(req) = request.to(api.create_url("/api/stream/dashboard"))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, rsvp.expect_json(decode.list(dashboard_row_decoder()), resp))
}

pub fn on_deck(order: Int, resp: api.Response(SeriesList, a)) {
  let assert Ok(req) =
    request.to(api.create_url("/api/series/on-deck?pageNumber=1&pageSize=10"))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(
    req,
    rsvp.expect_json(
      decode.new_primitive_decoder(
        "SeriesList",
        dashboard_series_list_decoder(order, "Continue Reading"),
      ),
      resp,
    ),
  )
}

pub fn recently_added(order: Int, resp: api.Response(SeriesList, a)) {
  let assert Ok(req) =
    request.to(api.create_url(
      "/api/series/recently-added-v2?pageNumber=1&pageSize=10",
    ))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(
    req,
    rsvp.expect_json(
      decode.new_primitive_decoder(
        "SeriesList",
        dashboard_series_list_decoder(order, "Newly Added"),
      ),
      resp,
    ),
  )
}

pub fn recently_updated(order: Int, resp: api.Response(SeriesList, a)) {
  let assert Ok(req) =
    request.to(api.create_url(
      "/api/series/recently-updated-series?pageNumber=1&pageSize=10",
    ))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(
    req,
    rsvp.expect_json(
      decode.new_primitive_decoder(
        "RecentlyUpdated",
        dashboard_recently_updated_decoder(order, "Recently Updated"),
      ),
      resp,
    ),
  )
}
