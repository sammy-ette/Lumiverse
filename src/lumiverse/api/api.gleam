import gleam/dynamic
import gleam/http
import gleam/http/request
import gleam/json
import gleam/option

import gleam/io

import lustre_http

import router

import lumiverse/api/msg
import lumiverse/layout
import lumiverse/models/auth
import lumiverse/models/stream

// UPDATE BOTH
fn decoder() {
  dynamic.decode4(
    auth.User,
    dynamic.field("username", dynamic.string),
    dynamic.field("token", dynamic.string),
    dynamic.field("refreshToken", dynamic.string),
    dynamic.field("apiKey", dynamic.string),
  )
}

pub fn encode_login_json(user: auth.User) -> String {
  json.object([
    #("username", json.string(user.username)),
    #("token", json.string(user.token)),
    #("refreshToken", json.string(user.refresh_token)),
    #("apiKey", json.string(user.api_key)),
  ])
  |> json.to_string
}

// ^^ UPDATE BOTH

fn refresh_decoder() {
  dynamic.decode2(
    auth.Refresh,
    dynamic.field("token", dynamic.string),
    dynamic.field("refreshToken", dynamic.string),
  )
}

fn config_decoder() {
  dynamic.decode5(
    auth.Config,
    dynamic.field("authority", dynamic.string),
    dynamic.field("clientId", dynamic.string),
    dynamic.field("providerName", dynamic.string),
    dynamic.field("disablePasswordAuthentication", dynamic.bool),
    dynamic.field("autoLogin", dynamic.bool),
  )
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

pub fn decode_login_json(jd: String) -> Result(auth.User, json.DecodeError) {
  json.decode(jd, decoder())
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
  dynamic.list(dynamic.decode7(
    stream.DashboardItem,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("isProvided", dynamic.bool),
    dynamic.field("order", dynamic.int),
    dynamic.field("streamType", stream.dynamic_streamtype),
    dynamic.field("visible", dynamic.bool),
    dynamic.optional_field("smartFilterEncoded", dynamic.string),
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
    lustre_http.expect_json(dashboard_decoder(), layout.DashboardRetrieved),
  )
}
