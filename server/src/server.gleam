import envoy
import gleam/erlang/process
import gleam/result
import gleam/string
import gleam/string_tree
import simplifile

import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  let assert Ok(_) =
    wisp_mist.handler(handle_request, wisp.random_string(64))
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}

pub fn handle_request(req: wisp.Request) -> wisp.Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/", from: "../priv/static")

  let body =
    simplifile.read("../priv/static/index.html")
    |> result.unwrap("")
    |> string.replace("</head>", "<script>" <> "window.config = {
          SERVER_URL: '" <> result.unwrap(envoy.get("SERVER_URL"), "") <> "'
          }" <> "</script></head>")
    |> string_tree.from_string
  wisp.html_response(body, 200)
}
