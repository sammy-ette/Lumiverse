import lustre/attribute
import lustre/element
import lustre/element/html

import lumiverse/elements/button

pub type ErrorType {
  Offline
  NotFound
  Forbidden
  Other
}

pub fn page(err: ErrorType) {
  echo err
  let err_display = case err {
    Offline -> #(
      "(-_-;)",
      "You're offline. Connect to the internet and try again.",
      "",
    )
    NotFound -> #("Not Found Σ(°ロ°)", "This page does not exist...", "")
    Forbidden -> #("Forbidden ( ｡ •̀ ᴖ •́ ｡ )", "You are not allowed here.", "")
    Other -> #(
      "∘ ∘ ∘ ( °ヮ° ) ?",
      "Awkward. I've hit a snag. Try again, or report this error.",
      "",
    )
  }

  html.main(
    [
      attribute.class(
        "font-['Poppins'] flex flex-col justify-center items-center h-screen space-y-4",
      ),
    ],
    [
      html.h1([attribute.class("font-bold text-6xl")], [
        element.text(err_display.0),
      ]),
      html.p([], [element.text(err_display.1)]),
      html.a([attribute.href("/")], [
        button.button([button.bg(button.Neutral), button.md()], [
          element.text("Home"),
        ]),
      ]),
    ],
  )
}
