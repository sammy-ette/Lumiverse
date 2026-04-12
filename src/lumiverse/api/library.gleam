import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleam/uri
import lumiverse/api/account
import lumiverse/api/api
import rsvp

pub type Library {
  Library(id: Int, name: String, type_: LibraryType)
}

fn library_decoder() -> decode.Decoder(Library) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use type_ <- decode.field(
    "type",
    decode.new_primitive_decoder("LibraryType", dynamic_librarytype),
  )
  decode.success(Library(id:, name:, type_:))
}

pub type LibraryType {
  Manga
  Unknown(Int)
  Invalid
}

fn dynamic_librarytype(
  from: dynamic.Dynamic,
) -> Result(LibraryType, LibraryType) {
  case decode.run(from, decode.int) {
    Ok(num) ->
      case num {
        0 -> Ok(Manga)
        _ -> Error(Unknown(num))
      }
    Error(_) -> Error(Invalid)
  }
}

pub type Path {
  Path(full: String, basename: String)
}

fn path_decoder() -> decode.Decoder(Path) {
  use full <- decode.field("fullPath", decode.string)
  use basename <- decode.field("name", decode.string)
  decode.success(Path(full:, basename:))
}

pub fn scan_all(resp: api.Response(Nil, a)) {
  let assert Ok(req) = request.to(api.create_url("/api/library/scan-all"))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, api.expect_ok_response(resp))
}

pub fn all(resp: api.Response(List(Library), a)) {
  let assert Ok(req) = request.to(api.create_url("/api/library/libraries"))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, rsvp.expect_json(decode.list(library_decoder()), resp))
}

pub fn list_paths(path: String, resp: api.Response(List(Path), a)) {
  let assert Ok(req) =
    request.to(api.create_url(
      "/api/library/list"
      <> case path {
        "" -> ""
        path ->
          "?path="
          <> case uri.percent_decode(path) {
            Ok(encoded) -> encoded
            Error(_) -> path
          }
      },
    ))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, rsvp.expect_json(decode.list(path_decoder()), resp))
}
