--[[
config.lua
--]]

config = {
  controls = {
    toggleMenu = 'p',
    setPower = 'x',
    setAllPower = 'c'
  }
}

--[[
utils.lua
--]]

function string:tohex()
  return self:gsub('.', function (c)
    return string.format('%02X', string.byte(c))
  end)
end

--[[
controls.lua
--]]

local pressedControls = {}
local controlBinds = {}

local checkControl = function(controlName,formatted)  
  controlBinds[controlName] = controlBinds[controlName] or {}

  if not _G["c_" .. formatted .. "_keyDown"] then
    _G["c_" .. formatted .. "_keyDown"] = function(plyId)
      if not controlBinds[controlName][plyId].isPressed then
        controlBinds[controlName][plyId].isPressed = true

        for k,v in ipairs(controlBinds[controlName][plyId].onPressed) do
          v(plyId,controlName)
        end
      end
    end
  end
  
  if not _G["c_" .. formatted .. "_keyUp"] then
    _G["c_" .. formatted .. "_keyUp"] = function(plyId)
      if controlBinds[controlName][plyId].isPressed then
        controlBinds[controlName][plyId].isPressed = false

        for k,v in ipairs(controlBinds[controlName][plyId].onReleased) do
          v(plyId,controlName)
        end
      end    
    end
  end
end

controls = {}

controls.bind = function(playerId,controlName,onPressed,onReleased)
  local formatted = controlName:gsub(" ","_"):tohex()
  checkControl(controlName,formatted)

  if controlBinds[controlName][playerId] then
    if onPressed then
      table.insert(controlBinds[controlName][playerId].onPressed,onPressed)
    end

    if onReleased then
      table.insert(controlBinds[controlName][playerId].onReleased,onReleased)
    end
  else
    controlBinds[controlName][playerId] = {
      isPressed = false,
      onPressed = {onPressed},
      onReleased = {onReleased}
    }
  end

  tm.input.RegisterFunctionToKeyDownCallback  (playerId, "c_" .. formatted .. "_keyDown", controlName)
  tm.input.RegisterFunctionToKeyUpCallback    (playerId, "c_" .. formatted .. "_keyUp",   controlName)  
end

controls.glue = function(...)
  for i=1,#select("#",...),4 do
    local v = select(i,...)
    controls.bind(v.playerId or v[1],v.controlName or v[2],v.onPressed or v[3],v.onReleased or v[4])
  end
end

controls.unbind = function(playerId,controlName)
  controlBinds[controlName][playerId] = nil
end

controls.unglue = function(...)
  for i=1,#select("#",...),4 do
    local v = select(i,...)
    controls.unbind(v.playerId or v[1],v.controlName or v[2])
  end
end

--[[
ui.lua
--]]

local isOpen = {}
local wasOpen = {}
local prevBlock = {}
local powerMod = {}

local getBlockPower = function(block)
  local jetPower = block.GetJetPower()
  local engPower = block.GetEnginePower()

  if jetPower > 0 then
    return jetPower,"jet"
  elseif engPower > 0 then
    return engPower,"engine"
  end
end

local getAddMod = function(mod)
  if mod > 10000 then
    return math.min(100000.0,mod * 5.0)
  else
    return math.min(100000.0,mod * 10.0)
  end
end

local getSubMod = function(mod)
  if mod >= 50000 then
    return math.max(1.0,mod / 5.0)
  else
    return math.max(1.0,mod / 10.0)
  end
end

local clearUi = function(playerId)
  tm.playerUI.ClearUI(playerId)
end

local refreshUi = function(playerId,block)
  clearUi(playerId)
  powerMod[playerId] = powerMod[playerId] or 100.0

  local power,powerType

  if block then
    power,powerType = getBlockPower(block)
  end

  tm.playerUI.AddUILabel(playerId,"bt:power","Power: " .. (power or "N/A"))
  tm.playerUI.AddUILabel(playerId,"bt:mod","Mod: " .. powerMod[playerId])
  
  tm.playerUI.AddUIButton(playerId,"bt:addmod","Add Mod",function()
    powerMod[playerId] = getAddMod(powerMod[playerId])
    tm.playerUI.SetUIValue(playerId,"bt:mod","Mod: "..powerMod[playerId])
  end)
  
  tm.playerUI.AddUIButton(playerId,"bt:submod","Sub Mod",function()
    powerMod[playerId] = getSubMod(powerMod[playerId])
    tm.playerUI.SetUIValue(playerId,"bt:mod","Mod: "..powerMod[playerId])
  end)
end

local updateUi = function(playerId,block)
  local power,powerType

  if block then
    power,powerType = getBlockPower(block)
  end

  tm.playerUI.SetUIValue(playerId,"bt:power","Power: " .. (power or "N/A"))
end

local toggleMenu = function(playerId,controlName)
  if not tm.players.GetPlayerIsInBuildMode(playerId) then
    return
  end

  if isOpen[playerId] then
    wasOpen[playerId] = false
    isOpen[playerId] = false
    clearUi(playerId)
  else
    wasOpen[playerId] = true
    isOpen[playerId] = true
    refreshUi(playerId)
  end
end

local setPower = function(playerId,controlName)
  if not tm.players.GetPlayerIsInBuildMode(playerId) then
    return
  end

  if not powerMod[playerId] then
    return
  end

  local target = tm.players.GetPlayerSelectBlockInBuild(playerId)
  if not target then
    return
  end

  local power,type = getBlockPower(target)
  if not power then
    return
  end

  if type == "jet" then
    target.SetJetPower(powerMod[playerId])
  elseif type == "engine" then
    target.SetEnginePower(powerMod[playerId])
  end
end

local setAllPower = function(playerId,controlName)
  if not tm.players.GetPlayerIsInBuildMode(playerId) then
    return
  end

  if not powerMod[playerId] then
    return
  end

  local target = tm.players.GetPlayerSelectBlockInBuild(playerId)
  if not target then
    return
  end

  local structs = tm.players.GetPlayerStructuresInBuild(playerId)
  if not structs then
    return
  end

  local power,type = getBlockPower(target)
  if not power then
    return
  end

  for _,struct in ipairs(structs) do
    for _,block in ipairs(struct.GetBlocks()) do
      if block.GetName() == target.GetName() then
        if type == "jet" then
          block.SetJetPower(powerMod[playerId])
        elseif type == "engine" then
          block.SetEnginePower(powerMod[playerId])
        end
      end
    end
  end
end

ui = {}

ui.isOpen = function(playerId)
  return isOpen[playerId]
end

ui.toggle = function(playerId,block)
  if not playerId then
    return
  end

  if isOpen[playerId] then
    isOpen[playerId] = false
  else
    isOpen[playerId] = true
  end

  updateUi(playerId,block)
end

function update()
  local players = tm.players.CurrentPlayers()
  for _,player in ipairs(players) do
    local playerId = player.playerId
    if tm.players.GetPlayerIsInBuildMode(playerId) then      
      local selectedBlock = tm.players.GetPlayerSelectBlockInBuild(playerId)
      if not isOpen[playerId] and wasOpen[playerId] then
        isOpen[playerId] = true
        refreshUi(playerId,selectedBlock)
      elseif isOpen[playerId] then
        if not prevBlock[playerId] or prevBlock[playerId] ~= selectedBlock then
          prevBlock[playerId] = selectedBlock
          updateUi(playerId,selectedBlock)
        end
      end
    else
      if isOpen[playerId] then
        wasOpen[playerId] = true
        isOpen[playerId] = false
        clearUi(playerId)
      end
    end
  end
end

tm.players.OnPlayerJoined.add(function(player)
  controls.bind(player.playerId,config.controls.toggleMenu,toggleMenu)
  controls.bind(player.playerId,config.controls.setPower,setPower)
  controls.bind(player.playerId,config.controls.setAllPower,setAllPower)
end)