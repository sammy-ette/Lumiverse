import gleam/dynamic/decode
import gleam/json
import lumiverse/api/api
import lumiverse/api/fetch

pub type Status {
  Status(anilist_connected: Bool, mal_connected: Bool)
}

fn status_decoder() -> decode.Decoder(Status) {
  use anilist_connected <- decode.field("anilistConnected", decode.bool)
  use mal_connected <- decode.field("malConnected", decode.bool)
  decode.success(Status(anilist_connected:, mal_connected:))
}

pub fn status(resp: api.Response(Status, b)) {
  fetch.get("/api/lumiverse/scrobble/status", status_decoder(), resp)
}

pub fn report_chapter_read(
  series_id: Int,
  chapter_id: Int,
  resp: api.Response(Nil, b),
) {
  fetch.post_empty(
    "/api/lumiverse/scrobble/chapter-read",
    json.object([
      #("seriesId", json.int(series_id)),
      #("chapterId", json.int(chapter_id)),
    ]),
    resp,
  )
}

pub fn disconnect_anilist(resp: api.Response(Nil, b)) {
  fetch.delete_empty("/api/lumiverse/scrobble/anilist", resp)
}

pub fn disconnect_mal(resp: api.Response(Nil, b)) {
  fetch.delete_empty("/api/lumiverse/scrobble/mal", resp)
}

fn login_url_decoder() -> decode.Decoder(String) {
  use url <- decode.field("url", decode.string)
  decode.success(url)
}

pub fn anilist_login(resp: api.Response(String, b)) {
  fetch.get("/api/lumiverse/scrobble/anilist/login", login_url_decoder(), resp)
}

pub fn mal_login(resp: api.Response(String, b)) {
  fetch.get("/api/lumiverse/scrobble/mal/login", login_url_decoder(), resp)
}
