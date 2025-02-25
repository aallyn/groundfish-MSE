


# path_current <- Sys.getenv('PATH')
# path_new <- paste0('c:\\Rtools\\bin;c:\\Rtools\\mingw_32\\bin;', 
#                    path_current)
# Sys.setenv(PATH=path_new)

# load the TMB package
require(TMB)

# unlink('scratch/growth/tmbModel/full/growth.o')
# unlink('scratch/growth/tmbModel/full/growth.dll')

# compile the c++ file and make available to R
compile("scratch/growth/tmbModel/full_logistic/growth.cpp")
dyn.load(dynlib("scratch/growth/tmbModel/full_logistic/growth"))


# read in the data
load('data/data_processed/trawlBiol.Rdata') # biol
# load('data/data_processed/gbT.Rdata')       # gbT
load(file='data/data_raw/mqt_oisst.Rdata') #mqt_oisst
mqt_oisst <- mqt_oisst[complete.cases(mqt_oisst),]
# gbT$Year <- as.numeric(gbT$Year)


tdc <- subset(biol, COMNAME == 'ATLANTIC COD')


yss <- substr(tdc$CRUISE, start=1, stop=4)
tdc$YEAR <- as.numeric(yss)
tdcsub0 <- tdc[,c('YEAR', 'AGE', 'LENGTH')]
tdcsub1 <- subset(tdcsub0, AGE > 0 & AGE < 11)
tdcsub <- tdcsub1[complete.cases(tdcsub1),]

# have to ensure that there is enough temperature data
# to get back into the history of the observed fish
# (could edit this to use slightly more data)
tdcsub <- subset(tdcsub, 
                 YEAR > min(mqt_oisst$Year) + max(tdcsub$AGE))


## check which temp you're using in data()

# get overall average
mqt_oisst$T <- apply(mqt_oisst[,2:13], 1, mean, na.rm=TRUE)
mqt_oisst <- subset(mqt_oisst, Year <= max(tdcsub$YEAR))


# number of years to include in the analysis will be the
# number of years there are altogether plus an initialization
# period of mxage
mxage <- max(tdcsub$AGE)
mxyear <- max(tdcsub$YEAR)
nyear <- length(unique(tdcsub$YEAR))
nage <- length(unique(tdcsub$AGE))
avec <- sort(unique(tdcsub$AGE))

data <- list(nyear = nyear+nage,
             nage = nage,
             mxage = mxage,
             mxyear = mxyear,
             avec = avec,
             nrec = nrow(tdcsub),
             YEAR = tdcsub$YEAR,
             AGE = tdcsub$AGE,
             LENGTH = tdcsub$LENGTH,
             TEMP = mqt_oisst$q3 - mean(mqt_oisst$q3))

# could put the betas on a log scale and force them
# to start positive and head negative. Not doing this lets
# the data decide what to do.
parameters <- list(alpha0 = 0,
                   alpha1 = -0.5,#0,
                   log_alpha2 = log(5), # A50
                   log_Linf = log(108.4925139), 
                   log_K = log(0.1805161),
                   t0 = -0.5958480,
                   log_oe_L = 0.5)

# Set parameter bounds
lb <- list(alpha0 = -4,
           alpha1 = -5,
           log_alpha2 = log(0.01), 
           log_Linf = log(80),
           log_K = log(0.001),
           t0 = -1,
           log_oe_L = log(0.001))

ub <- list(alpha0 = 4,
           alpha1 = 5,
           log_alpha2 = log(20),
           log_Linf = log(200), 
           log_K = log(1),
           t0 = 1,
           log_oe_L = log(20))


map_par <- list(
                # alpha0 = factor(NA),
                # alpha1 = factor(NA)
                log_alpha2 = factor(NA)
                # log_Linf = factor(NA),
                # log_K = factor(NA),
                # t0 = factor(NA)
                # log_oe_L = factor(NA)
)


# map_par <- list() # all parameters active


# make an objective function
obj <- MakeADFun(data = data,
                 parameters = parameters,
                 DLL = "growth",
                 map = map_par
)


# index for active parameter bounds
# (note that R does not give an error message if the wrong
# number of parameter bounds are given
# if having estimation problems parameter bounds are a good
# place to check)
active_idx <- !names(lb) %in% names(map_par)



# run the model using the R function nlminb()
opt <- nlminb(start=obj$par,
              objective=obj$fn,
              gradient=obj$gr,
              lower=unlist(lb[active_idx]),
              upper=unlist(ub[active_idx]))



# estimates and standard errors (run after model optimization)
sdrep <- sdreport(obj)


# list of variables exported using REPORT() function in c++ code
rep <- obj$report()
print(rep$L[1:3,1:8])
print(sdrep)
aic <- 2*sum(active_idx) - 2*rep$NLL
print(paste('AIC', aic))

plot(LENGTH ~ AGE, data=tdcsub, ylim=c(0, 155),
     xlim=c(0, 20))
vb <- function(x) rep$Linf * (1-exp(-rep$K*(x-rep$t0)))
curve(vb, from=0, to=20, add=TRUE, col='blue', lwd=5)


m <- nls(LENGTH~Linf * (1-exp(-K*(AGE-t0))),
         data=tdcsub,
         start=list(Linf=120, K=0.2, t0=0))
vb2 <- function(x) coef(m)['Linf'] *
                   (1-exp(-coef(m)['K']*(x-coef(m)['t0'])))
curve(vb2, from=0, to=20, add=TRUE, col='red', lwd=2)





# adjustment is larger in recent years which means that
# they will be growing a little bit faster.
cfun <- colorRampPalette(c('blue', 'red'))
egam <- exp(rep$gamma[11:nrow(rep$gamma),])
cols <- cfun(nrow(egam))
plot(NA, ylim=range(egam), xlim=range(data$avec))
matplot(x=data$avec, y=t(egam), type='l', col=cols, add=TRUE,
        lty=1, lwd=2)
abline(h=1, lwd=4)






