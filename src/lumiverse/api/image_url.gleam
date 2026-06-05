import gleam/int
import gleam/option
import lumiverse/api/api
import lumiverse/api/prefs
import plinth/browser/window

pub fn reader_page(chapter_id: Int, page: Int, api_key: String, width: Int) -> String {
  build(
    "/api/reader/image?chapterId="
      <> int.to_string(chapter_id)
      <> "&page="
      <> int.to_string(page)
      <> "&apiKey="
      <> api_key,
    option.Some(width),
    option.None,
  )
}

pub fn series_cover(series_id: Int, api_key: String) -> String {
  let w = responsive_cover_width()
  build(
    "/api/image/series-cover?seriesId="
      <> int.to_string(series_id)
      <> "&apiKey="
      <> api_key,
    option.Some(w),
    option.Some(75),
  )
}

pub fn series_cover_w(series_id: Int, api_key: String, width: Int) -> String {
  build(
    "/api/image/series-cover?seriesId="
      <> int.to_string(series_id)
      <> "&apiKey="
      <> api_key,
    option.Some(width),
    option.Some(75),
  )
}

pub fn series_cover_blur(series_id: Int, api_key: String) -> String {
  build(
    "/api/image/series-cover?seriesId="
      <> int.to_string(series_id)
      <> "&apiKey="
      <> api_key,
    option.Some(400),
    option.Some(5),
  )
}

pub fn volume_cover(volume_id: Int, api_key: String) -> String {
  build(
    "/api/image/volume-cover?volumeId="
      <> int.to_string(volume_id)
      <> "&apiKey="
      <> api_key,
    option.Some(200),
    option.Some(75),
  )
}

pub fn chapter_cover(chapter_id: Int, api_key: String) -> String {
  build(
    "/api/image/chapter-cover?chapterId="
      <> int.to_string(chapter_id)
      <> "&apiKey="
      <> api_key,
    option.Some(200),
    option.Some(75),
  )
}

fn responsive_cover_width() -> Int {
  case window.inner_width(window.self()) >= 640 {
    True -> 384
    False -> 192
  }
}

fn build(
  kavita_path: String,
  width: option.Option(Int),
  quality_override: option.Option(Int),
) -> String {
  let w_part = case width {
    option.None -> ""
    option.Some(w) -> "&w=" <> int.to_string(w)
  }
  let q_part = case quality_override {
    option.Some(q) -> "&q=" <> int.to_string(q)
    option.None ->
      case prefs.image_quality() {
        option.None -> ""
        option.Some(q) -> "&q=" <> int.to_string(q)
      }
  }
  api.create_url(kavita_path <> w_part <> q_part <> "&optimizeDelivery=1")
}
