import gleam/dynamic

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
  dynamic.decode2(
    Details,
    dynamic.field("chapters", dynamic.list(chapter_decoder())),
    dynamic.field("volumes", dynamic.list(volume_decoder())),
  )
}

pub type Volume {
  Volume(id: Int, name: String, max_number: Int, chapters: List(Chapter))
}

pub fn volume_decoder() {
  dynamic.decode4(
    Volume,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("maxNumber", dynamic.int),
    dynamic.field("chapters", dynamic.list(chapter_decoder())),
  )
}

pub type Chapter {
  Chapter(id: Int, title: String, sort_order: Float)
}

pub fn chapter_decoder() {
  dynamic.decode3(
    Chapter,
    dynamic.field("id", dynamic.int),
    dynamic.field("title", dynamic.string),
    dynamic.field("sortOrder", dynamic.float),
  )
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
  dynamic.decode3(
    MinimalInfo,
    dynamic.field("id", dynamic.int),
    dynamic.field("name", dynamic.string),
    dynamic.field("localizedName", dynamic.string),
  )
}

pub fn recently_updated_decoder() {
  dynamic.decode3(
    MinimalInfo,
    dynamic.field("seriesId", dynamic.int),
    dynamic.field("seriesName", dynamic.string),
    fn(_) { Ok("") },
  )
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
