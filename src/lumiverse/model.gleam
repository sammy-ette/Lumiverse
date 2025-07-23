import gleam/dict
import gleam/option

import lustre_http as http

import lumiverse/models/auth
import lumiverse/models/reader
import lumiverse/models/router
import lumiverse/models/series

pub type Model {
  Model(
    route: router.Route,
    health_failed: option.Option(Bool),
    user: option.Option(auth.User),
    guest: Bool,
    auth: AuthModel,
    oidc_config: auth.Config,
    doing_oidc: Bool,
    home: HomeModel,
    metadatas: dict.Dict(Int, series.Metadata),
    series: dict.Dict(Int, series.MinimalInfo),
    viewing_series: option.Option(Result(series.MinimalInfo, http.HttpError)),
    reader_progress: option.Option(reader.Progress),
    reader_image_loaded: Bool,
    continue_point: option.Option(reader.ContinuePoint),
    prev_chapter: option.Option(Int),
    next_chapter: option.Option(Int),
    chapter_info: option.Option(reader.ChapterInfo),
  )
}

pub type AuthModel {
  AuthModel(auth_message: String, user_details: auth.LoginDetails)
}

pub type HomeModel {
  HomeModel(
    carousel_smalldata: List(series.MinimalInfo),
    carousel: List(series.Metadata),
    series_lists: List(SeriesList),
    dashboard_count: Int,
  )
}

pub type SeriesList {
  SeriesList(items: List(series.MinimalInfo), title: String, idx: Int)
}
