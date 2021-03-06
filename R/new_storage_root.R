#' new_storage_root
#'
#' @param name e.g.
#' @param root e.g.
#' @param accessibility e.g.
#' @param key key
#'
#' @export
#'
new_storage_root <- function(name,
                             root,
                             accessibility,
                             key) {

  if(missing(accessibility)) {
    data <- list(name = name,
                 root = root)
  } else {
    data <- list(name = name,
                 root = root,
                 accessibility = accessibility)
  }

  post_data(table = "storage_root",
            data = data,
            key)
}
