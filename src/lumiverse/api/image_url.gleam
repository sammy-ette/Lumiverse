import gleam/int
import gleam/option
import lumiverse/api/api
import lumiverse/api/prefs

pub fn reader_page(chapter_id: Int, page: Int, api_key: String, width: Int) -> String {
  build(
    "/api/reader/image?chapterId="
      <> int.to_string(chapter_id)
      <> "&page="
      <> int.to_string(page)
      <> "&apiKey="
      <> api_key,
    option.Some(width),
  )
}

pub fn series_cover(series_id: Int, api_key: String) -> String {
  build(
    "/api/image/series-cover?seriesId="
      <> int.to_string(series_id)
      <> "&apiKey="
      <> api_key,
    option.None,
  )
}

pub fn volume_cover(volume_id: Int, api_key: String) -> String {
  build(
    "/api/image/volume-cover?volumeId="
      <> int.to_string(volume_id)
      <> "&apiKey="
      <> api_key,
    option.None,
  )
}

pub fn chapter_cover(chapter_id: Int, api_key: String) -> String {
  build(
    "/api/image/chapter-cover?chapterId="
      <> int.to_string(chapter_id)
      <> "&apiKey="
      <> api_key,
    option.None,
  )
}

fn build(kavita_path: String, width: option.Option(Int)) -> String {
  let w_part = case width {
    option.None -> ""
    option.Some(w) -> "&w=" <> int.to_string(w)
  }
  let q_part = case prefs.image_quality() {
    option.None -> ""
    option.Some(q) -> "&q=" <> int.to_string(q)
  }
  api.create_url(kavita_path <> w_part <> q_part <> "&optimizeDelivery=1")
}
