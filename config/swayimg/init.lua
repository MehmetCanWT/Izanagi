-- swayimg configuration (Izanagi)

-- Automatically load all images in the same directory when opening a file
swayimg.imagelist.adjacent = true
swayimg.imagelist.order = "numeric"
swayimg.viewer.loop = true

-- Navigate previous/next image with Left/Right arrows (plus Space, h/l, PgUp/PgDn)
swayimg.viewer.on_key("Right", function()
  swayimg.viewer.open("next")
end)

swayimg.viewer.on_key("Left", function()
  swayimg.viewer.open("prev")
end)

swayimg.viewer.on_key("l", function()
  swayimg.viewer.open("next")
end)

swayimg.viewer.on_key("h", function()
  swayimg.viewer.open("prev")
end)

swayimg.viewer.on_key("Space", function()
  swayimg.viewer.open("next")
end)

-- WASD navigation (60% keyboard friendly)
swayimg.viewer.on_key("d", function()
  swayimg.viewer.open("next")
end)

swayimg.viewer.on_key("a", function()
  swayimg.viewer.open("prev")
end)

swayimg.viewer.on_key("w", function()
  swayimg.viewer.scale = swayimg.viewer.scale + swayimg.viewer.scale / 10
end)

swayimg.viewer.on_key("s", function()
  swayimg.viewer.scale = swayimg.viewer.scale - swayimg.viewer.scale / 10
end)

swayimg.gallery.on_key("a", function()
  swayimg.gallery.select("left")
end)

swayimg.gallery.on_key("d", function()
  swayimg.gallery.select("right")
end)

swayimg.gallery.on_key("w", function()
  swayimg.gallery.select("up")
end)

swayimg.gallery.on_key("s", function()
  swayimg.gallery.select("down")
end)
