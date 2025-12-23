pub const guest_mode = False

pub const guest_mode_username = "guest"

pub const guest_mode_password = "guest"

pub fn logo() -> String {
  "/priv/static/logo.svg"
}

pub fn name() -> String {
  "Lumiverse"
}

@external(javascript, "./config.ffi.mjs", "get")
pub fn get(_field: String) -> String
