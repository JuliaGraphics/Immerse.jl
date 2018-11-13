# Utilities we need. unzip is being contributed to ZipFile,
# the more memory-efficient lda is being offered to MultivariateStats.
function unzip(inputfilename, outputpath=pwd())
    r = ZipFile.Reader(inputfilename)
    for f in r.files
        outpath = joinpath(outputpath, f.name)
        if isdirpath(outpath)
            mkpath(outpath)
        else
            open(outpath, "w") do io
                write(io, read(f))
            end
        end
    end
    nothing
end

## Memory-efficient LDA
# These are large vectors, and storing the full covariance matrix is
# problematic. This algorithm works in terms of a projection onto a
# subspace spanning the means, which also serves to regularize. See
#   Yu, Hua, and Jie Yang. "A direct LDA algorithm for
#      high-dimensional data—with application to face recognition."
#      Pattern recognition 34.10 (2001): 2067-2070.
function lda(X::AbstractMatrix{T}, group::Vector{Int}) where {T}
    nd = size(X,1)
    dmeans, dX = lda_prepare(X, group)
    UB, SB, _ = svd(dmeans, thin=true)
    ikeep = SB .>= sqrt(eps(T))*maximum(SB)
    Y = UB[:,ikeep]
    Z = scale(Y, 1 ./ SB[ikeep])
    projW = Z'*dX
    UW, SW, _ = svd(projW, thin=true)
    eigenval = 1 ./ SW.^2
    eigenvec = Z*scale(UW, 1 ./ SW)
    # Normalize
    for j = 1:size(eigenvec,2)
        evn = zero(T)
        for i = 1:nd
            evn += eigenvec[i,j]^2
        end
        evn = sqrt(evn)
        for i = 1:nd
            eigenvec[i,j] /= evn
        end
    end
    # Start with largest eigenvalues first
    return eigenvec[:,end:-1:1], eigenval[end:-1:1]
end

function lda_prepare(X::AbstractMatrix{T}, group::Vector{Int}) where {T}
    nd = size(X,1)
    npoints = size(X,2)
    xbar = zeros(T,nd)
    ngroups = maximum(group)
    if ngroups > npoints
        error("The group indices must be consecutive, starting at 1")
    end
    ngroups > 1 || error("Must have more than one group")
    # Calculate the group means
    means = zeros(T,nd,ngroups)
    npergroup = zeros(Int,ngroups)
    for j = 1:npoints
        k = group[j]
        for i = 1:nd
            means[i,k] += X[i,j]
        end
        npergroup[k] += 1
    end
    keep = npergroup .> 0
    if !all(keep)
        npergroup = npergroup[keep]
        means = means[:,keep]
    end
    gindex = cumsum(keep)
    ngroups = length(npergroup)
    for j = 1:ngroups
        n = npergroup[j]
        for i = 1:nd
            xbar[i] += means[i,j]
            means[i,j] /= n
        end
    end
    for i = 1:nd
        xbar[i] /= npoints
    end
    # Compute differences from the means
    dX = Array(T, nd, npoints)
    for j = 1:npoints
        k = gindex[group[j]]
        for i = 1:nd
            dX[i,j] = X[i,j] - means[i,k]
        end
    end
    dmeans = means .- xbar
    dmeans, dX
end
