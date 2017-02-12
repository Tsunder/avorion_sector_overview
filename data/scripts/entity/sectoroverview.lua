package.path = package.path .. ";data/scripts/lib/?.lua"

require("utility")
require("stringutility")


local stationList = nil
local gateList = nil
local playerList = nil
local tabMap = {}
local entities = {}
local playerAddedList = {}
local isWindowShowing = false
local window = nil
local tabbedWindow = nil
local playerTabIndex = nil
local playerIndexMap = {}

function getIcon()
    return "data/textures/icons/computer.png"
end

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)
    if Entity().factionIndex == playerIndex then
        return true, ""
    end

    return false
end

-- create all required UI elements for the client side
function initUI()
    local res = getResolution()
    local size = vec2(300, 400)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(window, "Sector Overview"%_t)
    window.caption = "Sector Overview"%_t
    window.showCloseButton = 1
    window.moveable = 1

    -- create a tabbed window inside the main window
    tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- stations
    local buildTab = tabbedWindow:createTab("Build"%_t, "data/textures/icons/rss.png", "Station List"%_t)
    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), tabbedWindow.size ), 10, 0, 0.5)
    hsplit.bottomSize = 40
    stationList = buildTab:createListBox(hsplit.top)
    tabMap[buildTab.index] = stationList

    -- ship
    local buildTab = tabbedWindow:createTab("Build"%_t, "data/textures/icons/vortex.png", "Gate List"%_t)
    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), tabbedWindow.size ), 10, 0, 0.5)
    hsplit.bottomSize = 40
    gateList = buildTab:createListBox(hsplit.top)
    tabMap[buildTab.index] = gateList

    -- Players
    local buildTab = tabbedWindow:createTab("Build"%_t, "data/textures/icons/backup.png", "Player List"%_t)
    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), tabbedWindow.size - vec2(0, 55) ), 10, 0, 0.5)
    hsplit.bottomSize = 70 
    playerList = buildTab:createListBox(hsplit.top)
    tabMap[buildTab.index] = playerList 
    playerTabIndex = buildTab.index

    local hsplit = UIHorizontalSplitter(hsplit.bottom, 10, 0, 0.5)
    hsplit.bottomSize = 35

    playerCombo = buildTab:createComboBox(hsplit.top, "")

    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)

    addScriptButton = buildTab:createButton(vsplit.left, "Add"%_t, "onAddPlayerToGroupPressed")
    addScriptButton.tooltip = 
        [[ Add the selected player from the combo box to the list of players"]]
    removeScriptButton = buildTab:createButton(vsplit.right, "Remove"%_t, "onRemovePlayerFromGroupPressed")
    removeScriptButton.tooltip =
        [[ "Remove the selected player from the list of players."]]

    local player = Player()
    print ("INIT PLAYER INFO craft : ", player.craftIndex,
           ", numShips :", player.numShips,
           "shipname :", player:getShipNames(),
           "ship pos2 : ",  "END")
    local x, y = player:getShipPosition(player:getShipNames())
end

function refreshPlayerList()
    -- small hack to keep the order of the players consistent on the screen
    playerList:clear()
    local playerSortedList = {}
    for name, isInList in pairs(playerAddedList) do
        if (isInList) then
            table.insert(playerSortedList, name)
        end
    end

    table.sort(playerSortedList)
    for _, name in ipairs(playerSortedList) do
        playerList:addEntry(name)
    end
end

function onAddPlayerToGroupPressed()
    local name = playerCombo.selectedEntry
    if (not playerAddedList[name]) then
        playerList:addEntry(name)
        playerAddedList[name] = true
        refreshPlayerList()
    end
end

function onRemovePlayerFromGroupPressed()
    local name = playerCombo.selectedEntry
    if (playerAddedList[name]) then
        playerAddedList[name] = nil 
        refreshPlayerList()
    end
end

function onShowWindow()
    entities = {}
    stationList:clear()
    gateList:clear()
    playerList:clear()
    playerCombo:clear()

    -- fill list for station and gates
    local player = Player()
    for index, entity in pairs({Sector():getEntities()}) do
        if (entity.type == EntityType.Station) then
            local titleArgs = entity:getTitleArguments()
            local title =  entity.title % titleArgs
            local entryName = title .. "    " .. entity.name 
            stationList:addEntry(entryName)
            entities[entryName] = entity
        end
        if (entity.title and string.match(entity.title, "Gate"))then
            local entryName = entity.title 
            gateList:addEntry(entryName)
            entities[entryName] = entity
        end
    end

    -- fill player combo box
    for index, name in pairs(Galaxy():getPlayerNames()) do
        print("FOR index ", index, " name ", name )
        if player.name:lower() ~= name:lower() then
            playerCombo:addEntry(name);
            print("WHAT ", name, " index ", index)
            playerIndexMap[name] = index
        end
    end

    refreshPlayerList()

    isWindowShowing = true
end

function onCloseWindow()
    isWindowShowing = false
end
function getPlayerCoord(playerIndex)
    print("getPlayerCoord index", playerIndex )
    if onServer() then
        print("getPlayerCoord server")
        local otherPlayer = Player(playerIndex)
        if (otherPlayer) then
            print("getPlayerCoord ship index ", otherPlayer.craftIndex)
            local ship = otherPlayer:getShipNames() 
            if (ship) then
                print("getPlayerCoord ship ", ship)
                local x, y = otherPlayer:getShipPosition(ship)
                print("on server in x ", x, " y ", y)
                invokeClientFunction(Player(callingPlayer), "showPlayerOnMap", x, y)
            end
            return 
        end
    end
end

function showPlayerOnMap(x, y)
    print("Got coord x ", x, " y ", y)
    GalaxyMap():show(x, y)
end

function updateUI()
    if not isWindowShowing then
        return end

    if Mouse():mouseDown(1) then
        local tabIndex = tabbedWindow:getActiveTab().index
        local selectedEntry = tabMap[tabIndex]:getSelectedEntry()
        if (selectedEntry) then
            if (tabIndex == playerTabIndex) then
                print("tabindex", selectedEntry)
                local playerIndex = playerIndexMap[selectedEntry]
                print ("tabindex player index ", playerIndex)
                invokeServerFunction("getPlayerCoord", playerIndex)
                return
            end

            local entityToTarget = entities[selectedEntry];
            if (entityToTarget) then
                Player().selectedObject = entityToTarget
            end
        end
    end
end


