import plinth/javascript/date

@external(javascript, "./date.ffi.mjs", "new_")
pub fn new(ts: Int) -> date.Date
