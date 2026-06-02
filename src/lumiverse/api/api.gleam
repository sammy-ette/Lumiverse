import gleam/dynamic/decode
import gleam/http/response
import router
import rsvp

pub type Response(a, b) =
  fn(Result(a, rsvp.Error)) -> b

pub fn create_url(path: String) -> String {
  router.direct(path)
}

pub fn health(s: Response(response.Response(String), b)) {
  rsvp.get(create_url("/api/health"), rsvp.expect_ok_response(s))
}

pub fn expect_ok_response(handler: fn(Result(Nil, rsvp.Error)) -> a) {
  rsvp.expect_ok_response(fn(res) {
    case res {
      Ok(_) -> handler(Ok(Nil))
      Error(e) -> handler(Error(e))
    }
  })
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

pub fn oidc_authenticated(s: Response(Bool, b)) {
  rsvp.get(
    create_url("/api/account/oidc-authenticated"),
    rsvp.expect_json(decode.bool, s),
  )
}
