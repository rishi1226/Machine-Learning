library(plyr)
library(ggplot2)
library(mvtnorm)
source("genData.R")
#classification trees

#==================================================================
Entropy <- function(labels){
  #' calculates entropy given a vector of labels or classes
  N <- length(labels)
  label.counts <- count(labels)$freq
  entropy.vec <- sapply(label.counts, function(count) -(count/N) * log2(count/N))
  return(sum(entropy.vec))
}

##test case
#labels <- c(rep("a", 10), rep("b", 10), rep("c", 10))
#labels1 <- c(rep("a", 6), rep("b", 6))

#Entropy(labels) #expected value =  1.584963
#Entropy(labels1)
#==================================================================

#==================================================================
ExpectedEntropy <- function(parent.labels, children.labels) {
  #' calculates expected entropy given parent labels and 
  #' labels of the children resulting from the split
  
  N <- length(parent.labels)
  expected.entropy <- sum(sapply(children.labels, function(child) (length(child)/ N)* Entropy(child)))
  return(expected.entropy)
}

##test case
#parent.labels <- c(rep("a", 6), rep("b", 6))
#children.labels <- list(rep("a",2), rep("b",4), c(rep("b",2), rep("a",4)))
#ExpectedEntropy(parent.labels, children.labels) # expected answer = expected.entropy


#==================================================================
BestThresholdEntropy <- function(feature, labels, no.thresh = 10, diagnostics = FALSE) {
  #' breaks continuous feature into specified intervals and 
  #' calculates information gain on each interval.
  #' If  diagnostics = FALSE returns best intra feature split
  #' If diagnostics = TRUE returns a table of information gains 
  
  # create potential thresholds vector
  pot.thresh <- seq(min(feature), max(feature), length.out = (no.thresh + 2))
  pot.thresh <- pot.thresh[2: (no.thresh + 1)]
  #evaluate inforation gain at each threshold 
  
  information.gain.vec <- sapply(pot.thresh, 
                                 function(thresh) Entropy(labels) - ExpectedEntropy(labels, 
                                                                                    list(labels[feature > thresh], 
                                                                                         labels[!(feature > thresh)])))
  
  best.thresh <- pot.thresh[which.max(information.gain.vec)]
  
  if(diagnostics == FALSE){
    return(c(best.thresh = best.thresh, information.gain = max(information.gain.vec)))
  }
  else {
    
    return(data.frame(threshold = pot.thresh, information.gain = information.gain.vec))
  }
}

#test
#labels1 <- c(rep("a", 15), rep("b", 5), rep("c", 10))
#BestThresholdEntropy(rnorm(100), sample(c("a", "b"), 100, replace = T), 10)
#feature <- features[,1]; labels <- labels
#BestThresholdEntropy(features[,1], labels, 10, diag = T)
#==================================================================

ChooseSplit <- function(features, labels, costFnc, diagnostics = FALSE){
  #' Uses the method specified to calculate best information gain from all features
  #' If diagnostics = FALSE returns the best feature and split
  #' If diagnostics = TRUE returns a table of features and information gain
  
  if ( (tolower(costFnc) == "entropy") | (method = 1) ) {
    information.gain <-  as.data.frame(t(apply(features, 2, function(feature) BestThresholdEntropy(feature, labels))))
  }
  
  information.gain$feature <- rownames(information.gain)
  
  if(diagnostics == FALSE){
    best.cut <- information.gain[which.max(information.gain$information.gain),]
    return(best.cut)
  }
  else {
    
    return(information.gain)
  }
  
}
#==================================================================

SplitData <- function(features, labels, rule, decision.tree, parent, last.node) {
  #' slpits data based on rule given and returns a list 
  #' with rules, predicted label, probabilities
  child1 <- features[[rule[1, 3]]] < rule[1, 1] 
  child2 <- !child1
  
  features1 <- features[child1,]
  labels1 <- labels[child1]
  prob1 <- count(labels1)
  #prob1$freq <- prob1$freq/length(labels1)  
  
  features2 <- features[child2,]
  labels2 <- labels[child2]
  prob2 <- count(labels2)
  #prob2$freq <- prob2$freq/length(labels2)  
  
  node <- c(last.node + 1, last.node + 2)
  parent.node <- c(parent, parent)
  which.child <- c("left", "right")
  split.feature <- c(rule[1, 3], rule[1, 3])
  threshold <- c(round(rule[1, 1], 3), round(rule[1, 1], 3))
  pred.class <- c(as.character(prob1$x[which.max(prob1$freq)]), 
                  as.character(prob2$x[which.max(prob2$freq)]))
  class.prob <- c(round(prob1$freq[which.max(prob1$freq)]/length(labels1), 3),
                  round(prob2$freq[which.max(prob2$freq)]/length(labels2), 3))
  
  decision.tree <- rbind(decision.tree, data.frame(node, parent.node, which.child, split.feature,
                                                   threshold, pred.class, class.prob))
  
  return(list(feat1 = features1, 
              lab1 = labels1,
              no.points1 = length(labels1),
              feat2 = features2, 
              lab2 = labels2,
              no.points2 = length(labels2),
              decision.tree = decision.tree))
}
#==================================================================
BuildCTree <- function(features, labels, depth = 3, minPoints = 10, parent.node){
  #' Buils a tree given the depth and minPoints argument
  
  #' depth queue will act as a rough queue to build the tree breadth wise.
  #' i.e all the leaf nodes will be split firt before moving to teh new depth
  #' cerated
  depth.queue <- list()
  
  
  depth.queue[[length(depth.queue) + 1]] <- list(features = features, labels = labels, node = 1)
  
  #' stores information to predict based on accepted splits
  decision.tree <- data.frame(node = numeric(),
                              parent.node = numeric(),
                              which.child = character(),
                              split.feature = character(),
                              threshold = numeric(),
                              pred.class = character(),
                              class.prob = double())
  
  

  for (k in 1:depth){
    temp.queue <- list()
    
    while (length(depth.queue) != 0) {
      
      split <- depth.queue[[1]]
      
      if(length(temp.queue) != 0) {
        last.node <- temp.queue[[length(temp.queue)]]$node
      } else { 
        last.node <- depth.queue[[length(depth.queue)]]$node
      }
      
      
      
      
      depth.queue[[1]] <- NULL
      
      decision.rule <- ChooseSplit(split$features, split$labels, 1, FALSE)
      
      new.split <- SplitData(split$features, 
                             split$labels, 
                             decision.rule, 
                             decision.tree, 
                             split$node, 
                             last.node) 
      
      decision.tree <- new.split$decision.tree
      
      if(decision.tree$class.prob[length(decision.tree$class.prob) - 1] != 1 | length(new.split$lab1) > minPoints) {
        temp.queue[[length(temp.queue) + 1]] <- list(features = new.split$feat1, 
                                                     labels = new.split$lab1, 
                                                     node = decision.tree$node[length(decision.tree$node) - 1])
      }
      
      if(decision.tree$class.prob[length(decision.tree$class.prob)] != 1 | length(new.split$lab2) > minPoints) {
        temp.queue[[length(temp.queue) + 1]] <- list(features = new.split$feat2, 
                                                     labels = new.split$lab2, 
                                                     node = decision.tree$node[length(decision.tree$node)])
      }
      
    }
    
    depth.queue <- c(depth.queue, temp.queue)
  }
  
  return(decision.tree)
}


PredictPoint <- function(features, label, tree){
  parent.present <- TRUE
  parent <- 1
  which.child <- NULL
  prediction <- NULL
  pred.prob <- NULL
  
  while(parent.present){
    feature.name <- unique(as.character(tree$split.feature[tree$parent.node == parent]))
    threshold <- unique(tree$threshold[tree$parent.node == parent])
    
    if(features[[feature.name]] < threshold){
      which.child <- "left"
    } else {
      which.child <- "right"
    }
    
    if(tree[tree$parent.node == parent & tree$which.child == which.child,]$node %in% tree$parent.node ){
      parent.present <- TRUE
      parent <- tree[tree$parent.node == parent & tree$which.child == which.child,]$node
    } else {
      parent.present <- FALSE
      prediction <- tree[tree$parent.node == parent & tree$which.child == which.child,]$pred.class
      pred.prob <- tree[tree$parent.node == parent & tree$which.child == which.child,]$class.prob
    }
    
    
  }
  return(c(prediction = as.character(prediction),
                    probability = pred.prob)
  )
}


PredictData <- function(features, labels, decision.tree) {
  
  data <- cbind(labels, features)
  
  as.data.frame(t(apply(data, 1, function(row) PredictPoint(features = row[2:ncol(data)], 
                                             label = row[1],
                                             tree = decision.tree))))
  
}

#==================================================================

set.seed(1000)
param.vector <- list(
  class1 = list(no = 50, rho = -0.7, sd = c(10, 20), mean = c(20, 60), class.name = "Approved"),
  class2 = list(no = 50, rho = -0.1, sd = c(20, 20), mean = c(40, 80), class.name = "Denied"),
  class3 = list(no = 50, rho = 0.5, sd = c(15, 12), mean = c(20, 25), class.name = "Undecided")
)

data <- GenData(param.vector)[,1:3]
features <- data[,1:2]
labels <- data[,3]


#split <- ChooseSplit(features, labels, 1, FALSE)



decision.tree <- BuildCTree(features, labels, depth = 4, minPoints = 3)

predictions <- PredictData(features = features, label = labels, decision.tree = decision.tree)

sum(predictions$prediction == labels)/150

