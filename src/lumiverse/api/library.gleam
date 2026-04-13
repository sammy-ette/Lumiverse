import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/uri
import lumiverse/api/account
import lumiverse/api/api
import rsvp

pub type LibraryConfig {
  LibraryConfig(
    folder_watching: Bool,
    include_in_dashboard: Bool,
    include_in_recommended: Bool,
    include_in_search: Bool,
    manage_collections: Bool,
    manage_reading_lists: Bool,
    allow_scrobbling: Bool,
    allow_metadata_matching: Bool,
    collapse_series_relationships: Bool,
    enable_metadata: Bool,
    remove_prefix_for_sort_name: Bool,
    inherit_web_links_from_first_chapter: Bool,
    default_language: String,
  )
}

pub type Library {
  Library(
    id: Int,
    name: String,
    type_: LibraryType,
    last_scanned: String,
    cover_image: option.Option(String),
    folders: List(String),
    library_file_types: List(LibraryFileType),
    exclude_patterns: List(String),
    config: LibraryConfig,
  )
}

pub type LibraryCreate {
  LibraryCreate(
    id: Int,
    name: String,
    type_: LibraryType,
    folders: List(String),
    exclude_patterns: List(String),
    file_group_types: List(LibraryFileType),
    config: LibraryConfig,
  )
}

pub type LibraryFileType {
  Archive
  EPUB
  PDF
  Image
}

fn library_file_type_to_json(library_file_type: LibraryFileType) -> json.Json {
  case library_file_type {
    Archive -> json.int(1)
    EPUB -> json.int(2)
    PDF -> json.int(3)
    Image -> json.int(4)
  }
}

fn library_file_type_decoder() -> decode.Decoder(LibraryFileType) {
  use variant <- decode.then(decode.int)
  case variant {
    1 -> decode.success(Archive)
    2 -> decode.success(EPUB)
    3 -> decode.success(PDF)
    4 -> decode.success(Image)
    _ ->
      decode.failure(Archive, "LibraryFileType")
  }
}

fn config_decoder() -> decode.Decoder(LibraryConfig) {
  use folder_watching <- decode.field("folderWatching", decode.bool)
  use include_in_dashboard <- decode.field("includeInDashboard", decode.bool)
  use include_in_recommended <- decode.field(
    "includeInRecommended",
    decode.bool,
  )
  use include_in_search <- decode.field("includeInSearch", decode.bool)
  use manage_collections <- decode.field("manageCollections", decode.bool)
  use manage_reading_lists <- decode.field("manageReadingLists", decode.bool)
  use allow_scrobbling <- decode.field("allowScrobbling", decode.bool)
  use allow_metadata_matching <- decode.field(
    "allowMetadataMatching",
    decode.bool,
  )
  use collapse_series_relationships <- decode.field(
    "collapseSeriesRelationships",
    decode.bool,
  )
  use enable_metadata <- decode.field("enableMetadata", decode.bool)
  use remove_prefix_for_sort_name <- decode.field(
    "removePrefixForSortName",
    decode.bool,
  )
  use inherit_web_links_from_first_chapter <- decode.field(
    "inheritWebLinksFromFirstChapter",
    decode.bool,
  )
  use default_language <- decode.field("defaultLanguage", decode.string)
  decode.success(LibraryConfig(
    folder_watching:,
    include_in_dashboard:,
    include_in_recommended:,
    include_in_search:,
    manage_collections:,
    manage_reading_lists:,
    allow_scrobbling:,
    allow_metadata_matching:,
    collapse_series_relationships:,
    enable_metadata:,
    remove_prefix_for_sort_name:,
    inherit_web_links_from_first_chapter:,
    default_language:,
  ))
}

fn library_decoder() -> decode.Decoder(Library) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use type_ <- decode.field(
    "type",
    decode.new_primitive_decoder("LibraryType", dynamic_librarytype),
  )
  use last_scanned <- decode.field("lastScanned", decode.string)
  use cover_image <- decode.field("coverImage", decode.optional(decode.string))
  use folders <- decode.field("folders", decode.list(decode.string))
  use library_file_types <- decode.field(
    "libraryFileTypes",
    decode.list(library_file_type_decoder()),
  )
  use exclude_patterns <- decode.field(
    "excludePatterns",
    decode.list(decode.string),
  )
  use config <- decode.then(decode.at([], config_decoder()))
  decode.success(Library(
    id:,
    name:,
    type_:,
    last_scanned:,
    cover_image:,
    folders:,
    library_file_types:,
    exclude_patterns:,
    config:,
  ))
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

pub fn to_create(lib: Library) -> LibraryCreate {
  LibraryCreate(
    id: lib.id,
    name: lib.name,
    type_: lib.type_,
    folders: lib.folders,
    exclude_patterns: lib.exclude_patterns,
    file_group_types: lib.library_file_types,
    config: lib.config,
  )
}

pub fn create_to_json(lib: LibraryCreate) -> json.Json {
  let c = lib.config
  json.object(
    list.append(
      [
        #("name", json.string(lib.name)),
        #(
          "type",
          json.int(case lib.type_ {
            Manga -> 0
            Unknown(n) -> n
            Invalid -> -1
          }),
        ),
        #("folders", json.array(lib.folders, json.string)),
        #("excludePatterns", json.array(lib.exclude_patterns, json.string)),
        #("folderWatching", json.bool(c.folder_watching)),
        #("includeInDashboard", json.bool(c.include_in_dashboard)),
        #("includeInRecommended", json.bool(c.include_in_recommended)),
        #("includeInSearch", json.bool(c.include_in_search)),
        #("manageCollections", json.bool(c.manage_collections)),
        #("manageReadingLists", json.bool(c.manage_reading_lists)),
        #("allowScrobbling", json.bool(c.allow_scrobbling)),
        #("allowMetadataMatching", json.bool(c.allow_metadata_matching)),
        #(
          "collapseSeriesRelationships",
          json.bool(c.collapse_series_relationships),
        ),
        #("enableMetadata", json.bool(c.enable_metadata)),
        #("removePrefixForSortName", json.bool(c.remove_prefix_for_sort_name)),
        #(
          "inheritWebLinksFromFirstChapter",
          json.bool(c.inherit_web_links_from_first_chapter),
        ),
        #("defaultLanguage", json.string(c.default_language)),
        #(
          "fileGroupTypes",
          json.array(lib.file_group_types, library_file_type_to_json),
        ),
      ],
      case lib.id {
        -1 -> []
        id -> [#("id", json.int(id))]
      },
    ),
  )
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

pub fn create(lib: LibraryCreate, resp: api.Response(Nil, a)) {
  let assert Ok(req) = request.to(api.create_url("/api/library/create"))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(create_to_json(lib) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, api.expect_ok_response(resp))
}

pub fn update(lib: LibraryCreate, resp: api.Response(Nil, a)) {
  let assert Ok(req) = request.to(api.create_url("/api/library/update"))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(create_to_json(lib) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, api.expect_ok_response(resp))
}

pub fn scan(id: Int, resp: api.Response(Nil, a)) {
  let assert Ok(req) =
    request.to(api.create_url(
      "/api/library/scan?libraryId=" <> int.to_string(id),
    ))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, api.expect_ok_response(resp))
}

pub fn delete(id: Int, resp: api.Response(Nil, a)) {
  let assert Ok(req) =
    request.to(api.create_url(
      "/api/library/delete?libraryId=" <> int.to_string(id),
    ))

  let req =
    req
    |> request.set_method(http.Delete)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, api.expect_ok_response(resp))
}
