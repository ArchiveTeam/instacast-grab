dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local downloaded = {}
local addedtolist = {}

-- do not download following static files:
downloaded["https://instacastcloud.com/bootstrap/css/bootstrap.min.css"] = true
downloaded["https://instacastcloud.com/scripts/jquery-1.11.1.min.js"] = true
downloaded["https://instacastcloud.com/css/site.css"] = true
downloaded["https://instacastcloud.com/mediaelement/mediaelement-and-player.min.js"] = true
downloaded["https://instacastcloud.com/mediaelement/mediaelementplayer.min.css"] = true
downloaded["https://instacastcloud.com/shared/episode/mediaelement/flashmediaelement.swf"] = true
downloaded["https://instacastcloud.com/bootstrap/js/bootstrap.min.js"] = true
downloaded["https://instacastcloud.com/dashboard/contact"] = true
downloaded["https://instacastcloud.com/signin"] = true
downloaded["https://instacastcloud.com/dashboard"] = true
downloaded["http://vemedio.com/support/contact"] = true
downloaded["http://vemedio.com/discontinued/"] = true
downloaded["http://vemedio.com/"] = true
downloaded["http://vemedio.com/instacast"] = true
downloaded["https://oss.maxcdn.com/libs/respond.js/1.4.2/respond.min.js"] = true
downloaded["https://oss.maxcdn.com/libs/html5shiv/3.7.0/html5shiv.js"] = true
downloaded["https://instacastcloud.com/bootstrap/fonts/glyphicons-halflings-regular.eot"] = true
downloaded["https://instacastcloud.com/bootstrap/fonts/glyphicons-halflings-regular.eot?"] = true
downloaded["https://instacastcloud.com/bootstrap/fonts/glyphicons-halflings-regular.woff"] = true
downloaded["https://instacastcloud.com/bootstrap/fonts/glyphicons-halflings-regular.ttf"] = true
downloaded["https://instacastcloud.com/bootstrap/fonts/glyphicons-halflings-regular.svg"] = true
downloaded["https://instacastcloud.com/images/icon-50.png"] = true
downloaded["https://instacastcloud.com/mediaelement/bigplay.svg"] = true
downloaded["https://instacastcloud.com/mediaelement/bigplay.png"] = true
downloaded["https://instacastcloud.com/mediaelement/background.png"] = true
downloaded["https://instacastcloud.com/mediaelement/loading.gif"] = true
downloaded["https://instacastcloud.com/mediaelement/controls.svg"] = true
downloaded["https://instacastcloud.com/mediaelement/controls.png"] = true

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  
  if downloaded[url] == true or addedtolist[url] == true then
    return false
  end
  
  if (downloaded[url] ~= true or addedtolist[url] ~= true) then
    if (string.match(url, "/"..item_value) and string.match(url, "https?://instacastcloud%.com/") and not string.match(url, "/"..item_value.."[a-z0-9]")) or html == 0 then
      addedtolist[url] = true
      return true
    else
      return false
    end
  end
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  if downloaded[url] ~= true then
    downloaded[url] = true
  end
 
  local function check(url)
    if (downloaded[url] ~= true and addedtolist[url] ~= true) then
      if string.match(url, "&amp;") then
        table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&amp;", "&")] = true
      else
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end
  
  if string.match(url, item_value) then
    html = read_file(file)
    for newurl in string.gmatch(html, 'src=("https?.//[^"]+)"') do
      if not string.match(newurl, '"https?://') then
        check(string.match(newurl, '"(https?)')..":"..string.match(newurl, '"https?.(//.+)'))
      else
        check(string.match(newurl, '"(.+)'))
      end
    end
    for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
      if (string.match(url, "/"..item_value) and string.match(url, "https?://instacastcloud%.com/") and not string.match(url, "/"..item_value.."[a-z0-9]")) then
        check(newurl)
      end
    end
    for newurl in string.gmatch(html, '"(/[^"]+)"') do
      if (string.match(url, "/"..item_value) and string.match(url, "https?://instacastcloud%.com/") and not string.match(url, "/"..item_value.."[a-z0-9]")) then
        check("https://instacastcloud.com"..newurl)
      end
    end
  end
  
  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 403 and status_code ~= 400) then

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 1")

    tries = tries + 1

    if tries >= 6 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  elseif status_code == 0 then

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 10")
    
    tries = tries + 1

    if tries >= 6 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
