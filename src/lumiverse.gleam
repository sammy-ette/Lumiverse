import form
import gleam/bool
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/order
import gleam/result
import gleam/string
import gleam/uri
import lumiverse/api/library
import lumiverse/pages/error
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
import plinth/javascript/global

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
          let _ = localstorage.remove("kavita_user")
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
        carousel_index: 0,
        carousel_smalldata: [],
        series_lists: [],
        carousel_timer_id: global.set_timeout(0, fn() { Nil }),
        // to get a global.TimerID value
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
      effect.batch([
        api.dashboard(user.token),
        api.popular_series(user.token),
        effect.from(fn(dispatch) {
          let timer_id =
            global.set_interval(6000, fn() {
              layout.CarouselNext |> dispatch
              Nil
            })
          layout.CarouselIntervalID(timer_id) |> dispatch
        }),
      ])
    }
  }
}

fn redirect_login() {
  let assert Ok(login) = uri.parse("/login")
  modem.load(login)
}

fn route_effect(model: model.Model, route: router.Route) -> Effect(layout.Msg) {
  case route {
    _ -> global.clear_interval(model.home.carousel_timer_id)
    router.Home -> Nil
  }

  case route {
    router.Home ->
      case model.user == option.None && model.guest == False {
        True -> redirect_login()
        False -> homepage_display(model.user)
      }
    router.OIDCCallback -> {
      let _ =
        oidc.callback(model.oidc_config.authority, model.oidc_config.client_id)
      effect.none()
    }
    router.Logout -> {
      let _ = localstorage.remove("kavita_user")
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
        option.None -> redirect_login()
        option.Some(user) -> reader.get_progress(user.token, id)
      }
    router.Upload ->
      case model.user {
        option.None -> redirect_login()
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

fn error_effect(e: http.HttpError) {
  effect.from(fn(dispatch) {
    router.ErrorPage(e)
    |> router.ChangeRoute
    |> layout.Router
    |> dispatch
  })
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
    layout.PopularSeriesRetrieved(Ok(serieses)) -> {
      let assert option.Some(user) = model.user
      let metadata_fetchers =
        list.map(serieses, fn(s: series_model.Info) {
          series_req.metadata(s.id, user.token)
        })
      #(
        model.Model(
          ..model,
          home: model.HomeModel(..model.home, carousel: serieses),
        ),
        effect.batch(metadata_fetchers),
      )
    }
    layout.CarouselNext -> #(
      model.Model(
        ..model,
        home: model.HomeModel(..model.home, carousel_index: {
          use <- bool.guard(model.home.carousel |> list.is_empty, 0)
          case
            model.home.carousel_index + 1 == model.home.carousel |> list.length
          {
            True -> 0
            False -> model.home.carousel_index + 1
          }
        }),
      ),
      effect.none(),
    )
    layout.CarouselPrevious -> #(model, effect.none())
    layout.CarouselIntervalID(id) -> #(
      model.Model(
        ..model,
        home: model.HomeModel(..model.home, carousel_timer_id: id),
      ),
      effect.none(),
    )
    layout.PopularSeriesRetrieved(Error(e)) -> #(model, error_effect(e))
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
      #(model, error_effect(e))
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
      #(model, error_effect(e))
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
    layout.AllSeriesRetrieved(Error(e)) -> #(model, error_effect(e))
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
      let set_auth_message = fn(msg) {
        effect.from(fn(dispatch) {
          msg
          |> auth_model.AuthMessage
          |> layout.AuthPage
          |> dispatch
        })
      }
      let eff = case e {
        http.Unauthorized -> {
          set_auth_message("Incorrect username or password")
        }
        http.InternalServerError(err) -> {
          echo err
          set_auth_message("SSO sign in failure")
        }
        http.NetworkError -> {
          set_auth_message("You're offline. Connect to the internet.")
        }
        e -> {
          echo e
          set_auth_message("(｡>﹏<) unknown error, please report.")
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
          let _ = localstorage.remove("kavita_user")
          redirect_login()
        }
        _ -> {
          echo e
          effect.none()
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
    layout.TagClicked(cross, t) ->
      case cross {
        True -> {
          let assert option.Some(user) = model.user
          let res = {
            use viewing_series <- result.try(
              option.to_result(model.viewing_series, #(model, effect.none())),
            )
            let assert Ok(srs) = viewing_series
            use metadata <- result.try(
              result.replace_error(dict.get(model.metadatas, srs.id), #(
                model,
                effect.none(),
              )),
            )
            use updated_tags <- result.try(
              result.replace_error(
                metadata.tags
                  |> list.map(fn(t: series_model.Tag) { #(t.id, t.title) })
                  |> list.key_pop(t.id),
                #(model, effect.none()),
              ),
            )
            Ok(#(
              model,
              series_req.update_metadata(
                series_model.Metadata(
                  ..metadata,
                  tags: updated_tags.1
                    |> list.map(fn(tag_pair) {
                      series_model.Tag(tag_pair.0, tag_pair.1)
                    }),
                ),
                user.token,
              ),
            ))
          }
          result.unwrap_both(res)
        }
        False -> {
          echo "opening tag"
          #(model, effect.none())
        }
      }
    layout.SeriesMetadataUpdated(Ok(series_id)) -> {
      echo "updated tags!"
      let assert option.Some(user) = model.user
      #(model, series_req.metadata(series_id, user.token))
    }
    layout.SeriesMetadataUpdated(Error(e)) -> #(model, error_effect(e))
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
        option.None -> #(model, redirect_login())
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
          let assert option.Some(cont_point) = model.continue_point
          let assert option.Some(user) = model.user
          let num = case current_progress.page_number == cont_point.pages {
            True -> {
              echo "going back twice"
              num - 1
            }
            False -> num
          }
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
      let assert option.Some(cont_point) = model.continue_point
      let assert option.Some(current_progress) = model.reader_progress
      let advanced_progress =
        reader_model.Progress(
          ..current_progress,
          page_number: current_progress.page_number + 1
            |> int.clamp(min: 0, max: cont_point.pages),
        )

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
    layout.PreviousChapterRetrieved(Ok(prev)) -> #(
      model.Model(..model, prev_chapter: case prev {
        -1 -> option.None
        _ -> option.Some(prev)
      }),
      effect.none(),
    )
    layout.PreviousChapterRetrieved(Error(e)) -> #(model, error_effect(e))
    layout.NextChapterRetrieved(Ok(next)) -> #(
      model.Model(..model, next_chapter: case next {
        -1 -> option.None
        _ -> option.Some(next)
      }),
      effect.none(),
    )
    layout.NextChapterRetrieved(Error(e)) -> #(model, error_effect(e))
    layout.ProgressUpdated(Ok(Nil)) -> {
      let assert option.Some(cont_point) = model.continue_point
      let assert option.Some(current_progress) = model.reader_progress

      case int.compare(current_progress.page_number, cont_point.pages) {
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
        _ -> #(model, effect.none())
      }
    }
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
    layout.ContinuePointRetrieved(Error(e)) -> #(model, error_effect(e))
    layout.ProgressRetrieved(Ok(progress)) -> {
      let assert option.Some(user) = model.user
      #(
        model.Model(..model, reader_progress: option.Some(progress)),
        reader.chapter_info(user.token, progress.chapter_id),
      )
    }
    layout.ProgressRetrieved(Error(e)) -> #(model, error_effect(e))
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
    layout.ChapterInfoRetrieved(Error(e)) -> #(model, error_effect(e))
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
      #(model, error_effect(e))
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
        router.ErrorPage(err) -> error.page(err)
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
