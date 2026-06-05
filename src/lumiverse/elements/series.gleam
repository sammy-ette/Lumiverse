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
    [
      attribute.href("/series/" <> int.to_string(srs.id)),
      attribute.class("group"),
    ],
    [
      html.div([attribute.class("snap-start sm:w-48 w-24 space-y-2")], [
        html.img([
          attribute.attribute("loading", "lazy"),
          attribute.src(image_url.series_cover(
            srs.id,
            user |> account.image_key,
          )),
          attribute.alt(""),
          attribute.class(
            "rounded-lg bg-zinc-800 w-full object-cover sm:h-72 h-44 group-hover:brightness-75 transition-all duration-200",
          ),
        ]),
        html.div(
          [
            attribute.class(
              "font-[Poppins,sans-serif] font-semibold text-zinc-200 text-sm truncate",
            ),
          ],
          [
            element.text(srs.name),
          ],
        ),
      ]),
    ],
  )
}

pub fn grid_card(srs: series.SeriesMinimal) {
  let user = account.get()
  html.a(
    [
      attribute.href("/series/" <> int.to_string(srs.id)),
      attribute.class("group"),
    ],
    [
      html.div([attribute.class("w-full space-y-1.5")], [
        html.img([
          attribute.attribute("loading", "lazy"),
          attribute.src(image_url.series_cover(
            srs.id,
            user |> account.image_key,
          )),
          attribute.alt(""),
          attribute.class(
            "rounded-lg bg-zinc-800 w-full object-cover aspect-[2/3] group-hover:brightness-75 transition-all duration-200",
          ),
        ]),
        html.div(
          [
            attribute.class(
              "font-[Poppins,sans-serif] font-semibold text-zinc-200 text-xs truncate",
            ),
          ],
          [element.text(srs.name)],
        ),
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
    attribute.alt(srs.name),
    ..attrs
  ])
}

pub fn cover_image_w(
  srs: series.SeriesMinimal,
  width: Int,
  attrs: List(attribute.Attribute(a)),
) {
  let user = account.get()
  html.img([
    attribute.src(image_url.series_cover_w(srs.id, user |> account.image_key, width)),
    attribute.alt(srs.name),
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

pub fn age_rating(
  rating: series.AgeRating,
  attrs: List(attribute.Attribute(a)),
) {
  html.span(
    [
      attribute.class("text-xs font-bold px-1.5 py-0.5 rounded w-fit"),
      attribute.class(age_rating_color(rating)),
      ..attrs
    ],
    [element.text(age_rating_label(rating))],
  )
}

pub fn age_rating_color(rating: series.AgeRating) -> String {
  case rating {
    series.RatingPending
    | series.EarlyChildhood
    | series.Everyone
    | series.Everyone10Plus -> "bg-emerald-500/20 text-emerald-400"
    series.Teen -> "bg-amber-500/20 text-amber-400"
    series.Mature17Plus -> "bg-orange-500/20 text-orange-400"
    series.AdultsOnly -> "bg-red-500/20 text-red-400"
    _ -> "bg-zinc-700 text-zinc-400"
  }
}

pub fn age_rating_label(rating: series.AgeRating) -> String {
  case rating {
    series.RatingPending -> "Rating Pending"
    series.EarlyChildhood -> "Early Childhood"
    series.Everyone -> "Everyone"
    series.Everyone10Plus -> "Everyone 10+"
    series.Teen -> "Teen"
    series.Mature17Plus -> "Mature 17+"
    series.AdultsOnly -> "Adults Only"
    _ -> "Unknown"
  }
}
