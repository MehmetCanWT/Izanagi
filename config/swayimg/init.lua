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
