import gleam/dynamic
import gleam/dynamic/decode
import gleam/result
import plinth/javascript/date

pub type Manga {
  Manga(
    name: String,
    id: String,
    image: String,
    description: String,
    authors: List(String),
    artists: List(String),
    genres: List(String),
    tags: List(String),
    publication: Publication,
  )
}

pub type Details {
  Details(
    chapters: List(Chapter),
    volumes: List(Volume),
    specials: List(Chapter),
  )
}

pub fn details_decoder() {
  use chapters <- decode.field("chapters", decode.list(chapter_decoder()))
  use volumes <- decode.field("volumes", decode.list(volume_decoder()))
  use specials <- decode.field("specials", decode.list(chapter_decoder()))
  decode.success(Details(chapters:, volumes:, specials:))
}

pub type Volume {
  Volume(
    id: Int,
    name: String,
    max_number: Int,
    chapters: List(Chapter),
    pages: Int,
    pages_read: Int,
  )
}

pub fn volume_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use max_number <- decode.field("maxNumber", decode.int)
  use chapters <- decode.field("chapters", decode.list(chapter_decoder()))
  use pages <- decode.field("pages", decode.int)
  use pages_read <- decode.field("pagesRead", decode.int)
  decode.success(Volume(id:, name:, max_number:, chapters:, pages:, pages_read:))
}

pub type Chapter {
  Chapter(
    id: Int,
    title: String,
    sort_order: Float,
    pages: Int,
    pages_read: Int,
  )
}

pub fn chapter_decoder() {
  use id <- decode.field("id", decode.int)
  use title <- decode.field("title", decode.string)
  use sort_order <- decode.field("sortOrder", decode.float)
  use pages <- decode.field("pages", decode.int)
  use pages_read <- decode.field("pagesRead", decode.int)
  decode.success(Chapter(id:, title:, sort_order:, pages:, pages_read:))
}

pub type Metadata {
  Metadata(
    id: Int,
    genres: List(Tag),
    tags: List(Tag),
    summary: String,
    publication_status: Publication,
    series_id: Int,
  )
}

pub type Tag {
  Tag(id: Int, title: String)
}

pub type Info {
  Info(
    id: Int,
    name: String,
    localized_name: String,
    created: date.Date,
    last_chapter_added: date.Date,
    pages: Int,
    pages_read: Int,
  )
}

pub fn info_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use localized_name <- decode.field("localizedName", decode.string)
  use created <- decode.field("created", date_decoder())
  use last_chapter_added <- decode.field("lastChapterAdded", date_decoder())
  use pages <- decode.field("pages", decode.int)
  use pages_read <- decode.field("pagesRead", decode.int)
  decode.success(Info(
    id:,
    name:,
    localized_name:,
    created:,
    last_chapter_added:,
    pages:,
    pages_read:,
  ))
}

pub type MinimalInfo {
  MinimalInfo(id: Int, name: String, localized_name: String, created: date.Date)
}

pub fn date_decoder() {
  decode.new_primitive_decoder("Date", fn(v) {
    use timestamp <- result.try(
      decode.run(v, decode.string)
      |> result.map_error(fn(_) { date.new("May 19 2024") }),
    )
    Ok(date.new(timestamp))
  })
}

pub fn minimal_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use localized_name <- decode.field("localizedName", decode.string)
  use created <- decode.field("created", date_decoder())
  decode.success(MinimalInfo(id:, name:, localized_name:, created:))
}

pub fn recently_updated_decoder() {
  use id <- decode.field("seriesId", decode.int)
  use name <- decode.field("seriesName", decode.string)
  use created <- decode.field("created", date_decoder())
  decode.success(MinimalInfo(id:, name:, localized_name: "", created:))
}

pub type Publication {
  Ongoing
  Hiatus
  Completed
  Cancelled
  Ended
}

pub fn publication_title(publication: Publication) -> String {
  case publication {
    Ongoing -> "ongoing"
    Hiatus -> "hiatus"
    Completed -> "completed"
    Cancelled -> "cancelled"
    Ended -> "ended"
  }
}
