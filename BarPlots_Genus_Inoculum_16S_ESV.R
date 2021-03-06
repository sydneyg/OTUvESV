
#March 5, 2018
#make Genus bar plots for 16S ESV

#Reset R's Brain
rm(list=ls())

## Set working directory
#setwd("")
#set working directory
setwd("~/Dropbox/StatsandProgramming/16SElevationGradient/")

#source in functions
source('~/Dropbox/StatsandProgramming/source/gettaxondd.R', chdir = TRUE)
source('~/Dropbox/StatsandProgramming/source/getrowsums.R', chdir = TRUE)

################################################################################
############################## 1. DATA PROCESSING ##############################
################################################################################

#Bacteria
# 1.1. Input the file of rarefied OTU-abundance-taxon table
#read in dataframes
zotu_abundance_taxa <- read.csv("data/16S_usearch10/zotutab_inoculum_tax_filtered.csv", row.names=1)
head(zotu_abundance_taxa)


# 1.2. Extract otu-abundance table from OTU-abundance-taxon table
zotu_abundance_bac <- zotu_abundance_taxa[, colnames(zotu_abundance_taxa) != "Consensus.Lineage"]
head(zotu_abundance_bac)

#transform
zotu_abundance_bac_trans <- t(zotu_abundance_bac)
#rarefy
set.seed(10)
getrowsums(zotu_abundance_bac_trans)
zotu_abundance_bac_trans<- rrarefy(zotu_abundance_bac_trans,9212)

rowSums(zotu_abundance_bac_trans)
#rarefied
zotu_abundance_bac <- t(zotu_abundance_bac_trans)
colSums(zotu_abundance_bac)

#head(otu_taxa)


dd_zotu <- as.data.frame(zotu_abundance_taxa$Consensus.Lineage)
dd_zotu$ZOTU <- row.names(zotu_abundance_taxa)
names(dd_zotu) <- c("taxon","id")


names(dd_zotu)
library("stringr")
library("plyr")
zotu_taxa1 <- ldply(str_split(string = dd_zotu$taxon, pattern=";"), rbind) # Divide a column using ";"and convert list to data frame
names(zotu_taxa1) <- c("Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species")
zotu_taxa2 <- as.data.frame(lapply(zotu_taxa1, gsub, pattern=" ", replacement=""))
zotu_taxa3<- cbind(dd_zotu[,1:2 ],zotu_taxa2)


#check they match
row.names(zotu_abundance_bac)==(zotu_taxa3$id)
zotu_abundance_taxa2 <- cbind(zotu_abundance_bac, zotu_taxa3) #Combine otu ID and taxon table
head(zotu_abundance_taxa2)

#figure out how many phyla are in the inoculum
phyla_inoculum_zotu <- as.vector(unique(zotu_abundance_taxa2$Phylum))
length(phyla_inoculum_zotu) #20 phyla
Family_inoculum_zotu <- as.vector(unique(zotu_abundance_taxa2$Family ))
length(Family_inoculum_zotu) #123 families
Genus_inoculum_zotu <- as.vector(unique(zotu_abundance_taxa2$Genus ))
length(Genus_inoculum_zotu) #213 genera

##########################################################################################
########################## 4. Community composition at phylum level ######################
##########################################################################################


# 4.1. Make dataframe for phylum composition
zotu_abundance_taxa3 <- cbind(OTU_ID = rownames(zotu_abundance_taxa2), zotu_abundance_taxa2)  #convert the rownames to a proper column of the data.frame
rownames(zotu_abundance_taxa3) <- NULL

zotu_abundance_taxa3$Phylum <- as.character(zotu_abundance_taxa3$Phylum)  #convert empty column to unidentified
zotu_abundance_taxa3$Phylum[is.na(zotu_abundance_taxa3$Phylum)]<-"p__unidentified"

zotu_abundance_taxa3$Family <- as.character(zotu_abundance_taxa3$Family)  #convert empty column to unidentified
zotu_abundance_taxa3$Family[is.na(zotu_abundance_taxa3$Family)]<-"f__unidentified"
zotu_abundance_taxa3$Family[zotu_abundance_taxa3$Family=="f__"]<-"f__unidentified"

zotu_abundance_taxa3$Genus <- as.character(zotu_abundance_taxa3$Genus)  #convert empty column to unidentified
zotu_abundance_taxa3$Genus[is.na(zotu_abundance_taxa3$Genus)]<-"g__unidentified"
zotu_abundance_taxa3$Genus[zotu_abundance_taxa3$Genus=="g__"]<-"g__unidentified"

zotu_abundance_taxa3$Kingdom_Phylum <- str_c(zotu_abundance_taxa3$Phylum,zotu_abundance_taxa3$Family, zotu_abundance_taxa3$Genus, sep=";") #combine kingdom and phylun
zotu_abundance_taxa4 <- zotu_abundance_taxa3[, !(colnames(zotu_abundance_taxa3) %in% c("Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species"))]

zotu_abundance_taxa4 <- zotu_abundance_taxa4[, -c(22,23)]
head(zotu_abundance_taxa4)



# 4.2. Caluculate mean value for each phylum on each date
library("reshape2")
zotu_abundance_taxa5 <- melt(zotu_abundance_taxa4, id.vars= c("OTU_ID","Kingdom_Phylum"), variable.name="Sample", value.name="Abundance")
zotu_abundance_taxa5 <- subset(zotu_abundance_taxa5, Abundance>0)
#get total number of sequences per sample
totalseqs <- colSums(zotu_abundance_taxa4[ ,2:21])
avgnumseqs <- sum(totalseqs)/20

zotu_abundance_taxa5$Abundance <- zotu_abundance_taxa5$Abundance/avgnumseqs*100 # Check your sequence number and convert to relative abundance (%)
head(zotu_abundance_taxa5)

phylum_abundance_zotu <- ddply(zotu_abundance_taxa5, c("Kingdom_Phylum","Sample"), summarise,
                          sum = sum(Abundance, na.rm=TRUE)
)
head(phylum_abundance_zotu)

library("stringr")
library("plyr")

phylum_abundance_zotu$Site <- str_sub(phylum_abundance_zotu$Sample,2,2) #get a column of site names
head(phylum_abundance_zotu)


phylum_abundance2_zotu <- ddply(phylum_abundance_zotu, c("Kingdom_Phylum","Site"), summarise, # Caluculate mean value on each date
                           mean = mean(sum, na.rm=TRUE),
                           sd = sd(sum, na.rm=TRUE),
                           n = sum(!is.na(sum)),
                           se = sd/sqrt(n),
                           max = max(sum, na.rm=TRUE) 
)
head(phylum_abundance2_zotu)


# 4.3. Classify phylum with mean abundance < XX% (1% here) into "other phylum". 
# Twelve phylum and others are recommended to use palette="Paired".
# "maximum abundance" rather than "mean abundance" will be better when compositional change is large.
phylum_over1_zotu <- subset(phylum_abundance2_zotu, mean>6) # Subset the phylum with >1%

#if one site has more than 1% of that phylum then it stays
phylum_over1_zotu <- as.vector(unique(phylum_over1_zotu$Kingdom_Phylum)) # Subset the phylum with >1%
length(phylum_over1_zotu) #11
#stick with over 6% bc its 12 families which is the max that can fit
phylum_abundance_over1_zotu <- subset(phylum_abundance2_zotu, Kingdom_Phylum==phylum_over1_zotu[1]) # Subset the phylum with >1%
for(i in 2:length(phylum_over1_zotu)){ 
  phylum_abundance_over1_zotu <-merge(phylum_abundance_over1_zotu, subset(phylum_abundance2_zotu, Kingdom_Phylum==phylum_over1_zotu[i]), all=T)
}
phylum_abundance_over1_zotu 

#figure out how many phyla are in the inoculum
famininoculum_zotu <- as.vector(unique(phylum_abundance2_zotu$Kingdom_Phylum))
length(famininoculum_zotu)
#246 genera in the inoculum



#ok so this script adds up the mean abundance of every phyla in Site D, then 100-that number, is the other phyla
phylum_abundance_below1_zotu <- ddply(phylum_abundance_over1_zotu, c("Site"), summarise, # Subset the phylum with <1% and classify into other phylum
                                 Kingdom_Phylum = "p__;f__other taxa",
                                 mean = 100-sum(mean),
                                 sd = 0,
                                 n = mean(n),
                                 se= 0
)

#ok so what this says is that only ~1% of the reads in desert belong to other phyla
phylum_abundance_below1_zotu

phylum_abundance3_zotu <- merge(phylum_abundance_over1_zotu, phylum_abundance_below1_zotu, all=T)
head(phylum_abundance3_zotu)


# 4.4. Reformat the date description
phylum_abundance3_zotu$Phylum <- ldply(str_split(string=phylum_abundance3_zotu$Kingdom_Phylum, pattern=";f__"), rbind)[,2] # Divide a column using "_".

#order by most abundant phyla
phyla_sorted_zotu <- phylum_abundance3_zotu[order(-phylum_abundance3_zotu[,3]), ]
phyla_sorted_zotu
# 4.4. Reorder the phylum from the largest abundance to the lowest
length(levels(phylum_abundance3_zotu$Phylum))


                                     
#re order the Sites - give site full names
phyla_sorted_zotu <- phylum_abundance3_zotu[order(phylum_abundance3_zotu[,2]), ]
phyla_sorted_zotu
table(phyla_sorted_zotu$Site)

phyla_sorted_zotu$Sitefullnames <- c(rep("Desert",12),rep("Grassland",12),rep("Pine-Oak",12),rep("Subalpine",12),rep("Scrubland",12))
phyla_sorted_zotu
phyla_sorted_zotu$Sitefullnames <- factor(phyla_sorted_zotu$Sitefullnames, 
                                   levels = c("Desert","Scrubland","Grassland","Pine-Oak","Subalpine"))                                             

# 4.5 Graph making
library("ggplot2")
library("scales")
library("gridExtra")

genus_barplot1_zotu<-
  ggplot(phyla_sorted_zotu, aes(x=Sitefullnames, y=mean, fill=Phylum)) + 
  geom_bar(stat="identity",color="black", width=0.4) +
  scale_fill_brewer(palette = "Paired")+ 
     #When you use scale_fill_brewer(palette = "Paired"), the maximum is 12, or 13 ("other phylum" is not colored)
  labs(x="Site", y="Relative abundance (%) ESV", fill="Genus") + theme_bw()+
  theme(axis.text.x=element_text(size=12,angle=30, hjust=1),
        axis.text.y=element_text(size=12),
        legend.text = element_text(size=12)
        )
genus_barplot1_zotu

phyla_sorted_zotu$otuvesv <- rep("ESV", nrow(phyla_sorted_zotu))

write.csv(phyla_sorted_zotu, "Figures/otuvzotu_taxonomy/16S_Inoculum_phylasorted_genus_zotu_rarefied.csv")
genus_barplot1_zotu
ggsave(genus_barplot1_zotu,filename=paste("Figures/otuvzotu_taxonomy/genusbarplot_inoculum_16S_zotu_rarefied.pdf"), width=7, height=4.5)


