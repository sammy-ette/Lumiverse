import lumiverse/elements/tag_new
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html

type Model {
  Model
}

type Msg

pub fn register() {
  let app = lustre.component(init, update, view, [])
  lustre.register(app, "home-page")
}

pub fn element() {
  element.element(
    "home-page",
    [attribute.class("flex-1 flex flex-col justify-center items-center")],
    [],
  )
}

fn init(_) {
  #(Model, effect.none())
}

fn update(m: Model, msg: Msg) {
  #(m, effect.none())
}

fn view(m: Model) {
  html.div([attribute.class("w-full h-full")], [
    html.div(
      [attribute.class("h-1/3 min-h-48 bg-sky-500 rounded-md p-4 flex gap-4")],
      [
        html.div([attribute.class("rounded-md h-full w-42 bg-white")], []),
        html.div([attribute.class("flex flex-col gap-2")], [
          html.h1(
            [attribute.class("font-[Poppins,sans-serif] font-bold text-2xl")],
            [element.text("Insert A Manga Name Here")],
          ),
          html.div([attribute.class("flex flex-wrap gap-2")], [
            tag_new.single("explicit-test-tag"),
            tag_new.single("beware-test-tag"),
            tag_new.single("Comedy"),
            tag_new.single("Romance"),
          ]),
          html.p([attribute.class("flex-wrap text-wrap")], [
            element.text(
              "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
            ),
          ]),
        ]),
      ],
    ),
  ])
}
