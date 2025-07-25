import gleam/dynamic
import gleam/dynamic/decode
import gleam/option

import lumiverse/model
import lumiverse/models/series

pub type DashboardItem {
  DashboardItem(
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

pub fn dashboard_series_list_decoder(order: Int, title: String) {
  fn(from: dynamic.Dynamic) {
    case decode.run(from, decode.list(series.minimal_decoder())) {
      Ok(series) ->
        Ok(model.SeriesList(items: series, title: title, idx: order))
      Error(_) -> Error(model.SeriesList(items: [], title:, idx: order))
    }
  }
}

pub fn dashboard_recently_updated_decoder(order: Int, title: String) {
  fn(from: dynamic.Dynamic) {
    case decode.run(from, decode.list(series.recently_updated_decoder())) {
      Ok(series) ->
        Ok(model.SeriesList(items: series, title: title, idx: order))
      Error(_) -> Error(model.SeriesList(items: [], title:, idx: order))
    }
  }
}
