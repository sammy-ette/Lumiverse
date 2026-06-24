import gleam/int
import gleam/javascript/array
import gleam/option
import lumiverse/pages/reader/model
import plinth/browser/document
import plinth/browser/element as plinth_element
import plinth/browser/shadow

@external(javascript, "./reader_ffi.mjs", "eventKey")
pub fn event_key(event: a) -> String

@external(javascript, "./reader_ffi.mjs", "scrollBy")
pub fn do_scroll_by(amount: Int) -> Nil

@external(javascript, "./reader_ffi.mjs", "windowScrollTo")
pub fn window_scroll_to(y: Float) -> Nil

@external(javascript, "./reader_ffi.mjs", "captureWindowScroll")
pub fn capture_window_scroll() -> Nil

@external(javascript, "./reader_ffi.mjs", "captureElementScroll")
pub fn capture_element_scroll() -> Nil

@external(javascript, "./reader_ffi.mjs", "applyScrollToElement")
pub fn apply_scroll_to_element() -> Nil

@external(javascript, "./reader_ffi.mjs", "applyScrollToWindow")
pub fn apply_scroll_to_window() -> Nil

@external(javascript, "./reader_ffi.mjs", "observeLazyImages")
pub fn observe_lazy_images() -> Nil

@external(javascript, "./reader_ffi.mjs", "addListener")
pub fn add_listener(type_: String, listener: fn(a) -> Nil) -> Nil

@external(javascript, "./reader_ffi.mjs", "removeListeners")
pub fn remove_listeners() -> Nil

pub fn range(from: Int, to: Int) -> List(Int) {
  case from > to {
    True -> []
    False -> [from, ..range(from + 1, to)]
  }
}

pub fn update_title(m: model.Model) {
  case m.chapter_info, m.progress {
    option.Some(chapter_info), option.Some(Ok(progress)) ->
      document.set_title(
        chapter_info.series_name
        <> " - "
        <> chapter_info.subtitle
        <> " ("
        <> progress.page_number + 1 |> int.to_string
        <> "/"
        <> chapter_info.pages |> int.to_string
        <> ") | Lumiverse",
      )
    _, _ -> Nil
  }
}

pub fn scroll_reader() {
  let assert Ok(elem) =
    document.get_elements_by_tag_name("reader-page") |> array.get(0)
  let assert Ok(shadow_root) = shadow.shadow_root(elem)

  case shadow_root |> shadow.query_selector("#reader-img") {
    Ok(reader_elem) -> plinth_element.scroll_into_view(reader_elem)
    Error(_) -> Nil
  }
}
