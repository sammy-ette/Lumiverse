import formal/form
import gleam/json
import gleam/list
import gleam/uri
import localstorage
import lumiverse/api/account
import lumiverse/elements/button
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import modem
import rsvp

type Register {
  Register(username: String, email: String, password: String)
}

type Model {
  Model(form: form.Form(Register))
}

type Msg {
  RegisterSubmitted(Result(Register, form.Form(Register)))
  RegisterResponse(Result(account.Account, rsvp.Error))
}

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "setup-page")
}

pub fn element() {
  element.element(
    "setup-page",
    [
      attribute.class(
        "w-screen h-screen flex flex-col justify-center items-center",
      ),
    ],
    [],
  )
}

fn register_form() {
  form.new({
    use username <- form.field(
      "username",
      form.parse_string |> form.check_not_empty,
    )
    use email <- form.field("email", form.parse_email)
    use password <- form.field(
      "password",
      form.parse_string
        |> form.check_not_empty
        |> form.check_string_length_more_than(6),
    )

    form.success(Register(username:, email:, password:))
  })
}

fn init(_) {
  #(Model(form: register_form()), effect.none())
}

fn update(m: Model, msg: Msg) {
  case msg {
    RegisterSubmitted(Ok(register)) -> #(
      m,
      account.register(
        register.username,
        register.email,
        register.password,
        RegisterResponse,
      ),
    )
    RegisterSubmitted(Error(form)) -> #(Model(form:), effect.none())
    RegisterResponse(Ok(user_account)) -> {
      localstorage.write(
        "user",
        account.account_to_json(user_account)
          |> json.to_string,
      )
      #(m, {
        let assert Ok(url) = uri.parse("/")
        modem.load(url)
      })
    }
    RegisterResponse(Error(e)) -> {
      case echo e {
        rsvp.HttpError(_) -> {
          let form =
            m.form
            |> form.add_error(
              "register_error",
              form.CustomError("Invalid username or password."),
            )
          #(Model(form:), effect.none())
        }
        _ -> #(m, effect.none())
      }
    }
  }
}

fn view(m: Model) {
  let submit = fn(fields) {
    register_form()
    |> form.add_values(fields)
    |> form.run
    |> RegisterSubmitted
  }

  container([
    html.h2([attribute.class("font-bold text-2xl text-center")], [
      element.text("Log In"),
    ]),
    html.small(
      [attribute.class("text-red-400 block")],
      list.map(
        form.field_error_messages(m.form, "register_error"),
        element.text,
      ),
    ),
    html.div([attribute.class("space-y-4")], [
      html.form(
        [
          attribute.class("flex flex-col gap-4"),
          event.on_submit(submit),
        ],
        [
          html.div([attribute.class("space-y-1")], [
            html.label(
              [
                attribute.for("username"),
                attribute.class("block text-sm text-zinc-300"),
              ],
              [
                element.text("Username"),
              ],
            ),
            html.input([
              attribute.class(
                "bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none border-b-5 border-zinc-700 focus:border-violet-600",
              ),
              attribute.name("username"),
              attribute.autocomplete("username"),
            ]),
            html.small(
              [attribute.class("text-red-400 block")],
              list.map(
                form.field_error_messages(m.form, "username"),
                element.text,
              ),
            ),
          ]),
          html.div([attribute.class("space-y-1")], [
            html.label(
              [
                attribute.for("email"),
                attribute.class("block text-sm text-zinc-300"),
              ],
              [
                element.text("Email"),
              ],
            ),
            html.input([
              attribute.class(
                "bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none border-b-5 border-zinc-700 focus:border-violet-600",
              ),
              attribute.name("email"),
              attribute.autocomplete("email"),
            ]),
            html.small(
              [attribute.class("text-red-400 block")],
              list.map(form.field_error_messages(m.form, "email"), element.text),
            ),
          ]),
          html.div([attribute.class("space-y-1")], [
            html.label(
              [
                attribute.for("password"),
                attribute.class("block text-sm text-zinc-300"),
              ],
              [
                element.text("Password"),
              ],
            ),
            html.input([
              attribute.class(
                "bg-zinc-700 rounded-md p-1 text-zinc-200 outline-none border-b-5 border-zinc-700 focus:border-violet-600",
              ),
              attribute.name("password"),
              attribute.type_("password"),
              attribute.autocomplete("current-password"),
            ]),
            html.small(
              [attribute.class("text-red-400 block")],
              list.map(
                form.field_error_messages(m.form, "password"),
                element.text,
              ),
            ),
          ]),
          button.button(
            [button.bg(button.Primary), button.md(), attribute.class("w-full")],
            [
              element.text("Register"),
            ],
          ),
        ],
      ),
    ]),
  ])
}

fn container(contents: List(element.Element(a))) -> element.Element(a) {
  html.main(
    [
      attribute.class(
        "flex-1 flex flex-col justify-center items-center h-screen",
      ),
    ],
    [
      html.div(
        [attribute.class("flex items-center justify-center space-x-2 mb-8")],
        [
          //   html.img([attribute.src(config.logo()), attribute.class("h-12")]),
          html.span(
            [
              attribute.class(
                "self-center font-['Poppins'] text-3xl md:text-5xl font-bold dark:text-white",
              ),
            ],
            [element.text("Lumiverse")],
          ),
        ],
      ),
      html.div(
        [
          attribute.class(
            "rounded-md bg-zinc-900 border-t-5 border-violet-500 md:px-9 md:py-6 p-4 space-y-4",
          ),
        ],
        contents,
      ),
    ],
  )
}
