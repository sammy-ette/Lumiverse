import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import lumiverse/api/account
import lumiverse/api/library
import lumiverse/api/user
import lumiverse/elements/button
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import rsvp

type Model {
  Model(
    users: List(user.User),
    libraries: List(library.Library),
    current_user: option.Option(user.User),
    edited_roles: List(account.Role),
    edited_libraries: List(Int),
    show_menu: option.Option(Int),
    confirm_delete: option.Option(Int),
  )
}

type Msg {
  UsersRetrieved(Result(List(user.User), rsvp.Error))
  LibrariesRetrieved(Result(List(library.Library), rsvp.Error))
  OpenEdit(user.User)
  CloseEdit
  ToggleRole(account.Role)
  ToggleLibrary(Int)
  SubmitEdit
  UserUpdated(Result(Nil, rsvp.Error))
  ShowMenu(option.Option(Int))
  ConfirmDelete(Int)
  CancelDelete
  DeleteUser(Int)
  DeleteResult(Result(Nil, rsvp.Error))
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "settings-users")
}

pub fn element() {
  element.element(
    "settings-users",
    [attribute.class("flex-1 flex flex-col")],
    [],
  )
}

fn init(_) {
  #(
    Model(
      users: [],
      libraries: [],
      current_user: option.None,
      edited_roles: [],
      edited_libraries: [],
      show_menu: option.None,
      confirm_delete: option.None,
    ),
    effect.batch([
      user.all(UsersRetrieved),
      library.all(LibrariesRetrieved),
    ]),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    UsersRetrieved(Ok(users)) -> #(Model(..m, users:), effect.none())
    UsersRetrieved(Error(_)) -> #(m, effect.none())
    LibrariesRetrieved(Ok(libraries)) -> #(
      Model(..m, libraries:),
      effect.none(),
    )
    LibrariesRetrieved(Error(_)) -> #(m, effect.none())
    OpenEdit(u) -> #(
      Model(
        ..m,
        current_user: option.Some(u),
        edited_roles: u.roles,
        edited_libraries: user.library_ids(u),
        show_menu: option.None,
      ),
      effect.none(),
    )
    CloseEdit -> #(Model(..m, current_user: option.None), effect.none())
    ToggleRole(role) -> #(
      Model(..m, edited_roles: case list.contains(m.edited_roles, role) {
        True -> list.filter(m.edited_roles, fn(r) { r != role })
        False -> [role, ..m.edited_roles]
      }),
      effect.none(),
    )
    ToggleLibrary(lib_id) -> #(
      Model(
        ..m,
        edited_libraries: case list.contains(m.edited_libraries, lib_id) {
          True -> list.filter(m.edited_libraries, fn(id) { id != lib_id })
          False -> [lib_id, ..m.edited_libraries]
        },
      ),
      effect.none(),
    )
    SubmitEdit ->
      case m.current_user {
        option.Some(u) -> #(
          m,
          user.update(u, m.edited_roles, m.edited_libraries, UserUpdated),
        )
        option.None -> #(m, effect.none())
      }
    UserUpdated(Ok(_)) -> #(
      Model(..m, current_user: option.None),
      effect.batch([user.all(UsersRetrieved), toast("User updated", "info")]),
    )
    UserUpdated(Error(_)) -> #(m, toast("Failed to update user", "error"))
    ShowMenu(show_menu) -> #(Model(..m, show_menu:), effect.none())
    ConfirmDelete(uid) -> #(
      Model(..m, confirm_delete: option.Some(uid), show_menu: option.None),
      effect.none(),
    )
    CancelDelete -> #(Model(..m, confirm_delete: option.None), effect.none())
    DeleteUser(uid) -> #(
      Model(..m, confirm_delete: option.None),
      user.delete_(uid, DeleteResult),
    )
    DeleteResult(Ok(_)) -> #(
      Model(..m, show_menu: option.None),
      effect.batch([
        user.all(UsersRetrieved),
        toast("User deleted", "info"),
      ]),
    )
    DeleteResult(Error(_)) -> #(m, toast("Failed to delete user", "error"))
  }
}

fn view(m: Model) {
  html.div([attribute.class("space-y-4 h-full w-full")], [
    case m.current_user {
      option.Some(u) -> editor(m, u)
      option.None -> element.none()
    },
    html.div([attribute.class("flex justify-between")], [
      html.h1([attribute.class("text-5xl font-bold")], [element.text("Users")]),
    ]),
    html.table([attribute.class("w-full text-left border-collapse")], [
      html.thead([], [
        html.tr(
          [attribute.class("border-b border-zinc-700 text-zinc-400 text-sm")],
          [
            html.th([attribute.class("py-2 px-4 font-semibold")], [
              element.text("Username"),
            ]),
            html.th([attribute.class("py-2 px-4 font-semibold")], [
              element.text("Email"),
            ]),
            html.th([attribute.class("py-2 px-4 font-semibold")], [
              element.text("Roles"),
            ]),
            html.th([attribute.class("py-2 px-4 font-semibold")], [
              element.text("Libraries"),
            ]),
            html.th([attribute.class("py-2 px-4 font-semibold")], []),
          ],
        ),
      ]),
      html.tbody(
        [],
        list.map(m.users, fn(u) {
          html.tr(
            [
              attribute.class(
                "border-b border-zinc-800 hover:bg-zinc-900 transition",
              ),
            ],
            [
              html.td([attribute.class("py-2 px-4 font-semibold")], [
                element.text(u.username),
              ]),
              html.td([attribute.class("py-2 px-4 text-zinc-400 text-sm")], [
                element.text(u.email),
              ]),
              html.td([attribute.class("py-2 px-4 text-zinc-400 text-sm")], [
                element.text(
                  u.roles
                  |> list.map(account.role_to_string)
                  |> string.join(", "),
                ),
              ]),
              html.td([attribute.class("py-2 px-4 text-zinc-400 text-sm")], [
                element.text(
                  int.to_string(list.length(u.libraries)) <> " library(s)",
                ),
              ]),
              html.td([attribute.class("py-2 px-4 text-sm")], [
                html.div([attribute.class("relative")], [
                  button.icon("ph ph-[dots-three-vertical]", "User options", [
                    attribute.class("p-1"),
                    event.on_click(
                      ShowMenu(case m.show_menu {
                        option.Some(id) if id == u.id -> option.None
                        _ -> option.Some(u.id)
                      }),
                    ),
                  ]),
                  case m.show_menu {
                    option.Some(id) if id == u.id ->
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
                            OpenEdit(u),
                            "text-zinc-200",
                          ),
                          html.div(
                            [attribute.class("border-t border-zinc-700")],
                            [],
                          ),
                          case m.confirm_delete {
                            option.Some(did) if did == u.id ->
                              html.div(
                                [
                                  attribute.class("px-3 py-2 space-y-2 text-sm"),
                                ],
                                [
                                  html.p([attribute.class("text-zinc-300")], [
                                    element.text("Delete this user?"),
                                  ]),
                                  html.div([attribute.class("flex gap-2")], [
                                    button.button("Delete", [
                                      attribute.type_("button"),
                                      button.danger(),
                                      event.on_click(DeleteUser(u.id)),
                                    ]),
                                    button.button("Cancel", [
                                      attribute.type_("button"),
                                      button.secondary(),
                                      event.on_click(CancelDelete),
                                    ]),
                                  ]),
                                ],
                              )
                            _ ->
                              menu_item(
                                "trash",
                                "Delete",
                                ConfirmDelete(u.id),
                                "text-red-400",
                              )
                          },
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

fn editor(m: Model, u: user.User) {
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
            "flex flex-col p-4 gap-4 bg-zinc-800 rounded-md h-[75%] w-[50%]",
          ),
        ],
        [
          html.div([attribute.class("flex justify-between items-center")], [
            html.h1([attribute.class("font-bold text-xl")], [
              element.text(u.username),
            ]),
            button.icon("ph ph-[x] text-2xl", "Close", [event.on_click(CloseEdit)]),
          ]),
          html.div(
            [attribute.class("flex-1 overflow-y-auto flex flex-col gap-6 pr-1")],
            [
              html.div([attribute.class("space-y-2")], [
                html.p(
                  [attribute.class("text-sm font-semibold text-zinc-400")],
                  [
                    element.text("Roles"),
                  ],
                ),
                html.div(
                  [attribute.class("grid grid-cols-2 gap-x-6 gap-y-2")],
                  list.map(account.all_roles(), fn(role) {
                    role_toggle(role, list.contains(m.edited_roles, role))
                  }),
                ),
              ]),
              html.div([attribute.class("space-y-2")], [
                html.p(
                  [attribute.class("text-sm font-semibold text-zinc-400")],
                  [
                    element.text("Libraries"),
                  ],
                ),
                case m.libraries |> list.is_empty {
                  True ->
                    html.p([attribute.class("text-sm text-zinc-500")], [
                      element.text("No libraries available"),
                    ])
                  False ->
                    html.div(
                      [attribute.class("grid grid-cols-2 gap-x-6 gap-y-2")],
                      list.map(m.libraries, fn(lib) {
                        library_toggle(
                          lib,
                          list.contains(m.edited_libraries, lib.id),
                        )
                      }),
                    )
                },
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
              button.button("Cancel", [
                attribute.type_("button"),
                event.on_click(CloseEdit),
              ]),
              button.button("Save", [
                attribute.type_("button"),
                button.primary(),
                attribute.class("font-semibold"),
                event.on_click(SubmitEdit),
              ]),
            ],
          ),
        ],
      ),
    ],
  )
}

fn role_toggle(role: account.Role, checked: Bool) {
  html.label(
    [attribute.class("flex items-center gap-2 cursor-pointer select-none")],
    [
      html.input([
        attribute.type_("checkbox"),
        attribute.checked(checked),
        attribute.class("accent-violet-500 w-4 h-4 cursor-pointer"),
        event.on_check(fn(_) { ToggleRole(role) }),
      ]),
      html.span([attribute.class("text-sm text-zinc-300")], [
        element.text(account.role_to_string(role)),
      ]),
    ],
  )
}

fn library_toggle(lib: library.Library, checked: Bool) {
  html.label(
    [attribute.class("flex items-center gap-2 cursor-pointer select-none")],
    [
      html.input([
        attribute.type_("checkbox"),
        attribute.checked(checked),
        attribute.class("accent-violet-500 w-4 h-4 cursor-pointer"),
        event.on_check(fn(_) { ToggleLibrary(lib.id) }),
      ]),
      html.span([attribute.class("text-sm text-zinc-300")], [
        element.text(lib.name),
      ]),
    ],
  )
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
      html.i([attribute.class("ph ph-[" <> icon <> "] text-base")], []),
      element.text(label),
    ],
  )
}

fn toast(message: String, kind: String) {
  event.emit(
    "toast",
    json.object([
      #("message", json.string(message)),
      #("kind", json.string(kind)),
    ]),
  )
}
