import formal/form
import gleam/option
import lumiverse/api/reader
import lumiverse/api/series
import rsvp

pub type Tab {
  StorylineTab
  VolumesTab
  ChaptersTab
}

pub type StorylineItem {
  StorylineVolume(vol: series.Volume, sort_key: Float)
  StorylineChapter(chp: series.Chapter)
}

pub type EditorSection {
  BasicInfoSection
  TagsSection
  DetailsSection
}

pub type BasicInfoEdit {
  BasicInfoEdit(series_name: String, localized_name: String)
}

pub type DetailsEdit {
  DetailsEdit(summary: String)
}

pub type Model {
  Model(
    id: Int,
    series: option.Option(Result(series.Series, rsvp.Error)),
    details: option.Option(series.Details),
    time_left: option.Option(series.Time),
    admin: Bool,
    sort_ascending: Bool,
    active_tab: Tab,
    loading_reader: Bool,
    // editor state
    show_editor: Bool,
    editor_section: EditorSection,
    new_tag_input: String,
    new_genre_input: String,
    basic_form: form.Form(BasicInfoEdit),
    details_form: form.Form(DetailsEdit),
  )
}

pub type Msg {
  SeriesID(Int)
  SeriesRetrieved(Result(series.Series, rsvp.Error))
  MetadataRetrieved(Result(series.Metadata, rsvp.Error))
  DetailsRetrieved(Result(series.Details, rsvp.Error))
  ContinuePointRetrieved(Result(reader.ContinuePoint, rsvp.Error))
  TagsRetrieved(String, Result(List(series.Tag), rsvp.Error))
  GenresRetrieved(String, Result(List(series.Tag), rsvp.Error))
  TimeLeftRetrieved(Result(series.Time, rsvp.Error))
  MetadataUpdated(Result(Nil, rsvp.Error))
  Read
  Admin(Bool)
  ToggleSort
  ReadChapter(Int)
  ReadVolume(series.Volume)
  SetTab(Tab)
  // editor msgs
  ShowEditor(Bool)
  SwitchEditorSection(EditorSection)
  UpdateNewTagInput(String)
  SubmitNewTag
  RemoveTag(Int)
  UpdateNewGenreInput(String)
  SubmitNewGenre
  RemoveGenre(Int)
  BasicInfoSubmitted(Result(BasicInfoEdit, form.Form(BasicInfoEdit)))
  DetailsSubmitted(Result(DetailsEdit, form.Form(DetailsEdit)))
}
