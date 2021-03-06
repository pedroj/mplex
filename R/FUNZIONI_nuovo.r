
#' @export
create.multiplex <- function(nodes, layersNames = FALSE, layer1, type1, ...){
  N <- nrow(nodes)
  layer1 <- as.matrix(layer1)
  colnames(layer1) <- c("ID1","ID2","Weight")
  layersList <- list(layer1)
  L <- 1

  if(pmatch(type1, c("directed","Directed"), nomatch = 0) > 0){
    type <- "directed"
  }
  else{
    type <- "undirected"
  }

  #################################### Handling ... ####################################
  dots <- list(...)

  for(i in 1:length(dots)){
    if(is.data.frame(dots[[i]]) == TRUE | is.matrix(dots[[i]])){
      if(dim(dots[[i]])[2] == 3 & dim(dots[[i]])[1] <= N*(N-1)){
        if((dots[[i]][,1] %in% nodes[,1]) && (dots[[i]][,2] %in% nodes[,1])){
          if(is.numeric(dots[[i]][,3])){
            L <- L + 1

            layersList[[L]] <- as.matrix(dots[[i]])
            colnames(layersList[[L]]) <- c("ID1","ID2","Weight")

            if(i == length(dots)){
              type <- c(type, "undirected")
              break
            }
            if(is.character(dots[[i+1]])){
              if(pmatch(dots[[i+1]], c("directed","Directed"), nomatch = 0) > 0){
                type <- c(type, "directed")
              }
              else{
                type <- c(type, "undirected")
              }
            }
            else{
              type <- c(type, "undirected")
            }
          }
        }
      }
    }
  }

  if(is.character(layersNames)){
    names(layersList) <- layersNames
  }
  else{
    names(layersList) <- sprintf("Layer%i", 1:length(layersList))
  }
  ###################################################################

  adjList <- list(NULL)
  for(j in 1:L){
    adjList[[j]] <- matrix(0, N, N)
    for(i in 1:nrow(layersList[[j]])){
      adjList[[j]][layersList[[j]][,1][i], layersList[[j]][,2][i]] <- layersList[[j]][,3][i]
    }
    if(type[j] == "undirected"){
      adjList[[j]] <- adjList[[j]] + t(adjList[[j]])
    }

    if(sum((diag(adjList[[j]]) != 0) * 1) > 0){
      diag(adjList[[j]]) <- 0
      cat("Self-loops have been removed from layer", j ,".\n")
    }

    colnames(adjList[[j]]) <- as.character(nodes[, 2])
    rownames(adjList[[j]]) <- as.character(nodes[, 1])
  }

  if(is.character(layersNames)){
    lNames <- layersNames
    names(adjList) <- lNames
  }
  else{
    lNames <- sprintf("Layer%i", 1:length(layersList))
    names(adjList) <- lNames
  }

  mplex <- list(nodes = nodes, layers = layersList, adjacency = adjList, type = type, layersNames = lNames)
  class(mplex) <- "multiplex"
  mplex <- addInterlayer.multiplex(mplex) # Adding the interlayer structure
  class(mplex) <- "multiplex" # Assigning 'multiplex' class

  return(mplex)
}

#' @importFrom utils combn
addInterlayer.multiplex <- function(obj){
  L <- length(layers.multiplex(obj))
  N <- length(nodes.multiplex(obj))

  layersList <- layers.multiplex(obj)
  combMatrix <- combn(1:L, m = 2)
  interlayerSupraMatrix <- matrix(0, N * L, N * L)

  for(i in 1:ncol(combMatrix)){
    L1 <- combMatrix[1, i]
    L2 <- combMatrix[2, i]
    nodes1 <- as.vector(layersList[[L1]][, -3])
    nodes2 <- as.vector(layersList[[L2]][, -3])
    commonsNodes <- intersect(nodes1, nodes2)
    diagTempMatrix <- matrix(0, N, N)
    for(j in 1:N){
      if(j %in% commonsNodes){
        diagTempMatrix[j, j] <- 1
      }
    }
    interlayerSupraMatrix[(1 + (L1 - 1) * N):(N + (L1 - 1) * N), (1 + (L2 - 1) * N):(N + (L2 - 1) * N)] <- diagTempMatrix
    interlayerSupraMatrix[(1 + (L2 - 1) * N):(N + (L2 - 1) * N), (1 + (L1 - 1) * N):(N + (L1 - 1) * N)] <- diagTempMatrix
  }
  obj$interlayersMatrix <- interlayerSupraMatrix
  return(obj)
}

#' @export
interlayer.multiplex <- function(obj, level1, level2){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object.\n")
  if(level1 == level2){
    stop("The output is an adiacency matrix for the interlayer relationships, so 'level1' and 'level2' arguments must be different.\n")
  }
  N <- length(nodes.multiplex(obj))
  interlayerMatrix <- obj$interlayersMatrix[(1 + (level1 - 1) * N):(N + (level1 - 1) * N), (1 + (level2 - 1) * N):(N + (level2 - 1) * N)]
  rownames(interlayerMatrix) <- nodes.multiplex(obj, label = TRUE)
  colnames(interlayerMatrix) <- nodes.multiplex(obj, label = TRUE)
  return(interlayerMatrix)
}

#' @export
nodes.multiplex <- function(obj, index = 1:nrow(obj$nodes), label = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  if(label == TRUE){
    return(as.character(obj$nodes[index, 2]))
  }
  else{
    out <- obj$nodes[, 1]
    names(out) <- as.character(obj$nodes[, 2])
    return(out[index])
  }
}

#' @export
layers.multiplex <- function(obj, index = 1:length(obj$layers), label = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  if(label == TRUE){
    return(obj$layersNames[index])
  }
  else{
    return(obj$layers[index])
  }
}

#' @export
adjacency.multiplex <- function(obj, index = 1:length(obj$adjacency)){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  return(obj$adjacency[index])
}

#' @export
type.multiplex <- function(obj, index = 1:length(obj$type)){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  out <- obj$type
  names(out) <- layers.multiplex(obj, label = TRUE)
  return(out[index])
}

#' @importFrom igraph graph.adjacency
graph.multiplex <- function(obj){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  G <- list()
# require(igraph)
  for(i in 1:length(layers.multiplex(obj))){
    G[[i]] <- graph.adjacency(adjmatrix = adjacency.multiplex(obj)[[i]],
                              mode = type.multiplex(obj, index = i))
  }
  names(G) <- layers.multiplex(obj, label = T)
  return(G)
}

#' @importFrom igraph degree
#' @export
degree.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj)), modeDirected = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  degreeList <- list()

# require(igraph)
  for(i in 1:length(layers.multiplex(obj))){
    degreeList[[i]] <- degree(graph.multiplex(obj)[[i]], v = indexNode, mode = "total", loops = FALSE)
    if(type.multiplex(obj)[i] == "directed" & modeDirected){
      degreeList[[i]] <- list(Total = degree(graph.multiplex(obj)[[i]], v = indexNode, mode = "total", loops = FALSE),
                              In = degree(graph.multiplex(obj)[[i]], v = indexNode, mode = "in", loops = FALSE),
                              Out = degree(graph.multiplex(obj)[[i]], v = indexNode, mode = "out", loops = FALSE))
    }
  }
  names(degreeList) <- layers.multiplex(obj, label = T)
  return(degreeList)
}

#' @importFrom igraph degree.distribution
#' @export
degreeDistribution.multiplex <- function(obj){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  distributionList <- list()
# require(igraph)
  graphList <- graph.multiplex(obj)
  for(i in 1:length(layers.multiplex(obj))){
    distributionList[[i]] <- degree.distribution(graphList[[i]], mode = "total", loops = FALSE)
    names(distributionList[[i]]) <- sprintf("deg = %i", 0:(length(distributionList[[i]]) - 1))
  }
  names(distributionList) <- layers.multiplex(obj, label = T)
  return(distributionList)
}

#' @export
totalDegree.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj)), indexLayer = 1:length(layers.multiplex(obj)), verbose = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

# require(igraph)
  degreeList <- degree.multiplex(obj)

  totalDegree <- rep(0, length(nodes.multiplex(obj)))
  names(totalDegree) <- nodes.multiplex(obj, label = T)

  for(i in indexLayer){
    totalDegree <- totalDegree + as.vector(degreeList[[i]])
  }

  if(verbose){
    if(length(indexLayer) == 1){
      cat("Obtained with level", layers.multiplex(obj, label = T)[indexLayer],".\n")
    }
    else{
      cat("Obtained with levels", layers.multiplex(obj, label = T)[indexLayer],".\n")
    }
  }

  return(totalDegree[indexNode])
}

#' @export
meanDegree.multiplex <- function(obj, indexNodeMean = 1:length(nodes.multiplex(obj)), verbose = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  meanList <- list()
# require(igraph)
  degreeList <- degree.multiplex(obj, indexNodeMean)

  for(i in 1:length(layers.multiplex(obj))){
    meanList[[i]] <- mean(degreeList[[i]])
  }
  names(meanList) <- layers.multiplex(obj, label = T)

  if(verbose){
    if(length(indexNodeMean) == 1){
      cat("Mean obtained with node", nodes.multiplex(obj, label = T)[indexNodeMean],".\n")
    }
    else{
      cat("Mean obtained with nodes", nodes.multiplex(obj, label = T)[indexNodeMean],".\n")
    }
  }

  return(meanList)
}

#' @export
#' @importFrom stats var
varianceDegree.multiplex <- function(obj, indexNodeVar = 1:length(nodes.multiplex(obj)), verbose = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  varList <- list()
# require(igraph)
  degreeList <- degree.multiplex(obj, indexNodeVar)

  N <- length(indexNodeVar)

  for(i in 1:length(layers.multiplex(obj))){
    varList[[i]] <- (N - 1)/N * var(degreeList[[i]])
  }
  names(varList) <- layers.multiplex(obj, label = T)

  if(verbose){
    if(length(indexNodeVar) == 1){
      cat("Variance obtained with node", nodes.multiplex(obj, label = T)[indexNodeVar],".\n")
    }
    else{
      cat("Variance obtained with nodes", nodes.multiplex(obj, label = T)[indexNodeVar],".\n")
    }
  }
  return(varList)
}

#' @export
#' @importFrom igraph graph.density
densityLayers.multiplex <- function(obj){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  densityList <- list()
# require(igraph)
  graphList <- graph.multiplex(obj)

  for(i in 1:length(layers.multiplex(obj))){
    densityList[[i]] <- graph.density(graphList[[i]], loops = FALSE)
  }
  names(densityList) <- layers.multiplex(obj, label = T)

  return(densityList)
}

#' @export
aggregatedTopological.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj)), indexLayer = 1:length(layers.multiplex(obj)), verbose = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  N <- length(indexNode)
  A <- matrix(0, N, N)
  colnames(A) <- nodes.multiplex(obj, label = T)[indexNode]
  rownames(A) <- as.character(nodes.multiplex(obj))[indexNode]

  for(i in 1:N){
    for(j in 1:N){
      if (i == j) next
      positionX <- indexNode[i]
      positionY <- indexNode[j]
      for(z in indexLayer){
        if(adjacency.multiplex(obj)[[z]][positionX, positionY] > 0){
          A[i, j] <- 1
          break
        }
      }
    }
  }

  if(verbose){
    if(length(indexLayer) == 1){
      cat("Matrix obtained with level", layers.multiplex(obj, label = T)[indexLayer],".\n")
    }
    else{
      cat("Matrix obtained with levels", layers.multiplex(obj, label = T)[indexLayer],".\n")
    }
  }

  return(A)
}

#' @export
aggregatedOverlapping.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj)), indexLayer = 1:length(layers.multiplex(obj)), verbose = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  N <- length(indexNode)
  A <- matrix(0, N, N)
  colnames(A) <- nodes.multiplex(obj, label = T)[indexNode]
  rownames(A) <- as.character(nodes.multiplex(obj))[indexNode]

  for(z in indexLayer){
    A <- A + adjacency.multiplex(obj)[[z]][indexNode, indexNode]
  }

  if(verbose){
    if(length(indexLayer) == 1){
      cat("Matrix obtained with level", layers.multiplex(obj, label = T)[indexLayer],".\n")
    }
    else{
      cat("Matrix obtained with levels", layers.multiplex(obj, label = T)[indexLayer],".\n")
    }
  }
  return(A)
}

#' @export
supraAdjacency.multiplex <- function(obj){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  adjList <- adjacency.multiplex(obj)
  N <- length(nodes.multiplex(obj))
  L <- length(adjList)

  supraMatrix <- obj$interlayersMatrix

  for(i in 1:L){
    supraMatrix[(1 + (i - 1) * N):(N + (i - 1) * N), (1 + (i - 1) * N):(N + (i - 1) * N)] <- as.matrix(adjList[[i]])
  }
  return(supraMatrix)
}


#entropy.degree.multiplex <- function(multiplex, indexNode = 1:length(nodes.multiplex(multiplex)), indexOverlappingLayer = 1:length(layers.multiplex(multiplex)), verbose = FALSE){
#  degreesOverlapped <- degree(graph.adjacency(aggregated.overlapping.multiplex(multiplex, indexLayer = indexOverlappingLayer), mode = "undirected"), loops = FALSE) # Vettore dei degree sull'overlapped
#
#  H <- function(row){
#    last <- length(row)
#    return(-sum((row[-last]/row[last]) * log((row[-last] + 0.001)/row[last]))) # Correzzione +0.5
#  }
#
#  tab <- cbind(simplify2array(degree.multiplex(multiplex))[, indexOverlappingLayer], degreesOverlapped)
#  out <- apply(tab, 1, H)[indexNode]
#
#  if(verbose){
#    plot(indexNode, out, xlab = "", ylab = "<- Heterogenity    |    Uniformity ->", ylim = c(0, max(out)),
#         main = "Entropy of degrees distribution", col = "blue", pch = 16, axes = FALSE)
#    lines(indexNode, out, col = "blue", lty = 3, lwd = 2)
#    box(); grid(lwd = 2)
#    axis(1, at = indexNode, labels = nodes.multiplex(multiplex, index = indexNode, label = T), las = 2)
#    axis(2, at = c(0, seq(min(out), max(out), length.out = 10)), labels = as.character(c(0, round(seq(min(out), max(out), length.out = 10), 2))), las = 1)
#  }
#  return(out)
#}

#' @export
#' @importFrom graphics plot
#' @importFrom graphics points
#' @importFrom graphics box
#' @importFrom graphics grid
#' @importFrom graphics axis
#' @importFrom igraph graph.adjacency
entropyDegree.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj)), indexOverlappingLayer = 1:length(layers.multiplex(obj)), display = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

# require(igraph)
  degreesOverlapped <- degree(graph.adjacency(aggregatedOverlapping.multiplex(obj, indexLayer = indexOverlappingLayer), mode = "undirected"), loops = FALSE) # Vettore dei degree sull'overlapped

  H <- function(row){
    last <- length(row)
    return(-sum((row[-last]/row[last]) * log((row[-last] + 0.001)/row[last]))) # Correction +0.001
  }

  tab <- cbind(simplify2array(degree.multiplex(obj))[, indexOverlappingLayer], degreesOverlapped)
  out <- apply(tab, 1, H)[indexNode]

  if(display){
    plot(indexNode, sort(out, decreasing = T), xlab = "", ylab = "<- Heterogenity    |    Uniformity ->", ylim = c(0, max(out)),
         main = "Entropy of degrees distribution", col = "blue", axes = FALSE, type = "h")
    points(indexNode, sort(out, decreasing = T), pch = 16, col = "blue")
    box(); grid(lwd = 2)
    axis(1, at = indexNode, labels = names(sort(out, decreasing = T)), las = 2)
    axis(2, at = c(0, seq(min(out), max(out), length.out = 10)), labels = as.character(c(0, round(seq(min(out), max(out), length.out = 10), 2))), las = 1)
  }
  return(out)
}

#' @export
#' @importFrom graphics plot
#' @importFrom graphics points
#' @importFrom graphics box
#' @importFrom graphics grid
#' @importFrom graphics axis
#' @importFrom igraph graph.adjacency
#' @importFrom graphics abline
participationDegree.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj)), indexOverlappingLayer = 1:length(layers.multiplex(obj)), display = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

# require(igraph)
  degreesOverlapped <- degree(graph.adjacency(aggregatedOverlapping.multiplex(obj, indexLayer = indexOverlappingLayer)), loops = FALSE) # Vettore dei degree sull'overlapped

  P <- function(row){
    last <- length(row)
    return(1 - sum((row[-last]/row[last])^2))
  }

  tab <- cbind(simplify2array(degree.multiplex(obj))[, indexOverlappingLayer], degreesOverlapped)
  out <- apply(tab, 1, P)[indexNode]

  if(display){
    plot(indexNode, sort(out, decreasing = T), xlab = "", ylab = "<- Focused   |  Mixed  |   Truly Multiplex ->", ylim = c(0, 1),
         main = "Multiplex Participation Index", col = "red", axes = FALSE, type = "h")
    points(indexNode, sort(out, decreasing = T), pch = 16, col = "red")
    box(); grid(lwd = 2)
    axis(1, at = indexNode, labels = names(sort(out, decreasing = T)), las = 2)
    axis(2, at = c(seq(0, 0.75, by = 0.25), seq(0.75, 1, by = 0.05)), labels = as.character(c(seq(0, 0.75, by = 0.25), seq(0.75, 1, by = 0.05))), las = 1)
    abline(h=c(1/3, 2/3), lwd = 2, col = "green", lty = 2)
  }

  return(out)
}

#' @export
#' @importFrom igraph transitivity
localClustering.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj))){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  graphList <- graph.multiplex(obj)
# require(igraph)
  clusteringList <- list()

  for(i in 1:length(layers.multiplex(obj))){
    clusteringList[[i]] <- transitivity(graphList[[i]], type = "local", vids = indexNode)
    names(clusteringList[[i]]) <- nodes.multiplex(obj, label = T)[indexNode]
  }

  names(clusteringList) <- layers.multiplex(obj, label = T)
  return(clusteringList)
}

# This function comes from 'gtools' package:
# https://cran.r-project.org/web/packages/gtools/index.html

permutations <- function(n, r, v = 1:n, set = TRUE, repeats.allowed=FALSE){
  if(mode(n) != "numeric" || length(n) != 1
     || n < 1 || (n %% 1) != 0) stop("bad value of n")
  if(mode(r) != "numeric" || length(r) != 1
     || r < 1 || (r %% 1) != 0) stop("bad value of r")
  if(!is.atomic(v) || length(v) < n)
    stop("v is either non-atomic or too short")
  if( (r > n) & repeats.allowed==FALSE)
    stop("r > n and repeats.allowed=FALSE")
  if(set) {
    v <- unique(sort(v))
    if (length(v) < n) stop("too few different elements")
  }
  v0 <- vector(mode(v), 0)
  ## Inner workhorse
  if(repeats.allowed)
    sub <- function(n, r, v)
    {
      if(r==1) matrix(v,n,1) else
        if(n==1) matrix(v,1,r) else
        {
          inner  <-  Recall(n, r-1, v)
          cbind( rep( v, rep(nrow(inner),n)  ),
                 matrix( t(inner), ncol=ncol(inner), nrow=nrow(inner) * n ,
                         byrow=TRUE )
          )
        }
    }
  else
    sub <- function(n, r, v)
    {
      if(r==1) matrix(v,n,1) else
        if(n==1) matrix(v,1,r) else
        {
          X  <-  NULL
          for(i in 1:n)
            X  <-  rbind( X, cbind( v[i], Recall(n-1, r - 1, v[-i])))
          X
        }
    }

  sub(n, r, v[1:n])
}

#' @export
c1Local.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj)), indexLayer = 1:length(layers.multiplex(obj))){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  N <- length(nodes.multiplex(obj))
  L <- length(indexLayer)
  if(L < 2) stop("c1 can only be defined for multiplex composed of at least 2 layers.")
  adjList <- adjacency.multiplex(obj) # List of adjacency matrices for each level of the multiplex network.

# require(gtools)
  couples <- t(permutations(n = L, r = 2, indexLayer))

  numMatrix <- matrix(0, N, N)
  for(i in 1:ncol(couples)){
    numMatrix <- numMatrix + as.matrix(adjList[[couples[1, i]]] %*% adjList[[couples[2, i]]] %*% adjList[[couples[1, i]]])
  }

  sumDegree <- rep(0, N)
  for(i in indexLayer){
    sumDegree <- sumDegree + (degree.multiplex(obj)[[i]] * (degree.multiplex(obj)[[i]] - 1)) # Vettore (denom)
  }

  out <- (diag(numMatrix)/((L - 1) * sumDegree))
  names(out) <- nodes.multiplex(obj, label = T)
  return(out[indexNode])
}

#' @export
c2Local.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj)), indexLayer = 1:length(layers.multiplex(obj))){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  N <- length(nodes.multiplex(obj))
  L <- length(indexLayer)
  if(L < 3) stop("c2 can only be defined for multiplex composed of at least 3 layers.")
  adjList <- adjacency.multiplex(obj)

# require(gtools)
  triples <- t(permutations(n = L, r = 3, indexLayer))
  couples <- t(permutations(n = L, r = 3, indexLayer))

  numMatrix <- matrix(0, N, N)
  for(i in 1:ncol(triples)){
    numMatrix <- numMatrix + as.matrix(adjList[[triples[1, i]]] %*% adjList[[triples[2, i]]] %*% adjList[[triples[3, i]]])
  }

  denMatrix <- matrix(0, N, N)
  for(i in 1:ncol(couples)){
    denMatrix <- denMatrix + as.matrix(adjList[[couples[1, i]]] %*% (matrix(1, N, N) - diag(1, N)) %*% adjList[[couples[2, i]]])
  }

  out <- diag(numMatrix)/((L - 2) * diag(denMatrix))
  names(out) <- nodes.multiplex(obj, label = T)
  return(out[indexNode])
}

#' @export
C1Global.multiplex <- function(obj, indexLayer = 1:length(layers.multiplex(obj))){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  N <- length(nodes.multiplex(obj))
  L <- length(indexLayer)
  if(L < 2) stop("C1 can only be defined for multiplex composed of at least 2 layers.")
  adjList <- adjacency.multiplex(obj)

# require(gtools)
  couples <- t(permutations(n = L, r = 2, indexLayer))

  numMatrix <- matrix(0, N, N)

  for(i in 1:ncol(couples)){
    numMatrix <- numMatrix + as.matrix(adjList[[couples[1,i]]] %*% adjList[[couples[2, i]]] %*% adjList[[couples[1, i]]])
  }

  denMatrix <- matrix(0, N, N)
  for(i in indexLayer){
    denMatrix <- denMatrix + as.matrix(adjList[[i]] %*% (matrix(1, N, N) - diag(1, N)) %*% adjList[[i]])
  }

  return(sum(diag(numMatrix))/sum(diag(denMatrix)))
}

#' @export
C2Global.multiplex <- function(obj, indexLayer = 1:length(layers.multiplex(obj))){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  N <- length(nodes.multiplex(obj))
  L <- length(indexLayer)
  if(L < 3) stop("C2 can only be defined for sysyems composed of at least 3 layers.")
  adjList <- adjacency.multiplex(obj)

# require(gtools)
  triples <- t(permutations(n = L, r = 3, indexLayer))
  couples <- t(permutations(n = L, r = 3, indexLayer))


  numMatrix <- matrix(0, N, N)
  for(i in 1:ncol(triples)){
    numMatrix <- numMatrix + as.matrix(adjList[[triples[1, i]]] %*% adjList[[triples[2, i]]] %*% adjList[[triples[3, i]]])
  }

  denMatrix <- matrix(0, N, N)
  for(i in 1:ncol(couples)){
    denMatrix <- denMatrix + as.matrix(adjList[[couples[1, i]]] %*% (matrix(1, N, N) - diag(1, N)) %*% adjList[[couples[2, i]]])
  }

  return(sum(diag(numMatrix))/sum(diag(denMatrix)))
}

#' @export
globalOverlayClustering.multiplex <- function(obj, indexLayer = 1:length(layers.multiplex(obj)), verbose = FALSE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  overlayMatrix <- aggregatedOverlapping.multiplex(obj, indexLayer = indexLayer)
  L <- length(indexLayer)
  N <- length(nodes.multiplex(obj))
  adjList <- adjacency.multiplex(obj)

  max <- 0
  for(i in 1:N){
    for(j in 1:N){
      if(overlayMatrix[i, j] > max){
        max <- overlayMatrix[i, j]
      }
    }
  }

  if(verbose) cat("Standardizing coefficient:", max/L, ".\n")

  numMatrix <- overlayMatrix %*% overlayMatrix %*% overlayMatrix
  denMatrix <- overlayMatrix %*% (matrix(L, N, N) - diag(L, N)) %*% overlayMatrix
  return(sum(diag(numMatrix))/((max/L) * sum(diag(denMatrix))))
}

#' @export
degreeCentrality.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj))){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  overlayMatrix <- aggregatedOverlapping.multiplex(obj)
  N <- length(nodes.multiplex(obj))

  interlayersMatrix <- matrix(0, N, N)
  for(i in 1:length(layers.multiplex(obj))){
    for(j in 1:length(layers.multiplex(obj))){
      if(i == j){
        next
      }
      else{
        interlayersMatrix <- interlayersMatrix + interlayer.multiplex(obj, level1 = i, level2 = j)
      }
    }
  }

  projMatrix <- overlayMatrix + interlayersMatrix
  out <- as.vector(projMatrix %*% rep(1, N))
  names(out) <- nodes.multiplex(obj, label = T)
  return(out[indexNode])
}

#' @export
supraEigenvectorCentrality.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj)), rowStand = TRUE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  supraMatrix <- supraAdjacency.multiplex(obj) # Supra adjacency matrix
  N <- length(nodes.multiplex(obj))
  L <- length(layers.multiplex(obj))

  supraEigenvector <- eigen(supraMatrix)$vectors[,1]

  outMatrix <- matrix(supraEigenvector, nrow = L, ncol = N, byrow = T)
  rownames(outMatrix) <- layers.multiplex(obj, label = T)
  colnames(outMatrix) <- nodes.multiplex(obj, label = T)

  if(rowStand){
    outMatrix <- t(apply(outMatrix, 1, function(row) row/sum(row)))
  }

  if(sign(Re(outMatrix[1,1])) == -1) return((-1) * Re(outMatrix[, indexNode]))
  else return(Re(outMatrix[, indexNode]))
}

#' @export
heterEigenvectorCentrality.multiplex <- function(obj, indexNode = 1:length(nodes.multiplex(obj)), W = matrix(1, length(layers.multiplex(obj)), length(layers.multiplex(obj))), rowStand = TRUE){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  N <- length(nodes.multiplex(obj))
  L <- length(layers.multiplex(obj))
  adjList <- adjacency.multiplex(obj)

  adjTransposeBlockVector <- do.call(cbind, lapply(adjList, t)) # Matrice rettangolare di dimensione N * L.
  adjTransposeBlockVectorMatrix <- do.call(rbind, replicate(L, adjTransposeBlockVector, simplify = FALSE))
  perronMatrix <- kronecker(W, matrix(1, N, N)) * adjTransposeBlockVectorMatrix

  perronEigenvector <- eigen(perronMatrix)$vectors[,1]

  outMatrix <- matrix(perronEigenvector, nrow = L, ncol = N, byrow = T)
  rownames(outMatrix) <- layers.multiplex(obj, label = T)
  colnames(outMatrix) <- nodes.multiplex(obj, label = T)

  if(rowStand){
    outMatrix <- t(apply(outMatrix, 1, function(row) row/sum(row)))
  }

  if(sign(Re(outMatrix[1,1])) == -1) return((-1) * Re(outMatrix[, indexNode]))
  else return(Re(outMatrix[, indexNode]))
}

##### NUOVO:

#' @importFrom networkD3 simpleNetwork
#' @importFrom igraph plot.igraph
#' @export
plot.multiplex <- function(obj, index = 1:length(layers.multiplex(obj)), interactive = FALSE, ...){
  if(class(obj) != "multiplex") stop("obj argument must be a multiplex object")

  if(interactive){
    if(length(index) == 1) {
      layerDataFrame <- as.data.frame(obj$layers[[index]])[, c(1, 2)]
      for(i in 1:2) layerDataFrame[, i] <- nodes.multiplex(obj, label = T)[layerDataFrame[, i]]
      simpleNetwork(layerDataFrame, fontSize = 15, zoom = T, ...)
    }
    else{
      stop("If interactive = TRUE, index must be a length-1 vector. Please select interactive = FALSE.")
    }
  }
  else{
    for(i in index){
      plot.igraph(graph.multiplex(obj)[[i]], main = layers.multiplex(obj, index = i, label = T), vertex.size = 10, ...)
      readline("Please press [enter] to see next graph.")
    }
  }
}

#' @export
plot <- function(obj, index = 1:length(layers.multiplex(obj)), ...){
  UseMethod("plot", obj)
}

#' @export
summary.multiplex <- function(obj, ...){
  cat("Multiplex network is composed of", length(nodes.multiplex(obj)), "nodes and",
      length(layers.multiplex(obj)), "layers.")

}

#' @export
summary <- function(obj, ...){
  UseMethod("summary", obj)
}

