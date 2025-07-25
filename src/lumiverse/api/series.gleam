import gleam/dynamic
import gleam/fetch
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/option

import gleam/io

import lustre_http

import lumiverse/layout
import lumiverse/model
import lumiverse/models/filter
import lumiverse/models/series
import lumiverse/models/stream
import router

fn metadata_decoder() {
  dynamic.decode6(
    series.Metadata,
    dynamic.field("id", dynamic.int),
    dynamic.field("genres", dynamic.list(tag_decoder())),
    dynamic.field("tags", dynamic.list(tag_decoder())),
    dynamic.field("summary", dynamic.string),
    dynamic.field("publicationStatus", dynamic_publication),
    dynamic.field("seriesId", dynamic.int),
  )
}

fn dynamic_publication(
  from: dynamic.Dynamic,
) -> Result(series.Publication, List(dynamic.DecodeError)) {
  let publication = dynamic.int(from)
  case publication {
    Ok(num) ->
      case num {
        // https://github.com/Kareadita/Kavita/blob/develop/API/Entities/Enums/PublicationStatus.cs
        0 -> Ok(series.Ongoing)
        1 -> Ok(series.Hiatus)
        2 -> Ok(series.Completed)
        3 -> Ok(series.Cancelled)
        4 -> Ok(series.Ended)
        _ ->
          Error([
            dynamic.DecodeError(
              expected: "expected publicationStatus to be int of range 0-4",
              found: "it wasnt?? lol",
              path: ["what?"],
            ),
          ])
      }
    Error(e) -> Error(e)
  }
}

fn tag_decoder() {
  dynamic.decode2(
    series.Tag,
    dynamic.field("id", dynamic.int),
    dynamic.field("title", dynamic.string),
  )
}

pub fn recently_added(token: String, order: Int, title: String) {
  let assert Ok(req) =
    request.to(router.direct(
      "/api/series/recently-added-v2?pageNumber=1&pageSize=10",
    ))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(
      stream.dashboard_series_list_decoder(order, title),
      layout.DashboardItemRetrieved,
    ),
  )
}

pub fn recently_updated(token: String, order: Int, title: String) {
  let assert Ok(req) =
    request.to(router.direct(
      "/api/series/recently-updated-series?pageNumber=1&pageSize=10",
    ))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(
      stream.dashboard_recently_updated_decoder(order, title),
      layout.DashboardItemRetrieved,
    ),
  )
}

pub fn on_deck(token: String, order: Int, title: String) {
  let assert Ok(req) =
    request.to(router.direct("/api/series/on-deck?pageNumber=1&pageSize=10"))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(
      stream.dashboard_series_list_decoder(order, title),
      layout.DashboardItemRetrieved,
    ),
  )
}

pub fn decode_smart_filter(
  token: String,
  order: Int,
  smart_filter_encoded: String,
  for_dashboard: Bool,
) {
  let assert Ok(req) = request.to(router.direct("/api/filter/decode"))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(
      json.object([#("encodedFilter", json.string(smart_filter_encoded))])
      |> json.to_string,
    )
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(
      filter.smart_filter_decoder(for_dashboard, order),
      layout.SmartFilterDecode,
    ),
  )
}

pub fn series(series_id: Int, token: String) {
  let assert Ok(req) =
    request.to(router.direct("/api/series/" <> int.to_string(series_id)))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(series.minimal_decoder(), layout.SeriesRetrieved),
  )
}

pub fn metadata(series_id: Int, token: String) {
  let assert Ok(req) =
    request.to(router.direct(
      "/api/series/metadata?seriesId=" <> int.to_string(series_id),
    ))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(metadata_decoder(), layout.SeriesMetadataRetrieved),
  )
}

pub fn series_details(series_id: Int, token: String) {
  let assert Ok(req) =
    request.to(router.direct(
      "/api/series/series-detail?seriesId=" <> int.to_string(series_id),
    ))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(
      fn(val) {
        let decoder = series.details_decoder()
        case decoder(val) {
          Ok(details) -> {
            Ok(#(series_id, details))
          }
          Error(e) -> Error(e)
        }
      },
      layout.SeriesDetailsRetrieved,
    ),
  )
}

pub fn all(token: String, smart_filter: filter.SmartFilter) {
  let assert Ok(req) =
    request.to(router.direct("/api/series/all-v2?pageSize=10"))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(
      filter.encode_smart_filter(smart_filter) |> json.to_string,
    )
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(
      fn(val) {
        let decoder = dynamic.list(series.minimal_decoder())
        case decoder(val) {
          Ok(serieses) ->
            Ok(#(
              smart_filter.for_dashboard,
              model.SeriesList(
                idx: smart_filter.order,
                title: smart_filter.name,
                items: serieses,
              ),
            ))
          Error(e) -> Error(e)
        }
      },
      layout.AllSeriesRetrieved,
    ),
  )
}

pub fn request_update(
  srs: series.MinimalInfo,
  token: String,
  user_requested: String,
) {
  let assert Ok(req) = request.to(router.direct_lumify("/api/update-request"))
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(
      json.object([
        #("name", json.string(srs.name)),
        #("seriesId", json.int(srs.id)),
        #("userThatRequested", json.string(user_requested)),
      ])
      |> json.to_string,
    )
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_anything(layout.SeriesUpdateRequested),
  )
}
