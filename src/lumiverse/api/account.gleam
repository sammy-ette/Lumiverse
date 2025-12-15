import gleam/dynamic/decode
import gleam/json
import localstorage
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

fn account_decoder() -> decode.Decoder(Account) {
  use username <- decode.field("username", decode.string)
  use token <- decode.field("token", decode.string)
  use refresh_token <- decode.field("refresh_token", decode.string)
  use api_key <- decode.field("api_key", decode.string)
  decode.success(Account(username:, token:, refresh_token:, api_key:))
}

pub fn get() {
  let assert Ok(user) = localstorage.read("user")
  let assert Ok(account) = json.parse(user, account_decoder())
  account
}

pub fn token() {
  let account = get()
  account.token
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
