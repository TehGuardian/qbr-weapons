local sharedItems = exports['qbr-core']:GetItems()
local sharedWeapons = exports['qbr-core']:GetWeapons()
-- Functions

local function IsWeaponBlocked(WeaponName)
    local retval = false
    for _, name in pairs(Config.DurabilityBlockedWeapons) do
        if name == WeaponName then
            retval = true
            break
        end
    end
    return retval
end

local function HasAttachment(component, attachments)
    local retval = false
    local key = nil
    for k, v in pairs(attachments) do
        if v.component == component then
            key = k
            retval = true
        end
    end
    return retval, key
end

local function GetAttachmentType(attachments)
    local attype = nil
    for k,v in pairs(attachments) do
        attype = v.type
    end
    return attype
end

-- Callback

exports['qbr-core']:CreateCallback("weapons:server:GetConfig", function(source, cb)
    cb(Config.WeaponRepairPoints)
end)

exports['qbr-core']:CreateCallback("weapon:server:GetWeaponAmmo", function(source, cb, WeaponData)
    local Player = exports['qbr-core']:GetPlayer(source)
    local retval = 0
    if WeaponData then
        if Player then
            local ItemData = Player.Functions.GetItemBySlot(WeaponData.slot)
            if ItemData then
                retval = ItemData.info.ammo and ItemData.info.ammo or 0
            end
        end
    end
    cb(retval)
end)

exports['qbr-core']:CreateCallback('weapons:server:RemoveAttachment', function(source, cb, AttachmentData, ItemData)
    local src = source
    local Player = exports['qbr-core']:GetPlayer(src)
    local Inventory = Player.PlayerData.items
    local AttachmentComponent = WeaponAttachments[ItemData.name:upper()][AttachmentData.attachment]
    if Inventory[ItemData.slot] then
        if Inventory[ItemData.slot].info.attachments and next(Inventory[ItemData.slot].info.attachments) then
            local HasAttach, key = HasAttachment(AttachmentComponent.component, Inventory[ItemData.slot].info.attachments)
            if HasAttach then
                table.remove(Inventory[ItemData.slot].info.attachments, key)
                Player.Functions.SetInventory(Player.PlayerData.items, true)
                Player.Functions.AddItem(AttachmentComponent.item, 1)
                TriggerClientEvent('inventory:client:ItemBox', src, sharedItems[AttachmentComponent.item], "add")
                TriggerClientEvent("QBCore:Notify", src, Lang:t('info.removed_attachment', { value = sharedItems[AttachmentComponent.item].label }), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
                cb(Inventory[ItemData.slot].info.attachments)
            else
                cb(false)
            end
        else
            cb(false)
        end
    else
        cb(false)
    end
end)

exports['qbr-core']:CreateCallback("weapons:server:RepairWeapon", function(source, cb, RepairPoint, data)
    local src = source
    local Player = exports['qbr-core']:GetPlayer(src)
    local minute = 60 * 1000
    local Timeout = math.random(5 * minute, 10 * minute)
    local WeaponData = sharedWeapons[GetHashKey(data.name)]
    local WeaponClass = (exports['qbr-core']:SplitStr(WeaponData.ammotype, "_")[2]):lower()

    if Player.PlayerData.items[data.slot] then
        if Player.PlayerData.items[data.slot].info.quality then
            if Player.PlayerData.items[data.slot].info.quality ~= 100 then
                if Player.Functions.RemoveMoney('cash', Config.WeaponRepairCosts[WeaponClass]) then
                    Config.WeaponRepairPoints[RepairPoint].IsRepairing = true
                    Config.WeaponRepairPoints[RepairPoint].RepairingData = {
                        CitizenId = Player.PlayerData.citizenid,
                        WeaponData = Player.PlayerData.items[data.slot],
                        Ready = false,
                    }
                    Player.Functions.RemoveItem(data.name, 1, data.slot)
                    TriggerClientEvent('inventory:client:ItemBox', src, sharedItems[data.name], "remove")
                    TriggerClientEvent("inventory:client:CheckWeapon", src, data.name)
                    TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)

                    SetTimeout(Timeout, function()
                        Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
                        Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready = true
                        TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
                        SetTimeout(7 * 60000, function()
                            if Config.WeaponRepairPoints[RepairPoint].RepairingData.Ready then
                                Config.WeaponRepairPoints[RepairPoint].IsRepairing = false
                                Config.WeaponRepairPoints[RepairPoint].RepairingData = {}
                                TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[RepairPoint], RepairPoint)
                            end
                        end)
                    end)
                    cb(true)
                else
                    cb(false)
                end
            else
                TriggerClientEvent("QBCore:Notify", src, Lang:t('error.no_damage_on_weapon'), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
                cb(false)
            end
        else
            TriggerClientEvent("QBCore:Notify", src, Lang:t('error.no_damage_on_weapon'), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
            cb(false)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 9, Lang:t('error.no_weapon_in_hand'), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
        TriggerClientEvent('weapons:client:SetCurrentWeapon', src, {}, false)
        cb(false)
    end
end)

-- Events

RegisterNetEvent("weapons:server:AddWeaponAmmo", function(CurrentWeaponData, amount)
    local src = source
    local Player = exports['qbr-core']:GetPlayer(src)
    local amount = tonumber(amount)
    if CurrentWeaponData then
        if Player.PlayerData.items[CurrentWeaponData.slot] then
            Player.PlayerData.items[CurrentWeaponData.slot].info.ammo = amount
        end
        Player.Functions.SetInventory(Player.PlayerData.items, true)
    end
end)

RegisterNetEvent("weapons:server:UpdateWeaponAmmo", function(CurrentWeaponData, amount)
    local src = source
    local Player = exports['qbr-core']:GetPlayer(src)
    local amount = tonumber(amount)
    if CurrentWeaponData then
        if Player.PlayerData.items[CurrentWeaponData.slot] then
            Player.PlayerData.items[CurrentWeaponData.slot].info.ammo = amount
        end
        Player.Functions.SetInventory(Player.PlayerData.items, true)
    end
end)

RegisterNetEvent("weapons:server:TakeBackWeapon", function(k, data)
    local src = source
    local Player = exports['qbr-core']:GetPlayer(src)
    local itemdata = Config.WeaponRepairPoints[k].RepairingData.WeaponData
    itemdata.info.quality = 100
    Player.Functions.AddItem(itemdata.name, 1, false, itemdata.info)
    TriggerClientEvent('inventory:client:ItemBox', src, sharedItems[itemdata.name], "add")
    Config.WeaponRepairPoints[k].IsRepairing = false
    Config.WeaponRepairPoints[k].RepairingData = {}
    TriggerClientEvent('weapons:client:SyncRepairShops', -1, Config.WeaponRepairPoints[k], k)
end)

RegisterNetEvent("weapons:server:SetWeaponQuality", function(data, hp)
    local src = source
    local Player = exports['qbr-core']:GetPlayer(src)
    local WeaponSlot = Player.PlayerData.items[data.slot]
    WeaponSlot.info.quality = hp
    Player.Functions.SetInventory(Player.PlayerData.items, true)
end)

RegisterNetEvent('weapons:server:UpdateWeaponQuality', function(data, RepeatAmount)
    local src = source
    local Player = exports['qbr-core']:GetPlayer(src)
    local WeaponData = sharedWeapons[GetHashKey(data.name)]
    local WeaponSlot = Player.PlayerData.items[data.slot]
    local DecreaseAmount = Config.DurabilityMultiplier[data.name]
    if WeaponSlot then
        if not IsWeaponBlocked(WeaponData.name) then
            if WeaponSlot.info.quality then
                for i = 1, RepeatAmount, 1 do
                    if WeaponSlot.info.quality - DecreaseAmount > 0 then
                        WeaponSlot.info.quality = WeaponSlot.info.quality - DecreaseAmount
                    else
                        WeaponSlot.info.quality = 0
                        -- TriggerClientEvent('inventory:client:UseWeapon', src, data)
                        TriggerClientEvent('QBCore:Notify', src, 9, Lang:t('error.weapon_broken_need_repair'), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
                        break
                    end
                end
            else
                WeaponSlot.info.quality = 100
                for i = 1, RepeatAmount, 1 do
                    if WeaponSlot.info.quality - DecreaseAmount > 0 then
                        WeaponSlot.info.quality = WeaponSlot.info.quality - DecreaseAmount
                    else
                        WeaponSlot.info.quality = 0
                        -- TriggerClientEvent('inventory:client:UseWeapon', src, data)
                        TriggerClientEvent('QBCore:Notify', src, 9, Lang:t('error.weapon_broken_need_repair'), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
                        break
                    end
                end
            end
        end
    end
    Player.Functions.SetInventory(Player.PlayerData.items, true)
end)

RegisterNetEvent("weapons:server:EquipAttachment", function(ItemData, CurrentWeaponData, AttachmentData)
    local src = source
    local Player = exports['qbr-core']:GetPlayer(src)
    local Inventory = Player.PlayerData.items
    local GiveBackItem = nil
    if Inventory[CurrentWeaponData.slot] then
        if Inventory[CurrentWeaponData.slot].info.attachments and next(Inventory[CurrentWeaponData.slot].info.attachments) then
            local currenttype = GetAttachmentType(Inventory[CurrentWeaponData.slot].info.attachments)
            local HasAttach, key = HasAttachment(AttachmentData.component, Inventory[CurrentWeaponData.slot].info.attachments)
            if not HasAttach then
                if AttachmentData.type ~=nil and currenttype == AttachmentData.type then
                    for k, v in pairs(Inventory[CurrentWeaponData.slot].info.attachments) do
                        if v.type and v.type == currenttype then
                            GiveBackItem = tostring(v.item):lower()
                            table.remove(Inventory[CurrentWeaponData.slot].info.attachments, key)
                            TriggerClientEvent('inventory:client:ItemBox', src, sharedItems[GiveBackItem], "add")
                        end
                    end
                end
                Inventory[CurrentWeaponData.slot].info.attachments[#Inventory[CurrentWeaponData.slot].info.attachments+1] = {
                    component = AttachmentData.component,
                    label = sharedItems[AttachmentData.item].label,
                    item = AttachmentData.item,
                    type = AttachmentData.type,
                }
                TriggerClientEvent("addAttachment", src, AttachmentData.component)
                Player.Functions.SetInventory(Player.PlayerData.items, true)
                Player.Functions.RemoveItem(ItemData.name, 1)
                SetTimeout(1000, function()
                    TriggerClientEvent('inventory:client:ItemBox', src, ItemData, "remove")
                end)
            else
				TriggerClientEvent('QBCore:Notify', src, 9, Lang:t('error.attachment_already_on_weapon', { value = sharedItems[AttachmentData.item].label }), 5000, 0, 'mp_lobby_textures', 'cross', 'COLOR_WHITE')
            end
        else
            Inventory[CurrentWeaponData.slot].info.attachments = {}
            Inventory[CurrentWeaponData.slot].info.attachments[#Inventory[CurrentWeaponData.slot].info.attachments+1] = {
                component = AttachmentData.component,
                label = sharedItems[AttachmentData.item].label,
                item = AttachmentData.item,
                type = AttachmentData.type,
            }
            TriggerClientEvent("addAttachment", src, AttachmentData.component)
            Player.Functions.SetInventory(Player.PlayerData.items, true)
            Player.Functions.RemoveItem(ItemData.name, 1)
            SetTimeout(1000, function()
                TriggerClientEvent('inventory:client:ItemBox', src, ItemData, "remove")
            end)
        end
    end
    if GiveBackItem then
        Player.Functions.AddItem(GiveBackItem, 1, false)
        GiveBackItem = nil
    end
end)

-- Commands

exports['qbr-core']:AddCommand("repairweapon", "Repair Weapon (God Only)", {{name="hp", help=Lang:t('info.hp_of_weapon')}}, true, function(source, args)
    TriggerClientEvent('weapons:client:SetWeaponQuality', source, tonumber(args[1]))
end, "god")

-- Items

-- AMMO
exports['qbr-core']:CreateUseableItem("ammo_repeater", function(source, item)
    TriggerClientEvent('weapon:client:AddAmmo', source, 'AMMO_REPEATER', 12, item)
end)

exports['qbr-core']:CreateUseableItem("ammo_revolver", function(source, item)
    TriggerClientEvent('weapon:client:AddAmmo', source, 'AMMO_REVOLVER', 12, item)
end)

exports['qbr-core']:CreateUseableItem("ammo_rifle", function(source, item)
    TriggerClientEvent('weapon:client:AddAmmo', source, 'AMMO_RIFLE', 12, item)
end)

exports['qbr-core']:CreateUseableItem("ammo_pistol", function(source, item)
    TriggerClientEvent('weapon:client:AddAmmo', source, 'AMMO_PISTOL', 12, item)
end)

exports['qbr-core']:CreateUseableItem("ammo_shotgun", function(source, item)
    TriggerClientEvent('weapon:client:AddAmmo', source, 'AMMO_SHOTGUN', 12, item)
end)

exports['qbr-core']:CreateUseableItem("ammo_arrow", function(source, item)
    TriggerClientEvent('weapon:client:AddAmmo', source, 'AMMO_ARROW', 12, item)
end)


-- TINTS
exports['qbr-core']:CreateUseableItem('weapontint_black', function(source)
    TriggerClientEvent('weapons:client:EquipTint', source, 0)
end)

-- ATTACHMENTS
exports['qbr-core']:CreateUseableItem('pistol_defaultclip', function(source, item)
    TriggerClientEvent('weapons:client:EquipAttachment', source, item, 'defaultclip')
end)
