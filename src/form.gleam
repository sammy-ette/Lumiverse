import gleam/javascript/array
import gleam/javascript/promise
import gleam/list
import lumiverse/layout
import lustre/effect

@external(javascript, "./form.ffi.mjs", "submit")
fn submit_js(
  _element_id: String,
  _headers: array.Array(array.Array(String)),
) -> promise.Promise(Result(Nil, Nil))

pub fn submit(
  element_id: String,
  headers: List(List(String)),
  on_result handle_result: fn(Result(Nil, Nil)) -> layout.Msg,
) -> effect.Effect(layout.Msg) {
  use dispatch <- effect.from

  let _ =
    promise.await(
      submit_js(
        element_id,
        array.from_list(
          list.map(headers, fn(header_pair: List(String)) {
            array.from_list(header_pair)
          }),
        ),
      ),
      fn(result) { promise.resolve(dispatch(handle_result(result))) },
    )

  Nil
}
