# Source: Suzanne via
# * ViewFullTable:
# https://github.com/forestgeo/fgeo.data/issues/24#issuecomment-400262852
# * ViewTaxonomy: https://goo.gl/hkiKUW

set.seed(123)
library(luquillo)
library(tidyverse)



# ViewTaxonomy # ------------------------------------------------------------

luquillo_taxa <- luquillo::ViewTaxonomy_luquillo
# "spec" must have come from reading with readr.
attr(luquillo_taxa, "spec") <- NULL

# Allow downloading as .csv.
write_tsv(luquillo_taxa, here::here("data-raw/luquillo_taxa.csv"))
use_data(luquillo_taxa, overwrite = TRUE)



# ViewFullTable # -----------------------------------------------------------

luquillo_vft <- luquillo::ViewFullTable_luquillo

# Choose 1000 tags at random from the entire plot
tags_random <- luquillo_vft %>% 
  filter(CensusID == 6) %>%
  pull(Tag) %>% 
  unique() %>% 
  sample(1000, replace = FALSE)

# Choose all tags from the most abundant hectare
# Find abundance hectare
ha <- luquillo_vft %>% 
 mutate(
   xha = ggplot2::cut_interval(PX, length = 100),
   yha = ggplot2::cut_interval(PY, length = 100)
 ) %>% 
 filter(!is.na(PX), !is.na(DBH)) %>% 
 group_by(xha, yha) %>% 
 summarise(xn = length(DBH), yn = length(DBH)) %>% 
 select(matches("x|y")) %>% 
 arrange(xn, yn)

# Confirm visually
p <- luquillo_vft %>% 
 filter(!is.na(DBH)) %>% 
 sample_n(10000) %>% 
 ggplot(aes(PX, PY)) + geom_point()
# Most abundant hectare is x = (100,200]; y = (400,500]

tags_1ha <- luquillo_vft %>% 
  filter(between(PX, 100, 200), between(PY, 400, 500)) %>% 
  pull(Tag) %>% 
  unique()

# Keep chosen tags exclusively
luquillo_vft_random <- filter(luquillo_vft, Tag %in% tags_random)
# Allow downloading entire vft (all censuses) as .csv
write_tsv(luquillo_vft_random, here::here("data-raw/luquillo_vft_random.csv"))
# luquillo_vft_random not saved in data/ to save space

luquillo_vft_1ha <- filter(luquillo_vft, Tag %in% tags_1ha)
# Allow downloading as .csv
write_tsv(luquillo_vft_1ha, here::here("data-raw/luquillo_vft_1ha.csv"))
# luquillo_vft_1ha not saved in data/ to save space

# Reducing data size even further
luquillo_vft_4quad <- luquillo_vft_1ha %>% 
  # Keep only four quadrats
  filter(between(PX, 100, 140), between(PY, 400, 440)) %>% 
  # Keep only two censuses
  filter(CensusID  %in% 4:6)

attr(luquillo_vft_4quad, "spec") <- NULL
use_data(luquillo_vft_4quad, overwrite = TRUE)



# Tree and stem tables ----------------------------------------------------

if (fs::dir_exists("data-raw/private/")) {
  fs::dir_delete("data-raw/private/")
}

# Build new tables: 1ha

# Create folders in working directory
rtbl::rtbl(
  luquillo_vft_1ha,
  luquillo_taxa,
  plotname = "luquillo"
)

# Move folders to a private directory
path_1ha <- here::here("data-raw/private/rtbl_1ha")
fs::dir_create(path_1ha)
folders <- c("stem", "full", "RAnalyticalTables")
purrr::map(folders, fs::file_move, path_1ha)



# Build new tables: random

# Create folders in working directory
rtbl::rtbl(
  luquillo_vft_random,
  luquillo_taxa,
  plotname = "luquillo"
)

# Move folders to a private directory
path_random <- here::here("data-raw/private/rtbl_random")
purrr::map(folders, fs::file_move, path_random)

# FIXME: stem tables end up in wrong directory. This code does the fix had-hoc
path_random <- here::here("data-raw/private/rtbl_random")
stem_tables <- fs::dir_ls(path_random, regexp = "stem..rdata")
path_stem <- fs::path(path_random, "stem")
fs::dir_create(path_stem)
purrr::map(stem_tables, fs::file_move, path_stem)



# Load and use_data()

load_ls <- function(path, env) {
  path %>% 
  purrr::map(fs::dir_ls) %>% 
  purrr::map(fs::dir_ls) %>% 
  purrr::reduce(c) %>% 
  lapply(load, env)
}

compile_census <- function(.x, table) {
  .x %>% 
    purrr::keep(grepl(table, names(ls_1ha))) %>% 
    purrr::map(as.tibble) %>% 
    purrr::map(., 
      ~dplyr::mutate(., CensusID = unique(CensusID[!is.na(CensusID)]))
    ) %>% 
    purrr::reduce(rbind)
}



# 1 hectare

env_1ha <- new.env(parent = .GlobalEnv)
here::here("data-raw/private/rtbl_1ha") %>% 
  load_ls(env_1ha)
ls_1ha <- as.list(env_1ha)

# luquillo_tree_1ha not saved to save space. Tree can be reproduced from stem.

luquillo_tree6_1ha <- as.tibble(ls_1ha$luquillo.full6)
use_data(luquillo_tree6_1ha, overwrite = TRUE)

luquillo_stem6_1ha <- as.tibble(ls_1ha$luquillo.stem6)
use_data(luquillo_stem6_1ha, overwrite = TRUE)



# Random

env_random <- new.env(parent = .GlobalEnv)
here::here("data-raw/private/rtbl_random") %>% 
  load_ls(env_random)
ls_random <- as.list(env_random)

# luquillo_tree_random not saved to save space. It can be reproduced from stem.

luquillo_tree5_random <- as.tibble(ls_random$luquillo.full5)
use_data(luquillo_tree5_random, overwrite = TRUE)

luquillo_tree6_random <- as.tibble(ls_random$luquillo.full6)
use_data(luquillo_tree6_random, overwrite = TRUE)

luquillo_stem_random <- compile_census(ls_random, "stem")
use_data(luquillo_stem_random, overwrite = TRUE)

luquillo_stem5_random <- as.tibble(ls_random$luquillo.stem5)
use_data(luquillo_stem5_random, overwrite = TRUE)

luquillo_stem6_random <- as.tibble(ls_random$luquillo.stem6)
use_data(luquillo_stem6_random, overwrite = TRUE)

if (fs::dir_exists("data-raw/private/")) {
  fs::dir_delete("data-raw/private/")
}

# Species table -----------------------------------------------------------

luquillo_species <- as.tibble(ls_1ha$luquillo.spptable)
use_data(luquillo_species, overwrite = TRUE)



# Elevation ---------------------------------------------------------------

# Source: Suzanne Lao via http://bit.ly/2JaKqwi

load(here::here("data-raw/CTFSElev_luquillo.rdata"))
luquillo_elevation <- CTFSElev_luquillo
luquillo_elevation$col <- as.tibble(luquillo_elevation$col)
use_data(luquillo_elevation, overwrite = TRUE)



# Habitat -----------------------------------------------------------------

# > We don't have habitat data.  We have soil maps, topographic classes, and
# land use, etc.  Probably easiest if you use elevation chunks. 
# --Jess K. Zimmerman

# On Fri, Mar 24, 2017 at 4:28 PM, Davies, Stuart J. <DaviesS@si.edu> wrote:
# One quick way to make habitats is just divide quadrats into 4 or 5 equal
# elevation chunks.

luquillo_habitat <- fgeo.analyze::fgeo_habitat(
  fgeo.data::luquillo_elevation, gridsize = 20, n = 4, only_elev = FALSE,
  edgecorrect = TRUE
)
use_data(luquillo_habitat, overwrite = TRUE)



# Toy ---------------------------------------------------------------------
set.seed(123)
library(tidyverse)

luquillo_stem_random <- luquillo_stem_random %>% as.tibble()

# Most and least abundant species
top_sp <- luquillo_stem_random %>% 
  count(sp) %>% 
  top_n(3) %>% 
  pull(sp) %>% 
  sample(3)
bottom_sp <- luquillo_stem_random %>% 
  count(sp) %>% 
  top_n(-3) %>% 
  pull(sp) %>% 
  sample(3)
keep_sp <- c(top_sp, bottom_sp)

# Two quadrats where the kept species are most abundant
two_abundant_quads <- luquillo_stem_random %>% 
  filter(sp %in% keep_sp) %>% 
  filter(!is.na(dbh)) %>% 
  count(quadrat) %>% 
  top_n(2) %>% 
  pull(quadrat) %>% 
  sample(2)

luquillo_stem_random_tiny <- luquillo_stem_random %>% 
  filter(
    sp %in% keep_sp,
    quadrat %in% two_abundant_quads
  )

use_data(luquillo_stem_random_tiny, overwrite = TRUE)
