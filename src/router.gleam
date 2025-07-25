import gleam/int
import gleam/io
import gleam/option
import gleam/uri
import plinth/browser/window

import lumiverse/common
import lumiverse/layout
import lumiverse/models/router
import lustre/effect

pub fn uri_to_route(uri: uri.Uri) -> router.Route {
  case uri.path {
    "/" -> router.Home
    "/login" -> router.Login
    "/oidc/callback" -> router.OIDCCallback
    "/all" -> router.All
    "/series/" <> rest -> router.Series(rest)
    "/chapter/" <> rest -> {
      let assert Ok(chapter_id) = int.base_parse(rest, 10)
      router.Reader(chapter_id)
    }
    "/signout" -> router.Logout
    _ -> router.NotFound
  }
}

pub fn root_uri() -> uri.Uri {
  let route = get_route()
  case route.host, route.port {
    option.Some("localhost"), option.Some(1234)
    | option.Some("127.0.0.1"), option.Some(1234)
    -> {
      let assert Ok(local) = uri.parse(common.kavita_dev_api)
      local
    }
    _, _ -> route
  }
}

pub fn root_url() -> String {
  root_uri() |> uri.to_string
}

pub fn direct_lumify(rel: String) -> String {
  let assert Ok(rel_url) = uri.parse("/lumify" <> rel)
  let assert Ok(direction) = uri.merge(root_uri(), rel_url)
  echo "call to redirect to lumify result: " <> direction |> uri.to_string
  echo rel
  uri.to_string(direction)
}

pub fn direct(rel: String) -> String {
  let assert Ok(rel_url) = uri.parse(rel)
  let assert Ok(direction) = uri.merge(root_uri(), rel_url)
  uri.to_string(direction)
}

pub fn change_route(rel: String) {
  let assert Ok(rel_url) = uri.parse(rel)
  let route = uri_to_route(rel_url)

  effect.from(fn(dispatch) {
    layout.Router(router.ChangeRoute(route))
    |> dispatch
  })
}

pub fn get_route() -> uri.Uri {
  let assert Ok(route) = uri.parse(window.location())
  route
}
