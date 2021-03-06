--[[
Todo:
Multiple in/out
User learnt recipes
    Crafting
    Smelting/Machine processing
        Furnace:
            Slot 1 > Input
            Slot 2 > Fuel
            Slot 3 > Output
    Chain autocrafting
        Minimum amount of item in storage, otherwise craft 
Item folders
User friendly output/input chest determining
]]

local debug = true

local output_inventory = "quark:quark_chest_1630"
local input_inventory = "minecraft:ironchest_iron_2052"

local storage = {} -- Chests and IDs
local items = {}   -- Stored items in chests
local drawnItems = {}  -- Position of items on screen
local itemCache = {}  -- Non internal names of items
local position = 0  -- Position of the scroll
local search = ""  -- Search bar 

local mon = (peripheral.find("monitor") or term.current())  -- Get the display
local inv = peripheral.wrap(input_inventory)

local width, height = mon.getSize()  -- Get monitor dimensions
local itemDisplay = window.create(mon, 3, 2, width - 4, height - 2)

---------------------------------------------------------------------
local topBar = window.create(mon, 1, 1, width, 1)                  --
local sideBar = window.create(mon, width - 1, 2, width - 4, height)--  Create windows
local searchBar = window.create(mon, 3, height, width - 4, 1)      --
local requestBar = window.create(mon, 1, 2, 2, height-2)           --
---------------------------------------------------------------------

----------------------------
local _ = {}              --
for k, v in pairs(keys) do-- Invert computercraft's key table
    _[v] = k              --
end                       --
keys = _                  --
----------------------------

--------------------------------------------------
mon.setBackgroundColor(colors.lightGray)        --
mon.clear()                                     --
                                                --
topBar.setBackgroundColor(colors.black)         --
topBar.clear()                                  --
                                                --
requestBar.setBackgroundColor(colors.lightGray) --
requestBar.clear()                              --
                                                --  Create the windows content
sideBar.setBackgroundColor(colors.lightGray)    --
sideBar.clear()                                 --
sideBar.setCursorPos(1, height - 1)             --
sideBar.write("\\/")                            --
sideBar.setCursorPos(1, height - 4)             --
sideBar.write("/\\")                            --
sideBar.setCursorPos(1, height - 7)             --
sideBar.write("RE")                             --
                                                --
itemDisplay.setBackgroundColor(colors.white)    --
itemDisplay.setTextColor(colors.black)          --
itemDisplay.clear()                             --
                                                --
searchBar.setBackgroundColor(colors.lightBlue)  --
searchBar.clear()                               --
--------------------------------------------------

function logp(...)
    if debug then
        print(...)
    end
end

function serialize(data, name)  -- Store data
    if not fs.exists('/disk') then
        return
    end
    if not fs.exists('/disk/data') then
        fs.makeDir('/disk/data')
    end
    local f = fs.open('/disk/data/'..name, 'w')
    f.write(textutils.serialize(data))
    f.close()
end
 
function unserialize(name)  -- Get data
    if fs.exists('/disk/data/'..name) then
        local f = fs.open('/disk/data/'..name, 'r')
        data = textutils.unserialize(f.readAll())
        f.close()
    end
    return data
end

itemCache = unserialize("itemCache") or {}


function seekChests()  -- Find attached chests
    storage = {}
    for k, v in pairs(peripheral.getNames()) do
        if v:match("chest") and not v:match(output_inventory) then
            storage[#storage + 1] = {["peripheral"] = peripheral.wrap(v), ["id"] = #storage}
        end
    end
end

function itemName(item)  --Get an item's displayName
    return itemCache[item.name.. ":" .. item.damage]
end

function addItem(inventory, chest, pull)  -- Add an item to the list of items we have
    updated = false
    if chest ~= nil and inventory ~= nil then
        for slot, item in pairs(inventory) do
            if pull then
                local a = (chest["peripheral"].pullItems(input_inventory,slot,64) > 0)
            end
            
            if not itemName(item) then
                updated = true
                itemCache[item.name.. ":" .. item.damage] = chest["peripheral"].getItemMeta(slot).displayName
                logp("Found new item: "..itemName(item)..". Adding to local cache..")
                sleep(0.25)
            end
            
            if items[itemName(item)] == nil then 
                items[itemName(item)] = {}
                items[itemName(item)]["count"] = 0
            end

            if items[itemName(item)][chest.id] == nil then
                items[itemName(item)][chest.id] = {}
            end

            items[itemName(item)]["count"] = items[itemName(item)]["count"] + item.count
            items[itemName(item)][chest.id][slot] = item.count
            items[itemName(item)]["damage"] = item.damage
            if a then local b = true end
        end
    end
    if updated then
        serialize(itemCache, "itemCache")
    end
    table.sort(items)
    if b or not pull then
        return true
    else
        return false
    end
end

function getItem(item, count)   -- Put an item in the output chest
    if not item then return end
    for key,value in pairs(items[item]) do
        if type(key) == "number" then
            for _,chest in pairs(storage) do
                if chest["id"] == key then
                    for slot,cnt in pairs(value) do
                        chest["peripheral"].pushItems(output_inventory, slot, count)
                        items[item]["count"] = items[item]["count"] - cnt
                        table.remove(items[item][key], 1)
                        count = count-cnt
                        if count < 1 then return end
                    end
                end
            end
        end
    end
end

function addItems() -- Scan all chests for items
    itemDisplay.clear()
    items = {}
    for _, chest in pairs(storage) do
        addItem(chest["peripheral"].list(),chest)
    end
end

function DrawItems(items, offset)  -- Draw items on screen
    drawnItems = {}
    position = offset
    itemDisplay.clear()
    requestBar.clear()
    itemDisplay.setCursorPos(1, 0)
    local i = 0
    local j = 0
    for itemId, itemData in pairs(items) do
        i = i + 1
        if i > offset and itemId:lower():find(search) and itemData.count > 0 then
            j = j+1
            drawnItems[j] = itemId
            local x, y = itemDisplay.getCursorPos()
            requestBar.setCursorPos(1,y+1)
            itemDisplay.setCursorPos(1, y + 1)
            if itemData.count < 10 then
                itemId = " " .. itemId
            end
            itemDisplay.write(itemData.count .. " " .. itemId)
            requestBar.write(" +")
        end
    end
end

seekChests()
addItems()

topBar.clear()
topBar.setCursorPos(1, 1)
topBar.write("Made by Folfy Blue")

function storeItem()  --Add items from input chest
    while true do
        sleep(1)
        local inventory = inv.list()
        if #inventory > 0 then
            logp("Items found, storing...")
            for _, chest in pairs(storage) do
                if addItem(inventory, chest, true) then
                    addItems()
                    break
                end
            end
        end
    end
end

function eventHandler()  -- Handle key presses and monitor touches
    while true do
        if position < 0 then position = 0 end
        DrawItems(items, position)
        local event, key, x, y = os.pullEvent()
        if event == "monitor_touch" or event == "mouse_click" then
            logp("Monitor touched at "..x.."/"..y)
            if x >= width - 2 then
                if y >= height - 2 then --down
                    logp("\\/ Pressed")
                    position = position + 3
                elseif y >= height - 5 then --up
                    position = position - 3
                    logp("/\\ Pressed")
                elseif y >= height - 7 then --up
                    seekChests()
                    addItems()
                    logp("Refresh Pressed")
                end  --x, y, width, height 1, 2, 2, height-2)
            end

            if x <= 2 then
                logp(drawnItems[y-1])
                logp(y)
                getItem(drawnItems[y-1],64)
            end

        elseif event == "key" then
            position = 0
            key = keys[key] or ""
            logp("Key "..key.." pressed")
            x, y = searchBar.getCursorPos()
            if key == "enter" then
                search = ""
                key = ""
            end
            if key == "backspace" then
                search = search:sub(1, -2)
                key = ""
            end
            if key == "space" then
                key = " "
            end
            if #key > 1 then
                key = ""
            end
            search = search .. key
            logp("Searching: "..search)
            searchBar.clear()
            searchBar.setCursorPos(1, 1)
            searchBar.write(search)
        end
    end
end

parallel.waitForAny(eventHandler,storeItem)