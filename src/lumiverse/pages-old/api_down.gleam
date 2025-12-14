import lustre/attribute.{attribute}
import lustre/element
import lustre/element/html

import lumiverse/layout

pub fn page() -> element.Element(layout.Msg) {
  html.main(
    [
      attribute.class(
        "font-['Poppins'] flex flex-col justify-center items-center h-screen space-y-4",
      ),
    ],
    [
      html.h1([attribute.class("font-bold text-6xl")], [element.text("(×_×)")]),
      html.p([], [
        element.text(
          "Could not connect to the backend API. Maybe try reloading?",
        ),
      ]),
    ],
  )
}
