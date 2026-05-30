import gleam/dynamic/decode
import gleam/int
import gleam/json
import lumiverse/api/api
import lumiverse/api/fetch

pub type ContinuePoint {
  ContinuePoint(id: Int, pages_read: Int, pages: Int)
}

fn continue_point_decoder() -> decode.Decoder(ContinuePoint) {
  use id <- decode.field("id", decode.int)
  use pages_read <- decode.field("pagesRead", decode.int)
  use pages <- decode.field("pages", decode.int)
  decode.success(ContinuePoint(id:, pages_read:, pages:))
}

pub type Progress {
  Progress(
    volume_id: Int,
    chapter_id: Int,
    page_number: Int,
    series_id: Int,
    library_id: Int,
  )
}

fn progress_decoder() {
  use volume_id <- decode.field("volumeId", decode.int)
  use chapter_id <- decode.field("chapterId", decode.int)
  use page_number <- decode.field("pageNum", decode.int)
  use series_id <- decode.field("seriesId", decode.int)
  use library_id <- decode.field("libraryId", decode.int)
  decode.success(Progress(
    volume_id:,
    chapter_id:,
    page_number:,
    series_id:,
    library_id:,
  ))
}

pub type ChapterInfo {
  ChapterInfo(
    volume_id: Int,
    series_id: Int,
    series_name: String,
    library_id: Int,
    pages: Int,
    subtitle: String,
  )
}

fn chapter_info_decoder() {
  use volume_id <- decode.field("volumeId", decode.int)
  use series_id <- decode.field("seriesId", decode.int)
  use series_name <- decode.field("seriesName", decode.string)
  use library_id <- decode.field("libraryId", decode.int)
  use pages <- decode.field("pages", decode.int)
  use subtitle <- decode.field("subtitle", decode.string)
  decode.success(ChapterInfo(
    volume_id:,
    series_id:,
    series_name:,
    library_id:,
    pages:,
    subtitle:,
  ))
}

pub fn continue_point(series_id: Int, resp: api.Response(ContinuePoint, a)) {
  fetch.get(
    "/api/reader/continue-point?seriesId=" <> int.to_string(series_id),
    continue_point_decoder(),
    resp,
  )
}

pub fn progress(chapter_id: Int, resp: api.Response(Progress, a)) {
  fetch.get(
    "/api/reader/get-progress?chapterId=" <> int.to_string(chapter_id),
    progress_decoder(),
    resp,
  )
}

pub fn save_progress(progress: Progress, resp: api.Response(Nil, a)) {
  fetch.post_empty(
    "/api/reader/progress",
    json.object([
      #("volumeId", json.int(progress.volume_id)),
      #("chapterId", json.int(progress.chapter_id)),
      #("pageNum", json.int(progress.page_number)),
      #("seriesId", json.int(progress.series_id)),
      #("libraryId", json.int(progress.library_id)),
    ]),
    resp,
  )
}

pub fn next_chapter(
  series_id: Int,
  volume_id: Int,
  chapter_id: Int,
  resp: api.Response(Int, a),
) {
  fetch.get_int(
    "/api/reader/next-chapter?seriesId="
      <> int.to_string(series_id)
      <> "&volumeId="
      <> int.to_string(volume_id)
      <> "&currentChapterId="
      <> int.to_string(chapter_id),
    resp,
  )
}

pub fn prev_chapter(
  series_id: Int,
  volume_id: Int,
  chapter_id: Int,
  resp: api.Response(Int, a),
) {
  fetch.get_int(
    "/api/reader/prev-chapter?seriesId="
      <> int.to_string(series_id)
      <> "&volumeId="
      <> int.to_string(volume_id)
      <> "&currentChapterId="
      <> int.to_string(chapter_id),
    resp,
  )
}

pub fn chapter_info(chapter_id: Int, resp: api.Response(ChapterInfo, a)) {
  fetch.get(
    "/api/reader/chapter-info?chapterId=" <> int.to_string(chapter_id),
    chapter_info_decoder(),
    resp,
  )
}
