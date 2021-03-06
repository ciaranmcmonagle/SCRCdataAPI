#' upload_github_repo
#'
#' @param storage_root_id e.g.
#' @param path e.g. "ScottishCovidResponse/SCRCdata"
#' @param filename e.g.
#' @param hash e.g.
#' @param run_date e.g.
#' @param key key
#'
#' @export
#'
upload_github_repo <- function(storage_root_id,
                               repo,
                               hash,
                               version,
                               key) {

  repo_storeId <- new_storage_location(path = paste(repo, "repository"),
                                       hash = hash,
                                       storage_root = storage_root_id,
                                       key = key)

  repo_objectId <- new_object(storage_location_id = repo_storeId,
                              key = key)

  repo_codeRepoReleaseId <- new_code_repo_release(
    name = repo,
    version = version,
    website = paste0("https://github.com/", repo),
    object_id = repo_objectId,
    key = key)

  list(repo_storeId = repo_storeId,
       repo_objectId = repo_objectId,
       repo_codeRepoReleaseId = repo_codeRepoReleaseId)
}
