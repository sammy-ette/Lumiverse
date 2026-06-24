import gleam/option
import lumiverse/api/reader
import lumiverse/api/series
import rsvp

pub type Model {
  Model(
    id: Int,
    loading: Bool,
    progress: option.Option(Result(reader.Progress, rsvp.Error)),
    cont_point: option.Option(reader.ContinuePoint),
    next_chapter: option.Option(Int),
    prev_chapter: option.Option(Int),
    chapter_info: option.Option(reader.ChapterInfo),
    pending_chapter_info: option.Option(reader.ChapterInfo),
    image_loaded: Bool,
    show_hint: Bool,
    show_settings: Bool,
    show_menu: Bool,
    settings_section: SettingsSection,
    reading_mode: ReadingMode,
    prefs: ReaderPrefs,
    zen: Bool,
    editing_page: Bool,
    scrubber_hovered: Bool,
    strip_loaded: Int,
  )
}

pub type Direction {
  LTR
  RTL
}

pub type FitMode {
  FitWidth
  FitHeight
  Original
}

pub type ReadingMode {
  PageByPage
  LongStrip
}

pub type ReaderPrefs {
  ReaderPrefs(
    direction: Direction,
    fit_mode: FitMode,
    reading_mode: ReadingMode,
    zoom: Int,
    scroll_speed: Int,
    preload_count: Int,
  )
}

pub type SettingsSection {
  PageLayout
  Header
  Keybinds
}

pub type Msg {
  ID(Int)
  Next
  Previous
  EndStrip
  NavigateRight
  NavigateLeft
  GoToPage(Int)
  EditPage
  ConfirmPageEdit(String)
  ProgressUpdate(Result(Nil, rsvp.Error))
  PreviousChapter(Result(Int, rsvp.Error))
  NextChapter(Result(Int, rsvp.Error))
  ProgressRetrieved(Result(reader.Progress, rsvp.Error))
  ContinuePointRetrieved(Result(reader.ContinuePoint, rsvp.Error))
  ChapterInfoRetrieved(Result(reader.ChapterInfo, rsvp.Error))
  SeriesMetadataRetrieved(Result(series.Metadata, rsvp.Error))
  NextChapterInfoPrefetched(Result(reader.ChapterInfo, rsvp.Error))
  PageLoaded
  DismissHint
  ToggleSettings
  ToggleMenu
  SwitchSection(SettingsSection)
  ToggleZen
  SyncZen(Bool)
  SetDirection(Direction)
  SetFitMode(FitMode)
  SetZoom(Int)
  SetScrollSpeed(Int)
  SetPreloadCount(Int)
  SetReadingMode(ReadingMode)
  ScrollUp
  ScrollDown
  ScrubberHover(Bool)
  LongStripScroll
  Nothing
  Unmount
}
