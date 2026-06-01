import gleam/json
import lumiverse/api/account
import lumiverse/api/api
import lumiverse/api/fetch

pub fn create_auth_key(
  name: String,
  length: Int,
  resp: api.Response(account.AuthKey, a),
) {
  let req_json =
    json.object([
      #("name", json.string(name)),
      #("keyLength", json.int(length)),
      #("expiresUtc", json.null()),
    ])

  fetch.post(
    "/api/account/create-auth-key",
    req_json,
    account.auth_key_decoder(),
    resp,
  )
}
