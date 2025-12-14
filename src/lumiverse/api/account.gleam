import gleam/dynamic/decode
import gleam/json
import lumiverse/api/api
import rsvp

pub type Account {
  Account(
    username: String,
    token: String,
    refresh_token: String,
    api_key: String,
  )
}

pub fn login(username: String, password: String, resp: api.Response(Account, a)) {
  let decoder = {
    use username <- decode.field("username", decode.string)
    use token <- decode.field("token", decode.string)
    use refresh_token <- decode.field("refreshToken", decode.string)
    use api_key <- decode.field("apiKey", decode.string)
    decode.success(Account(username:, token:, refresh_token:, api_key:))
  }

  let req_json =
    json.object([
      #("username", json.string(username)),
      #("password", json.string(password)),
      #("apiKey", json.string("")),
    ])

  rsvp.post(
    api.create_url("/api/account/login"),
    req_json,
    rsvp.expect_json(decoder, resp),
  )
}
