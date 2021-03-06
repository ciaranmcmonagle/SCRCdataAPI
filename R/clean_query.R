#' clean_query
#'
#' @param data data
#'
#' @export
#'
clean_query <- function(data) {
  data_tmp <- lapply(data, function(x) {
    ifelse(grepl("https://data.scrc.uk/api", x), basename(x), x)
  })
  return(data_tmp)
}
