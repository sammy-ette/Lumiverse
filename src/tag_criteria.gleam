import gleam/list
import gleam/order
import gleam/string

pub const content_type = ["artbook"]

pub const special = ["doujinshi", "uncensored"]

// colored red
pub const explicit = [
  "hentai", "sexual violence", "gore", "adult", "erotica", "explicit-test-tag",
  "explicit-2-test-tag",
]

// colored orange
pub const beware = ["suggestive", "ecchi", "beware-test-tag"]

pub fn compare(a: String, b: String) -> order.Order {
  case compare_in_list(a, b, content_type) {
    order.Eq ->
      case compare_in_list(a, b, special) {
        order.Eq ->
          case compare_in_list(a, b, explicit) {
            order.Eq ->
              case compare_in_list(a, b, beware) {
                order.Eq -> string.compare(a, b)
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
