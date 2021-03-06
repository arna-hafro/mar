lb_catch <- function(con) {
  q <-
    afli_afli(con) %>%
    select(visir,
           sid = tegund,
           catch = afli)
  return(q)
}

lb_base <- function(con, standardize = TRUE) {

  q <-
    afli_stofn(con)

  if(standardize) {
    q <-
      q %>%
      dplyr::select(visir,
                    vid = skipnr,
                    gid = veidarf,
                    year = ar,
                    month = man,
                    date = vedags,
                    lat1 = breidd,
                    lon1 = lengd,
                    lat2 = breidd_lok,
                    lon2 = lengd_lok,
                    sq = reitur,        # Local statistical rectange (same resolution as ICES)
                    ssq = smareitur,    # The quarter within a rectangle. NOTE: It is derived if NA
                    z1 = dypi,          # depth
                    z2 = dypi_lok,
                    winddirection = vindatt,
                    beaufort = vindstig,
                    m_sec = m_sek,       # Meters per second??
                    distance = toglengd, # Derived measure
                    datel = ldags,       # Landing date
                    hidl = lhofn)        # Harbour id landings took place
  }

  return(q)
}


#' lb_mobile
#'
#' @param con Oracle connection
#' @param standardize Boolean (default TRUE) if only certain variables returned
#'
#' @return A sql tibble
#'

lb_mobile <- function(con, standardize = TRUE) {

  q <-
    tbl_mar(con, "afli.toga")

  if(standardize) {
    q <-
      q %>%
      # get date of fishing (note: may also need gid)
      dplyr::left_join(tbl_mar(con, "afli.stofn") %>%
                         dplyr::select(visir, date = vedags, gid = veidarf),
                       by = "visir") %>%
      dplyr::rename(towtime = togtimi) %>%
      dplyr::mutate(effort = dplyr::case_when(gid %in% c(6, 7, 9, 14, 15, 38, 40) ~ towtime / 60,
                                              # for seine and traps use setting as effort
                                              gid %in% c(5, 18, 39, 42) ~ 1,
                                              TRUE ~ NA_real_),
                    effort_unit = dplyr::case_when(gid %in% c(6, 7, 9, 14, 15, 38, 40) ~ "hours towed",
                                                   # for seine just use the setting
                                                   gid %in% c(5, 18, 39, 42) ~ "setting",
                                                   TRUE ~ NA_character_)) %>%
      dplyr::select(visir,
                    date,
                    towtime,                     # in minutes
                    effort,
                    effort_unit,
                    mesh = moskvi,
                    mesh_min = moskvi_minnsti,
                    doors = hlerar,              # in kilograms
                    headline = hoflina,
                    sweeps = grandarar,          # in meters ???
                    plow_width = pl_breidd,
                    tempb1 = botnhiti,           # bottom temperature
                    tempb2 = botnhiti_lok,
                    temps1 = uppsj_hiti,         # surface temperature
                    temps2 = uppsj_hiti_lok,
                    on.bottom = ibotni) %>%
      dplyr::mutate(on.bottom = lpad(on.bottom, 4, "0")) %>%
      # vedags + (substr(lpad(ibotni,4,'0'),1,2)*60+substr(lpad(ibotni,4,'0'),3,2))/24/60 t1
      # Oracle time is in days
      dplyr::mutate(t1 = date + (substr(on.bottom, 1, 2) * 60 + substr(on.bottom, 3, 4)) / (24 * 60),
                    t2 = date + (substr(on.bottom, 1, 2) * 60 + substr(on.bottom, 3, 4) + towtime) / (24 * 60)) %>%
      select(-date)



  }

  return(q)

}


lb_static <- function(con, standardize = TRUE) {

  q <-
    afli_lineha(con)

  if(standardize) {
    q <-
      q %>%
      # get gid
      dplyr::left_join(tbl_mar(con, "afli.stofn") %>%
                         select(visir, gid = veidarf),
                       by = "visir") %>%
      # NOTE: SHOULD NOT REALLY FILTER DATA HERE
      dplyr::filter(gid %in% c(1, 2, 3)) %>%
      # Question really how to define effort, below is one way - each gear having a
      #  different unit of measure
      # number of longline hooks
      #   question if (soak)time should be added to the effort variable for gid == 1
      #   this may though be difficult to quantify
      dplyr::mutate(effort = dplyr::case_when(gid == 1 ~ as.numeric(onglar * bjod),
                                              # netnights - the old measure used in iceland
                                              gid == 2 ~ as.numeric(dregin * naetur),
                                              # jigger hookhours
                                              gid == 3 ~ as.numeric(faeri * klst)),
                    effort_unit = dplyr::case_when(gid == 1 ~ "hooks",
                                                   gid == 2 ~ "netnights",
                                                   gid == 3 ~ "hookours")) %>%
      dplyr::select(visir,
                    effort,
                    effort_unit,
                    mesh = moskvi,           # gillnets
                    height = haed,           # gillnets
                    mean_gillnet_length = medal_lengd_neta,
                    bait = beita,
                    tempb1 = botnhiti,       # bottom temperature
                    temps1 = uppsjavarhiti,  # surface temperature
                    # check what fj_kroka really is, looks like it is
                    # a "new" variable related to longline fishing
                    fj_kroka,
                    t0 = logn_hefst,         # time setting starts
                    t1 = drattur_hefst,      # time gear hauling starts
                    t2 = drattur_lykur)      # time gear hauling ends

    # Standardized gillnet meshes - at this stage it may though be better to
    #  just ignore them
    #mutate(mesh.std = case_when(gid == 2 & mesh < 150 ~ 125,
    #                            gid == 2 & between(mesh, 150, 200) ~ 175,
    #                            gid == 2 & between(mesh, 201, 250) ~ 225,
    #                            gid == 2 & between(mesh, 250, 300) ~ 275,
    #                            gid == 2 & mesh > 300 ~ 325,
    #                            gid == 2 & is.na(mesh) ~ 275))
  }

  return(q)

}

lb_std_meshsize <- function(d) {
  d %>%
    dplyr::mutate(mesh.std = dplyr::case_when(gid == 2 ~ 0L,
                                              gid ==  9 ~ 80L,
                                              gid %in% c(7, 10, 12, 14) ~ 40L,
                                              gid %in% c(5, 6) & (mesh <= 147 | is.na(mesh)) ~ 135L,
                                              gid %in% c(5, 6) &  mesh >  147 ~ 155L,
                                              gid %in% c(15, 38, 40) ~ 100L,
                                              TRUE ~ NA_integer_))

}
