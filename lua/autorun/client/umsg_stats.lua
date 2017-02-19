local function do_umsg_hooks()
	if not usermessage then
		hook.Add("InitPostEntity", "IncomingMessageStats", do_umsg_hooks)
		return
	end
	
	local currentsize,totalsize,totalamount,starttime = 0,0,0,CurTime()
	
	local usermessage_IncomingMessage = umsg_hooks_usermessage_IncomingMessage or usermessage.IncomingMessage
	umsg_hooks_usermessage_IncomingMessage = usermessage_IncomingMessage
	IncomingMessage_lookup = {}
	function usermessage.IncomingMessage( MessageName, msg )
		local entry = IncomingMessage_lookup[MessageName]
		if not entry then
			print("First received a \""..MessageName.."\" message")
			entry = { 0, 0 }
			IncomingMessage_lookup[MessageName] = entry
		end
		
		entry[1] = entry[1] + 1
		totalamount = totalamount + 1
		
		currentsize = 0
		usermessage_IncomingMessage(MessageName, msg)
		
		totalsize = totalsize + currentsize
		entry[2] = entry[2] + currentsize
	end
	
	local bf_read = FindMetaTable("bf_read")
	local function wrap(tp,size)
		local oldfunc = bf_read["Read"..tp]
		bf_read["Read"..tp] = function(...)
			currentsize = currentsize + size
			return oldfunc(...)
		end
	end
	wrap("Bool",1)
	wrap("Char",1)
	wrap("Short",2)
	wrap("Long",4)
	wrap("Float",4)
	wrap("Entity",4)
	wrap("Vector",12)
	wrap("VectorNormal",12)
	wrap("Angle",12)
	
	local bf_read_ReadString = bf_read.ReadString
	function bf_read:ReadString(...)
		local ret = bf_read_ReadString(self, ...)
		currentsize = currentsize + #ret + 1
		return ret
	end
	
	concommand.Add("umsg_stats", function(ply, command, args)
		local dt = CurTime()-starttime
		local reset = args[1] == "reset"
		
		for MessageName, v in pairs_sortvalues(IncomingMessage_lookup, function(a,b) return a[1]<b[1] end) do
			local amount, bytes = unpack(v)
			if reset then v[1] = 0 v[2] = 0 end
			print(string.format("%s: %d packets containing %d bytes received (%.3f bytes/s).", MessageName, amount, bytes, bytes/dt))
		end
		print(string.format("Total: %d packets containing %d bytes received (%.3f bytes/s).", totalamount, totalsize, totalsize/dt))
		
		if reset then starttime = CurTime() totalsize = 0 totalamount = 0 end
	end)
	
	local dat = {}
	dat.__index = dat
	
	function dat:Initialize()
		self.maxentries = 10
		self.cursor = 0
		self.accum = 0
	end
	
	function dat:dat(data)
		cursor = self.cursor + 1
		if cursor > self.maxentries then cursor = 1 end
		self.cursor = cursor
		
		self.accum = self.accum - (self[cursor] or 0) + data
		self[cursor] = data
	end
	
	local dat_amount = setmetatable({}, dat) dat_amount:Initialize()
	local dat_size   = setmetatable({}, dat) dat_size:Initialize()
	
	
	local lastamount, lastsize, lasttime = 0,0,CurTime()
	local text = ""
	
	local function IncomingMessageStats()
			--local text = string.format("Total: %d packets containing %d bytes received (%.3f bytes/s).", totalamount, totalsize, totalsize/dt)
			
			draw.DrawText(text, "Default", 2, 2, Color(255,255,255,255), TEXT_ALIGN_LEFT)
	end
	hook.Add("HUDPaint", "IncomingMessageStats", IncomingMessageStats)
	
	timer.Create("IncomingMessageStats_refresh", 0.1, 0, function()
		local display_amount, display_size = totalamount-lastamount, totalsize-lastsize
		
		dat_amount:dat(display_amount)
		dat_size:dat(display_size)
		
		local t = CurTime()
		local dt = t-lasttime
		
		text = string.format("umsg_stats: %d packets containing %d bytes received (%.0f bytes/s).", totalamount, totalsize, dat_size.accum)
		
		lastamount, lastsize, lasttime = totalamount, totalsize, t
	end)
	
	umsg_stats_display = CreateClientConVar("umsg_stats_display", 0, true, false)
	cvars.AddChangeCallback("umsg_stats_display", function(CVar, PreviousValue, NewValue)
		if PreviousValue == NewValue then return end
		NewValue = tonumber(NewValue) or 0
		if NewValue ~= 0 then
			hook.Add("HUDPaint", "IncomingMessageStats", IncomingMessageStats)
		else
			hook.Remove("HUDPaint", "IncomingMessageStats")
		end
	end)
end

do_umsg_hooks()
