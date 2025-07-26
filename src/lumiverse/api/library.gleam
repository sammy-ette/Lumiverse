import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json

import lustre_http

import lumiverse/layout
import lumiverse/models/library
import router

fn library_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  decode.success(library.Library(id:, name:))
}

pub fn libraries(token: String) {
  let assert Ok(req) = request.to(router.direct("/api/library/libraries"))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(decode.list(library_decoder()), layout.LibrariesGot),
  )
}
