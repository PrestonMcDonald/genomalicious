#' Compare simulated and observed inferred genetic relationships
#'
#' This function can help compare observed estimates of relatedness to expected
#' values of relatedness for different familial relationships given a set of
#' loci and population alelle frequencies. It returns a data table combining
#' the simulated and observed estiamtes and a plot of density curves overlaying
#' the distribution of observed relatedness estimates on top of simulated values.
#'
#' The function takes the output of \code{family_sim_data} and additional calculations
#' of the genetic relationiship matrix (GRM) that are performed by the user on
#' the simulated and observed individuals.
#'
#' @param simFamily Data.table: The output from from the function \code{family_sim_data}.
#' Contains a set of simulated individuals with known familial relationships,
#' given a set of loci and their population allele frequencies.
#'
#' @param simGRM Matrix: The simulated GRM using the individuals generated
#' from \code{family_sim_data}. See Details.
#'
#' @param obsGRM Matrix: The observed GRM using the observed individuals.
#' See Details.
#'
#' @param numSims Integer: The number of simulated individuals for each family
#' relationship. Default is 100.
#'
#' @param look Character: The look of the plot. Default = \code{'ggplot'}, the
#' typical gray background with gridlines produced by \code{ggplot2}. Alternatively,
#' when set to \code{'classic'}, produces a base R style plot.
#'
#' @param legendPos Character: Where should the legend be positioned? Default is
#' \code{'top'}, but could also be one of, \code{'right'}, \code{'bottom'},
#' \code{'left'}, or \code{'none'}.
#'
#' @param curveAlpha Numeric: A value between 0 and 1 to set the transparency of
#' the density curves. Default = 0.7.
#'
#' @param curveFill Character: A vector of colours to fill density curves,
#' but is an optional argument. Default = \code{NULL}. If specified, must be
#' a length of 5, with colours corresponding to the levels 'Unrelated', 'Cousins',
#' 'Half-siblings', 'Siblings', and 'Observed', in that order.
#'
#' @param curveOutline Character: A vector of colours to for density curve outlines,
#' but is an optional argument. Default = \code{NULL}. If specified, must be
#' a length of 5, with colours corresponding to the levels 'Unrelated', 'Cousins',
#' 'Half-siblings', 'Siblings', and 'Observed', in that order.
#'
#' @details The GRMs for arguments \code{simGRM} and \code{obsGRM} need to be
#' created by the user with whatever program they want to use to calculate
#' pairwise relatedness among individuals. The same function call should be used
#' ob both datasets. The GRM should be a square matrix with the relatedness of
#' individuals to themselves on the diagonal, and their relatedness to other
#' individuals on the off-diagonal.
#'
#' @returns Returns two objects. The first is data.table with the following columns:
#' \enumerate{
#'    \item \code{$SIM}, the simulation number for pairs of simulated individuals,
#'    or 'NA' for the pairs of observed individuals.
#'    \item \code{$SAMPLE1}, the sample ID for the first individual.
#'    \item \code{$SAMPLE2}, the sample ID for the second individual.
#'    \item \code{$FAMILY}, the familial relationship for simulated individuals.
#'    \item \code{$RELATE}, the estimated relatedness.
#' }
#'
#' The second is a ggplot object which plots density curves for the estimated
#' relatedness values calculated for simulated pairs of unrelated individuals,
#' cousins, half-siblings, and siblings, with the observed relatedness values
#' from the user's dataset overlayed. Dashed lines are used to demarcate the
#' theoretical expected relatedness values for unrelated individuals (0),
#' cousins (0.125), half-siblings (0.25), and siblings (0.5).
#'
#' @examples
#' library(genomalicious)
#' data(data_Genos)
#'
#' # Subset Pop1 genotypes
#' genosPop1 <- data_Genos[POP=='Pop1', c('SAMPLE', 'LOCUS', 'GT')]
#'
#' # Get the allele frequencies for Pop1
#' freqsPop1 <- genosPop1[, .(FREQ=sum(GT)/(length(GT)*2)), by=LOCUS]
#'
#' # Simulate 100 families
#' simFamily <- family_sim_data(
#'    freqData=freqsPop1,
#'    locusCol='LOCUS',
#'    freqCol='FREQ',
#'    numSims=100
#' )
#'
#' # Create some siblings in Pop1 from two sets of parents
#' parentList <- list(c('Ind1_1','Ind1_2'), c('Ind1_29','Ind1_30'))
#' genosSibs <- lapply(1:2, function(i){
#'   parents <- parentList[[i]]
#'
#'   child <- paste(sub('Ind1_', '', parents), collapse='.')
#'
#'   gamete1 <- genosPop1[SAMPLE == parents[1]] %>%
#'     .[, .(GAMETE=rbinom(n=2,size=1,prob=GT/2)), by=c('SAMPLE','LOCUS')] %>%
#'     .[, SIB:=1:2, by=LOCUS]
#'
#'   gamete2 <- genosPop1[SAMPLE == parents[2]] %>%
#'     .[, .(GAMETE=rbinom(n=2,size=1,prob=GT/2)), by=c('SAMPLE','LOCUS')] %>%
#'     .[, SIB:=1:2, by=LOCUS]
#'
#'   rbind(gamete1, gamete2) %>%
#'     .[, .(GT=sum(GAMETE)), by=c('LOCUS','SIB')] %>%
#'     .[, SAMPLE:=paste0('Child_',child,'_',SIB)] %>% print
#' }) %>%
#'   do.call('rbind', .)
#'
#' ### THE OBSERVED GENETIC RELATIONSHIPS MATRIX
#' library(AGHmatrix)
#'
#' # Combine the population samples and the created siblings
#' # into a single genotype matrix
#' obsGenosMat <- rbind(genosPop1, genosSibs[, c('SAMPLE','LOCUS','GT')]) %>%
#'   DT2Mat_genos()
#'
#' # Calculate the GRM
#' obsGRM <- Gmatrix(obsGenosMat, method='Yang', ploidy=2)
#'
#' ### THE SIMULATED GENETIC RELATIONSHIPS MATRIX
#' # Convert simulated families into a genotype matrix
#' simGenosMat <- DT2Mat_genos(simFamily)
#'
#' # Calculate the GRM
#' simGRM <- Gmatrix(simGenosMat, method='Yang', ploidy=2)
#'
#' ### COMPARE THE OBSERVED AND SIMULATED
#' relComp <- family_sim_compare(
#'    simFamily=simFamily,
#'    simGRM=simGRM,
#'    obsGRM=obsGRM,
#'    look='classic'
#' )
#'
#' # The data
#' relComp$data
#'
#' # Plot of relatedness values. Dashed lines denote relatedness
#' # values of 0, 0.125, 0.25, and 0.5, which are the theoretical
#' # expectations for unrelated individuals, cousins, half-siblings,
#' # and siblings, respectively.
#' # You will note a large variance are the expected values, which
#' # is not surprising for this very small SNP dataset (200 loci).
#' relComp$plot
#'
#' # Take a look at the "known" relationships in the observed dataset
#' # Note, siblings and parent-offspring pairs have a theoretical
#' # relatedness of 0.5. But you will probably find the "observed"
#' # relatedness values are much lower.
#' relComp$data[SAMPLE1=='Child_1.2_1' & SAMPLE2%in%c('Child_1.2_2','Ind1_1','Ind1_2')]
#' relComp$data[SAMPLE1=='Child_29.30_1' & SAMPLE2%in%c('Child_29.30_2','Ind1_29','Ind1_30')]
#'
#' # Now take a look at the simulated distribution.
#' relComp$data[FAMILY=='Half-siblings']$RELATE %>% summary()
#' relComp$data[FAMILY=='Siblings']$RELATE %>% summary()
#'
#' @export

family_sim_compare <- function(
    simFamily, simGRM, obsGRM, plotColous=NULL, look='ggplot', legendPos='right',
    curveAlpha=0.7, curveFill=NULL, curveOutline=NULL
){
  # --------------------------------------------+
  # Libraries and assertions
  # --------------------------------------------+
  require(data.table); require(ggplot2); require(tidyverse)

  # Adjust values for curveOutline if NULL or if length != 5
  if(is.null(curveOutline)){
    curveOutline <- rep('grey20', 5)
  }

  if(length(curveOutline)<5){
    curveOutline <- rep(curveOutline[1], 5)
  }

  # Check that fill colours are specified correctly if NULL, and
  # if not NULL, make sure there are only 5 colours
  if(!is.null(curveFill)){
    if(length(curveFill)!=5){
      stop('Argument `curveFill` must be a character vector of 5 colours. See ?family_sim_plot.')
    }
  }

  if(is.null(curveFill)){
    curveFill <- c("#F05F5F", "#E8CE00", "#54C567", "#4F9CE6", "#B54ECD")
  }

  # Legend position
  if(!legendPos %in% c('top','right','left','bottom')){
    stop('Argument `legendPos` must be on of "top", "right", "left", and "bottom". See ?family_sim_plot.')
  }

  # Set the plot theme by look
  if(!look %in% c('ggplot','classic')){
    stop('Argument `look` must be one of "ggplot" or "classic". See ?family_sim_plot.')
  }

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

  # --------------------------------------------+
  # Code
  # --------------------------------------------+
  # Number of sims
  numSims <- simFamily$SIM %>% max

  # Compile the relatedness data table from simulated and observed GRMs.
  simRel <- lapply(1:numSims, function(sim){
    # Line up the known pairs. Note, that samples with "G3.2" are half-siblings
    # with "G3.3" and cousins with "G3.4". But these relationships are not
    # included to keep things balanced.
    unrel <- c(paste0('S',sim,c('_UR.1','_UR.2')))
    sibs <- c(paste0('S',sim,c('_G3.1','_G3.2')))
    halfsibs <- c(paste0('S',sim,c('_G3.1','_G3.3')))
    cousins <- c(paste0('S',sim,c('_G3.1','_G3.4')))

    data.table(
      SIM=sim,
      SAMPLE1=c(unrel[1],sibs[1],halfsibs[1],cousins[1]),
      SAMPLE2=c(unrel[2],sibs[2],halfsibs[2],cousins[2]),
      FAMILY=c('Unrelated','Siblings','Half-siblings','Cousins'),
      RELATE=c(
        simGRM[unrel[1],unrel[2]],
        simGRM[sibs[1],sibs[2]],
        simGRM[halfsibs[1],halfsibs[2]],
        simGRM[cousins[1],cousins[2]]
      )
    )
  }) %>%
    do.call('rbind', .)

  obsRel <- combn(colnames(obsGRM),2) %>%
    apply(., 2, function(x){
      data.table(SIM=NA, SAMPLE1=x[1], SAMPLE2=x[2], FAMILY='Observed', RELATE=obsGRM[x[1],x[2]])
      }) %>%
    do.call('rbind', .)

  # Make the data
  rel_data <- rbind(obsRel, simRel) %>%
    as.data.table %>%
    .[, FAMILY:=factor(FAMILY, levels=c('Unrelated','Cousins','Half-siblings','Siblings','Observed'))]

  # Make the plot
  rel_gg <- ggplot(rel_data, aes(x=RELATE, fill=FAMILY, colour=FAMILY)) +
    plotTheme +
    geom_density(alpha=curveAlpha,position="identity") +
    geom_vline(xintercept=c(0,0.125,0.25,0.5), linetype='longdash') +
    scale_colour_manual(values=curveOutline) +
    scale_fill_manual(values=curveFill) +
    scale_x_continuous(breaks=seq(-0.1, 1, 0.1)) +
    labs(x='Relatedness', y='Density', fill='', colour='')

  # Return a list
  list(data=rel_data, plot=rel_gg) %>% return()
}

