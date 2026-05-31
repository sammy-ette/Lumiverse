import gleam/list
import gleam/option
import gleam/result
import gleam/uri
import lumiverse/common
import plinth/browser/location

import plinth/browser/window

pub type SearchParams {
  SearchParams(query: String)
}

pub type Route {
  Home
  Setup
  Login
  All
  Settings
  Preferences
  Series(String)
  Search(SearchParams)
  NotFound
  Logout
  Reader(String)
  Upload
}

// Update Function with Routing
pub type Msg {
  ChangeRoute(route: Route)
}

pub fn uri_to_route(uri: uri.Uri) -> Route {
  // modem sometimes gives us a uri that doesnt have the query
  // in the query field, but instead appends it to the path
  // turning the uri to a string and reparsing it fixes it tho lol
  let assert Ok(uri) = uri.parse(uri.to_string(uri))
  let params = case uri.query {
    option.Some(q) ->
      case uri.parse_query(q) {
        Ok(p) -> p
        Error(_) -> []
      }
    option.None -> []
  }

  let router = fn(path: String) {
    case echo path {
      "/" | "" -> Home
      "/setup" -> Setup
      "/settings" -> Settings
      "/preferences" -> Preferences
      "/login" -> Login
      "/upload" -> Upload
      "/all" -> All
      "/search" | "/search" <> _params ->
        Search(SearchParams(
          query: list.key_find(params, "q") |> result.unwrap(""),
        ))
      "/series/" <> rest -> Series(rest)
      "/read/" <> rest -> Reader(rest)
      "/signout" -> Logout
      _ -> NotFound
    }
  }

  router(uri.path)
}

pub fn localhost() -> Bool {
  let route = get_route()
  case route.host, route.port {
    option.Some("localhost"), option.Some(1234)
    | option.Some("127.0.0.1"), option.Some(1234)
    -> True
    _, _ -> False
  }
}

pub fn root_uri() -> uri.Uri {
  let route = get_route()
  case localhost() {
    True -> {
      let assert Ok(local) = uri.parse(common.kavita_dev_api)
      local
    }
    False -> route
  }
}

pub fn root_url() -> String {
  root_uri() |> uri.to_string
}

pub fn direct_lumify(rel: String) -> String {
  let assert Ok(direction) = case localhost() {
    True -> {
      let assert Ok(lumify_uri) = uri.parse(common.lumify_dev_api)
      let assert Ok(rel_uri) = uri.parse(rel)
      uri.merge(lumify_uri, rel_uri)
    }
    False -> {
      let assert Ok(rel_url) = uri.parse("/lumify" <> rel)
      uri.merge(root_uri(), rel_url)
    }
  }
  uri.to_string(direction)
}

pub fn direct(rel: String) -> String {
  let assert Ok(rel_url) = uri.parse(rel)
  let assert Ok(direction) = uri.merge(root_uri(), rel_url)
  uri.to_string(direction)
}

pub fn direct_with_root(root: uri.Uri, rel: String) -> String {
  let assert Ok(rel_url) = uri.parse(rel)
  let assert Ok(direction) = uri.merge(root, rel_url)
  uri.to_string(direction)
}

pub fn get_route() -> uri.Uri {
  let assert Ok(route) =
    uri.parse(window.location(window.self()) |> location.origin)
  route
}
