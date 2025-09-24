--[[

    website_gallery.lua - export photos to a website gallery on disk

    Copyright (C) 2024 Bill Ferguson <wpferguson@gmail.com>.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
    website_gallery - export photos to a website gallery on disk

    <description>

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    <additional software>

    USAGE
    <usage>

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson@gmail.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local ds = require "lib/dtutils.string"
local dtsys = require "lib/dtutils.system"
local log = require "lib/dtutils.log"
-- local debug = require "darktable.debug"


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "website_gallery"
local DEFAULT_LOG_LEVEL <const> = log.warn
local TMP_DIR <const> = dt.configuration.tmp_dir
local CSS_FILE = dt.configuration.config_dir .. "/data/CSSBox.css"

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

local HEADER_HTML <const> = [[<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="Content-type" content="text/html;charset=UTF-8" />
    <link rel="shortcut icon" href="style/favicon.ico" />
    <link rel="stylesheet" href="style/cssbox.css" type="text/css" />
    <title>darktable gallery</title>
  </head>
  <body>
    <div class="title">darktable gallery</div>

]]

local FOOTER_HTML <const> = [[  </body>
</html>

]]

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A P I  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - - 

du.check_min_api_version("7.0.0", MODULE)   -- choose the minimum version that contains the features you need


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- I 1 8 N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- S C R I P T  M A N A G E R  I N T E G R A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local script_data = {}

script_data.destroy = nil           -- function to destory the script
script_data.destroy_method = nil    -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil           -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil              -- only required for libs since the destroy_method only hides them

script_data.metadata = {
  name = _("website_gallery"),         -- visible name of script
  purpose = _("export photos to a website gallery on disk"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",   -- your name and optionally e-mail address
  help = ""                   -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local website_gallery = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = website_gallery
local wg = website_gallery

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function build_image_html(image_name, thumb_name, num, total, theight, twidth)
  local html = {}

  local image_id = "id=\"image" .. num .. "\""
  local image_href = " href=#image" .. num .. "\""
  local prev_tag = num > 1 and "#image" .. tostring(num -1) or nil
  local next_tag = num == total and nil or "#image" .. tostring(num + 1)
  local thumb_dims = " height=\"" .. tostring(theight) .. "\" width=\"" .. tostring(twidth) .. "\"/>\""
  local thumb_src = "src=\"" .. thumb_name .. "\" "
  local image_src = "src=\"" .. image_name .. "\""


  table.insert("    <div class=\"cssbox\">")
  table.insert("    <a " .. image_id ..image_href .. "><img class=\"cssbox_thumb\" " .. thumb_src .. thumb_dims)
  table.insert("        <span class=\"cssbox_full\"><img " .. image_src" /></span>")
  table.insert("    </a>")
  table.insert("    <a class=\"cssbox_close\" href=\"#void\"></a>")
  if prev_tag then
    table.insert("    <a class=\"cssbox_prev\" href=\"" .. prev_tag .. "\">&lt;</a>")
  end
  if next_tag then
    table.insert("<a class=\"cssbox_next\" href=\"" .. next_tag .. "\">&gt;</a>")
  end
  table.insert("    </div>")


end

-- store function
local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
    dt.print(string.format(_("export image %i/%i"), number, total))
end

-- finialize function
local function build_gallery(storage, image_table, extra_data)
end

-- setup function
local function setup(storage, img_format, image_table, high_quality, extra_data)
end

local function supported_formats(storage, format)
  local retval = false

  if format.name == "avif" or
     format.name == "jpeg" or
     format.name == "tif" or
     format.name == "webp" then
       return true
  else
    return false
  end
end

local function build_webpage(storage, image_table, extra_data)
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- register storage
dt.register_storage(
  "new_website_gallery",
  _("new_website gallery"), 
  show_status, 
  build_gallery,
  supported_formats, 
  setup, 
  wg.storage_widget
)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  -- put things to destroy (events, storages, etc) here
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

return script_data
