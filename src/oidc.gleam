import gleam/javascript/promise
import lustre/effect

@external(javascript, "./oidc.ffi.mjs", "signin")
fn signin_js(
  _authority: String,
  _client_id: String,
) -> promise.Promise(Result(String, Nil))

pub fn signin(
  authority: String,
  client_id: String,
  on_result handle_result: fn(Result(String, Nil)) -> msg,
) -> effect.Effect(msg) {
  use dispatch <- effect.from

  let _ =
    promise.await(signin_js(authority, client_id), fn(result) {
      promise.resolve(dispatch(handle_result(result)))
    })

  Nil
}

@external(javascript, "./oidc.ffi.mjs", "callback")
pub fn callback(_authority: String, _client_id: String) -> Result(String, Nil) {
  Error(Nil)
}
