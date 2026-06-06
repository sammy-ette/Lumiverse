import gleam/dynamic/decode
import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event

pub type ToastKind {
  Info
  Warning
  Err
}

pub type Toast {
  Toast(id: Int, message: String, kind: ToastKind)
}

fn toast_kind_decoder() {
  use s <- decode.then(decode.string)
  decode.success(case s {
    "warning" -> Warning
    "error" -> Err
    _ -> Info
  })
}

pub fn on_toast(handler: fn(String, ToastKind) -> msg) -> attribute.Attribute(msg) {
  event.on("toast", {
    use message <- decode.subfield(["detail", "message"], decode.string)
    use kind <- decode.subfield(["detail", "kind"], toast_kind_decoder())
    decode.success(handler(message, kind))
  })
}

fn render_toast(toast: Toast, on_dismiss: fn(Int) -> msg) -> element.Element(msg) {
  let #(border, icon) = case toast.kind {
    Info -> #("border-blue-500 bg-blue-500/10", "ph ph-[info] text-blue-400")
    Warning -> #(
      "border-amber-500 bg-amber-500/10",
      "ph ph-[warning] text-amber-400",
    )
    Err -> #("border-red-500 bg-red-500/10", "ph ph-[x-circle] text-red-400")
  }
  html.div(
    [
      attribute.class(
        "flex items-start gap-3 border rounded-lg px-4 py-3 text-sm shadow-lg bg-zinc-900 "
        <> border,
      ),
    ],
    [
      html.i([attribute.class(icon <> " text-lg mt-0.5")], []),
      html.span([attribute.class("flex-1 text-zinc-200")], [
        element.text(toast.message),
      ]),
      html.button(
        [
          attribute.class("text-zinc-500 hover:text-white ml-2"),
          event.on_click(on_dismiss(toast.id)),
        ],
        [html.i([attribute.class("ph ph-[x]")], [])],
      ),
    ],
  )
}

pub fn toast_overlay(
  toasts: List(Toast),
  on_dismiss: fn(Int) -> msg,
) -> element.Element(msg) {
  html.div(
    [
      attribute.class(
        "fixed bottom-4 right-4 z-50 flex flex-col gap-2 items-end pointer-events-none",
      ),
    ],
    list.map(toasts, fn(t) {
      html.div([attribute.class("pointer-events-auto w-80 animate-[toast-in_0.2s_ease-out]")], [
        render_toast(t, on_dismiss),
      ])
    }),
  )
}
