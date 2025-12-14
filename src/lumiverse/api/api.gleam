import gleam/dynamic/decode
import gleam/http/response
import gleam/uri
import localstorage
import router
import rsvp

pub type Response(a, b) =
  fn(Result(a, rsvp.Error)) -> b

pub fn create_url_with_root(root: String, path: String) -> String {
  let assert Ok(root_uri) = uri.parse(root)
  router.direct_with_root(root_uri, path)
}

pub fn create_url(path: String) -> String {
  let assert Ok(server_url) = localstorage.read("server_url")
  server_url |> create_url_with_root(path)
}

pub fn health(server: String, s: Response(response.Response(String), b)) {
  rsvp.get(
    server |> create_url_with_root("/api/health"),
    rsvp.expect_ok_response(s),
  )
}

pub fn setup_done(s: Response(Bool, b)) {
  rsvp.get(create_url("/api/admin/exists"), rsvp.expect_json(decode.bool, s))
}

pub type OIDC {
  OIDC(
    enabled: Bool,
    disable_password_auth: Bool,
    provider_name: String,
    auto_login: Bool,
  )
}

pub fn oidc(s: Response(OIDC, b)) {
  let decoder = {
    use enabled <- decode.field("enabled", decode.bool)
    use disable_password_auth <- decode.field(
      "disablePasswordAuthentication",
      decode.bool,
    )
    use provider_name <- decode.field("providerName", decode.string)
    use auto_login <- decode.field("autoLogin", decode.bool)

    decode.success(OIDC(
      enabled:,
      disable_password_auth:,
      provider_name:,
      auto_login:,
    ))
  }

  rsvp.get(create_url("/api/settings/oidc"), rsvp.expect_json(decoder, s))
}
