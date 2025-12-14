import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleam/option

import lustre_http

import lumiverse/layout
import lumiverse/models/auth
import lumiverse/models/series
import lumiverse/models/stream
import router

// UPDATE BOTH
fn decoder() {
  use username <- decode.field("username", decode.string)
  use token <- decode.field("token", decode.string)
  use refresh_token <- decode.field("refreshToken", decode.string)
  use api_key <- decode.field("apiKey", decode.string)
  decode.success(auth.User(
    username:,
    token:,
    refresh_token:,
    api_key:,
    roles: option.None,
  ))
}

pub fn encode_login_json(user: auth.User) -> String {
  json.object([
    #("username", json.string(user.username)),
    #("token", json.string(user.token)),
    #("refreshToken", json.string(user.refresh_token)),
    #("apiKey", json.string(user.api_key)),
    // roles is not actually in the login response.
  // its just grouped in auth.User because it makes sense.
  ])
  |> json.to_string
}

// ^^ UPDATE BOTH

fn refresh_decoder() {
  use token <- decode.field("token", decode.string)
  use refresh_token <- decode.field("refreshToken", decode.string)
  decode.success(auth.Refresh(token:, refresh_token:))
}

fn config_decoder() {
  use authority <- decode.field("authority", decode.string)
  use client_id <- decode.field("clientId", decode.string)
  use provider_name <- decode.field("providerName", decode.string)
  use disable_password <- decode.field(
    "disablePasswordAuthentication",
    decode.bool,
  )
  use auto_login <- decode.field("autoLogin", decode.bool)
  decode.success(auth.Config(
    authority:,
    client_id:,
    provider_name:,
    disable_password:,
    auto_login:,
  ))
}

pub fn login(username: String, password: String) {
  let req_json =
    json.object([
      #("username", json.string(username)),
      #("password", json.string(password)),
      #("apiKey", json.string("")),
    ])

  lustre_http.post(
    router.direct("/api/account/login"),
    req_json,
    lustre_http.expect_json(decoder(), layout.LoginGot),
  )
}

pub fn login_bearer(token: String) {
  let assert Ok(req) = request.to(router.direct("/api/account"))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(req, lustre_http.expect_json(decoder(), layout.LoginGot))
}

pub fn refresh_auth(token: String, refresh_token: String) {
  let req_json =
    json.object([
      #("token", json.string(token)),
      #("refreshToken", json.string(refresh_token)),
    ])

  lustre_http.post(
    router.direct("/api/account/refresh-token"),
    req_json,
    lustre_http.expect_json(refresh_decoder(), layout.RefreshGot),
  )
}

fn dynamic_role(from: dynamic.Dynamic) -> Result(auth.Role, auth.Role) {
  case decode.run(from, decode.string) {
    Ok(str) ->
      case str {
        "Admin" -> Ok(auth.Admin)
        _ -> {
          echo "unhandled role " <> str
          Ok(auth.Unimplemented)
        }
      }
    Error(_) -> Error(auth.Unimplemented)
  }
}

pub fn roles(token: String) {
  let assert Ok(req) = request.to(router.direct("/api/account/roles"))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(
      decode.list(decode.new_primitive_decoder("Role", dynamic_role)),
      layout.RolesGot,
    ),
  )
}

pub fn decode_login_json(jd: String) -> Result(auth.User, json.DecodeError) {
  json.parse(jd, decoder())
}

pub fn health() {
  lustre_http.get(
    router.direct("/api/health"),
    lustre_http.expect_anything(layout.HealthCheck),
  )
}

pub fn config() {
  lustre_http.get(
    router.direct("/api/oidc/config"),
    lustre_http.expect_json(config_decoder(), layout.ConfigGot),
  )
}

fn dashboard_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use provided <- decode.field("isProvided", decode.bool)
  use order <- decode.field("order", decode.int)
  use stream_type <- decode.field(
    "streamType",
    decode.new_primitive_decoder("StreamType", stream.dynamic_streamtype),
  )
  use visible <- decode.field("visible", decode.bool)
  use smart_filter_encoded <- decode.optional_field(
    "smartFilterEncoded",
    option.None,
    decode.new_primitive_decoder("Option", fn(from: dynamic.Dynamic) {
      case decode.run(from, decode.string) {
        Ok(x) -> Ok(option.Some(x))
        Error(_) -> Ok(option.None)
      }
    }),
  )
  decode.success(stream.DashboardItem(
    id:,
    name:,
    provided:,
    order:,
    stream_type:,
    visible:,
    smart_filter_encoded:,
  ))
}

pub fn dashboard(token: String) {
  let assert Ok(req) = request.to(router.direct("/api/stream/dashboard"))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(
      decode.list(dashboard_decoder()),
      layout.DashboardRetrieved,
    ),
  )
}

fn popular_decoder() {
  use info <- decode.field(
    "mostPopularSeries",
    decode.list({
      use info <- decode.field("value", series.info_decoder())
      decode.success(info)
    }),
  )
  decode.success(info)
}

pub fn popular_series(token: String) {
  let assert Ok(req) = request.to(router.direct("/api/stats/server/stats"))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token)
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  lustre_http.send(
    req,
    lustre_http.expect_json(popular_decoder(), layout.PopularSeriesRetrieved),
  )
}
