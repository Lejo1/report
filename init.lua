--[[This is a mod that contains a player register with the count of the reports.
          Mod created by Lejo!]]
local settings = {
  time_played_to_report = 3600, --  in seconds  Only needed when using playtime
	time_of_tempban = minetest.settings:get("report_tempbantime") or 259200, --  bantime inseconds
}
reportlist = {}
local s = minetest.get_mod_storage()
local new_table = {r = {}}
--[[
Player table schem:
reporter = {["name"] = {reason = "..", time=os.time()}}
{r = {["name"] = {r = "Reason", t = os.time()}},
}
]]

function reportlist.get_data(name)
  local data = s:get_string(name)
  if data ~= "" then
    return minetest.deserialize(data)
  else s:set_string(name, new_table)
    return new_table
  end
end

function reportlist.get_all_data()
  local out = {}
  for name, data in pairs(s:to_table().fields) do
    out[name] = minetest.deserialize(data)
  end
  return out
end

function reportlist.set_data(name, data)
  s:set_string(name, minetest.serialize(data))
end

function reportlist.remove_data(name)
	s:set_string(name, "")
end

function reportlist.exist(name)
	if s:get_string(name) ~= "" then
		return true
	else return false
	end
end

function reportlist.is_reporter(name, reportername)
  local data = reportlist.get_data(name)
  if data.r[reportername] then
    return true
  end
end

function reportlist.add_reporter(name, reportername, reason)
	local data = reportlist.get_data(name)
  data.r[reportername] = {r = reason, t = os.time()}
  reportlist.set_data(name, data)
end

--  Add the report Command
minetest.register_chatcommand("report", {
  privs = {shout = true},
  params = "<name> <reason>",
  description = "Use it to report players, if they are hacking, cheating...",
  func = function(name, param)
    local reported, reason = param:match("(%S+)%s+(.+)")
    if type(reported) == "string" and type(reason) == "string" then
      if minetest.player_exists(reported) then
        if name ~= reported and minetest.get_player_ip(name) ~= minetest.get_player_ip(reported) then
          if minetest.get_player_by_name(reported) then
            if not playtime or playtime.get_total_playtime(name) >= settings.time_played_to_report then
              reportlist.add_reporter(reported, name, reason)
              minetest.log("action", "Player "..reported.." has been reported by "..name)
              return true, reported.." has been reported!"
            else return false, "You have to play longer to report a player!"
            end
          else return false, "The Player "..reported.." is not online!"
          end
        else return false, "You can't report yourself or somebody out of you ip-Group."
        end
      else return false, "The Player doesn't exist."
      end
    else return false, "Please specific a playername and a reason"
    end
  end,
})


function reportlist.show_form(name, fields)
	local reported = fields.name or ""
  local tabledata = ""
  local form = "size[14,5.5]" ..
  "label[3.5,0.1;Reportlist. Enter playername to do an action.]" ..
  "button[11.2,2.6;2.5,1;reset;reset]" ..
  "field[11.5,4;2.5,1;reason;Ban Reason;]" ..
  "button[11.2,4.4;2.5,1;tempban;Tempban(default 3 days)]" ..
  "field[11.5,1;1.7,1;name;Player Name;"..reported.."]" ..
  "field_close_on_enter[name;false]" ..
  "button[12.9,0.7;0.8,1;go;Go]"
  if fields and fields.name and fields.name ~= "" then
		if reportlist.exist(fields.name) then
    	local data = reportlist.get_data(fields.name)
    	for playername, d in pairs(data.r) do
      	local pdata = reportlist.get_data(playername)
      	tabledata = tabledata..playername..","..os.date("%c", d.t)..","..minetest.formspec_escape(d.r)..","
    	end
		else tabledata = "Player hasn't been reported yet"
		end
    form = form .. "tablecolumns[text;text;text]"
  else
    for name, data in pairs(reportlist.get_all_data()) do
      local count = 0
      local pstuff = ""
      for name, d in pairs(data.r) do
        pstuff = pstuff.."1,"..name..","..os.date("%c", d.t)..","..minetest.formspec_escape(d.r)..","
        count = count + 1
      end
      tabledata = tabledata.."0,"..name..","..count..",,"..pstuff
    end
    form = form .. "tablecolumns[tree;text;text;text]"
  end
  form = form .. "table[0.2,0.6;10.8,4.6;reports;"..tabledata..";1]"
  minetest.show_formspec(name, "reportlist:reportlist", form)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname == "reportlist:reportlist" then
  	local name = player:get_player_name()
  	if minetest.get_player_privs(name).ban then
			if fields.name and fields.name ~= "" then
				if fields.reset then
					reportlist.remove_data(fields.name)
					minetest.chat_send_player(name, "Reseted the reports of the player "..fields.name)
				elseif fields.tempban and fields.reason and fields.reason ~= "" then
					--  Support for sban mod or others using this command
					if minetest.registered_chatcommands["tempban"] then
						local success, msg = minetest.registered_chatcommands["tempban"].func(name, fields.name.." "..tostring(settings.time_of_tempban).." "..fields.reason)
						minetest.chat_send_player(name, msg)
					--  Xban support
					elseif xban and xban.ban_player then
						local success, err = xban.ban_player(fields.name, name, settings.time_of_tempban, fields.reason)
						if success then
							minetest.chat_send_player(name, "Banned "..fields.name)
						else minetest.chat_send_player(name, "Failed to ban "..fields.name.." Err:"..err)
						end
					else minetest.chat_send_player(name, "No compatible ban mod found, use sban or xban!")
					end
				end
			end
      if fields.reset or fields.tempban or fields.go or fields.key_enter then
    	   reportlist.show_form(name, fields)
      end
  	else
    	minetest.log("error", "Player "..name.." sent fields to reportlist:reportlist without the ban privi")
    	minetest.kick_player(name)
  	end
	end
end)

--  Add a chat command to get the report counter
minetest.register_chatcommand("reportlist", {
	privs = {ban = true},
	params = "[<name>]",
	description = "Use it to open the reportlist form.",
	func = function(name, param)
  	reportlist.show_form(name, {name = param})
	end,
})

--  Add a chat command to set the report counter
minetest.register_chatcommand("report_reset", {
	privs = {ban = true},
	params = "<name>",
	description = "Use it to reset the reports of a player.",
	func = function(name, param)
  	if minetest.player_exists(param) then
    	reportlist.remove_data(name)
    	minetest.chat_send_player(name, "Reseted the reports of the player "..param)
  	else minetest.chat_send_player(name, "The Player "..param.." doesn't exist.")
  	end
	end,
})
