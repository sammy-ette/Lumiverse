import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/json
import gleam/list
import localstorage
import lumiverse/api/api
import rsvp

pub type Account {
  Account(
    username: String,
    token: String,
    refresh_token: String,
    auth_keys: List(AuthKey),
  )
}

pub fn account_to_json(account: Account) -> json.Json {
  let Account(username:, token:, refresh_token:, auth_keys:) = account
  json.object([
    #("username", json.string(username)),
    #("token", json.string(token)),
    #("refreshToken", json.string(refresh_token)),
    #("authKeys", json.array(auth_keys, auth_key_to_json)),
  ])
}

pub type AuthKey {
  AuthKey(
    id: Int,
    key: String,
    name: String,
    created_at: String,
    expires_at: String,
    last_used_at: String,
    provider: Int,
  )
}

fn auth_key_to_json(auth_key: AuthKey) -> json.Json {
  let AuthKey(
    id:,
    key:,
    name:,
    created_at:,
    expires_at:,
    last_used_at:,
    provider:,
  ) = auth_key
  json.object([
    #("id", json.int(id)),
    #("key", json.string(key)),
    #("name", json.string(name)),
    #("createdAtUtc", json.string(created_at)),
    #("expiresAtUtc", json.string(expires_at)),
    #("lastAccessedAtUtc", json.string(last_used_at)),
    #("provider", json.int(provider)),
  ])
}

fn auth_key_decoder() -> decode.Decoder(AuthKey) {
  use id <- decode.field("id", decode.int)
  use key <- decode.field("key", decode.string)
  use name <- decode.field("name", decode.string)
  use created_at <- decode.field("createdAtUtc", decode.string)
  use expires_at <- decode.field(
    "expiresAtUtc",
    decode.one_of(decode.string, [decode.success("")]),
  )
  use last_used_at <- decode.field(
    "lastAccessedAtUtc",
    decode.one_of(decode.string, [decode.success("")]),
  )
  use provider <- decode.field("provider", decode.int)
  decode.success(AuthKey(
    id:,
    key:,
    name:,
    created_at:,
    expires_at:,
    last_used_at:,
    provider:,
  ))
}

pub fn image_key(account: Account) -> String {
  let assert Ok(key) =
    list.find(account.auth_keys, fn(auth_key) { auth_key.name == "image-only" })
  key.key
}

pub type Role {
  Admin
  Unknown
}

pub fn account_decoder() -> decode.Decoder(Account) {
  use username <- decode.field("username", decode.string)
  use token <- decode.field("token", decode.string)
  use refresh_token <- decode.field("refreshToken", decode.string)
  use auth_keys <- decode.field("authKeys", decode.list(auth_key_decoder()))
  decode.success(Account(username:, token:, refresh_token:, auth_keys:))
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
  let req_json =
    json.object([
      #("username", json.string(username)),
      #("password", json.string(password)),
      #("apiKey", json.string("")),
    ])

  rsvp.post(
    api.create_url("/api/account/login"),
    req_json,
    rsvp.expect_json(account_decoder(), resp),
  )
}

pub fn register(
  username: String,
  email: String,
  password: String,
  resp: api.Response(Account, a),
) {
  let req_json =
    json.object([
      #("username", json.string(username)),
      #("email", json.string(email)),
      #("password", json.string(password)),
    ])

  rsvp.post(
    api.create_url("/api/account/register"),
    req_json,
    rsvp.expect_json(account_decoder(), resp),
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
