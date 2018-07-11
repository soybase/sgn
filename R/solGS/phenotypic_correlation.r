 #SNOPSIS

 #runs phenotypic correlation analysis.
 #Correlation coeffiecients are stored in tabular and json formats 

 #AUTHOR
 # Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(ltm)
library(rjson)
library(data.table)
#library(phenoAnalysis)
library(dplyr)
#library(rbenchmark)
library(methods)

allArgs <- commandArgs()


outputFiles <- scan(grep("output_files", allArgs, value = TRUE),
                    what = "character")

inputFiles  <- scan(grep("input_files", allArgs, value = TRUE),
                    what = "character")

phenoDataFile      <- grep("\\/phenotype_data", inputFiles, value=TRUE)
formattedPhenoFile <- grep("formatted_phenotype_data", inputFiles, value = TRUE)

correCoefficientsFile     <- grep("corre_coefficients_table", outputFiles, value=TRUE)
correCoefficientsJsonFile <- grep("corre_coefficients_json", outputFiles, value=TRUE)

formattedPhenoData <- c()
phenoData          <- c()

phenoData <- fread(phenoDataFile,
                   na.strings = c("NA", " ", "--", "-", ".", "..")
                   ))

phenoData <- data.frame(phenoData)

allTraitNames <- c()
nonTraitNames <- c()
naTraitNames  <- c()

allNames <- names(phenoData)

nonTraitNames <- c('studyYear', 'studyDbId', 'studyName', 'studyDescription', 'studyDesign', 'locationDbId', 'locationName')
nonTraitNames <- c(nonTraitNames, 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel')
nonTraitNames <- c(nonTraitNames, 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber')
nonTraitNames <- c(nonTraitNames, 'programDbId', 'programName', 'programDescription', 'plotWidth', 'plotLength')
nonTraitNames <- c(nonTraitNames, 'fieldSize', 'fieldTrialIsPlannedToBeGenotyped', 'fieldTrialIsPlannedToCross',  'plantingDate')
nonTraitNames <- c(nonTraitNames,  'harvestDate', 'rowNumber', 'colNumber', 'entryType', 'plantNumber')
  
allTraitNames <- allNames[! allNames %in% nonTraitNames]

if (!is.null(phenoData)) {
  
    for (i in allTraitNames) {
      if (class(phenoData[, i]) != 'numeric') {
          phenoData[, i] <- as.numeric(as.character(phenoData[, i]))
      }

      if (all(is.nan(phenoData[, i]))) {
          phenoData[, i] <- sapply(phenoData[, i], function(x) ifelse(is.numeric(x), x, NA))        
      }

      if (sum(is.na(phenoData[,i])) > (0.5 * nrow(phenoData))) { 
          phenoData$i <- NULL
          naTraitNames <- c(naTraitNames, i)
          message('dropped trait ', i, ' no of missing values: ', sum(is.na(phenoData[,i])))
      }
  }
}

filteredTraits <- allTraitNames[!allTraitNames %in% naTraitNames]

correData <- phenoData %>%
                      select(germplasmName, allTraitNames) %>%
                      group_by(germplasmName) %>%
                      summarise_at(allTraitNames, mean, na.rm=TRUE) %>%
                      select(-germplasmName) %>%
                      round(., 2) %>%
                      data.frame
 
coefpvalues <- rcor.test(correData,
                         method="pearson",
                         use="pairwise"
                         )

coefficients <- coefpvalues$cor.mat
allcordata   <- coefpvalues$cor.mat

allcordata[lower.tri(allcordata)] <- coefpvalues$p.values[, 3]
diag(allcordata) <- 1.00

pvalues <- as.matrix(allcordata)

pvalues <- round(pvalues, 2)

coefficients <- round(coefficients, 3)
 
allcordata   <- round(allcordata, 3)

#remove rows and columns that are all "NA"
if (apply(coefficients, 1, function(x)any(is.na(x))) ||
    apply(coefficients, 2, function(x)any(is.na(x))))
  {
                                                            
    coefficients<-coefficients[-which(apply(coefficients, 1, function(x)all(is.na(x)))),
                               -which(apply(coefficients, 2, function(x)all(is.na(x))))]
  }


pvalues[upper.tri(pvalues)]           <- NA
coefficients[upper.tri(coefficients)] <- NA
coefficients <- data.frame(coefficients)

coefficients2json <- function(mat) {
  mat <- as.list(as.data.frame(t(mat)))
  names(mat) <- NULL
  toJSON(mat)
}

traits <- colnames(coefficients)

correlationList <- list(
                     "traits" = toJSON(traits),
                     "coefficients " =coefficients2json(coefficients)
                   )

correlationJson <- paste("{",paste("\"", names(correlationList), "\":", correlationList, collapse=","), "}")

correlationJson <- list(correlationJson)

fwrite(coefficients,
       file      = correCoefficientsFile,
       row.names = TRUE,
       sep       = "\t",
       quote     = FALSE,
       )

fwrite(correlationJson,
       file      = correCoefficientsJsonFile,
       col.names = FALSE,
       row.names = FALSE,
       qmethod   = "escape"
       )

q(save = "no", runLast = FALSE)
