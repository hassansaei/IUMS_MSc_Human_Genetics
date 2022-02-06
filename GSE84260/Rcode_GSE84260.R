# In god we trust
rm(list=ls())
library(limma)
library(dplyr)
library(radiant)
library(EnhancedVolcano)
library(tidyverse)
library(clusterProfiler)
library(data.table)
library(ggplot2)

# Raw expression matrix and annotation
rawdata <- fread("GSE84260_series_matrix.txt", skip = "!series_matrix_table_begin")
ann <- fread("GSE84260_family.soft", skip = "!platform_table_begin")

rawdata <- data.frame(rawdata)
row.names(rawdata) <- rawdata$ID_REF

rawdata <- rawdata[,-1]

datalog <- function(x) {
  if(max(x) > 30)
    log2(x)
  else
    x
}

data <- datalog(rawdata)
colnames(ann)


#Annotation
annNames <- c("ID", "Symbol")
ann <- ann[,c("ID", "GENE_SYMBOL")]
colnames(ann) <- annNames
data$ID <- rownames(data)

#Merge data with annotation file
adata <- merge(data, ann, by="ID")

adata <- data.frame(adata)
adata <- adata[,-1]
dataDF <- aggregate(.~Symbol, adata, mean)
any(duplicated(dataDF$Symbol))

rownames(dataDF) <- dataDF$Symbol
dataDF <- dataDF[-1,]
dataDF <- dataDF[,-1]
dim(dataDF)

######## Normalization Step

mdata.q <- normalizeQuantiles(dataDF)

pdf("Boxplot_PE.pdf", width= 80)
boxplot(dataDF)
boxplot(mdata.q)
dev.off()

library(pheatmap)
pdf("CorHeatmap_PE.pdf", width = 20, height = 15)
pheatmap(cor(mdata.q))
dev.off()

pc <- prcomp(mdata.q)
pcr <- data.frame(Sample=rownames(pc$r), pc$r)
pdf("PCA_PE.pdf", width = 20, height = 15)
ggplot(pcr, aes(PC1, PC2, color=Sample))+geom_point(size=3)+theme_bw()
dev.off()

# Deferentially expressed miRNAs

target <- read.delim(file = "group.txt", sep = "\t")
group <- target$group
class(group)
group=factor(group,levels = unique(group))
class(group)
design <- model.matrix(~0+group)
rownames(design)=rownames(target)
colnames(design)=levels(group)

Fit <- lmFit(object = mdata.q,design = design)
f.data=data.frame(Fit)
mc=makeContrasts(contrasts = "PE-Control",levels = design)
Fit2=contrasts.fit(fit = Fit,contrasts = mc)
f.data=data.frame(Fit2)
Fit3=eBayes(fit = Fit2)
f.data=data.frame(Fit3)

results <- topTable(fit = Fit3,coef = "PE-Control",number = Inf ,adjust.method = "BH",
                    sort.by = "logFC")

write.table(x = results,file = "PE_Control.tsv", quote = F ,sep = "\t")

DEG.up <- subset(x = results, logFC>0.5 & adj.P.Val<0.05)

DEG.down <- subset(x = results, logFC<=-0.5 & adj.P.Val<0.05)

write.table(x =DEG.up,file = "PE_DEGs_up.tsv", quote = F,sep = "\t")
write.table(x =DEG.down,file = "PE_DEGs_down.tsv", quote = F,sep = "\t")

#plot

results$symbol <- rownames(results)
mdata.q$symbol <- rownames(mdata.q)
mdata <- merge(results, mdata.q, by= "symbol")


# plot
library(EnhancedVolcano)

EnhancedVolcano(mdata,
                lab = mdata$symbol,
                x = 'logFC',
                y = 'adj.P.Val',
                title = 'Pre-eclampsia versus healthy control',
                col=c('black', 'gray', 'black', 'red3'), pCutoff = 10e-2, FCcutoff = 0.8)
