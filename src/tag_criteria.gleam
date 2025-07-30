import gleam/list
import gleam/order
import gleam/string
import lumiverse/models/series

pub const content_type = ["artbook"]

pub const special = ["doujinshi", "uncensored"]

// colored red
pub const explicit = [
  "hentai", "sexual violence", "gore", "adult", "erotica", "explicit-test-tag",
  "explicit-2-test-tag",
]

// colored orange
pub const beware = ["suggestive", "ecchi", "beware-test-tag"]

pub fn compare(a: series.Tag, b: series.Tag) -> order.Order {
  case compare_in_list(a.title, b.title, content_type) {
    order.Eq ->
      case compare_in_list(a.title, b.title, special) {
        order.Eq ->
          case compare_in_list(a.title, b.title, explicit) {
            order.Eq ->
              case compare_in_list(a.title, b.title, beware) {
                order.Eq -> string.compare(a.title, b.title)
                res -> res
              }
            res -> res
          }
        res -> res
      }
    res -> res
  }
}

fn compare_in_list(a: String, b: String, lst: List(String)) -> order.Order {
  let a_in_list = list.contains(lst, string.lowercase(a))
  let b_in_list = list.contains(lst, string.lowercase(b))

  case a_in_list, b_in_list {
    True, False -> order.Lt
    False, True -> order.Gt
    _, _ -> order.Eq
  }
}
