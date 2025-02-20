#' @title  Get Flowline Node
#' @description Given one or more flowlines, returns
#'   a particular node from the flowline.
#' @param x sf data.frame with one or more flowlines
#' @param position character either "start" or "end"
#' @export
#' @return sf data.frame containing requested nodes
#' @importFrom sf st_crs st_coordinates st_as_sf
#' @importFrom dplyr select group_by filter row_number n ungroup
#' @examples
#'
#' source(system.file("extdata/sample_data.R", package = "nhdplusTools"))
#'
#' fline <- sf::read_sf(sample_data, "NHDFlowline_Network")
#'
#' start <- get_node(fline, "start")
#' end <- get_node(fline, "end")
#'
#' plot(sf::st_zm(fline$geom),
#'      lwd = fline$StreamOrde, col = "blue")
#' plot(sf::st_geometry(start), add = TRUE)
#'
#' plot(sf::st_zm(fline$geom),
#'      lwd = fline$StreamOrde, col = "blue")
#' plot(sf::st_geometry(end), add = TRUE)
#'
get_node <- function(x, position = "end") {
  in_crs <- st_crs(x)

  x <- x %>%
    st_coordinates() %>%
    as.data.frame()

  if("L2" %in% names(x)) {
    x <- group_by(x, .data$L2)
  } else {
    x <- group_by(x, .data$L1)
  }

  if(position == "end") {
    x <- filter(x, row_number() == n())
  } else if(position == "start") {
    x <- filter(x, row_number() == 1)
  }

  x <- dplyr::select(ungroup(x), .data$X, .data$Y)

  st_as_sf(x, coords = c("X", "Y"), crs = in_crs)
}

#' Fix flow direction
#' @description If flowlines aren't digitized in the expected direction,
#' this will reorder the nodes so they are.
#' @param comid The COMID of the flowline to check
#' @param network The entire network to check from. Requires a "toCOMID" field.
#' @return a geometry for the feature that has been reversed if needed.
#' @importFrom sf st_reverse st_join st_geometry
#' @export
#' @examples
#'
#' source(system.file("extdata/sample_data.R", package = "nhdplusTools"))
#'
#' fline <- sf::read_sf(sample_data, "NHDFlowline_Network")
#'
#' # We add a tocomid with prepare_nhdplus
#' fline <- sf::st_sf(prepare_nhdplus(fline, 0, 0, 0, FALSE),
#'                    geom = sf::st_zm(sf::st_geometry(fline)))
#'
#' # Look at the end node of the 10th line.
#' (n1 <- get_node(fline[10, ], position = "end"))
#'
#' # Break the geometry by reversing it.
#' sf::st_geometry(fline)[10] <- sf::st_reverse(sf::st_geometry(fline)[10])
#'
#' # Note that the end node is different now.
#' (n2 <- get_node(fline[10, ], position = "end"))
#'
#' # Pass the broken geometry to fix_flowdir with the network for toCOMID
#' sf::st_geometry(fline)[10] <- fix_flowdir(fline$COMID[10], fline)
#'
#' # Note that the geometry is now in the right order.
#' (n3 <- get_node(fline[10, ], position = "end"))
#'
#' plot(sf::st_geometry(fline)[10])
#' plot(n1, add = TRUE)
#' plot(n2, add = TRUE, col = "blue")
#' plot(n3, add = TRUE, cex = 2, col = "red")
#'

fix_flowdir <- function(comid, network) {

  network <- check_names(network,
                         "fix_flowdir",
                         tolower = TRUE)

  try({

    f <- network[network$comid == comid, ]

    #FIXME: consider not supporting na tocomid
    if(is.na(f$tocomid) | f$tocomid == 0) {

      check_line <- network[network$tocomid == f$comid, ][1, ]

      check_position <- "start"

    } else {

      check_line <- network[network$comid == f$tocomid, ][1, ]

      check_position <- "end"

    }

    suppressMessages(
      check_end <- st_join(get_node(f, position = check_position),
                           select(check_line, check_comid = .data$comid)))

    reverse <- is.na(check_end$check_comid)

    if(reverse) {
      st_geometry(f)[reverse] <- st_reverse(st_geometry(f)[reverse])
    }

    return(st_geometry(f))
  })
}
