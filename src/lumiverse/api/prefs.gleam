import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import localstorage

const prefs_key = "preferences"

pub type Prefs {
  Prefs(image_quality: Option(Int))
}

pub fn get() -> Prefs {
  case localstorage.read(prefs_key) {
    Error(_) -> Prefs(image_quality: None)
    Ok(raw) ->
      case json.parse(raw, prefs_decoder()) {
        Ok(p) -> p
        Error(_) -> Prefs(image_quality: None)
      }
  }
}

pub fn save(p: Prefs) -> Nil {
  let q = case p.image_quality {
    None -> -1
    Some(q) -> q
  }
  localstorage.write(
    prefs_key,
    json.to_string(json.object([#("imageQuality", json.int(q))])),
  )
}

pub fn image_quality() -> Option(Int) {
  get().image_quality
}

pub fn set_image_quality(q: Option(Int)) -> Nil {
  save(Prefs(image_quality: q))
}

fn prefs_decoder() -> decode.Decoder(Prefs) {
  use raw <- decode.field("imageQuality", decode.int)
  decode.success(Prefs(image_quality: case raw < 1 {
    True -> None
    False -> Some(raw)
  }))
}
