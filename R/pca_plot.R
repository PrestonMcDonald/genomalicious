#' Plot PCA results
#'
#' Plots results of a PCA, e.g., scatterplot, screeplot, and cumulative
#' explained variance plots. Takes \code{prcomp} object as the main input.
#'
#' @param pcaObj Prcomp object: A PCA of genotype data fitted using the
#' \code{prcomp} function. Either manually fitted, or using \code{genomalicious::pca_genos}.
#'
#' @param type Character: What type of plot to make: a scatterplot (\code{'scatter'}),
#' a screeplot of explained variances (\code{'scree'}), or the cumulative explained
#' variance (\code{'cumvar'}).
#'
#' @param axisIndex Integer: The PC axes to plot. If \code{type=='scatter'},
#' then must be exactly 2 values, the two PC axes to plot as a scatterplot.
#' If either \code{type=='scree'} or \code{type=='cumvar'}, then can be of
#' length from 1 to p, where p is the number of PC axes, and values again
#' represent the desired PC axes to plot.
#'
#' @param pops Character: A vector of population IDs, should match the
#' rows in \code{pcaObj$x}, but is an optional argument. Default = \code{NULL}.
#' The function will search for \code{pcaObj$pops} to assign to this argument
#' if not specified. Only valid when \code{type=='scatter'}.
#'
#' @param plotColours Character: A vector of colours to use for plotting,
#' but is an optional argument. Default = \code{NULL}.
#' When \code{type=='scatter'}, this must be a named list with one colour
#' per population. When \code{type=='scree'} or \code{type=='cumvar'}, only
#' a single colour is required, which is the colour of bars in the screeplot
#' or cumulative variance plot, respectively, and will default to 'grey20'
#' if unspecified.
#'
#' @param look Character: The look of the plot. Default = \code{'ggplot'}, the
#' typical gray background with gridlines produced by \code{ggplot2}. Alternatively,
#' when set to \code{'classic'}, produces a base R style plot.
#'
#' @param legendPos Character: Where should the legend be positioned? Default is
#' \code{'top'}, but could also be one of, \code{'right'}, \code{'bottom'},
#' \code{'left'}, or \code{'none'}.
#'
#' @return Returns a ggplot object.
#'
#' @examples
#' library(genomalicious)
#' data(data_Genos)
#'
#' # Conduct the PCA with Patterson et al.'s (2006) normalisation, and
#' # population specified
#' PCA <- pca_genos(dat=data_Genos, scaling='patterson', popCol='POP')
#'
#' # Plot the PCA
#' pca_plot(PCA)
#'
#' # Plot axies 2 and 3, custom colours, and a classic look.
#' pca_plot(
#'    PCA,
#'    axisIndex=c(2,3),
#'    plotColours=c(Pop1='gray30', Pop2='royalblue', Pop3='palevioletred3', Pop4='plum2'),
#'    look='classic'
#'    )
#'
#' # Explained variance
#' pca_plot(PCA, type='scree')
#'
#' # Cumulative variance for the first 10 axes with custom colour
#' pca_plot(PCA, type='cumvar', axisIndex=1:10, plotColours='royalblue')
#'
#' @export
pca_plot <- function(
    pcaObj, type='scatter', axisIndex=NULL, pops=NULL,
    plotColours=NULL, look='ggplot', legendPos='top'){

  # --------------------------------------------+
  # Libraries and assertions
  # --------------------------------------------+
  for(lib in c('data.table', 'ggplot2')){ require(lib, character.only = TRUE)}

  # Check the pcaObj is the correct data class
  if(!'prcomp' %in% class(pcaObj)){
    stop("Argument `pcaObj` must be a prcomp class object.")
  }

  # Check that type is specified correctly
  if(!type %in% c('scatter', 'scree', 'cumvar')){
    stop("Argument `type` must be either: 'scatter', 'scree', or 'cumvar'.")
  }

  # Check that axisIndex is only length == 2
  if(type=='scatter' & length(axisIndex)>2){
    stop("Argument `axisIndex` should only contain two integer values for type=='scatter'.")
  }
  if(type%in%c('scree','cumvar') & sum(!axisIndex %in% 1:length(pcaObj$sdev))){
    stop("Argument `axisIndex` should only contain values for indexes present in
         pcaObj$sdev for type=='scree' or type=='cumvar'.")
  }

  # Check that look is ggplot or classic.
  if(!look%in%c('ggplot', 'classic')){
    stop("Argument `look` is not one of: 'ggplot' or 'classic'.")
  }

  # Check if there is a $pops index in pcaObj and assign populations if the
  # argument pops is NULL
  if(is.null(pops)){
    if(is.null(pcaObj$pops)==FALSE){ pops <- pcaObj$pops}
  }

  # Check that specified populations in plotColours are all in pops.
  if(type=='scatter' & is.null(pops)==FALSE & is.null(plotColours)==FALSE &
     !sum(names(plotColours)%in%unique(pops))==length(unique(pops))){
    stop("Argument plotColours misspecified: names of colours must be in argument pops.")
  }

  # Specify axes if unassigned
  if(type=='scatter' & is.null(axisIndex)){
    axisIndex <- c(1,2)
  }

  if(type%in%c('scree','cumvar') & is.null(axisIndex)){
    axisIndex <- 1:length(pcaObj$sdev)
  }

  # Assign colour if unspecified for scree and cumulative variance plots.
  if(type%in%c('scree','cumvar') & is.null(plotColours)){
    plotColours <- 'grey20'
  }

  # Set the plot theme by look
  if(look=='ggplot'){
    plotTheme <- theme_gray() + theme(legend.position=legendPos, axis.ticks.length = unit(0.2, 'cm'))
  } else if(look=='classic'){
    plotTheme <- theme_bw() + theme(
      panel.grid.major=element_blank()
      , panel.grid.minor=element_blank()
      , text=element_text(colour='black')
      , legend.position=legendPos
      , axis.ticks.length=unit(0.2, 'cm'))
  }

  # Make pcaObj a data table of PC scores
  if(class(pcaObj)=='prcomp'){ plot.tab <- as.data.table(pcaObj$x) }

  # If pops has been assigned, add this as a column to new pcaObj
  if(is.null(pops)==FALSE){
    plot.tab$POP <- pops
  }

  # --------------------------------------------+
  # Code
  # --------------------------------------------+

  if(type=='scatter'){
    # Get axes
    axX <- paste0('PC', axisIndex[1])
    axY <- paste0('PC', axisIndex[2])

    # Percent explained variance
    eigvals <- pcaObj$sdev^2
    varX <- round(eigvals[axisIndex[1]]/sum(eigvals) * 100, 2)
    varY <- round(eigvals[axisIndex[2]]/sum(eigvals) * 100, 2)

    # Create skeleton of plot
    gg <- ggplot(plot.tab, aes_string(x=axX, y=axY)) +
      plotTheme +
      labs(
        x=paste0('PC', axisIndex[1], ' (', varX, '%)')
        , y=paste0('PC', axisIndex[2], ' (', varY, '%)')
      )

    # Add points and population colours if specified
    if(is.null(pops)==TRUE){ gg <- gg + geom_point()
    } else if(is.null(pops)==FALSE & is.null(plotColours)==TRUE){
      gg <- gg + geom_point(aes(colour=POP)) + labs(colour=NULL)
    } else if(is.null(pops)==FALSE & is.null(plotColours)==FALSE){
      gg <- gg + geom_point(aes(colour=POP)) + scale_colour_manual(values=plotColours) + labs(colour=NULL)
    }
  }

  if(type %in% c('scree', 'cumvar')){
    # Vector of number PCs for X axis
    S <- pcaObj$sdev^2
    X <- 1:length(S)

    # If explained variance, divide eigenvalues by sum,
    # also create Y axis label
    if(type=='cumvar'){
      Y <- unlist(lapply(1:length(S), function(i){
        sum(S[1:i])/sum(S) * 100
      }))
      axY <- 'Cumulative variance (%)'
    } else if(type=='scree'){
      Y <- S/sum(S) * 100
      axY <- 'Explained variance (%)'
    }

    # The plot
    gg <- (data.frame(X=X[axisIndex], Y=Y[axisIndex]) %>%
             ggplot(., aes(x=X, y=Y))
           + plotTheme
           + geom_col(fill=plotColours)
           + scale_x_continuous(breaks = ~round(unique(pretty(.))))
           + labs(x='PC axes', y=axY)
    )
  }

  # Plot and return
  return(gg)
}
