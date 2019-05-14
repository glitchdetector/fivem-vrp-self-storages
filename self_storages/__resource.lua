name 'vRP Self Storages'
author 'glitchdetector'
contact 'glitchdetector@gmail.com'
version '1.0.0'

description 'A self storage system, allowing players to store items at secure locations.'
usage [[
    Install into a vRP enabled server.
    Locations can be added or removed from the shared.lua file.
]]

client_script 'shared.lua'
client_script 'client.lua'

server_script '@vrp/lib/utils.lua'
server_script 'shared.lua'
server_script 'server.lua'
