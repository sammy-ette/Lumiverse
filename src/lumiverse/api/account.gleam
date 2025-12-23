import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
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

pub type Role {
  Admin
  Unknown
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

fn dynamic_role(from: dynamic.Dynamic) -> Result(Role, Role) {
  case decode.run(from, decode.string) {
    Ok(str) ->
      case str {
        "Admin" -> Ok(Admin)
        _ -> {
          echo "unhandled role " <> str
          Ok(Unknown)
        }
      }
    Error(_) -> Error(Unknown)
  }
}

pub fn roles(resp: api.Response(List(Role), a)) {
  let assert Ok(req) = request.to(api.create_url("/api/account/roles"))

  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(
    req,
    rsvp.expect_json(
      decode.list(decode.new_primitive_decoder("Role", dynamic_role)),
      resp,
    ),
  )
}
