import gleam/int
import lumiverse/api/account
import lumiverse/api/api
import lumiverse/api/series
import lustre/attribute
import lustre/element
import lustre/element/html

pub fn card(srs: series.SeriesMinimal) {
  let user = account.get()
  let cover_url =
    api.create_url(
      "/api/image/series-cover?seriesId="
      <> int.to_string(srs.id)
      <> "&apiKey="
      <> user.api_key,
    )

  html.a([attribute.href("/series/" <> int.to_string(srs.id))], [
    html.div([attribute.class("snap-start sm:w-48 w-24 space-y-2")], [
      html.img([
        attribute.attribute("loading", "lazy"),
        attribute.src(cover_url),
        attribute.class("rounded bg-zinc-800 w-full object-cover sm:h-72 h-44"),
      ]),
      html.div([attribute.class("font-medium text-xs md:text-base")], [
        element.text(srs.name),
      ]),
    ]),
  ])
}

pub fn cover_image(
  srs: series.SeriesMinimal,
  attrs: List(attribute.Attribute(a)),
) {
  let user = account.get()
  let cover_url =
    api.create_url(
      "/api/image/series-cover?seriesId="
      <> int.to_string(srs.id)
      <> "&apiKey="
      <> user.api_key,
    )

  html.img([attribute.src(cover_url), ..attrs])
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
