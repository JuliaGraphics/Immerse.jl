using Images, Immerse, Gadfly, Gtk, DataFrames, ExtraMatrix

function load_faces(parentdir="orl_faces")
    imgs = Any[]
    group = Int[]
    for i = 1:40
        childdir = joinpath(parentdir, string("s", i))
        for j = 1:10
            img = imread(joinpath(childdir, string(j, ".pgm")))
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
    c = @GtkCanvas()
    f = @GtkAspectFrame(c, "", 0.5, 0.5, size(img,1)/size(img,2))
    win = @GtkWindow(f, string("Face ", indx))
    showall(win)
    c.draw = function(widget)
        copy!(widget, imgs[indx])
    end
end

imgs, group = load_faces()
proj = run_lda(imgs, group)
df = DataFrame(Any[vec(proj[1,:]),vec(proj[2,:]),group], [:comp1,:comp2,:group])
p = plot(df, x=:comp1, y=:comp2, color=:group, Geom.point(tag=:lda));

hfig = display(p)
hit(hfig, :lda, @guarded (mindist, i) -> if mindist < 2 showimg(imgs, i) end)
