#' Prepare input for density plot 
#'
#' @param datain data.table with genenames in first columns and samples in following
#' @return data.frame 
#'
prepare_density_plot_input <- function(datain) {
    if(is.null(datain)) { return() }

    # Rename first column to identifier
    datain %>% dplyr::rename_(identifier = as.symbol(colnames(datain)[1])) %>%
    # Convert to long
    tidyr::gather(sample, value, -identifier) %>%
    # Ugly and slow but works for now    
    as.data.frame()
}

#' Create density plots for input data
#' 
#' @param datain data.table with genenames in first columns and samples in following
#' @return ggvis
#'
plot_density <- function(datain) {
    properties_y <- ggvis::axis_props(labels=list(fontSize=12), title=list(fontSize=12, dy=-35))
    properties_x <- ggvis::axis_props(labels=list(fontSize=12), title=list(fontSize=12, dx=-35))
    # Create plot 
    datain %>%
    ggvis::ggvis(~value) %>% ggvis::group_by(sample) %>%
    ggvis::layer_densities(stroke = ~sample, fill := NA) %>%
    ggvis::add_axis('y',  properties=properties_y) %>%
    ggvis::add_axis('x',  properties=properties_x)
}


#' Check if datain is a valid es. Experimental.
#' 
#' @param datain data.frame
#' @return single logical value with message attribute
#'
datain_is_valid <- function(datain) {
    not_all_numeric <- function(x) !all(sapply(x, is.numeric))
    valid <- TRUE
    
    if(is.null(datain) || !is.data.frame(datain)) {
        valid <- FALSE
        attributes(valid)$message <- 'To select samples you have to upload valid dataset.'
    } else if (ncol(datain) < 5) {
        valid <- FALSE
        attributes(valid)$message <- 'You need at least four samples to run Characteristic Direction Analysis'
    } else if(
        datain %>% 
            dplyr::select_(-1) %>%
            not_all_numeric()
    ) {
        valid <- FALSE
        attributes(valid)$message <- 'Your dataset contains non-numeric entries'
    }
    valid
}


#' log2 transform expression data
#' 
#' @param datain data.frame
#' @return data.frame where columns 2:ncol are log2 transformed
#'
datain_log2_transform <- function(datain) {
    adjust <- function(x) { x + 1e-21 }
    data.table(
        datain %>% dplyr::select_(1),
        datain %>% dplyr::select_(-1) %>% adjust() %>% log2()
    )
}


#' quantile normalize expression data
#'
#' @param datain data.frame
#' @param add_noise logical should we add random noise after quantile normalization
#' @return data.frame where columns 2:ncol are quantile normalized
#'
datain_quantile_normalize <- function(datain, add_noise=TRUE) {
    add_noise <- if(add_noise) { function(x) x + runif(length(x), 0, 1e-12) } else { identity }
    
    setNames(
        data.table(
            datain %>% dplyr::select_(1),
            datain %>% dplyr::select_(-1) %>% as.matrix() %>%
            preprocessCore::normalize.quantiles() %>% 
            # Ugly workaround for issue with GeoDE 
            # TODO Remove as soon as possible 
            as.data.frame() %>% 
            dplyr::mutate_each(dplyr::funs(add_noise))
        ),
        colnames(datain)
    )
}


#' Filter datain
#'
#' @param datain data.frame 
#' @param id_filter icu regex or NULL
#' @return data.table
#'
datain_filter <- function(datain, id_filter=NULL) {
    opts_regex <- stringi::stri_opts_regex(case_insensitive=TRUE)
    
    if(!is.null(id_filter))  {
        datain %>%
            dplyr::rename_(IDENTIFIER=as.symbol(colnames(datain)[1])) %>%
            dplyr::filter(!stringi::stri_detect_regex(IDENTIFIER, id_filter, opts_regex=opts_regex))
    } else {
        datain
    }
}


#' Apply preprocesing steps to expression data
#'
#' @param datain data.frame 
#' @param log2_transform logical
#' @param quantile_normalize logical
#' @param id_filter icu regex or NULL
#' @return data.table
#'
datain_preprocess <- function(datain, log2_transform=FALSE, quantile_normalize=FALSE, id_filter=NULL) {
    log2_f <- if(log2_transform) { datain_log2_transform } else { identity }
    quant_norm_f <- if(quantile_normalize) { datain_quantile_normalize } else { identity }
    
    datain %>% datain_filter(id_filter=id_filter) %>% log2_f() %>% quant_norm_f() %>% na.omit()
}


