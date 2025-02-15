#' Perform a DAPC of individual genotype data in a data table
#'
#' Takes a long-format data table of genotypes and conducts a PCA using R's
#' \code{prcomp} function, then fits a DA using R's \code{lda} function.
#' Can also be used to assess DA model fit using a leave-one-out cross-validation
#' or training-testing partitioning.
#'
#' @param dat Data table: A long data table, e.g. like that imported from
#' \code{genomalicious::vcf2DT}. Genotypes can be coded as '/' separated characters
#' (e.g. '0/0', '0/1', '1/1'), or integers as Alt allele counts (e.g. 0, 1, 2).
#' Must contain the following columns,
#' \enumerate{
#'   \item The population designation (see param \code{popCol})
#'   \item The sampled individuals (see param \code{sampCol}).
#'   \item The locus ID (see param \code{locusCol}).
#'   \item The genotype column (see param \code{genoCol}).
#' }
#'
#' @param popCol Character: An optional argument. The column name with the
#' population information. Default is \code{NULL}. If specified, population
#' membership is stored in the returned object.
#'
#' @param sampCol Character: The column name with the sampled individual information.
#' Default is \code{'SAMPLE'}.
#'
#' @param locusCol Character: The column name with the locus information.
#' Default is \code{'LOCUS'}.
#'
#' @param genoCol Character: The column name with the genotype information.
#' Default is \code{'GT'}.
#'
#' @param scaling Character: How should the data (loci) be scaled for PCA?
#' Default is \code{'covar'} to scale to mean = 0, but variance is not
#' adjusted, i.e. PCA on a covariance matrix. Set to \code{'corr'}
#' to scale to mean = 0 and variance = 1, i.e. PCA on a
#' correlation matrix. Set to \code{'patterson'} to use the
#' Patteron et al. (2006) normalisation. Set to \code{'none'} to
#' if you do not want to do any scaling before PCA.
#'
#' @param pcPreds Integer: The number of leading PC axes to use as predictors
#' of among-population genetic differences in DA. See details.
#'
#' @param method Character: The analysis to perform. Default is \code{'fit'},
#' which is a DAPC fitted to all the samples. \code{'loo_cv'} performs
#' leave-one-out cross-validation, and \code{'train_test'} performs
#' training-testing partitioning, for assessing model fit. See details
#'
#' @param numCores Integer: The number of cores to run leave-one-out cross-validation,
#' only required when \code{method=='loo_cv'}. Default is 1.
#'
#' @param trainProp Numeric: The proportion of the data to reserved as the
#' training set, with the remaining proportion used as the testing set.
#' Default is 0.7. See details.
#'
#' @return Returns a list, whose contents depend on the \code{method} specified.
#'
#' If \code{method=='fit'}, the list contains:
#' \enumerate{
#'   \item \code{$da.fit}: an \code{lda} object, a DA of genotypic PC axes.
#'      If also contains the index \code{$exp.var}, which is the percent of among
#'      population variance captured by each LD axis, and \code{$among.var}, the
#'      percent of among population variance.
#'   \item \code{$da.tab}: a data table of LD axis scores, with columns \code{$POP},
#'      the designated population, \code{$SAMPLE}, the sample ID, \code{$[axis]},
#'      where each \code{[axes]} is a column for a different DA axis.
#'   \item \code{$da.prob}: a data table of posterior probabilities of group
#'      assignment for each sample, with columns \code{$POP}, the designated
#'      population, \code{$SAMPLE}, the sample ID, \code{$POP.PRED}, the predicted
#'      population, \code{$PROB}, the posterior probability for the predicted
#'      populations (sums to 1 across predicted populations per sample).
#'   \item \code{pca.fit}: a \code{prcomp} object, a PCA of genotypes.
#'   \item \code{pca.tab}: a data table of PC axis scores, with columns \code{$POP},
#'      the designated populations, \code{$SAMPLE}, the sample ID, \code{$[axis]},
#'      where each \code{[axes]} is a column for a different PC axis.
#'   \item \code{snp.contrib}: a data table of SNP contributions to LD axes,
#'      with columns, \code{$LOCUS}, the SNP locus, \code{$LD[x]}, the individual
#'      LD axes, with \code{[x]} denoting the axis number.
#' }
#'
#' If \code{method=='loo_cv'} or \code{method=='train_test'}, the list contains:
#' \enumerate{
#'  \item \code{$tab}: a data table of predictions for tested samples, with
#'     columns, \code{$POP}, the designated population, \code{SAMPLE}, the
#'     sample ID, and \code{$POP.PRED}, the predicted population. Note, that
#'     for \code{method=='loo_cv'}, as samples with be present, but for
#'     \code{method=='train_test'}, only the samples retained for the testing
#'     set will be present.
#'  \item \code{$global}: a single numeric, the global \strong{correct} assignment rate.
#'  \item \code{$pairs.long}: a long-format data table, of pairwise population correct
#'     assignment rates, with columns, \code{$POP}, the designated population,
#'     \code{$POP.PRED}, the predicted population, and \code{$ASSIGN}, the
#'     assignment rate. Note, the \strong{correct} assignment rate are those
#'     instances where values in \code{POP==POP.PRED}.
#'  \item \code{$pairs.wide}: a wide-format data table of pairwise population
#'     assignment rates, with columns, \code{$POP}, the designated population,
#'     and \code{$[pop]}, the predicted populations, where each possible predicted
#'     population is a \code{[pop]} column. The cell contents are the assignment
#'     rate, with \strong{correct} assignment rates on the diagonal.
#' }
#'
#' @details DAPC was made popular in the population genetics/molecular ecology
#' community following Jombart et al.'s (2010) paper. The method uses a DA
#' to model the genetic differences among populations using PC axes of genotypes
#' as predictors.
#'
#' The choice of the number of PC axes to use as predictors of genetic
#' differences among populations should be determined using the \emph{k}-1 criterion
#' described in Thia (2022). This criterion is based on the findings of
#' Patterson et al. (2006) that only the leading \emph{k}-1 PC axes of a genotype
#' dataset capture biologically meaningful structure. Users can use the function
#' \code{genomalicious::dapc_infer} to examine eigenvalue screeplots and
#' perform K-means clustering with different parameters to infer the number of
#' biologically informative PC axes.
#'
#' Assessing model fit of DAPC requires partitioning data into sets
#' for training and testing. When \code{method=='loo_cv'}, leave-one-out cross-validation
#' is performed: each ith sample is withheld as a testing sample, the model is
#' fit without the ith sample, and then the model is used to predict the ith sample's
#' population. This method is preferable when sample sizes are small.
#' When \code{method=='train_test'}, a proportion of \code{trainProp} individuals
#' from each populations are used to train the DAPC model which is then used to
#' predict the populations in the remaining testing individuals.
#'
#' @references
#' Jombart et al. (2010) BMC Genetics. DOI: 10.1186/1471-2156-11-94
#' Patterson et al. (2006) PLoS Genetics. DOI: 10.1371/journal.pgen.0020190
#' Thia (2022) Mol. Ecol. DOI: 10.1111/1755-0998.13706
#'
#' @examples
#' library(genomalicious)
#'
#' data(data_Genos)
#'
#' ### Fit the DAPC with the first 3 PC axes as predictors
#' DAPC.fit <- dapc_fit(dat=data_Genos, pcPreds=3, method='fit')
#'
#' # Table of LD and PC axis scores
#' DAPC.fit$da.tab
#' DAPC.fit$pca.tab
#'
#' # The lda and prcomp objects
#' DAPC.fit$da.fit
#' DAPC.fit$pca.fit
#'
#' # The contributions of SNP to the LD axes
#' DAPC.fit$snp.contrib
#'
#' # The posterior probabilities
#' DAPC.fit$da.prob
#'
#' ### Leave-one out cross-validation with 2 cores
#' DAPC.loo <- dapc_fit(data_Genos, method='loo_cv', pcPreds=3, numCores=2)
#'
#' # Predictions
#' DAPC.loo$tab
#'
#' # Global correct assignment rate
#' DAPC.loo$global
#'
#' # Pairwise assignment rates in long-format data table
#' DAPC.loo$pairs.long
#'
#' # Pairwise correct assignment rates from long-format data table
#' DAPC.loo$pairs.long[POP==POP.PRED]
#'
#' # Pairwise assignment rates in wide-format data table
#' DAPC.loo$pairs.wide
#'
#' #### Training-testing partitioning with 80% used as trianing
#' DAPC.tt <- dapc_fit(data_Genos, method='train_test', pcPreds=3, trainProp=0.8)
#'
#' # Pairwise assignment rates in wide-format data table
#' DAPC.tt$pairs.wide
#'
#' @export

dapc_fit <- function(
  dat, sampCol='SAMPLE', locusCol='LOCUS', genoCol='GT', popCol='POP',
  scaling='covar', pcPreds, method='fit', numCores=1, trainProp=0.7
  ){
  # --------------------------------------------+
  # Libraries and assertions
  # --------------------------------------------+

  require(data.table)
  require(tidyverse)
  require(MASS)

  if(sum(c(popCol, sampCol, locusCol, genoCol) %in% colnames(dat)) != 4){
    stop('Argument `popCol`, `sampCol`, `locusCol` and `genoCol` must all be
       column names in argument `dat`. See ?dapc_fit.')
  }

  # Check that scaling is specified
  if(!scaling %in% c('covar', 'corr', 'patterson', 'none')){
    stop('Argument `scaling`` is invalid. See: ?pca_genos')
  }

  # Get the class of the genotypes
  gtClass <- class(dat[[genoCol]])

  # Check that genotypes are characters or counts
  if(!gtClass %in% c('character', 'numeric', 'integer')){
    stop("Check that genotypes are coded as '/' separated characters or as
         counts of the Alt allele. See: ?pca_genos")
  }

  # Convert characters of separated alleles to counts
  if(gtClass=='character'){
    dat[[genoCol]] <- genoscore_converter(dat[[genoCol]])
  }

  # Convert numeric allele counts to integers
  if(gtClass=='numeric'){
    dat[[genoCol]] <- as.integer(dat[[genoCol]])
  }

  # Check method is specified correctly
  if(!method %in% c('fit', 'loo_cv', 'train_test')){
    stop('Argument `method` must be one of "fit", "loo_cv", or "train_test".
       See ?dapc_fit.')
  }

  # Check that the training proportion is a proportion
  if(sum(c(trainProp<0,trainProp>1))>0){
    stop('Argument `trainProp` must be a proportion. See ?dapc_fit.')
  }

  # --------------------------------------------+
  # Internal function
  # --------------------------------------------+

  FUN_snp_da_contrib <- function(x){
    temp <- sum(x*x)
    if(temp < 1e-12) return(rep(0, length(x)))
    return(x*x / temp)
  }

  # --------------------------------------------+
  # Code
  # --------------------------------------------+

  # Rename columns
  colnames(dat)[match(c(sampCol, locusCol, popCol, genoCol),colnames(dat))] <- c(
    'SAMPLE','LOCUS','POP','GT'
  )

  ### The number of fitted populations
  k <- length(unique(dat$POP))

  ### Fit DAPC to all data
  if(method=='fit'){
    # Population reference table
    popRefs <- dat[, c('POP','SAMPLE')] %>% unique()

    # Fit the PCA
    PCA <- pca_genos(dat, scaling=scaling, popCol='POP')

    # Populations as vector in PCA
    pops <- PCA$pops %>%  as.factor()

    # PC axes as predictors
    X <- PCA$x[, 1:pcPreds] %>% as.data.frame()

    # Fit the DA
    DA <- lda(X, pops, tol=1e-30)

    # Add in the explained variance
    DA$exp.var <- round((DA$svd^2)/sum(DA$svd^2)*100, digits=2)

    # Add in the among population variance
    mov <- manova(as.matrix(X) ~ pops)
    mov$summary <- summary(mov)

    SS.pops <- sum(mov$summary$SS$pops)
    SS.resid <- sum(mov$summary$SS$Residuals)

    DA$among.var <- round(SS.pops/sum(SS.pops,SS.resid)*100, digits=2)

    # SNP loadings on LD axes
    snp.da.load <- as.matrix(PCA$rotation[, 1:pcPreds]) %*% as.matrix(DA$scaling)
    snp.da.contr <- apply(snp.da.load, 2, FUN_snp_da_contrib) %>%
      as.data.frame() %>%
      rownames_to_column(., 'LOCUS') %>%
      as.data.table

    # Tables of DA and PCA scores
    DA.tab <- data.table(
      POP=pops,
      SAMPLE=rownames(X),
      as.data.table(predict(DA)$x))

    PCA.tab <- PCA$x[, c(1:pcPreds)] %>%
      as.data.frame %>%
      rownames_to_column(., 'SAMPLE') %>%
      left_join(., popRefs) %>%
      as.data.table %>%
      .[, c('POP','SAMPLE',paste0('PC',1:pcPreds)), with=FALSE]

    # Posterior probabilities
    DA.prob <- predict(DA)$posterior %>%
      as.data.frame %>%
      rownames_to_column(., 'SAMPLE') %>%
      as.data.table %>%
      left_join(., popRefs) %>%
      melt(., id.vars=c('POP','SAMPLE'), variable.name='POP.PRED', value.name='PROB')

    # Output
    output <- list(
      da.fit=DA, da.tab=DA.tab, da.prob=DA.prob,
      pca.fit=PCA, pca.tab=PCA.tab,
      snp.contrib=snp.da.contr
    )
  }

  ### Leave-one-out cross-validation
  if(method=='loo_cv'){
    # Samples
    samps <- dat$SAMPLE %>% unique

    # Cluster for parallelisation
    my.cluster <- makeCluster(numCores)
    registerDoParallel(my.cluster)

    # Predictions table
    predTab <- foreach(i=1:length(samps)) %dopar%{
      require(genomalicious)
      require(MASS)

      # PCA on training
      PCA.train <- pca_genos(dat[SAMPLE!=samps[i],], scaling=scaling, popCol='POP')

      # DA on training
      DA.train <- lda(
        x=as.data.frame(PCA.train$x[, 1:pcPreds]),
        grouping=PCA.train$pops,
        tol=1e-30)

      # Data for testing set
      dat.test <- dat[SAMPLE==samps[i],]

      # Predictors for testing set
      X.test <- (DT2Mat_genos(dat.test) %*% PCA.train$rotation) %>%
        .[, 1:pcPreds] %>%
        matrix(., ncol=pcPreds, nrow=1) %>%
        as.data.frame() %>%
        setnames(., new=paste0('PC', 1:pcPreds))

      # DA for testing set
      DA.test <- predict(DA.train, newdata = X.test[1,])

      # Output
      data.table(
        POP=dat.test$POP[1],
        SAMPLE=samps[i],
        POP.PRED=DA.test$class
      )
    } %>%
      do.call('rbind',.)

    stopCluster(mu.cluster)
  }

  ### Training-testing partitioning
  if(method=='train_test'){
    # Samples
    samps.train <- dat %>%
      .[, c('POP','SAMPLE')] %>%
      unique %>%
      .[, sample(SAMPLE, round(length(unique(SAMPLE)))*trainProp), by=POP] %>%
      .[['V1']]

    samps.test <- dat %>%
      .[, c('POP','SAMPLE')] %>%
      unique %>%
      .[!SAMPLE%in%samps.train] %>%
      .[['SAMPLE']]

    # PCA fit to training set
    PCA.train <- dat %>%
      .[SAMPLE %in% samps.train] %>%
      pca_genos(., scaling=scaling, popCol='POP')

    # SNP names
    snp.names <- rownames(PCA.train$rotation)

    # DA fit to training set
    DA.train <- lda(
      x=PCA.train$x[, 1:pcPreds],
      grouping=PCA.train$pops,
      tol=1e-30
    )

    # Data for testing set
    dat.test <- dat[SAMPLE %in% samps.test] %>%
      dcast(., POP+SAMPLE~LOCUS, value.var='GT')

    # Predictors for the testing set
    X.test <- as.matrix(dat.test[, snp.names, with=FALSE])

    # PCA fit to the testing set
    PCA.test <- X.test %*% PCA.train$rotation

    # DA fit to the testing set
    DA.test <- predict(DA.train, newdata=PCA.test[, 1:pcPreds])

    # Predictions
    predTab <- data.table(
      POP=dat.test$POP,
      SAMPLE=dat.test$SAMPLE,
      POP.PRED=DA.test$class
    )
  }

  ### CV statistics
  if(method %in% c('loo_cv','train_test')){
    pops.uniq <- dat$POP %>% unique

    global <- predTab[, sum(POP==POP.PRED)/length(SAMPLE)]

    popComps <- CJ(POP=pops.uniq, POP.PRED=pops.uniq)

    predPairsLong <- lapply(1:nrow(popComps), function(i){
      pop.obs <- popComps$POP[i]
      pop.pred <- popComps$POP.PRED[i]
      assign <- nrow(predTab[POP==pop.obs & POP.PRED==pop.pred])/nrow(predTab[POP==pop.obs])
      data.table(POP=pop.obs, POP.PRED=pop.pred, ASSIGN=assign)
    }) %>%
      do.call('rbind', .)

    predPairsWide <- predPairsLong %>%
      dcast(., POP~POP.PRED, value.var='ASSIGN')

    output <- list(
      tab=predTab, global=global, pairs.long=predPairsLong, pairs.wide=predPairsWide
    )
  }

  ### Output results
  return(output)
}


