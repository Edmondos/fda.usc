fdata2plsr2=function (fdataobj, y, ncomp = 2, norm = TRUE,method="oscorespls", ...){
    C <- match.call()
    if (!is.fdata(fdataobj))
        stop("No fdata class")
    if (is.fdata(y))  ycen<-fdata.cen(y)$Xcen
    else  ycen = y - mean(y)

    X <- fdataobj[["data"]]
    tt <- fdataobj[["argvals"]]
    rtt <- fdataobj[["rangeval"]]
    nam <- fdataobj[["names"]]
    mm <- fdata.cen(fdataobj)
    xmean <- mm$meanX
    Xcen.fdata <- mm$Xcen
    n <- nrow(Xcen.fdata)
    J <- ncol(Xcen.fdata)
    Jmin <- min(c(ncomp, J, n))
    cnames <- paste("PLS", seq(1, ncol(fdataobj$data)), sep = "")
    response = "y"
     if (is.fdata(y)) {
       df <- data.frame(I(ycen$data), I(Xcen.fdata$data))
       print(names(df))
        cnames2 <- paste("PLS", seq(1, ncol(y$data)), sep = "")
        names(df) <- c("y","X")
        pf<-paste("y~X")
        print(names(df))
         }
     else {
     cnames <- paste("PLS", seq(1, ncol(fdataobj$data)), sep = "")
#    ycen = y - mean(y)
    response = "y"
    df <- data.frame(y, Xcen.fdata$data)
    colnames(df) <- c("y", cnames)
    pf <- paste(response, "~", sep = "")
    for (i in 1:length(cnames)) pf <- paste(pf, "+", cnames[i],
        sep = "")
         }
    res <- plsr(as.formula(pf), ncomp = ncomp, data = df, method = method,
        validation = "LO", ...)
    class(res$loadings) <- "matrix"
    vs <- fdata(t(res$loadings), tt, rtt, list(main = "pls.fdata",
        xlab = "t", ylab = "rotationloadings"))
    scores <- matrix(0, ncol = J, nrow = n)
    if (norm) {
        no <- norm.fdata(vs)
        vs$data <- sweep(vs$data, 1, drop(no), "/")
        scores[, 1:Jmin] <- inprod.fdata(Xcen.fdata, vs)
    }
    else {
        scores[, 1:Jmin] <- inprod.fdata(Xcen.fdata, vs)
    }
#    colnames(scores) <- paste("PLS", 1:J, sep = "")
    out <- list(rotation = vs, x = scores, res.pls = res, fdataobj.cen = Xcen.fdata,
        mean = xmean, y = y, l = 1:ncomp, C = C)
    class(out) = "fdata.comp"
    return(out)
}

################
################
dA<-function (w, A, dw){
    wa <- sqrt(sum((w * (A %*% w)))) #A=X`X que ya la han normalizado!!!!
    dummy <- (1/wa) * (diag(length(w)) - w %*% t(w) %*% A/(wa^2)) %*%   dw
    return(dummy)
}
################
################
vvtz<-function (v, z){as.vector(v %*% (t(v) %*% z))}
################
################
dvvtz<-function (v, z, dv, dz) {
    if (is.matrix(v) == FALSE) {
        v <- matrix(v, ncol = 1)
        dv <- array(dv, dim = c(1, nrow(dv), ncol(dv)))
    }
    k = ncol(v)
    p <- nrow(v)
    n <- dim(dv)[3]
    dummy <- matrix(0, dim(dv)[2], dim(dv)[3])
    for (i in 1:k) {
        D <- (v[, i] %*% t(z) + sum(v[, i] * z) * diag(p)) %*%
            dv[i, , ] + v[, i] %*% t(v[, i]) %*% dz
        dummy <- dummy + D
    }
    return(dummy)
}
#######################################################################
########################################################################
fdata2pls<-function(fdataobj,y, ncomp = 2,norm=TRUE,...) {
if (!is.fdata(fdataobj)) fdataobj<-fdataobj(fdataobj)
    C <- match.call()
    X<-fdataobj$data
    tt<-fdataobj[["argvals"]]
    rtt<-fdataobj[["rangeval"]]
    nam<-fdataobj[["names"]]
    J <- ncol(X);n <- nrow(X)
    Jmin<-min(c(J,n))
    Jmax = min(J+1,n-1)
    Beta <- matrix(, J,ncomp)
    W <- V <- Beta
    dW <- dBeta <- dV <- array(dim = c(ncomp, J, n))
    X0 <- X;  y0 <- y
    mean.y <- mean(y)
    y <- scale(y, scale = FALSE)
    center<-fdata.cen(fdataobj)
    mean.X<-center$meanX
    X<-center$Xcen$data

#    sdx = sqrt(apply(X, 2, var))
#    sd.X<-rep(mean(sd.X),len=J)
#    sd.X[sd.X == 0] = 1
if (norm)    {
 sd.X <- sqrt(apply(X, 2, var))
 X <- X/(rep(1, nrow(X)) %*% t(sd.X))
 }
    else {
#    X <-X/(rep(1, nrow(X)) %*%t(rep(mean(sd.X),J)))
    sd.X<-rep(1,len=J)
}
    repnX<-rep(1, n)
    X2<-fdata(X,tt,rtt,nam)
    dcoefficients = NULL
    DoF <- rep(NA,ncomp)#1:(ncomp + 1) ###
    tX<-t(X)
    A <- crossprod(X)
    b <- crossprod(X,y)
# r <- eigen(A)
# VV <- r$vectors; lam <- r$values,
# AA = VV%*% diag(lamb)%*%solve(V)
    W[, 1] <- b
    dV[1, , ] <- dW[1, , ] <- dA(W[, 1], A, tX)
    W[, 1] <- W[, 1]/sqrt((sum((W[, 1]) * (A %*% W[,1]))))
    V[, 1] <- W[, 1]
    Beta[, 1] <- sum(V[, 1] * b) * V[, 1]
    dBeta[1, , ] <-dvvtz(V[, 1], b, dV[1, , ],tX)
    DoF[1]<-traza(X %*%dBeta[1,,] + matrix(1,n, n)/n)
    if (ncomp>1) {
    for (i in 2:ncomp) {
            vsi <-b - A %*% Beta[, i - 1]
            W[, i]<-vsi
            dW[i, , ] <- t(X) - A %*% dBeta[i - 1, , ]
            V[, i] <- W[, i] - vvtz(V[, 1:(i - 1), drop = FALSE],A %*% W[, i])
            dV[i, , ] = dW[i, , ] - dvvtz(V[, 1:(i - 1),drop = FALSE],
              A %*% W[, i], dV[1:(i - 1), , , drop = FALSE], A %*% dW[i, , ])
            dV[i, , ] <- dA(V[, i], A, dV[i, , ])
            V[, i] <- V[, i]/sqrt((sum(t(V[, i]) %*% A %*% V[,i])))
            Beta[, i] = Beta[, i - 1] + sum(V[, i] * b) * V[,i]
            dBeta[i,,]<-dBeta[i-1,,]+dvvtz(V[,i],b,dV[i,,],tX)
            DoF[i] <-traza(X %*%dBeta[i,,] + matrix(1,n, n)/n)
            }
    }
    if (norm) {
      V2<- fdata(t(V)*(rep(1, nrow(t(V))) %*% t(sd.X)),tt,rtt,nam)
      V2$data<-sweep(V2$data,1,norm.fdata(V2),"/")
      }
    else V2<-fdata(t(V),tt,rtt,nam)
#    V2$data<-sweep(V2$data,1,norm.fdata(V2),"/")
    DoF[DoF > Jmax] = Jmax
    scores<-inprod.fdata(X2,V2,...)
#    scores<-X2$data%*%V
    l<-1:ncomp
    colnames(scores) <- paste("PLS", l, sep = "")
    outlist = list(call=C,df = DoF, rotation=V2,x=scores,fdataobj=fdataobj,
    y=y0,l=l,fdataobj.cen=center$Xcen,mean=mean.X,X2=X2,norm=norm)
    class(outlist)<-"fdata.comp"
    return(outlist)
}