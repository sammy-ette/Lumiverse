import gleam/int
import lumiverse/api/account
import lumiverse/api/image_url
import lumiverse/api/series
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn card(srs: series.SeriesMinimal) {
  let user = account.get()
  html.a(
    [attribute.href("/series/" <> int.to_string(srs.id)), attribute.class("group")],
    [
      html.div([attribute.class("snap-start sm:w-48 w-24 space-y-2")], [
        html.img([
          attribute.attribute("loading", "lazy"),
          attribute.src(image_url.series_cover(srs.id, user |> account.image_key)),
          attribute.class(
            "rounded bg-zinc-800 w-full object-cover sm:h-72 h-44 group-hover:scale-[1.02] group-hover:brightness-105 transition-all duration-200",
          ),
        ]),
        html.div([attribute.class("font-medium text-sm truncate")], [
          element.text(srs.name),
        ]),
      ]),
    ],
  )
}

pub fn cover_image(
  srs: series.SeriesMinimal,
  attrs: List(attribute.Attribute(a)),
) {
  let user = account.get()
  html.img([
    attribute.src(image_url.series_cover(srs.id, user |> account.image_key)),
    ..attrs
  ])
}

pub fn card_placeholder() {
  html.div([attribute.class("snap-start sm:w-48 w-24 space-y-2")], [
    html.div(
      [
        attribute.class(
          "rounded bg-zinc-800 w-full object-cover sm:h-72 h-44 animate-pulse",
        ),
      ],
      [],
    ),
    html.div(
      [
        attribute.class(
          "bg-zinc-800 font-medium h-6 w-36 text-xs md:text-base animate-pulse",
        ),
      ],
      [],
    ),
  ])
}
