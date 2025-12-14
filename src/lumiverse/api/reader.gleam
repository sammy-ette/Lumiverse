import gleam/dynamic
import gleam/dynamic/decode
import gleam/fetch
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/option
import gleam/result

import gleam/io

import lustre_http

import lumiverse/layout
import lumiverse/models/reader
import router

fn progress_decoder() {
  use volume_id <- decode.field("volumeId", decode.int)
  use chapter_id <- decode.field("chapterId", decode.int)
  use page_number <- decode.field("pageNum", decode.int)
  use series_id <- decode.field("seriesId", decode.int)
  use library_id <- decode.field("libraryId", decode.int)
  decode.success(reader.Progress(
    volume_id:,
    chapter_id:,
    page_number:,
    series_id:,
    library_id:,
  ))
}

fn continue_decoder() {
  use id <- decode.field("id", decode.int)
  use pages_read <- decode.field("pagesRead", decode.int)
  use pages <- decode.field("pages", decode.int)
  decode.success(reader.ContinuePoint(id:, pages_read:, pages:))
}

fn chapter_info_decoder() {
  use volume_id <- decode.field("volumeId", decode.int)
  use series_id <- decode.field("seriesId", decode.int)
  use library_id <- decode.field("libraryId", decode.int)
  use pages <- decode.field("pages", decode.int)
  use subtitle <- decode.field("subtitle", decode.string)
  decode.success(reader.ChapterInfo(
    volume_id:,
    series_id:,
    library_id:,
    pages:,
    subtitle:,
  ))
}

pub fn get_progress(token: String, chapter_id: Int) {
  let assert Ok(req) =
    request.to(router.direct(
      "/api/reader/get-progress?chapterId=" <> int.to_string(chapter_id),
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
    lustre_http.expect_json(progress_decoder(), layout.ProgressRetrieved),
  )
}

pub fn continue_point(
  token: String,
  series_id: Int,
  msg: fn(Result(reader.ContinuePoint, lustre_http.HttpError)) -> a,
) {
  let assert Ok(req) =
    request.to(router.direct(
      "/api/reader/continue-point?seriesId=" <> int.to_string(series_id),
    ))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(req, lustre_http.expect_json(continue_decoder(), msg))
}

pub fn save_progress(token: String, progress: reader.Progress) {
  let assert Ok(req) = request.to(router.direct("/api/reader/progress"))

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
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(req, lustre_http.expect_anything(layout.ProgressUpdated))
}

pub fn next_chapter(
  token: String,
  series_id: Int,
  volume_id: Int,
  chapter_id: Int,
) {
  let assert Ok(req) =
    request.to(router.direct(
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
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_text_response(
      fn(res: response.Response(String)) {
        int.base_parse(res.body, 10)
        |> result.replace_error(lustre_http.OtherError(
          7,
          res.body <> " is not a number..",
        ))
      },
      fn(e) { e },
      fn(res) { layout.NextChapterRetrieved(res) },
    ),
  )
}

pub fn prev_chapter(
  token: String,
  series_id: Int,
  volume_id: Int,
  chapter_id: Int,
) {
  let assert Ok(req) =
    request.to(router.direct(
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
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_text_response(
      fn(res: response.Response(String)) {
        int.base_parse(res.body, 10)
        |> result.replace_error(lustre_http.OtherError(
          7,
          res.body <> " is not a number..",
        ))
      },
      fn(e) { e },
      fn(res) { layout.PreviousChapterRetrieved(res) },
    ),
  )
}

pub fn chapter_info(token: String, chapter_id: Int) {
  let assert Ok(req) =
    request.to(router.direct(
      "/api/reader/chapter-info?chapterId=" <> int.to_string(chapter_id),
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
    lustre_http.expect_json(chapter_info_decoder(), layout.ChapterInfoRetrieved),
  )
}
