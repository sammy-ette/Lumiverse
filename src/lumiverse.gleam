import form
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/order
import gleam/string
import gleam/uri
import lumiverse/api/library
import lumiverse/pages/upload
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre_http as http
import modem
import plinth/browser/document
import plinth/browser/element as plinth_element

import localstorage
import oidc
import router as router_handler

import lumiverse/config

import lumiverse/api/api
import lumiverse/api/reader
import lumiverse/api/series as series_req
import lumiverse/layout
import lumiverse/model
import lumiverse/models/auth as auth_model
import lumiverse/models/reader as reader_model
import lumiverse/models/router
import lumiverse/models/series as series_model
import lumiverse/models/stream
import lumiverse/pages/all_page
import lumiverse/pages/api_down
import lumiverse/pages/auth
import lumiverse/pages/home
import lumiverse/pages/not_found
import lumiverse/pages/reader as reader_page
import lumiverse/pages/series as series_page
import lumiverse/pages/splash

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", 0)
}

fn init(_) {
  let kavita_user = localstorage.read("kavita_user")
  let user = case kavita_user {
    Ok(jsondata) -> {
      case api.decode_login_json(jsondata) {
        Ok(user) -> option.Some(user)
        Error(_) -> {
          localstorage.remove("kavita_user")
          option.None
        }
      }
    }
    Error(_) -> option.None
  }
  let route = router_handler.uri_to_route(router_handler.get_route())

  let model =
    model.Model(
      route: route,
      health_failed: option.None,
      user: user,
      guest: case user, config.guest_mode {
        option.Some(user), True -> {
          case user.username {
            "guest" -> True
            _ -> False
          }
        }
        option.None, True -> True
        _, _ -> False
      },
      auth: model.AuthModel(
        auth_message: "",
        user_details: auth_model.LoginDetails("", ""),
      ),
      oidc_config: auth_model.Config("", "lumiverse", "", False, False),
      doing_oidc: False,
      home: model.HomeModel(
        carousel: [],
        carousel_smalldata: [],
        series_lists: [],
        dashboard_count: 0,
      ),
      metadatas: dict.new(),
      series: dict.new(),
      series_details: dict.new(),
      viewing_series: option.None,
      reader_progress: option.None,
      reader_image_loaded: False,
      continue_point: option.None,
      prev_chapter: option.None,
      next_chapter: option.None,
      chapter_info: option.None,
      libraries: [],
      uploading: False,
      upload_result: option.None,
    )

  echo model.guest

  #(model, effect.batch([modem.init(on_url_change), api.health()]))
}

fn on_url_change(uri: uri.Uri) -> layout.Msg {
  router_handler.uri_to_route(uri) |> router.ChangeRoute |> layout.Router
}

fn homepage_display(user: option.Option(auth_model.User)) -> Effect(layout.Msg) {
  io.println("im here")
  case user {
    option.None -> {
      io.println("nope")
      effect.none()
    }
    option.Some(user) -> {
      io.println("getting recently added")
      api.dashboard(user.token)
    }
  }
}

fn route_effect(model: model.Model, route: router.Route) -> Effect(layout.Msg) {
  case route {
    router.Home ->
      case model.user == option.None && model.guest == False {
        True -> router_handler.change_route("/login")
        False -> homepage_display(model.user)
      }
    router.OIDCCallback -> {
      oidc.callback(model.oidc_config.authority, model.oidc_config.client_id)
      effect.none()
    }
    router.Logout -> {
      localstorage.remove("kavita_user")
      let assert Ok(home) = uri.parse("/")
      modem.load(home)
    }
    router.Series(id) ->
      case model.user {
        option.None -> {
          io.println("no siri")
          effect.none()
        }
        option.Some(user) -> {
          io.println("getting serie")
          let id_parsed = int.base_parse(id, 10)
          case id_parsed {
            Ok(id_int) -> series_and_metadata(user.token, id_int)
            Error(_) ->
              effect.from(fn(dispatch) {
                router.NotFound
                |> router.ChangeRoute
                |> layout.Router
                |> dispatch
              })
          }
        }
      }
    router.Reader(id) ->
      case model.user {
        option.None -> todo as "handle being in reader while not logged in"
        option.Some(user) -> reader.get_progress(user.token, id)
      }
    router.Upload ->
      case model.user {
        option.None -> todo as "handle trying to upload when not logged in"
        option.Some(user) -> library.libraries(user.token)
      }
    _ -> effect.none()
  }
}

fn series_and_metadata(token: String, id: Int) -> Effect(layout.Msg) {
  effect.batch([
    series_req.series(id, token),
    series_req.metadata(id, token),
    series_req.series_details(id, token),
  ])
}

fn scroll_reader() {
  case document.query_selector("#reader-img") {
    Ok(reader_elem) -> plinth_element.scroll_into_view(reader_elem)
    Error(_) -> Nil
  }
}

fn update(
  model: model.Model,
  msg: layout.Msg,
) -> #(model.Model, Effect(layout.Msg)) {
  case msg {
    layout.HealthCheck(Ok(Nil)) -> {
      #(
        model.Model(..model, health_failed: option.Some(False)),
        effect.batch(list.append(
          case model.user {
            option.Some(user) -> [
              api.refresh_auth(user.token, user.refresh_token),
              api.roles(user.token),
            ]
            option.None -> [api.config()]
          },
          list.append(
            case model.guest, model.user {
              True, option.None -> [api.login("guest", "password")]
              _, _ -> [effect.none()]
            },
            [
              route_effect(
                model,
                router_handler.uri_to_route(router_handler.get_route()),
              ),
            ],
          ),
        )),
      )
    }
    layout.HealthCheck(Error(_)) -> #(
      model.Model(..model, health_failed: option.Some(True)),
      effect.none(),
    )
    layout.Router(router.ChangeRoute(route)) -> {
      #(
        model.Model(..model, route: route, viewing_series: option.None),
        route_effect(model, route),
      )
    }
    layout.ConfigGot(Ok(conf)) -> {
      #(model.Model(..model, oidc_config: conf), effect.none())
    }
    layout.ConfigGot(Error(_)) -> {
      echo "config failed"
      #(model, effect.none())
    }
    layout.DashboardRetrieved(Ok(dashboard)) -> {
      let assert option.Some(user) = model.user
      let fetchers =
        list.map(
          list.filter(dashboard, fn(itm) { itm.visible }),
          fn(dash_item: stream.DashboardItem) {
            case dash_item.stream_type {
              stream.OnDeck ->
                series_req.on_deck(
                  user.token,
                  dash_item.order,
                  "Continue Reading",
                )
              stream.RecentlyUpdated ->
                series_req.recently_updated(
                  user.token,
                  dash_item.order,
                  "Latest Updates",
                )
              stream.NewlyAdded ->
                series_req.recently_added(
                  user.token,
                  dash_item.order,
                  "Newly Added Series",
                )
              stream.SmartFilter -> {
                let assert option.Some(smart_filter) =
                  dash_item.smart_filter_encoded
                series_req.decode_smart_filter(
                  user.token,
                  dash_item.order,
                  smart_filter,
                  True,
                )
              }
              _ -> effect.none()
            }
          },
        )

      #(
        model.Model(
          ..model,
          home: model.HomeModel(
            ..model.home,
            dashboard_count: list.length(
              list.filter(dashboard, fn(itm) {
                bool.and(itm.visible, case itm.stream_type {
                  stream.MoreInGenre -> False
                  _ -> True
                })
              }),
            ),
          ),
        ),
        effect.batch(list.unique(fetchers)),
      )
    }
    layout.DashboardRetrieved(Error(e)) -> {
      echo e
      todo as "handle dashboard retrieve failure"
    }
    layout.DashboardItemRetrieved(Ok(series)) -> {
      case model.user {
        option.Some(user) -> {
          let metadata_fetchers =
            list.map(series.items, fn(s: series_model.MinimalInfo) {
              series_req.metadata(s.id, user.token)
            })
          // let new_series =
          //   dict.from_list(
          //     list.map(series.items, fn(s: series_model.MinimalInfo) {
          //       #(s.id, s)
          //     }),
          //   )
          //   |> dict.merge(model.series)
          #(
            model.Model(
              ..model,
              home: model.HomeModel(
                ..model.home,
                series_lists: {
                  case list.length(series.items) {
                    0 -> model.home.series_lists
                    _ ->
                      list.unique(
                        list.sort(
                          [series, ..model.home.series_lists],
                          fn(list_a, list_b) {
                            int.compare(list_a.idx, list_b.idx)
                          },
                        ),
                      )
                  }
                },
                dashboard_count: case list.length(series.items) {
                  0 -> model.home.dashboard_count - 1
                  _ -> model.home.dashboard_count
                },
                carousel_smalldata: series.items,
              ),
              // series: new_series,
            ),
            effect.batch(metadata_fetchers),
          )
        }
        option.None -> #(model, effect.none())
      }
    }
    layout.DashboardItemRetrieved(Error(e)) -> {
      io.println("failure")
      echo e
      #(model, effect.none())
    }
    layout.SmartFilterDecode(Ok(smart_filter)) -> {
      let assert option.Some(user) = model.user
      #(model, series_req.all(user.token, smart_filter))
    }
    layout.SmartFilterDecode(Error(e)) -> {
      echo e
      todo as "smart filter failed :("
    }
    layout.AllSeriesRetrieved(Ok(all_serie)) -> {
      // if its a dashboard item
      case all_serie.0 {
        True -> #(
          model.Model(
            ..model,
            home: model.HomeModel(
              ..model.home,
              series_lists: list.unique(
                list.sort(
                  [all_serie.1, ..model.home.series_lists],
                  fn(list_a, list_b) { int.compare(list_a.idx, list_b.idx) },
                ),
              ),
            ),
          ),
          effect.none(),
        )
        False -> #(model, effect.none())
      }
    }
    layout.AllSeriesRetrieved(Error(_)) -> todo as "handle all series fail"
    layout.SeriesRetrieved(maybe_serie) -> {
      let series_store = case maybe_serie {
        Ok(serie) -> model.series |> dict.insert(serie.id, serie)
        Error(_) -> model.series
      }
      #(
        model.Model(
          ..model,
          viewing_series: option.Some(maybe_serie),
          series: series_store,
        ),
        effect.none(),
      )
    }
    layout.SeriesMetadataRetrieved(Ok(metadata)) -> {
      #(
        model.Model(
          ..model,
          metadatas: model.metadatas |> dict.insert(metadata.id, metadata),
        ),
        effect.none(),
      )
    }
    layout.SeriesMetadataRetrieved(Error(e)) -> {
      io.println("metadata fetch failed")
      echo e
      #(model, effect.none())
    }
    layout.SeriesDetailsRetrieved(Ok(#(series_id, details))) -> {
      #(
        model.Model(
          ..model,
          series_details: model.series_details
            |> dict.insert(series_id, details),
        ),
        effect.none(),
      )
    }
    layout.SeriesDetailsRetrieved(Error(e)) -> {
      echo "series details retrieve fail"
      echo e
      #(model, effect.none())
    }
    layout.AuthPage(auth_model.LoginSubmitted) -> {
      #(
        model,
        api.login(
          model.auth.user_details.username,
          model.auth.user_details.password,
        ),
      )
    }
    layout.AuthPage(auth_model.OIDCSubmitted) -> {
      #(
        model.Model(..model, doing_oidc: True),
        oidc.signin(
          model.oidc_config.authority,
          model.oidc_config.client_id,
          fn(result) {
            case result {
              Ok(access_token) -> {
                layout.AuthPage(auth_model.OIDCComplete(access_token))
              }
              Error(_) -> {
                echo "signin failure :("
                layout.AuthPage(auth_model.OIDCFailed)
              }
            }
          },
        ),
      )
    }
    layout.AuthPage(auth_model.OIDCComplete(token)) -> {
      #(model, api.login_bearer(token))
    }
    layout.AuthPage(auth_model.OIDCFailed) -> {
      #(
        model.Model(..model, doing_oidc: False),
        effect.from(fn(dispatch) {
          "Sign in failed. Try again later, or contact Cosmos."
          |> auth_model.AuthMessage
          |> layout.AuthPage
          |> dispatch
        }),
      )
    }
    layout.AuthPage(auth_model.UsernameUpdated(username)) -> {
      #(
        model.Model(
          ..model,
          auth: model.AuthModel(
            ..model.auth,
            user_details: auth_model.LoginDetails(
              ..model.auth.user_details,
              username: username,
            ),
          ),
        ),
        effect.none(),
      )
    }
    layout.AuthPage(auth_model.PasswordUpdated(password)) -> {
      #(
        model.Model(
          ..model,
          auth: model.AuthModel(
            ..model.auth,
            user_details: auth_model.LoginDetails(
              ..model.auth.user_details,
              password: password,
            ),
          ),
        ),
        effect.none(),
      )
    }
    layout.AuthPage(auth_model.AuthMessage(message)) -> {
      io.println("im infected")
      #(
        model.Model(
          ..model,
          auth: model.AuthModel(..model.auth, auth_message: message),
        ),
        effect.none(),
      )
    }
    layout.LoginGot(Ok(user)) -> {
      io.println("we got a user!")
      let assert Ok(home) = uri.parse("/")
      localstorage.write("kavita_user", api.encode_login_json(user))
      #(
        model.Model(..model, doing_oidc: False, user: option.Some(user)),
        modem.load(home),
      )
    }
    layout.LoginGot(Error(e)) -> {
      io.println("this is sad")
      let eff = case e {
        http.Unauthorized -> {
          io.println("not authorized??")
          effect.from(fn(dispatch) {
            "Incorrect username or password"
            |> auth_model.AuthMessage
            |> layout.AuthPage
            |> dispatch
          })
        }
        http.InternalServerError(err) -> {
          echo err
          effect.from(fn(dispatch) {
            "SSO signin failure"
            |> auth_model.AuthMessage
            |> layout.AuthPage
            |> dispatch
          })
        }
        e -> {
          echo e
          todo as "handle login error not being unauthorized"
        }
      }

      #(model.Model(..model, doing_oidc: False), eff)
    }
    layout.RefreshGot(Ok(new_tok)) -> {
      let assert option.Some(user) = model.user
      #(
        model.Model(
          ..model,
          user: option.Some(
            auth_model.User(
              ..user,
              token: new_tok.token,
              refresh_token: new_tok.refresh_token,
            ),
          ),
        ),
        effect.none(),
      )
    }
    layout.RefreshGot(Error(e)) -> {
      let eff = case e {
        http.Unauthorized -> {
          localstorage.remove("kavita_user")
          router_handler.change_route("/login")
        }
        _ -> {
          echo e
          todo as "handle refresh error being something other than unauthorized"
        }
      }
      #(model, eff)
    }
    layout.RolesGot(Ok(roles)) -> {
      let assert option.Some(user) = model.user
      #(
        model.Model(
          ..model,
          user: option.Some(auth_model.User(..user, roles: option.Some(roles))),
        ),
        effect.none(),
      )
    }
    layout.RolesGot(Error(_)) -> {
      echo "failed to get user roles"
      #(model, effect.none())
    }
    layout.TagClicked(cross) ->
      case cross {
        True -> {
          echo "deleting tag"
          #(model, effect.none())
        }
        False -> {
          echo "opening tag"
          #(model, effect.none())
        }
      }
    layout.Read(chp) -> {
      case model.user {
        option.Some(user) -> {
          case chp {
            option.Some(chapter_id) -> #(model, {
              let assert Ok(reader) =
                uri.parse("/chapter/" <> int.to_string(chapter_id))
              modem.load(reader)
            })
            option.None -> {
              let assert option.Some(Ok(serie)) = model.viewing_series
              #(model, reader.continue_point(user.token, serie.id))
            }
          }
        }
        option.None ->
          todo as "decide what should be done if read is used while not logged in"
      }
    }
    layout.ReaderImageLoaded(_) -> {
      #(model.Model(..model, reader_image_loaded: True), effect.none())
    }
    layout.ReaderPrevious -> {
      io.println("WAIT GO BACK")
      let assert option.Some(current_progress) = model.reader_progress
      echo current_progress.page_number - 1
      echo model.prev_chapter
      case current_progress.page_number - 1 {
        -1 -> {
          case model.prev_chapter {
            option.None -> #(model, effect.none())
            option.Some(prev_chapter) -> {
              let assert Ok(prev_uri) =
                uri.parse("/chapter/" <> int.to_string(prev_chapter))
              #(model, modem.load(prev_uri))
            }
          }
        }
        num -> {
          let assert option.Some(user) = model.user
          let advanced_progress =
            reader_model.Progress(..current_progress, page_number: num)
          scroll_reader()
          #(
            model.Model(
              ..model,
              reader_progress: option.Some(advanced_progress),
            ),
            reader.save_progress(user.token, advanced_progress),
          )
        }
      }
    }
    layout.ReaderNext -> {
      io.println("next, reader!")
      let assert option.Some(user) = model.user
      let assert option.Some(current_progress) = model.reader_progress
      let advanced_progress =
        reader_model.Progress(
          ..current_progress,
          page_number: current_progress.page_number + 1,
        )
      let assert option.Some(cont_point) = model.continue_point
      case int.compare(advanced_progress.page_number, cont_point.pages) {
        order.Eq -> {
          let assert Ok(next_uri) = case model.next_chapter {
            option.None ->
              uri.parse("/series/" <> int.to_string(current_progress.series_id))
            option.Some(next_chapter) ->
              uri.parse("/chapter/" <> int.to_string(next_chapter))
          }
          #(
            model.Model(
              ..model,
              reader_progress: option.None,
              reader_image_loaded: False,
            ),
            modem.load(next_uri),
          )
        }
        _ -> {
          scroll_reader()
          #(
            model.Model(
              ..model,
              reader_progress: option.Some(advanced_progress),
              reader_image_loaded: False,
            ),
            reader.save_progress(user.token, advanced_progress),
          )
        }
      }
    }
    layout.PreviousChapterRetrieved(Ok(prev)) -> #(
      model.Model(..model, prev_chapter: case prev {
        -1 -> option.None
        _ -> option.Some(prev)
      }),
      effect.none(),
    )
    layout.PreviousChapterRetrieved(Error(_)) ->
      todo as "handle prev chapter fail"
    layout.NextChapterRetrieved(Ok(next)) -> #(
      model.Model(..model, next_chapter: case next {
        -1 -> option.None
        _ -> option.Some(next)
      }),
      effect.none(),
    )
    layout.NextChapterRetrieved(Error(_)) -> todo as "handle next chapter fail"
    layout.ProgressUpdated(Ok(Nil)) -> #(model, effect.none())
    layout.ProgressUpdated(Error(_)) ->
      todo as "handle if progress update failed"
    layout.ContinuePointRetrieved(Ok(cont_point)) -> {
      #(
        model.Model(..model, continue_point: option.Some(cont_point)),
        case model.route {
          router.Reader(_) -> effect.none()
          _ -> {
            let assert Ok(reader) =
              uri.parse("/chapter/" <> int.to_string(cont_point.id))
            modem.load(reader)
          }
        },
      )
    }
    layout.ContinuePointRetrieved(Error(_)) ->
      todo as "handle continue point having an error"
    layout.ProgressRetrieved(Ok(progress)) -> {
      let assert option.Some(user) = model.user
      #(
        model.Model(..model, reader_progress: option.Some(progress)),
        reader.chapter_info(user.token, progress.chapter_id),
      )
    }
    layout.ProgressRetrieved(Error(_)) -> todo as "handle progress error??"
    layout.ChapterInfoRetrieved(Ok(inf)) -> {
      let assert option.Some(user) = model.user
      let assert option.Some(prog) = model.reader_progress
      #(
        model.Model(
          ..model,
          chapter_info: option.Some(inf),
          reader_progress: option.Some(
            reader_model.Progress(
              ..prog,
              volume_id: inf.volume_id,
              chapter_id: prog.chapter_id,
              library_id: inf.library_id,
              series_id: inf.series_id,
            ),
          ),
        ),
        effect.batch([
          reader.prev_chapter(
            user.token,
            inf.series_id,
            inf.volume_id,
            prog.chapter_id,
          ),
          reader.next_chapter(
            user.token,
            inf.series_id,
            inf.volume_id,
            prog.chapter_id,
          ),
          reader.continue_point(user.token, inf.series_id),
          series_and_metadata(user.token, inf.series_id),
        ]),
      )
    }
    layout.ChapterInfoRetrieved(Error(_)) -> todo as "handle chapter info error"
    layout.RequestSeriesUpdate(serie) -> {
      let assert option.Some(user) = model.user
      #(model, series_req.request_update(serie, user.token, user.username))
    }
    layout.SeriesUpdateRequested(Ok(_)) -> {
      echo "series update request sent successfully"
      #(model, effect.none())
    }
    layout.SeriesUpdateRequested(Error(err)) -> {
      echo "update request fail"
      echo err
      #(model, effect.none())
    }
    layout.LibrariesGot(Ok(libraries)) -> #(
      model.Model(..model, libraries:),
      effect.none(),
    )
    layout.LibrariesGot(Error(e)) -> {
      echo e
      todo as "handle library fail"
    }
    layout.FormSubmitted(element_id) -> {
      echo element_id
      let assert option.Some(user) = model.user

      case string.is_empty(element_id) {
        True ->
          panic as "there a form with a missing id that has layout.FormSubmitted"
        False -> Nil
      }

      #(
        model.Model(..model, upload_result: option.None, uploading: True),
        form.submit(
          element_id,
          [["Authorization", "Bearer " <> user.token]],
          fn(res) {
            case res {
              Ok(Nil) -> {
                echo "form submitted"
                layout.UploadSuccess
              }
              Error(Nil) -> {
                echo "form submit fail"
                layout.UploadFail
              }
            }
          },
        ),
      )
    }
    layout.UploadSuccess -> #(
      model.Model(
        ..model,
        uploading: False,
        upload_result: option.Some(Ok(Nil)),
      ),
      effect.none(),
    )
    layout.UploadFail -> #(
      model.Model(
        ..model,
        uploading: False,
        upload_result: option.Some(Error(Nil)),
      ),
      effect.none(),
    )
  }
}

fn view(model: model.Model) -> Element(layout.Msg) {
  case model.health_failed {
    option.Some(False) -> {
      let page = case model.route {
        router.Home -> home.page(model)
        router.Login -> auth.login(model)
        router.OIDCCallback -> auth.oidc_callback()
        router.Logout -> auth.logout()
        router.All -> all_page.page(model)
        router.Series(_) -> series_page.page(model)
        router.Reader(_) -> reader_page.page(model)
        router.Upload -> upload.page(model)
        router.NotFound -> not_found.page()
      }

      case model.route {
        router.Login -> page
        router.Logout -> page
        router.NotFound -> page
        router.OIDCCallback -> page
        router.Upload ->
          html.div([attribute.class("flex flex-col h-screen")], [
            layout.nav(model),
            page,
          ])
        _ -> html.div([], [layout.nav(model), page])
      }
    }
    option.Some(True) -> api_down.page()
    option.None -> splash.page()
  }
}
