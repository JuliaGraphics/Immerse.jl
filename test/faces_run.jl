p = plot(df, x=:comp1, y=:comp2, color=:group, Geom.point(tag=:lda));
figure()
hfig = display(p)
hit((hfig,:lda), @guarded (figtag, i, event, dist) -> if dist < 2 showimg(imgs, i) end)
lasso_initialize(hfig, (figno,selections) -> showimgs(imgs, first(values(selections))))
nothing
