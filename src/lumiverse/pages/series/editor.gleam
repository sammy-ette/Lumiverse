import formal/form
import gleam/list
import gleam/option
import gleam/string
import lumiverse/api/series
import lumiverse/elements/button
import lumiverse/elements/input
import lumiverse/elements/panel
import lumiverse/elements/tag
import lumiverse/pages/series/model
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event

pub fn basic_info_form() -> form.Form(model.BasicInfoEdit) {
  form.new({
    use series_name <- form.field(
      "series_name",
      form.parse_string |> form.check_not_empty,
    )
    use localized_name <- form.field("localized_name", form.parse_string)
    form.success(model.BasicInfoEdit(series_name:, localized_name:))
  })
}

pub fn details_form() -> form.Form(model.DetailsEdit) {
  form.new({
    use summary <- form.field("summary", form.parse_string)
    form.success(model.DetailsEdit(summary:))
  })
}

pub fn update(
  m: model.Model,
  msg: model.Msg,
) -> #(model.Model, effect.Effect(model.Msg)) {
  case msg {
    model.ShowEditor(show_editor) -> #(
      model.Model(
        ..m,
        show_editor:,
        editor_section: model.BasicInfoSection,
        new_tag_input: "",
        new_genre_input: "",
        basic_form: basic_info_form(),
        details_form: details_form(),
      ),
      effect.none(),
    )
    model.SwitchEditorSection(editor_section) -> #(
      model.Model(..m, editor_section:),
      effect.none(),
    )
    model.UpdateNewTagInput(new_tag_input) -> #(
      model.Model(..m, new_tag_input:),
      effect.none(),
    )
    model.SubmitNewTag ->
      case string.trim(m.new_tag_input) {
        "" -> #(m, effect.none())
        tag -> #(
          model.Model(..m, new_tag_input: ""),
          series.tags(fn(res) { model.TagsRetrieved(tag, res) }),
        )
      }
    model.TagsRetrieved(tag, Ok(known_tags)) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_metadata =
        series.Metadata(..metadata, tags: [
          resolve_tag(tag, known_tags),
          ..metadata.tags
        ])
      #(m, series.update_metadata(updated_metadata, model.MetadataUpdated))
    }
    model.TagsRetrieved(_, _) -> #(m, effect.none())
    model.RemoveTag(id) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_metadata =
        series.Metadata(
          ..metadata,
          tags: metadata.tags |> list.filter(fn(t) { t.id != id }),
        )
      #(m, series.update_metadata(updated_metadata, model.MetadataUpdated))
    }
    model.UpdateNewGenreInput(new_genre_input) -> #(
      model.Model(..m, new_genre_input:),
      effect.none(),
    )
    model.SubmitNewGenre ->
      case string.trim(m.new_genre_input) {
        "" -> #(m, effect.none())
        genre -> #(
          model.Model(..m, new_genre_input: ""),
          series.genres(fn(res) { model.GenresRetrieved(genre, res) }),
        )
      }
    model.GenresRetrieved(genre, Ok(known_genres)) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_metadata =
        series.Metadata(..metadata, genres: [
          resolve_tag(genre, known_genres),
          ..metadata.genres
        ])
      #(m, series.update_metadata(updated_metadata, model.MetadataUpdated))
    }
    model.GenresRetrieved(_, _) -> #(m, effect.none())
    model.RemoveGenre(id) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_metadata =
        series.Metadata(
          ..metadata,
          genres: metadata.genres |> list.filter(fn(t) { t.id != id }),
        )
      #(m, series.update_metadata(updated_metadata, model.MetadataUpdated))
    }
    model.MetadataUpdated(Ok(Nil)) -> #(
      m,
      series.metadata(m.id, model.MetadataRetrieved),
    )
    model.MetadataUpdated(Error(_)) -> #(m, effect.none())
    model.BasicInfoSubmitted(Ok(edit)) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_srs =
        series.Series(
          ..srs,
          name: edit.series_name,
          localized_name: edit.localized_name,
        )
      #(
        m,
        effect.batch([
          series.update_metadata(metadata, model.MetadataUpdated),
          series.update(updated_srs, fn(res) {
            case res {
              Ok(_) -> model.SeriesRetrieved(Ok(updated_srs))
              Error(e) -> model.SeriesRetrieved(Error(e))
            }
          }),
        ]),
      )
    }
    model.BasicInfoSubmitted(Error(basic_form)) -> #(
      model.Model(..m, basic_form:),
      effect.none(),
    )
    model.DetailsSubmitted(Ok(edit)) -> {
      let assert option.Some(Ok(srs)) = m.series
      let assert option.Some(metadata) = srs.metadata
      let updated_metadata = series.Metadata(..metadata, summary: edit.summary)
      #(m, series.update_metadata(updated_metadata, model.MetadataUpdated))
    }
    model.DetailsSubmitted(Error(details_form)) -> #(
      model.Model(..m, details_form:),
      effect.none(),
    )
    _ -> #(m, effect.none())
  }
}

fn resolve_tag(name: String, known: List(series.Tag)) -> series.Tag {
  series.Tag(
    id: case
      known
      |> list.find(fn(t) {
        t.title |> string.lowercase == name |> string.lowercase
      })
    {
      Ok(t) -> t.id
      Error(_) ->
        case known |> list.length {
          0 -> 0
          len -> len + 1
        }
    },
    title: name,
  )
}

pub fn panel(m: model.Model) -> element.Element(model.Msg) {
  case m.show_editor, m.series {
    True, option.Some(Ok(srs)) ->
      case srs.metadata {
        option.Some(metadata) -> view(m, srs, metadata)
        option.None -> element.none()
      }
    _, _ -> element.none()
  }
}

fn view(
  m: model.Model,
  srs: series.Series,
  metadata: series.Metadata,
) -> element.Element(model.Msg) {
  panel.shell(
    [model.BasicInfoSection, model.TagsSection, model.DetailsSection]
      |> list.map(fn(s) {
        panel.section_btn(
          section_label(s),
          s == m.editor_section,
          model.SwitchEditorSection(s),
        )
      }),
    "Edit Series",
    model.ShowEditor(False),
    case m.editor_section {
      model.BasicInfoSection -> basic_info_section(srs)
      model.TagsSection -> tags_section(m, metadata)
      model.DetailsSection -> details_section(metadata)
    },
  )
}

fn section_label(section: model.EditorSection) -> String {
  case section {
    model.BasicInfoSection -> "Basic Info"
    model.TagsSection -> "Tags & Genres"
    model.DetailsSection -> "Details"
  }
}

fn basic_info_section(srs: series.Series) -> element.Element(model.Msg) {
  let submit = fn(fields) {
    basic_info_form()
    |> form.add_values(fields)
    |> form.run
    |> model.BasicInfoSubmitted
  }
  html.form([attribute.class("space-y-4"), event.on_submit(submit)], [
    input.input_with_name("Series Name", [attribute.value(srs.name)]),
    input.input_with_name("Localized Name", [
      attribute.value(srs.localized_name),
    ]),
    button.button("Save", [button.primary()]),
  ])
}

fn tags_section(
  m: model.Model,
  metadata: series.Metadata,
) -> element.Element(model.Msg) {
  html.div([attribute.class("space-y-6")], [
    tag_manager(
      "TAGS",
      metadata.tags,
      m.new_tag_input,
      "Tag name...",
      model.UpdateNewTagInput,
      model.SubmitNewTag,
      model.RemoveTag,
    ),
    tag_manager(
      "GENRES",
      metadata.genres,
      m.new_genre_input,
      "Genre name...",
      model.UpdateNewGenreInput,
      model.SubmitNewGenre,
      model.RemoveGenre,
    ),
    html.p([attribute.class("text-xs text-zinc-500")], [
      element.text("Click a tag or genre to remove it"),
    ]),
  ])
}

fn tag_manager(
  title: String,
  items: List(series.Tag),
  input_value: String,
  placeholder: String,
  on_input: fn(String) -> model.Msg,
  on_submit: model.Msg,
  on_remove: fn(Int) -> model.Msg,
) -> element.Element(model.Msg) {
  panel.group(title, [
    case items {
      [] -> element.none()
      _ ->
        html.div(
          [attribute.class("flex flex-wrap gap-2")],
          list.map(items, fn(t) {
            tag.single(t, [
              attribute.class("cursor-pointer active:opacity-50"),
              event.on_click(on_remove(t.id)),
            ])
          }),
        )
    },
    html.div([attribute.class("flex gap-2 items-center")], [
      input.input([
        attribute.placeholder(placeholder),
        attribute.value(input_value),
        event.on_input(on_input),
      ]),
      button.icon("ph ph-[plus]", "Add", [
        attribute.type_("button"),
        button.secondary(),
        event.on_click(on_submit),
      ]),
    ]),
  ])
}

fn details_section(metadata: series.Metadata) -> element.Element(model.Msg) {
  let submit = fn(fields) {
    details_form()
    |> form.add_values(fields)
    |> form.run
    |> model.DetailsSubmitted
  }
  html.form([attribute.class("space-y-4"), event.on_submit(submit)], [
    panel.group("SUMMARY", [
      html.textarea(
        [
          attribute.class(
            "w-full h-36 text-sm bg-zinc-800 rounded-lg px-3 py-2 text-zinc-200 outline-none resize-none border border-zinc-700/50 focus:border-violet-500/50 focus:ring-2 focus:ring-violet-500/20 transition-colors",
          ),
          attribute.name("summary"),
        ],
        metadata.summary,
      ),
    ]),
    button.button("Save", [button.primary()]),
  ])
}
