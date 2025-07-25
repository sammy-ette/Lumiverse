import gleam/dynamic
import gleam/dynamic/decode

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
  Details(chapters: List(Chapter), volumes: List(Volume))
}

pub fn details_decoder() {
  use chapters <- decode.field("chapters", decode.list(chapter_decoder()))
  use volumes <- decode.field("volumes", decode.list(volume_decoder()))
  decode.success(Details(chapters:, volumes:))
}

pub type Volume {
  Volume(id: Int, name: String, max_number: Int, chapters: List(Chapter))
}

pub fn volume_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use max_number <- decode.field("maxNumber", decode.int)
  use chapters <- decode.field("chapters", decode.list(chapter_decoder()))
  decode.success(Volume(id:, name:, max_number:, chapters:))
}

pub type Chapter {
  Chapter(id: Int, title: String, sort_order: Float)
}

pub fn chapter_decoder() {
  use id <- decode.field("id", decode.int)
  use title <- decode.field("title", decode.string)
  use sort_order <- decode.field("sortOrder", decode.float)
  decode.success(Chapter(id:, title:, sort_order:))
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

pub type MinimalInfo {
  MinimalInfo(id: Int, name: String, localized_name: String)
}

pub fn minimal_decoder() {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use localized_name <- decode.field("localizedName", decode.string)
  decode.success(MinimalInfo(id:, name:, localized_name:))
}

pub fn recently_updated_decoder() {
  use id <- decode.field("seriesId", decode.int)
  use name <- decode.field("seriesName", decode.string)
  decode.success(MinimalInfo(id:, name:, localized_name: ""))
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
