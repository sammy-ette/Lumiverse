import gleam/dynamic/decode
import gleam/json
import lumiverse/api/api
import lumiverse/api/fetch

fn decoder() -> decode.Decoder(Int) {
  use max_age_rating <- decode.field("maxAgeRating", decode.int)
  decode.success(max_age_rating)
}

pub fn get_preferences(resp: api.Response(Int, b)) {
  fetch.get("/api/lumiverse/preferences", decoder(), resp)
}

pub fn set_preferences(max_age_rating: Int, resp: api.Response(Int, b)) {
  fetch.put(
    "/api/lumiverse/preferences",
    json.object([#("maxAgeRating", json.int(max_age_rating))]),
    decoder(),
    resp,
  )
}
