local colors = {
  BOLD = string.char(27) .. "[1m",
  GRAY = string.char(27) .. "[90m",
  RED = string.char(27) .. "[91m",
  GREEN = string.char(27) .. "[92m",
  BLUE = string.char(27) .. "[94m",
  YELLOW = string.char(27) .. "[93m",
  DEEPBLUE = string.char(27) .. "[34m",
  PURPLE = string.char(27) .. "[95m",
  CYAN = string.char(27) .. "[96m",
  RST = string.char(27) .. "[0m",
}
colors.CARET = string.char(27) .. "[92m => ".. colors.RST

local function colorConvert(log)
  -- 我真服了这些HTML颜色了 统一都用一个不行么
  log = log:gsub('<font color="#0598BC">', string.char(27) .. "[34m")
  log = log:gsub('<font color="#0C8F0C">', string.char(27) .. "[32m")
  log = log:gsub('<font color="#CC3131">', string.char(27) .. "[31m")
  log = log:gsub("<font color='#BE2020'>", string.char(27) .. "[31m")
  log = log:gsub('<font color="red">', string.char(27) .. "[31m")
  log = log:gsub('<font color="black">', string.char(27) .. "[0m")
  log = log:gsub('<font color="#0598BC">', string.char(27) .. "[34m")
  log = log:gsub('<font color="blue">', string.char(27) .. "[34m")
  log = log:gsub('<font color="#0C8F0C">', string.char(27) .. "[32m")
  log = log:gsub('<font color="green">', string.char(27) .. "[32m")
  log = log:gsub('<font color="#CC3131">', string.char(27) .. "[31m")
  log = log:gsub('<font color="#B5BA00">', string.char(27) .. "[33m")
  log = log:gsub('<font color="grey">', string.char(27) .. "[90m")
  log = log:gsub("<font color='grey'>", string.char(27) .. "[90m")
  log = log:gsub("<b>", colors.BOLD)
  log = log:gsub("</b></font>", colors.RST)
  log = log:gsub("</font>", colors.RST)
  log = log:gsub("<b>", colors.BOLD)
  log = log:gsub("</b>", colors.RST)

  log = log:gsub("<br>", "\n")
  log = log:gsub("<br/>", "\n")
  log = log:gsub("<br />", "\n")
  return log
end

return {
  cb = function(command, jsonData)
    if command == "GameLog" then
      -- print(colorConvert(jsonData))
    elseif command == "ShowToast" then
      -- print("TOAST: " .. colorConvert(jsonData))
    else
      -- print(command, jsonData)
    end
  end,
}
