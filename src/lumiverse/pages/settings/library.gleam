import gleam/int
import gleam/list
import gleam/option
import lumiverse/api/library
import lumiverse/elements/button
import lumiverse/elements/input
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import rsvp

type CurrentLibrary {
  CurrentLibrary(library: library.LibraryCreate, task: EditorTask)
}

type EditorTask {
  Edit
  Create
}

fn default_new_library() {
  library.LibraryCreate(
    id: -1,
    name: "",
    type_: library.Manga,
    folders: [],
    exclude_patterns: [],
    file_group_types: [
      library.Archive,
      library.EPUB,
      library.PDF,
      library.Image,
    ],
    config: library.LibraryConfig(
      folder_watching: True,
      include_in_dashboard: True,
      include_in_recommended: True,
      include_in_search: True,
      manage_collections: True,
      manage_reading_lists: True,
      allow_scrobbling: True,
      allow_metadata_matching: True,
      collapse_series_relationships: False,
      enable_metadata: True,
      remove_prefix_for_sort_name: False,
      inherit_web_links_from_first_chapter: False,
      default_language: "",
    ),
  )
}

type Model {
  Model(
    libraries: List(library.Library),
    show_creator: Bool,
    paths: List(library.Path),
    current_library: option.Option(CurrentLibrary),
    folder_input: String,
    exclude_input: String,
    show_menu: option.Option(Int),
  )
}

type Msg {
  LibrariesRetrieved(Result(List(library.Library), rsvp.Error))
  ShowCreator(option.Option(CurrentLibrary))
  FolderInput(String)
  MediaPaths(Result(List(library.Path), rsvp.Error))
  SelectPath(String)
  AddFolder
  RemoveFolder(String)
  SetExcludeInput(String)
  AddExcludePattern
  RemoveExcludePattern(String)
  UpdateNewLibrary(fn(CurrentLibrary) -> CurrentLibrary)
  ShowMenu(option.Option(Int))
  SubmitCreate
  SubmitEdit
  LibraryCreated(Result(Nil, rsvp.Error))
  LibraryUpdated(Result(Nil, rsvp.Error))
  ScanLibrary(Int)
  ScanLibraryResult(Result(Nil, rsvp.Error))
  DeleteLibrary(Int)
  DeleteLibraryResult(Result(Nil, rsvp.Error))
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "settings-library")
}

pub fn element() {
  element.element(
    "settings-library",
    [attribute.class("flex-1 flex flex-col")],
    [],
  )
}

fn init(_) {
  #(
    Model(
      libraries: [],
      show_creator: False,
      paths: [],
      current_library: option.None,
      folder_input: "",
      exclude_input: "",
      show_menu: option.None,
    ),
    library.all(LibrariesRetrieved),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    LibrariesRetrieved(Ok(libraries)) -> #(
      Model(..m, libraries:),
      effect.none(),
    )
    LibrariesRetrieved(Error(e)) -> {
      echo e
      #(m, effect.none())
    }
    ShowCreator(current_library) -> #(
      Model(
        ..m,
        show_creator: option.is_some(current_library),
        current_library:,
        show_menu: option.None,
        folder_input: "",
        exclude_input: "",
        paths: [],
      ),
      effect.none(),
    )
    FolderInput(str) -> #(
      Model(..m, folder_input: str),
      library.list_paths(str, MediaPaths),
    )
    MediaPaths(Ok(paths)) -> #(Model(..m, paths:), effect.none())
    SelectPath(full) -> #(
      Model(..m, folder_input: full <> "/", paths: []),
      effect.none(),
    )
    AddFolder -> {
      case m.folder_input {
        "" -> #(m, effect.none())
        path -> #(
          Model(
            ..m,
            folder_input: "",
            paths: [],
            current_library: option.map(m.current_library, fn(cl) {
              CurrentLibrary(
                library: library.LibraryCreate(
                  ..cl.library,
                  folders: list.append(cl.library.folders, [path]),
                ),
                task: cl.task,
              )
            }),
          ),
          effect.none(),
        )
      }
    }
    RemoveFolder(path) -> #(
      Model(
        ..m,
        current_library: option.map(m.current_library, fn(cl) {
          CurrentLibrary(
            ..cl,
            library: library.LibraryCreate(
              ..cl.library,
              folders: list.filter(cl.library.folders, fn(f) { f != path }),
            ),
          )
        }),
      ),
      effect.none(),
    )
    SetExcludeInput(str) -> #(Model(..m, exclude_input: str), effect.none())
    AddExcludePattern -> {
      case m.exclude_input {
        "" -> #(m, effect.none())
        pattern -> #(
          Model(
            ..m,
            exclude_input: "",
            current_library: option.map(m.current_library, fn(cl) {
              CurrentLibrary(
                ..cl,
                library: library.LibraryCreate(
                  ..cl.library,
                  exclude_patterns: list.append(cl.library.exclude_patterns, [
                    pattern,
                  ]),
                ),
              )
            }),
          ),
          effect.none(),
        )
      }
    }
    RemoveExcludePattern(pattern) -> #(
      Model(
        ..m,
        current_library: option.map(m.current_library, fn(cl) {
          CurrentLibrary(
            ..cl,
            library: library.LibraryCreate(
              ..cl.library,
              exclude_patterns: list.filter(cl.library.exclude_patterns, fn(p) {
                p != pattern
              }),
            ),
          )
        }),
      ),
      effect.none(),
    )
    UpdateNewLibrary(f) -> #(
      Model(..m, current_library: option.map(m.current_library, f)),
      effect.none(),
    )
    ShowMenu(show_menu) -> #(Model(..m, show_menu:), effect.none())
    SubmitCreate ->
      case m.current_library {
        option.Some(cl) -> #(m, library.create(cl.library, LibraryCreated))
        option.None -> #(m, effect.none())
      }
    SubmitEdit ->
      case m.current_library {
        option.Some(cl) -> #(m, library.update(cl.library, LibraryUpdated))
        option.None -> #(m, effect.none())
      }
    LibraryCreated(Ok(_)) -> #(
      Model(..m, show_creator: False, current_library: option.None),
      library.all(LibrariesRetrieved),
    )
    LibraryUpdated(Ok(_)) -> #(
      Model(..m, show_creator: False, current_library: option.None),
      library.all(LibrariesRetrieved),
    )
    // TODO: Show notifs for scan/delete for UX
    ScanLibrary(lib_id) -> #(
      m,
      library.scan(lib_id, fn(_) { ShowMenu(option.None) }),
    )
    // TODO: Add confirmation dialog before delete
    DeleteLibrary(lib_id) -> #(
      m,
      library.delete(lib_id, fn(_) { ShowMenu(option.None) }),
    )
    DeleteLibraryResult(Ok(_)) -> #(
      Model(..m, show_menu: option.None),
      library.all(LibrariesRetrieved),
    )
    _ -> #(m, effect.none())
  }
}

fn view(m: Model) {
  html.div([attribute.class("space-y-4 h-full w-full")], [
    case m.show_creator {
      True -> creator(m)
      False -> element.none()
    },
    html.div([attribute.class("flex justify-between")], [
      html.h1([attribute.class("text-5xl font-bold")], [
        element.text("Libraries"),
      ]),
      button.button(
        [
          button.lg(),
          button.bg(button.Primary),
          attribute.class("font-bold"),
          event.on_click(
            ShowCreator(
              option.Some(CurrentLibrary(default_new_library(), Create)),
            ),
          ),
        ],
        [
          html.i([attribute.class("ph-bold ph-stack-plus text-xl")], []),
          element.text("Add Library"),
        ],
      ),
    ]),
    html.table([attribute.class("w-full text-left border-collapse")], [
      html.thead([], [
        html.tr(
          [attribute.class("border-b border-zinc-700 text-zinc-400 text-sm")],
          [
            html.th([attribute.class("py-2 px-4 font-semibold")], [
              element.text("Name"),
            ]),
            html.th([attribute.class("py-2 px-4 font-semibold")], [
              element.text("Type"),
            ]),
            html.th([attribute.class("py-2 px-4 font-semibold")], [
              element.text("Folders"),
            ]),
            html.th([attribute.class("py-2 px-4 font-semibold")], [
              element.text("Metadata"),
            ]),
            html.th([attribute.class("py-2 px-4 font-semibold")], [
              element.text("Folder Watching"),
            ]),
            html.th([attribute.class("py-2 px-4 font-semibold")], []),
          ],
        ),
      ]),
      html.tbody(
        [],
        list.map(m.libraries, fn(lib) {
          html.tr(
            [
              attribute.class(
                "border-b border-zinc-800 hover:bg-zinc-900 transition",
              ),
            ],
            [
              html.td([attribute.class("py-2 px-4 font-semibold")], [
                element.text(lib.name),
              ]),
              html.td([attribute.class("py-2 px-4 text-zinc-400 text-sm")], [
                element.text(case lib.type_ {
                  library.Manga -> "Manga"
                  library.Unknown(n) -> "Unknown (" <> int.to_string(n) <> ")"
                  library.Invalid -> "Invalid"
                }),
              ]),
              html.td([attribute.class("py-2 px-4 text-zinc-400 text-sm")], [
                element.text(
                  int.to_string(list.length(lib.folders)) <> " folder(s)",
                ),
              ]),
              html.td([attribute.class("py-2 px-4 text-sm")], [
                html.span(
                  [
                    attribute.class(case lib.config.enable_metadata {
                      True -> "text-green-400"
                      False -> "text-zinc-500"
                    }),
                  ],
                  [
                    element.text(case lib.config.enable_metadata {
                      True -> "Enabled"
                      False -> "Disabled"
                    }),
                  ],
                ),
              ]),
              html.td([attribute.class("py-2 px-4 text-sm")], [
                html.span(
                  [
                    attribute.class(case lib.config.folder_watching {
                      True -> "text-green-400"
                      False -> "text-zinc-500"
                    }),
                  ],
                  [
                    element.text(case lib.config.folder_watching {
                      True -> "On"
                      False -> "Off"
                    }),
                  ],
                ),
              ]),
              html.td([attribute.class("py-2 px-4 text-sm")], [
                html.div([attribute.class("relative")], [
                  button.icon(
                    [
                      attribute.class("p-1"),
                      event.on_click(
                        ShowMenu(case m.show_menu {
                          option.Some(id) if id == lib.id -> option.None
                          _ -> option.Some(lib.id)
                        }),
                      ),
                    ],
                    "dots-three-vertical",
                  ),
                  case m.show_menu {
                    option.Some(id) if id == lib.id ->
                      html.div(
                        [
                          attribute.class(
                            "absolute right-0 top-full z-20 mt-1 w-44 bg-zinc-800 border border-zinc-700 rounded-md shadow-lg overflow-hidden",
                          ),
                        ],
                        [
                          menu_item(
                            "pencil",
                            "Edit",
                            ShowCreator(
                              option.Some(CurrentLibrary(
                                lib |> library.to_create,
                                Edit,
                              )),
                            ),
                            "text-zinc-200",
                          ),
                          menu_item(
                            "arrow-clockwise",
                            "Scan Library",
                            ScanLibrary(lib.id),
                            "text-zinc-200",
                          ),
                          html.div(
                            [attribute.class("border-t border-zinc-700")],
                            [],
                          ),
                          menu_item(
                            "trash",
                            "Delete",
                            DeleteLibrary(lib.id),
                            "text-red-400",
                          ),
                        ],
                      )
                    _ -> element.none()
                  },
                ]),
              ]),
            ],
          )
        }),
      ),
    ]),
  ])
}

fn menu_item(icon: String, label: String, msg: Msg, color: String) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class(
        "w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-zinc-700 transition "
        <> color,
      ),
      event.on_click(msg),
    ],
    [
      html.i([attribute.class("ph ph-" <> icon <> " text-base")], []),
      element.text(label),
    ],
  )
}

fn toggle_option(label: String, checked: Bool, on_toggle: fn(Bool) -> Msg) {
  html.label(
    [attribute.class("flex items-center gap-2 cursor-pointer select-none")],
    [
      html.input([
        attribute.type_("checkbox"),
        attribute.checked(checked),
        attribute.class("accent-violet-500 w-4 h-4 cursor-pointer"),
        event.on_check(on_toggle),
      ]),
      html.span([attribute.class("text-sm text-zinc-300")], [
        element.text(label),
      ]),
    ],
  )
}

fn file_type_toggle(
  nl: library.LibraryCreate,
  ft: library.LibraryFileType,
  label: String,
) {
  let enabled = list.contains(nl.file_group_types, ft)
  html.label(
    [attribute.class("flex items-center gap-2 cursor-pointer select-none")],
    [
      html.input([
        attribute.type_("checkbox"),
        attribute.checked(enabled),
        attribute.class("sr-only peer"),
        event.on_check(fn(v) {
          UpdateNewLibrary(fn(c) {
            CurrentLibrary(
              ..c,
              library: library.LibraryCreate(
                ..c.library,
                file_group_types: case v {
                  True -> list.append(c.library.file_group_types, [ft])
                  False ->
                    list.filter(c.library.file_group_types, fn(t) { t != ft })
                },
              ),
            )
          })
        }),
      ]),
      html.div(
        [
          attribute.class(
            "relative w-9 h-5 rounded-full transition-colors"
            <> " bg-zinc-600 peer-checked:bg-violet-500"
            <> " after:content-[''] after:absolute after:top-0.5 after:left-0.5"
            <> " after:bg-white after:rounded-full after:w-4 after:h-4 after:transition-all"
            <> " peer-checked:after:translate-x-4",
          ),
        ],
        [],
      ),
      html.span([attribute.class("text-sm text-zinc-300")], [
        element.text(label),
      ]),
    ],
  )
}

fn creator(m: Model) {
  let assert option.Some(cl) = m.current_library
  let nl = cl.library
  html.div(
    [
      attribute.class(
        "bg-zinc-950/75 z-100 absolute inset-0 flex justify-center items-center",
      ),
    ],
    [
      html.div(
        [
          attribute.class(
            "flex flex-col p-4 gap-4 bg-zinc-800 rounded-md h-[85%] w-[65%]",
          ),
        ],
        [
          html.div([attribute.class("flex justify-between items-center")], [
            html.h1([attribute.class("font-bold text-xl")], [
              element.text("Add Library"),
            ]),
            button.button([event.on_click(ShowCreator(option.None))], [
              html.i([attribute.class("ph ph-x text-2xl")], []),
            ]),
          ]),
          html.div(
            [attribute.class("flex-1 overflow-y-auto flex flex-col gap-4 pr-1")],
            [
              html.div([attribute.class("flex gap-4")], [
                html.div([attribute.class("flex-1 space-y-2")], [
                  input.label("Name"),
                  input.input([
                    attribute.class("w-full"),
                    attribute.value(nl.name),
                    event.on_input(fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(..c.library, name: v),
                        )
                      })
                    }),
                  ]),
                ]),
                html.div([attribute.class("space-y-2")], [
                  input.label("Type"),
                  html.select(
                    [
                      attribute.class(
                        "bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none",
                      ),
                      event.on_input(fn(v) {
                        UpdateNewLibrary(fn(c) {
                          CurrentLibrary(
                            ..c,
                            library: library.LibraryCreate(
                              ..c.library,
                              type_: case v {
                                "0" -> library.Manga
                                _ -> library.Manga
                              },
                            ),
                          )
                        })
                      }),
                    ],
                    [html.option([attribute.value("0")], "Manga")],
                  ),
                ]),
                html.div([attribute.class("space-y-2")], [
                  input.label("Default Language"),
                  input.input([
                    attribute.class("w-32"),
                    attribute.placeholder("e.g. en"),
                    attribute.value(nl.config.default_language),
                    event.on_input(fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              default_language: v,
                            ),
                          ),
                        )
                      })
                    }),
                  ]),
                ]),
              ]),
              html.div([attribute.class("space-y-2")], [
                input.label("Media Folders"),
                html.div([attribute.class("flex gap-2")], [
                  html.div([attribute.class("relative flex-1")], [
                    input.input([
                      attribute.class("w-full"),
                      attribute.value(m.folder_input),
                      case m.paths |> list.is_empty {
                        False -> attribute.class("rounded-b-none")
                        True -> attribute.none()
                      },
                      event.on_input(FolderInput),
                    ]),
                    case m.paths |> list.is_empty {
                      True -> element.none()
                      False ->
                        html.div(
                          [
                            attribute.class(
                              "absolute top-full left-0 right-0 z-10 bg-zinc-700 rounded-b-md overflow-hidden max-h-48 overflow-y-auto",
                            ),
                          ],
                          list.map(m.paths, fn(p) {
                            html.button(
                              [
                                attribute.type_("button"),
                                attribute.class(
                                  "w-full text-left px-3 py-1.5 hover:bg-zinc-600 text-sm text-zinc-200",
                                ),
                                event.on_click(SelectPath(p.full)),
                              ],
                              [element.text(p.basename)],
                            )
                          }),
                        )
                    },
                  ]),
                  button.button(
                    [
                      attribute.type_("button"),
                      button.bg(button.Primary),
                      button.sm(),
                      event.on_click(AddFolder),
                    ],
                    [element.text("Add Folder")],
                  ),
                ]),
                case nl.folders |> list.is_empty {
                  True -> element.none()
                  False ->
                    html.div(
                      [attribute.class("flex flex-col gap-1 mt-1")],
                      list.map(nl.folders, fn(f) {
                        html.div(
                          [
                            attribute.class(
                              "flex items-center justify-between bg-zinc-700 rounded px-3 py-1 text-sm",
                            ),
                          ],
                          [
                            html.span([attribute.class("text-zinc-200")], [
                              element.text(f),
                            ]),
                            button.button(
                              [
                                attribute.type_("button"),
                                event.on_click(RemoveFolder(f)),
                              ],
                              [
                                html.i(
                                  [attribute.class("ph ph-x text-zinc-400")],
                                  [],
                                ),
                              ],
                            ),
                          ],
                        )
                      }),
                    )
                },
              ]),
              html.div([attribute.class("space-y-2")], [
                input.label("Exclude Patterns"),
                html.div([attribute.class("flex gap-2")], [
                  input.input([
                    attribute.class("flex-1"),
                    attribute.placeholder("e.g. *.cbz"),
                    attribute.value(m.exclude_input),
                    event.on_input(SetExcludeInput),
                  ]),
                  button.button(
                    [
                      attribute.type_("button"),
                      button.bg(button.Primary),
                      button.sm(),
                      event.on_click(AddExcludePattern),
                    ],
                    [element.text("Add Pattern")],
                  ),
                ]),
                case nl.exclude_patterns |> list.is_empty {
                  True -> element.none()
                  False ->
                    html.div(
                      [attribute.class("flex flex-wrap gap-1 mt-1")],
                      list.map(nl.exclude_patterns, fn(p) {
                        html.div(
                          [
                            attribute.class(
                              "flex items-center gap-1 bg-zinc-700 rounded px-2 py-0.5 text-sm",
                            ),
                          ],
                          [
                            html.span([attribute.class("text-zinc-200")], [
                              element.text(p),
                            ]),
                            button.button(
                              [
                                attribute.type_("button"),
                                event.on_click(RemoveExcludePattern(p)),
                              ],
                              [
                                html.i(
                                  [
                                    attribute.class(
                                      "ph ph-x text-zinc-400 text-xs",
                                    ),
                                  ],
                                  [],
                                ),
                              ],
                            ),
                          ],
                        )
                      }),
                    )
                },
              ]),
              html.div([attribute.class("space-y-2")], [
                input.label("File Types"),
                html.div([attribute.class("flex flex-wrap gap-3")], [
                  file_type_toggle(nl, library.Archive, "Archive"),
                  file_type_toggle(nl, library.EPUB, "EPUB"),
                  file_type_toggle(nl, library.PDF, "PDF"),
                  file_type_toggle(nl, library.Image, "Image"),
                ]),
              ]),
              html.div([attribute.class("space-y-2")], [
                input.label("Options"),
                html.div([attribute.class("grid grid-cols-2 gap-x-6 gap-y-2")], [
                  toggle_option(
                    "Folder Watching",
                    nl.config.folder_watching,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              folder_watching: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Include in Dashboard",
                    nl.config.include_in_dashboard,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              include_in_dashboard: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Include in Recommended",
                    nl.config.include_in_recommended,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              include_in_recommended: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Include in Search",
                    nl.config.include_in_search,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              include_in_search: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Manage Collections",
                    nl.config.manage_collections,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              manage_collections: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Manage Reading Lists",
                    nl.config.manage_reading_lists,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              manage_reading_lists: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Allow Scrobbling",
                    nl.config.allow_scrobbling,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              allow_scrobbling: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Allow Metadata Matching",
                    nl.config.allow_metadata_matching,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              allow_metadata_matching: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Enable Metadata",
                    nl.config.enable_metadata,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              enable_metadata: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Collapse Series Relationships",
                    nl.config.collapse_series_relationships,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              collapse_series_relationships: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Remove Prefix for Sort Name",
                    nl.config.remove_prefix_for_sort_name,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              remove_prefix_for_sort_name: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                  toggle_option(
                    "Inherit Web Links from First Chapter",
                    nl.config.inherit_web_links_from_first_chapter,
                    fn(v) {
                      UpdateNewLibrary(fn(c) {
                        CurrentLibrary(
                          ..c,
                          library: library.LibraryCreate(
                            ..c.library,
                            config: library.LibraryConfig(
                              ..c.library.config,
                              inherit_web_links_from_first_chapter: v,
                            ),
                          ),
                        )
                      })
                    },
                  ),
                ]),
              ]),
            ],
          ),
          html.div(
            [
              attribute.class(
                "flex justify-end gap-2 pt-2 border-t border-zinc-700",
              ),
            ],
            [
              button.button(
                [
                  attribute.type_("button"),
                  button.md(),
                  event.on_click(ShowCreator(option.None)),
                ],
                [element.text("Cancel")],
              ),
              button.button(
                [
                  attribute.type_("button"),
                  button.md(),
                  button.bg(button.Primary),
                  attribute.class("font-semibold"),
                  event.on_click(case m.current_library {
                    option.Some(CurrentLibrary(_, Create)) -> SubmitCreate
                    option.Some(CurrentLibrary(_, Edit)) -> SubmitEdit
                    option.None -> SubmitCreate
                  }),
                ],
                [
                  case m.current_library {
                    option.Some(CurrentLibrary(_, Create)) ->
                      element.text("Create")
                    option.Some(CurrentLibrary(_, Edit)) -> element.text("Save")
                    option.None -> element.text("Submit")
                  },
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  )
}
