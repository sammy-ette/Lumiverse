import lustre/attribute
import lustre/element
import lustre/element/html

import lumiverse/layout

pub fn page() -> element.Element(layout.Msg) {
  html.div(
    [
      attribute.class(
        "flex flex-col justify-center items-center h-screen space-y-4",
      ),
    ],
    [
      html.img([
        attribute.src("/priv/static/logo.svg"),
        attribute.width(128),
        attribute.height(128),
      ]),
    ],
  )
}
