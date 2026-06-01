import formal/form
import gleam/int
import gleam/json
import gleam/option
import lumiverse/api/account
import lumiverse/api/auth_key
import lumiverse/elements/button
import lumiverse/elements/input
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import rsvp

type AuthKeyForm {
  AuthKeyForm(name: String, key_length: Int)
}

fn auth_key_form() {
  form.new({
    use name <- form.field("name", form.parse_string)
    use key_length <- form.field("key_length", form.parse_int)
    form.success(AuthKeyForm(name:, key_length:))
  })
}

type Model {
  Model(
    key_length: Int,
    form: form.Form(AuthKeyForm),
    created_key: option.Option(account.AuthKey),
  )
}

type Msg {
  SetKeyLength(Int)
  FormSubmitted(Result(AuthKeyForm, form.Form(AuthKeyForm)))
  KeyCreated(Result(account.AuthKey, rsvp.Error))
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "settings-auth-keys")
}

pub fn element() {
  element.element(
    "settings-auth-keys",
    [attribute.class("flex-1 flex flex-col")],
    [],
  )
}

fn init(_) {
  #(
    Model(key_length: 16, form: auth_key_form(), created_key: option.None),
    effect.none(),
  )
}

fn update(m: Model, msg: Msg) {
  case msg {
    SetKeyLength(n) -> #(Model(..m, key_length: n), effect.none())
    FormSubmitted(Ok(f)) -> #(
      m,
      auth_key.create_auth_key(f.name, f.key_length, KeyCreated),
    )
    FormSubmitted(Error(f)) -> #(Model(..m, form: f), effect.none())
    KeyCreated(Ok(k)) -> #(
      Model(..m, created_key: option.Some(k)),
      toast("Auth key created", "info"),
    )
    KeyCreated(Error(_)) -> #(m, toast("Failed to create auth key", "error"))
  }
}

fn view(m: Model) {
  let submit = fn(fields) {
    auth_key_form()
    |> form.add_values(fields)
    |> form.run
    |> FormSubmitted
  }

  html.div([attribute.class("space-y-6 h-full w-full overflow-y-auto pr-2")], [
    html.h1([attribute.class("text-5xl font-bold")], [element.text("Auth Keys")]),
    html.form([attribute.class("space-y-8"), event.on_submit(submit)], [
      section("Create Auth Key", [
        input.input_with_name("Name", [attribute.class("w-full max-w-sm")]),
        html.div([attribute.class("space-y-2")], [
          html.div(
            [attribute.class("flex items-center justify-between text-sm")],
            [
              input.label("Key Length"),
              html.span(
                [attribute.class("text-zinc-200 font-mono w-8 text-right")],
                [element.text(int.to_string(m.key_length))],
              ),
            ],
          ),
          html.input([
            attribute.type_("range"),
            attribute.name("key_length"),
            attribute.attribute("min", "8"),
            attribute.attribute("max", "32"),
            attribute.attribute("step", "1"),
            attribute.value(int.to_string(m.key_length)),
            attribute.class("w-full accent-violet-500 cursor-pointer"),
            event.on_input(fn(v) {
              case int.parse(v) {
                Ok(n) -> SetKeyLength(n)
                Error(_) -> SetKeyLength(m.key_length)
              }
            }),
          ]),
          html.div(
            [attribute.class("flex justify-between text-xs text-zinc-500")],
            [
              html.span([], [element.text("8")]),
              html.span([], [element.text("32")]),
            ],
          ),
        ]),
        button.button("Create", [button.primary(), attribute.type_("submit")]),
      ]),
      case m.created_key {
        option.None -> element.none()
        option.Some(k) ->
          section("Generated Key", [
            html.p([attribute.class("text-sm text-zinc-400")], [
              element.text("Copy this key now — it will not be shown again."),
            ]),
            html.div(
              [
                attribute.class(
                  "bg-zinc-800 rounded-md p-3 font-mono text-sm text-zinc-200 break-all select-all",
                ),
              ],
              [element.text(k.key)],
            ),
          ])
      },
    ]),
  ])
}

fn section(title: String, children: List(element.Element(Msg))) {
  html.div([attribute.class("space-y-4")], [
    html.h2(
      [
        attribute.class(
          "text-xl font-semibold text-zinc-200 border-b border-zinc-700 pb-2",
        ),
      ],
      [element.text(title)],
    ),
    html.div([attribute.class("space-y-4")], children),
  ])
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
