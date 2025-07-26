@external(javascript, "./ls.ffi.mjs", "read_localstorage")
pub fn read(_key: String) -> Result(String, Nil) {
  Error(Nil)
}

@external(javascript, "./ls.ffi.mjs", "write_localstorage")
pub fn write(_key: String, _value: String) -> Nil {
  Nil
}

@external(javascript, "./ls.ffi.mjs", "remove_localstorage")
pub fn remove(_key: String) -> Result(String, Nil) {
  Error(Nil)
}
