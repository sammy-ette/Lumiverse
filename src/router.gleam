import gleam/list
import gleam/option
import gleam/result
import gleam/uri
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
  Integrations
  Series(String)
  Search(SearchParams)
  NotFound
  Logout
  Reader(String)
  Upload
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
    case path {
      "/" | "" -> Home
      "/setup" -> Setup
      "/settings" -> Settings
      "/preferences" -> Preferences
      "/integrations" -> Integrations
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

pub fn direct(rel: String) -> String {
  let assert Ok(rel_url) = uri.parse(rel)
  let assert Ok(direction) = uri.merge(get_route(), rel_url)
  uri.to_string(direction)
}

pub fn get_route() -> uri.Uri {
  let assert Ok(route) =
    uri.parse(window.location(window.self()) |> location.origin)
  route
}
