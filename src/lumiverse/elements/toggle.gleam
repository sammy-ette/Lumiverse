import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

pub fn toggle(label: String, checked: Bool, on_check: fn(Bool) -> msg) {
  html.label(
    [
      attribute.class(
        "flex items-center justify-between rounded px-3 py-2 text-sm text-zinc-200 hover:bg-zinc-800 cursor-pointer select-none",
      ),
    ],
    [
      element.text(label),
      html.div(
        [
          attribute.class(
            "relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors "
            <> case checked {
              True -> "bg-violet-600"
              False -> "bg-zinc-600"
            },
          ),
        ],
        [
          html.input([
            attribute.type_("checkbox"),
            attribute.checked(checked),
            attribute.class("sr-only"),
            event.on_check(on_check),
          ]),
          html.span(
            [
              attribute.class(
                "inline-block h-3.5 w-3.5 rounded-full bg-white shadow transition-transform "
                <> case checked {
                  True -> "translate-x-4.5"
                  False -> "translate-x-0.5"
                },
              ),
            ],
            [],
          ),
        ],
      ),
    ],
  )
}
