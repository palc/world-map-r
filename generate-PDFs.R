#!/usr/bin/env Rscript

suppressMessages(library(ggplot2))

#############################################################################
# Feel free to edit the stuff below
#############################################################################

DATA_FILE="./data.txt"
CIRCLE_SIZE_PREFIX_IN_DATA_FILE="MAG_"
CIRCLE_DYNAMIC_COLOR_PREFIX_IN_DATA_FILE=""

# shape file. if you have a shapefile to work with, describe it here. if you
# fill in this variable, the code will use your shape file instead of the
# low resolution default world map (please see the README if you are not sure
# what is going on and would like to learn more):
SHAPEFILE=""

# Interface toys down below
FONT_SIZE <- 2 # set it to 0 to see no labels
FONT_COLOR="black"

# If you want each circle on the map to be colored according to a color gradient,
# provide low- and high-value colors. Otherwise, set CIRCLE_COLOR_LOW to your
# static color of interest (CIRCLE_COLOR_HIGH will be ignored).
CIRCLE_COLOR_LOW="red"
CIRCLE_COLOR_HIGH="yellow"

# translucency of circles. 1 is opaque, 0 is transparent
ALPHA <- 0.90

# thickness of border around each circle. 0 for no border
CIRCLE_BORDER_WIDTH <- 0.1

# scaling points
MIN_POINT_SIZE <- 0.2
MAX_POINT_SIZE <- 15

MARGIN_MIN_LAT <- -5
MARGIN_MAX_LAT <- 5
MARGIN_MIN_LON <- -5
MARGIN_MAX_LON <- 5

PDF_WIDTH <- 12
PDF_HEIGHT <- 5.5

#############################################################################

gen_blank_world_map_simple <- function(df) {
  suppressMessages(library(maps))

  world_map <- map_data("world")

  min_lat <- min(df$Lat) + MARGIN_MIN_LAT
  max_lat <- max(df$Lat) + MARGIN_MAX_LAT
  min_lon <- min(df$Lon) + MARGIN_MIN_LON
  max_lon <- max(df$Lon) + MARGIN_MAX_LON

  p <- ggplot(data=world_map,aes(x=long, y=lat, group=group))
  p <- p + geom_polygon(fill = '#777777')
  p <- p + coord_cartesian(xlim = c(min_lon, max_lon),
                           ylim = c(min_lat, max_lat))

  return(p)
}

gen_blank_world_map_with_shape_file <- function(df) {
  suppressMessages(library(rgdal))
  suppressMessages(library(raster))

  world_map <- fortify(shapefile(SHAPEFILE))

  min_lat <- min(df$Lat) + MARGIN_MIN_LAT
  max_lat <- max(df$Lat) + MARGIN_MAX_LAT
  min_lon <- min(df$Lon) + MARGIN_MIN_LON
  max_lon <- max(df$Lon) + MARGIN_MAX_LON

  p <- ggplot()
  p <- ggplot(data=world_map,aes(x=long, y=lat, group=group))
  p <- p + geom_polygon(fill = '#777777', size = 10)
  p <- p + coord_map(projection = "mercator", xlim = c(min_lon, max_lon),
  ylim = c(min_lat, max_lat))

  return(p)
}

add_mag_abundances <- function(plot_object, df, mag, mag_color=NULL, color_low=NULL, color_high=NULL, alpha=0.2, labels = TRUE){
  if (!is.null(mag_color)) {
    plot_object <- plot_object + geom_point(data = df,
                                            aes_string(x="Lon", y="Lat",
                                                       group=mag,
                                                       size=mag,
                                                       color=mag_color),
                                            stroke = 0,
                                            alpha=ALPHA)

    plot_object <- plot_object + scale_colour_gradient(low = color_low, high = color_high)

  } else {
    plot_object <- plot_object + geom_point(data = df,
                                            aes_string(x="Lon", y="Lat",
                                                       group=mag,
                                                       size=mag),
                                            color=CIRCLE_COLOR_LOW,
                                            stroke = 0,
                                            alpha=ALPHA)
  }

  if (CIRCLE_BORDER_WIDTH == 0) {
    # borders have lower limit stroke thickness
    alpha_for_border = 0
  } else {
    alpha_for_border = ALPHA
  }
  plot_object <- plot_object + geom_point(data = df,
                                          shape = 21,
                                          colour = "black",
                                          aes_string(x="Lon", y="Lat",
                                                     group=mag,
                                                     size=mag),
                                          stroke = CIRCLE_BORDER_WIDTH,
                                          alpha=alpha_for_border)

  plot_object <- plot_object + geom_text(data = df,
                                         aes(x=Lon, y=Lat,
                                             group='text',
                                             label=samples),
                                         size=FONT_SIZE,
                                         color=FONT_COLOR,
                                         vjust=1,
                                         nudge_y=-1)

  plot_object <- plot_object + scale_size(range=c(MIN_POINT_SIZE,
                                                  MAX_POINT_SIZE))

  return(plot_object)
}

clean_map <- function(plot_object){
  plot_object <- plot_object +
    xlab(NULL) + ylab(NULL) +
    theme(panel.grid.major = element_blank()) +
    theme(panel.grid.minor = element_blank()) +
    theme(panel.background = element_rect(colour = "gray"))
  return(plot_object)
}

# get the data
df <- read.table(file = DATA_FILE,
                 header = TRUE,
                 sep = "\t",
                 quote = "",
                 comment.char = '!')

# learn about columns that show distribution of MAGs
MAGs <- names(df)[startsWith(names(df), CIRCLE_SIZE_PREFIX_IN_DATA_FILE)]

# go through each MAG, and create a single image.
for (MAG in MAGs){
  cat(sprintf("Working on %s", MAG))

  # sort out the colors
  if (CIRCLE_DYNAMIC_COLOR_PREFIX_IN_DATA_FILE == "") {
    # no color columns. just use static color
    color_column = NULL
    cat(sprintf(" ... dynamic color [-]", MAG))
  } else {
    # search for corresponding color column for MAG
    suffix <- gsub(CIRCLE_SIZE_PREFIX_IN_DATA_FILE, "", MAG)
    color_column <- paste(CIRCLE_DYNAMIC_COLOR_PREFIX_IN_DATA_FILE, suffix, sep="")

    if (!(color_column %in% colnames(df))) {
      color_column <- NULL
      cat(sprintf(" ... dynamic color [-]"))
    } else {
      cat(sprintf(" ... dynamic color [+]"))
    }
  }

  # get a blank world map
  if (is.na(SHAPEFILE) || SHAPEFILE == '')
    world_map <- gen_blank_world_map_simple(df)
  else
    world_map <- gen_blank_world_map_with_shape_file(df)

  # add mag abundances on the canvas
  world_map <- add_mag_abundances(world_map, df, MAG, mag_color=color_column, color_low=CIRCLE_COLOR_LOW, color_high=CIRCLE_COLOR_HIGH, alpha=ALPHA)

  # clean it up
  world_map <- clean_map(world_map)

  # save it
  cat(sprintf(" ... generating the figure"))
  pdf(paste(MAG, '.pdf', sep=''), width=PDF_WIDTH, height=PDF_HEIGHT)
  print(world_map)
  dev.off()
  cat(sprintf(" ... OK\n"))
}

