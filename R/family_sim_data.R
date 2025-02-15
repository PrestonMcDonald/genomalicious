#' Simulate families of individuals from population allele frequencies
#'
#' This function produces families of siblings, half-siblings, and cousins
#' from observed population allele frequencies. These simulations can
#' then be used to test the power to discern between individuals with different
#' levels of relatedness. Assumes diploid genotypes.
#'
#' The output can be used to generate a simulated genetic relationship matrix (GRM)
#' that can be compared against an observed GRM using the function,
#' \code{family_sim_compare}. This can provide a graphical comparison
#' between the observed and expected (simulated) distribution of relatedness
#' values that you might expect for different familial relationships, given the
#' number of loci and their allele frequencies.
#'
#' @param freqData Data.table: Population allele frequencies.
#'
#' @param locusCol Character: Column name in \code{freqData} with the locus IDs.
#' Default is 'LOCUS'.
#'
#' @param freqCol Character: Column name in \code{freqData} with the allele frequencies.
#' Default is 'FREQ'.
#'
#' @param numSims Integer: The number of simulated individuals for each family
#' relationship. Default is 100.
#'
#' @details Each simulation generates 6 indivduals. A pair of unrelated individuals,
#' and a family of four individuals. Simulated samples have the naming convention
#' [simulation]_[code], with simulations, "S[number]", and codes denoting family
#' relationships within their simulation. Samples with the code, "UR" are an
#' unrelated pair. Samples with the codes "G3.1" and "G3.2" are siblings.
#' Samples with the code "G3.3" are half-siblings with "G3.1" and "G3.2".
#' Samples with the code "G3.4" are cousins with "G3.1" and "G3.2".
#'
#' @returns Returns a data.table with the following columns:
#' \enumerate{
#'    \item \code{$SIM}, the simulation number.
#'    \item \code{$LOCUS}, the locus ID.
#'    \item \code{$SAMPLE}, the sample ID.
#'    \item \code{$GT}, the diploid genotype as counts of the Alt alleles.
#' }
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

family_sim_data <- function(freqData, locusCol='LOCUS', freqCol='FREQ', numSims=100L){
  # --------------------------------------------+
  # Libraries and assertions
  # --------------------------------------------+
  for(lib in c('tidyr', 'data.table')){require(lib, character.only=TRUE)}

  # Check if data.table/can be converted to data.table
  freqData <- as.data.table(freqData)
  if(!'data.table' %in% class(freqData)){
    stop('Argument `freqData` must be a data.table class. See ?sim_family.')
  }

  # Check that columns are specified correctly
  column.check <- sum(c(locusCol,freqCol) %in% colnames(freqData))
  if(column.check!=2){
    stop(
      'Arguments `locusCol` and `freqCol` must be column names in the argument
    freqData. See ?sim_family.')
  }

  # Reassign column names.
  freqData <- freqData %>%
    copy %>%
    setnames(., old=c(locusCol,freqCol), new=c('LOCUS','FREQ'))

  # Check that numSims is >0 and is an integer
  numSims <- as.integer(numSims)
  if(!numSims>0){
    stop('Argument numSims must be an integer >0. See ?sim_family.')
  }

  # --------------------------------------------+
  # Internal functions
  # --------------------------------------------+
  FUN_draw_genos <- function(D, ploidy){
    # Function to create genotypes assuming random binomial draw at
    # each locus. Assumes loci are unlinked.

    # D = data.table of population allele freqs, with columns $LOCUS and $FREQ.
    # ploidy = integer of number of allles per genotype

    D[, .(FREQ=rbinom(n=1, size=ploidy, prob=FREQ)/ploidy), by=LOCUS] %>%
      data.table(PLOIDY=ploidy, .)
  }

  FUN_make_diploid_offspring <- function(D1, D2){
    # Function to create diploid offspring from the allele frequencies of two
    # diploid individuals.

    # D1 and D2 = parental allele frequencies as a data.table for the 1st and 2nd
    # parent, respectively. Contain $LOCUS and $FREQ. In this case, allele freqs
    # represent the relative dosage of a diploid genotype, so 0 = 0/0, 0.5 = 0/1,
    # and 1 = 1/1.

    left_join(
      FUN_draw_genos(D1, ploidy=1) %>%
        setnames(., old='FREQ', new='GAMETE1') %>%
        .[, c('LOCUS','GAMETE1')],
      FUN_draw_genos(D2, ploidy=1) %>%
        setnames(., old='FREQ', new='GAMETE2')%>%
        .[, c('LOCUS','GAMETE2')],
      by='LOCUS'
    ) %>%
      as.data.table %>%
      .[, FREQ:=(GAMETE1 + GAMETE2)/2] %>%
      .[, c('LOCUS','FREQ')] %>%
      data.table(PLOIDY=2, .)
  }

  # --------------------------------------------+
  # Code
  # --------------------------------------------+
  simFamily <- lapply(1:numSims, function(sim){
    # Unrelated parents in G1
    G1.1 <- FUN_draw_genos(freqData, ploidy=2)
    G1.2 <- FUN_draw_genos(freqData, ploidy=2)

    # Siblings in G2
    G2.1 <- FUN_make_diploid_offspring(G1.1, G1.2)
    G2.2 <- FUN_make_diploid_offspring(G1.1, G1.2)

    # Unrelated individuals in G2
    G2.3 <- FUN_draw_genos(freqData, ploidy=2)
    G2.4 <- FUN_draw_genos(freqData, ploidy=2)
    G2.5 <- FUN_draw_genos(freqData, ploidy=2)

    # Siblings in G3
    G3.1 <- FUN_make_diploid_offspring(G2.1, G2.3)
    G3.2 <- FUN_make_diploid_offspring(G2.1, G2.3)

    # Half siblings in G3
    G3.3 <- FUN_make_diploid_offspring(G2.1, G2.4)

    # Cousins in G3
    G3.4 <- FUN_make_diploid_offspring(G2.2, G2.5)

    # Random completely unrelated individuals
    UR.1 <- FUN_draw_genos(freqData, ploidy=2)
    UR.2 <- FUN_draw_genos(freqData, ploidy=2)

    rbind(
      UR.1 %>% data.table(SIM=sim, SAMPLE=paste0('S',sim,'_UR.1')),
      UR.2 %>% data.table(SIM=sim, SAMPLE=paste0('S',sim,'_UR.2')),
      G3.1 %>% data.table(SIM=sim, SAMPLE=paste0('S',sim,'_G3.1')),
      G3.2 %>% data.table(SIM=sim, SAMPLE=paste0('S',sim,'_G3.2')),
      G3.3 %>% data.table(SIM=sim, SAMPLE=paste0('S',sim,'_G3.3')),
      G3.4 %>% data.table(SIM=sim, SAMPLE=paste0('S',sim,'_G3.4'))
    )
  }) %>%
    do.call('rbind', .) %>%
    .[, GT:=FREQ*PLOIDY]

  # Output
  return(simFamily[, c('SIM','SAMPLE','LOCUS','GT')])
}


