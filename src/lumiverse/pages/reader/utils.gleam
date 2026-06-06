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
