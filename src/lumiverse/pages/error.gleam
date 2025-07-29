import lustre/attribute
import lustre/element
import lustre/element/html
import lustre_http

import lumiverse/components/button.{button}

pub fn page(err: lustre_http.HttpError) {
  echo err
  let err_display = case err {
    lustre_http.NetworkError -> #(
      "(-_-;)",
      "You're offline. Connect to the internet and try again.",
      "",
    )
    lustre_http.NotFound -> #(
      "Not Found Σ(°ロ°)",
      "This page does not exist...",
      "",
    )
    lustre_http.OtherError(403, _) -> #(
      "Forbidden ( ｡ •̀ ᴖ •́ ｡ )",
      "You are not allowed here.",
      "",
    )
    _ -> #(
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
        button([button.solid(button.Neutral), button.md()], [
          element.text("Home"),
        ]),
      ]),
    ],
  )
}
