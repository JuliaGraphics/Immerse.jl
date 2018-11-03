using Immerse, Images, Gtk, DataFrames, ZipFile
import ImageView

const testdir = splitdir(@__FILE__)[1]
const facesdir = joinpath(testdir, "orl_faces")
const orl_url = "http://www.cl.cam.ac.uk/Research/DTG/attarchive/pub/data/att_faces.zip"

include("faces_utilities.jl")

if !isdir(facesdir)
    fn = download(orl_url)
    mkpath(facesdir)
    unzip(fn, facesdir)
end

function load_faces(parentdir=facesdir)
    imgs = Any[]
    group = Int[]
    for i = 1:40
        childdir = joinpath(parentdir, string("s", i))
        for j = 1:10
            img = load(joinpath(childdir, string(j, ".pgm")))
            push!(imgs, Images.data(img))
            push!(group, i)
        end
    end
    imgs, group
end

function run_lda(imgs, group)
    M = zeros(Float32, length(imgs[1]), length(imgs))
    for i = 1:length(imgs)
        M[:,i] = vec(imgs[i])
    end
    evec, eval = lda(M, group)
    evec[:,1:2]'*M
end

function showimg(imgs, indx)
    img = imgs[indx]
    c = GtkCanvas()
    f = GtkAspectFrame(c, "", 0.5, 0.5, size(img,1)/size(img,2))
    win = GtkWindow(f, string("Face ", indx))
    showall(win)
    c.draw = function(widget)
        copy!(widget, imgs[indx])
    end
end

function showimgs(imgs, indexes=1:length(imgs))
    imgm = grayim(cat(3, imgs[indexes]...))
    ImageView.view(imgm, pixelspacing=[1,1])
end

imgs, group = load_faces()
proj = run_lda(imgs, group)
df = DataFrame(Any[vec(proj[1,:]),vec(proj[2,:]),group], [:comp1,:comp2,:group])

include("faces_run.jl")
