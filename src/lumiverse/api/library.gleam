import gleam/http
import gleam/http/request
import gleam/json
import lumiverse/api/account
import lumiverse/api/api
import rsvp

pub fn scan_all(resp: api.Response(Nil, a)) {
  let assert Ok(req) = request.to(api.create_url("/api/library/scan-all"))

  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(json.object([]) |> json.to_string)
    |> request.set_header("Authorization", "Bearer " <> account.token())
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")

  rsvp.send(req, api.expect_ok_response(resp))
}
