process_ons_demographics <- function (sourcefile, h5filename) 
{

  output_area_sf <- "data-raw/outputarea_shapefile/Output_Areas__December_2011__Boundaries_EW_BFC.shp"
  grp.names <- c("OA", "EW", "LA", "LSOA", "MSOA", "CCG", "STP", "UA","LHB",
                 "grid1km", "grid10km")
  full.names <- c("output area", "electoral ward", 
                  "local authority", "lower super output area", "mid-layer super output area", 
                  "clinical commissioning group", "sustainability and transformation partnership", 
                  "unitary authority", "local health board",
                  "grid area", "grid area")
  subgrp.names <- c("total", "1year", "5year", "10year", "sg_deaths_scheme")
  age.classes <- list("total", 0:90, seq(0, 90, 5), seq(0, 
                                                        90, 10), c(0, 1, 15, 45, 65, 75, 85))
  datazones <- sf::st_read(output_area_sf, quiet = TRUE) %>% 
    sf::st_make_valid()
  if (any(grepl("^grid", grp.names))) {
    gridsizes <- grp.names[grepl("^grid", grp.names)] %>% 
      sapply(function(x) gsub("grid", "", x) %>% gsub("km", 
                                                      "", .)) %>% as.numeric()
    dz_subdivisions <- list()
    grid_matrix <- list()
    for (g in seq_along(gridsizes)) {
      tmp <- grid_intersection(datazones, gridsizes[g])
      tag <- paste0("grid", gridsizes[g], "km")
      dz_subdivisions[[g]] <- tmp$dz_subdivisions
      names(dz_subdivisions)[g] <- tag
      grid_matrix[[g]] <- tmp$grid_matrix
      names(grid_matrix)[g] <- tag
    }
  }

  OA_EW_LA <- readr::read_csv("data-raw/england_lookup/output_to_ward_to_LA.csv",col_types = cols(.default = "c")
  )  %>% dplyr::rename(OAcode = OA11CD, EWcode = WD19CD, EWname = WD19NM, LAcode = LAD19CD, LAname = LAD19NM) %>%
  dplyr::select_if(grepl("name$|code$", colnames(.)))
  OA_LSOA_MSOA_LA <- readr::read_csv("data-raw/england_lookup/output_to_LSOA_MSOA_to_LA.csv",col_types = cols(.default = "c")
  )  %>% dplyr::rename(OAcode = OA11CD, LSOAcode = LSOA11CD, LSOAname = LSOA11NM, MSOAcode = MSOA11CD, MSOAname = MSOA11NM) %>%
    dplyr::select_if(grepl("name$|code$", colnames(.)))
  LSOA_CCG <- readr::read_csv("data-raw/england_lookup/LSOA_to_CCG.csv",col_types = cols(.default = "c")
  )  %>% dplyr::rename(LSOAcode = LSOA11CD, CCGcode = CCG19CD, CCGname = CCG19NM, STPcode = STP19CD, STP19name = STP19NM) %>%
    dplyr::select_if(grepl("name$|code$", colnames(.)))
  EW_UA <- readr::read_csv("data-raw/england_lookup/ward_to_UA_wales.csv",col_types = cols(.default = "c")
  )  %>% dplyr::rename(EWcode = WD19CD, UAcode = UA19CD, UAname = UA19NM) %>%
    dplyr::select_if(grepl("name$|code$", colnames(.)))
  UA_HB <- readr::read_csv("data-raw/england_lookup/UA_to_healthboard_wales.csv",col_types = cols(.default = "c")
  )  %>% dplyr::rename(UAcode = UA19CD, LHBcode = LHB19CD, LHBname = LHB19NM) %>%
    dplyr::select_if(grepl("name$|code$", colnames(.)))
  conversion.table <- OA_EW_LA %>% left_join(.,OA_LSOA_MSOA_LA,by = "OAcode") %>%
    left_join(.,LSOA_CCG,by = "LSOAcode") %>% 
    left_join(.,EW_UA,by = "EWcode") %>%
    left_join(.,UA_HB,by = "UAcode")
  conversion.table$OAname <- conversion.table$OAcode
  
  original.dat <- lapply(seq_along(sourcefile), function(k) {
    dataset <- sourcefile[k] %>% gsub("data-raw/england_", 
                                      "", .) %>% gsub(".csv", "", .)
    sape_tmp <- readr::read_csv(sourcefile[k], col_names = TRUE)
    header_new <- readr::read_csv(sourcefile[k], col_names = TRUE)[1,]
    header_new <- header_new %>% names(.) %>% gsub(" ", "",., fixed=TRUE) %>% gsub("Age", "AGE",., fixed=TRUE) %>% gsub("AGEd", "AGE",., fixed=TRUE) %>% gsub("2011outputarea", "OAcode",., fixed=TRUE)
    original.dat <- sape_tmp
    colnames(original.dat) <- header_new
    for (j in seq_along(subgrp.names)) {
      if (subgrp.names[j] == "1year") {
        transage.dat <- original.dat
      }
      else if (subgrp.names[j] == "total") {
        transage.dat <- bin_ages(original.dat, age.classes[[j]])
      }
      else {
        transage.dat <- bin_ages(original.dat, age.classes[[j]])
      }
      for (i in seq_along(grp.names)) {
        cat(paste0("\rProcessing ", j, "/", length(subgrp.names), 
                   ": ", i, "/", length(grp.names), "..."))
        if (grp.names[i] %in% c("OA", "EW", "LA", "LSOA", "MSOA", "CCG", "STP", "UA","LHB")) {
          tmp.dat <- oatolower(transage.dat, grp.names[i], 
                              conversion.table)
          transarea.dat <- list(grid_pop = as.matrix(tmp.dat$data[, 
                                                                  -1]), grid_id = tmp.dat$data[, 1])
          area.names <- tmp.dat$area.names
        }
        else if (grepl("grid", grp.names[i])) {
          transarea.dat <- oa2grid(dat = transage.dat, 
                                   datazones = datazones, dz_subdivisions = dz_subdivisions[[grp.names[i]]])
        }
        else {
          stop("OMG! - grpnames")
        }
        location <- file.path(grp.names[i], subgrp.names[j], 
                              dataset)
        dimension_names <- list(transarea.dat$grid_id, 
                                colnames(transarea.dat$grid_pop))
        names(dimension_names) <- c(full.names[i], "age groups")
        if (grepl("grid", grp.names[i])) {
          create_array(h5filename = h5filename, component = location, 
                       array = transarea.dat$grid_pop, dimension_names = dimension_names, 
                       dimension_values = list(grid_matrix[[grp.names[i]]]), 
                       dimension_units = list(gsub("grid", "", 
                                                   grp.names[i])))
        }
        else {
          create_array(h5filename = h5filename, component = location, 
                       array = transarea.dat$grid_pop, dimension_names = dimension_names)
        }
      }
    }
  })
}