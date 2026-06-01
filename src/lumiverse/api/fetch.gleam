import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/result
import localstorage
import lumiverse/api/account
import lumiverse/api/api
import rsvp

fn authed(req) {
  let req =
    req
    |> request.set_header("Accept", "application/json")
    |> request.set_header("Content-Type", "application/json")
  case localstorage.read("user") {
    Ok(user) ->
      case json.parse(user, account.account_decoder()) {
        Ok(acc) if acc.token != "" ->
          request.set_header(req, "Authorization", "Bearer " <> acc.token)
        _ -> req
      }
    Error(_) -> req
  }
}

pub fn get(path: String, decoder: decode.Decoder(a), resp: api.Response(a, b)) {
  let assert Ok(req) = request.to(api.create_url(path))
  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> authed
  rsvp.send(req, rsvp.expect_json(decoder, resp))
}

pub fn get_int(path: String, resp: api.Response(Int, b)) {
  let assert Ok(req) = request.to(api.create_url(path))
  let req =
    req
    |> request.set_method(http.Get)
    |> request.set_body(json.object([]) |> json.to_string)
    |> authed
  rsvp.send(
    req,
    rsvp.expect_any_response(fn(res) {
      case res {
        Ok(response) ->
          int.parse(response.body)
          |> result.map_error(fn(_) { rsvp.BadBody })
          |> resp
        Error(e) -> resp(Error(e))
      }
    }),
  )
}

pub fn post(
  path: String,
  body: json.Json,
  decoder: decode.Decoder(a),
  resp: api.Response(a, b),
) {
  let assert Ok(req) = request.to(api.create_url(path))
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(body |> json.to_string)
    |> authed
  rsvp.send(req, rsvp.expect_json(decoder, resp))
}

pub fn post_empty(path: String, body: json.Json, resp: api.Response(Nil, b)) {
  let assert Ok(req) = request.to(api.create_url(path))
  let req =
    req
    |> request.set_method(http.Post)
    |> request.set_body(body |> json.to_string)
    |> authed
  rsvp.send(req, api.expect_ok_response(resp))
}

pub fn put(
  path: String,
  body: json.Json,
  decoder: decode.Decoder(a),
  resp: api.Response(a, b),
) {
  let assert Ok(req) = request.to(api.create_url(path))
  let req =
    req
    |> request.set_method(http.Put)
    |> request.set_body(body |> json.to_string)
    |> authed
  rsvp.send(req, rsvp.expect_json(decoder, resp))
}

pub fn delete_empty(path: String, resp: api.Response(Nil, b)) {
  let assert Ok(req) = request.to(api.create_url(path))
  let req =
    req
    |> request.set_method(http.Delete)
    |> request.set_body(json.object([]) |> json.to_string)
    |> authed
  rsvp.send(req, api.expect_ok_response(resp))
}
