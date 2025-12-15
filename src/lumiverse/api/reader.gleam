import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/result
import lumiverse/api/account
import lumiverse/api/api
import rsvp

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
    library_id: Int,
    pages: Int,
    subtitle: String,
  )
}

fn chapter_info_decoder() {
  use volume_id <- decode.field("volumeId", decode.int)
  use series_id <- decode.field("seriesId", decode.int)
  use library_id <- decode.field("libraryId", decode.int)
  use pages <- decode.field("pages", decode.int)
  use subtitle <- decode.field("subtitle", decode.string)
  decode.success(ChapterInfo(
    volume_id:,
    series_id:,
    library_id:,
    pages:,
    subtitle:,
  ))
}

pub fn continue_point(series_id: Int, resp: api.Response(ContinuePoint, a)) {
  let assert Ok(req) =
    request.to(api.create_url(
      "/api/reader/continue-point?seriesId=" <> int.to_string(series_id),
    ))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, rsvp.expect_json(continue_point_decoder(), resp))
}

pub fn progress(chapter_id: Int, resp: api.Response(Progress, a)) {
  let assert Ok(req) =
    request.to(api.create_url(
      "/api/reader/get-progress?chapterId=" <> int.to_string(chapter_id),
    ))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, rsvp.expect_json(progress_decoder(), resp))
}

pub fn save_progress(progress: Progress, resp: api.Response(Nil, a)) {
  let assert Ok(req) = request.to(api.create_url("/api/reader/progress"))

  let req_body =
    json.object([
      #("volumeId", json.int(progress.volume_id)),
      #("chapterId", json.int(progress.chapter_id)),
      #("pageNum", json.int(progress.page_number)),
      #("seriesId", json.int(progress.series_id)),
      #("libraryId", json.int(progress.library_id)),
    ])

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(req_body |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(
    req,
    rsvp.expect_ok_response(fn(res) {
      case res {
        Error(e) -> Error(e)
        Ok(_) -> Ok(Nil)
      }
      |> resp
    }),
  )
}

pub fn next_chapter(
  series_id: Int,
  volume_id: Int,
  chapter_id: Int,
  resp: api.Response(Int, a),
) {
  let assert Ok(req) =
    request.to(api.create_url(
      "/api/reader/next-chapter?seriesId="
      <> int.to_string(series_id)
      <> "&volumeId="
      <> int.to_string(volume_id)
      <> "&currentChapterId="
      <> int.to_string(chapter_id),
    ))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(
    req,
    rsvp.expect_text(fn(res) {
      case res {
        Ok(num_str) -> {
          int.parse(num_str)
          |> result.map_error(fn(_) { rsvp.BadBody })
          |> resp
        }
        Error(e) -> resp(Error(e))
      }
    }),
  )
}

pub fn prev_chapter(
  series_id: Int,
  volume_id: Int,
  chapter_id: Int,
  resp: api.Response(Int, a),
) {
  let assert Ok(req) =
    request.to(api.create_url(
      "/api/reader/prev-chapter?seriesId="
      <> int.to_string(series_id)
      <> "&volumeId="
      <> int.to_string(volume_id)
      <> "&currentChapterId="
      <> int.to_string(chapter_id),
    ))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(
    req,
    rsvp.expect_text(fn(res) {
      case res {
        Ok(num_str) -> {
          int.parse(num_str)
          |> result.map_error(fn(_) { rsvp.BadBody })
          |> resp
        }
        Error(e) -> resp(Error(e))
      }
    }),
  )
}

pub fn chapter_info(chapter_id: Int, resp: api.Response(ChapterInfo, a)) {
  let assert Ok(req) =
    request.to(api.create_url(
      "/api/reader/chapter-info?chapterId=" <> int.to_string(chapter_id),
    ))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, rsvp.expect_json(chapter_info_decoder(), resp))
}
