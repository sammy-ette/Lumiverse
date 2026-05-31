import gleam/dynamic/decode
import gleam/uri
import lumiverse/api/api
import lumiverse/api/fetch

pub type SeriesSearchResult {
  SeriesSearchResult(
    series_id: Int,
    name: String,
    localized_name: String,
    library_id: Int,
    library_name: String,
  )
}

fn result_decoder() {
  use series_id <- decode.field("seriesId", decode.int)
  use name <- decode.field("name", decode.string)
  use localized_name <- decode.field("localizedName", decode.string)
  use library_id <- decode.field("libraryId", decode.int)
  use library_name <- decode.field("libraryName", decode.string)
  decode.success(SeriesSearchResult(
    series_id:,
    name:,
    localized_name:,
    library_id:,
    library_name:,
  ))
}

pub fn search(
  query: String,
  resp: api.Response(List(SeriesSearchResult), b),
) {
  let decoder = {
    use series <- decode.field("series", decode.list(result_decoder()))
    decode.success(series)
  }
  fetch.get(
    "/api/search/search?queryString=" <> uri.percent_encode(query),
    decoder,
    resp,
  )
}
