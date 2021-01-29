local F = far.Flags
local color = far.AdvControl(F.ACTL_GETCOLOR, far.Colors.COL_EDITORTEXT)
local colorguid = win.Uuid("507CFA2A-3BA3-4f2b-8A80-318F5A831235")
local quotes = { }
local bad_expr, detect_mode

local fnc_msg = function(msg_status, msg_title, msg_flags, msg_buttons)
	far.Message(msg_status, msg_title, msg_buttons, msg_flags)
	if msg_buttons == nil or msg_buttons == ""
	then far.Timer(400, function(caller) far.AdvControl("ACTL_REDRAWALL"); caller:Close(); end) end
end

Macro { description = "Highlight the selected quote",
	area = "Editor",
	key = "F5",
	action = function()
-- ###
local edin = editor.GetInfo()
local edid = edin.EditorID
if 	quotes[edid]
then
	if	detect_mode == ""
	then	detect_mode  = "CaseIns"
	elseif	detect_mode == "CaseIns"
--!	then	detect_mode  = "CaseSen"
--!	elseif	detect_mode == "CaseSen"
	then	detect_mode  = "RegExpr"
	elseif	detect_mode == "RegExpr"
	then	quotes[edid] = nil
	end
else
	local pos = edin.CurPos
	local line = editor.GetString().StringText
	local value_to_color = Editor.SelValue
	if value_to_color == "" then
	--!	no selection, take the current quote:
		if pos <= line:len() + 1 then
			local slab, tail
			slab = pos > 1 and line:sub(1, pos - 1):match('[%w_]+$') or ""
			tail = line:sub(pos):match('^[%w_]+') or ""
			value_to_color = slab..tail
		end
	end
	if value_to_color ~= "" then
		detect_mode = "CaseIns"
		quotes[edid] = value_to_color
	end
end
bad_expr = false
-- @@@
	end
}

Event { description = "<file:> "..mf.replace(mf.fsplit((...), 4), "_", " ");
	group = "EditorEvent",
	action = function(edid, event, param)
-- ###
if event == F.EE_CLOSE then
	quotes[edid] = nil
	return
end
if event ~= F.EE_REDRAW or not quotes[edid] or bad_expr
then return end

local edin = editor.GetInfo(edid)
local line_from = edin.TopScreenLine
local line_last = math.min(edin.TopScreenLine + edin.WindowSizeY, edin.TotalLines)
local the_quote = quotes[edid]
local the_quote_low = the_quote:lower()
local line, line_low, line_pos, quote_pos, quote_end, got_quote, case_diff

for ii_line = line_from, line_last do
	line = editor.GetString(edid, ii_line).StringText
	line_low = line:lower()
	line_pos = 1
	while true do
		got_quote = nil
		quote_pos = nil
		if 	detect_mode == "CaseSen"
		then	quote_pos, quote_end = line:cfind(the_quote, line_pos, true)
		elseif	detect_mode == "CaseIns"
		then	quote_pos, quote_end = line_low:cfind(the_quote_low, line_pos, true)
		elseif	detect_mode == "RegExpr"
		then	local res, msg = pcall(function()
			quote_pos, quote_end, got_quote = line:cfind(the_quote, line_pos, false) end)
			if not res then
				bad_expr = true
				mf.postmacro(fnc_msg, msg:gsub(":", "\n"), "incorrect expression: # "..the_quote.." #", "w", "OK")
				break;
			end
		end
		if not quote_pos then break; end
		if not got_quote then got_quote = line:sub(quote_pos, quote_end) end
		case_diff = got_quote ~= the_quote
		editor.AddColor(edid, ii_line, quote_pos, quote_end, F.ECF_AUTODELETE,
			{Flags = 3,
			BackgroundColor = mf.iif(case_diff, bnot(color.BackgroundColor), color.ForegroundColor),
			ForegroundColor = mf.iif(case_diff, bnot(color.ForegroundColor), color.BackgroundColor)
				},
			100, colorguid)
		line_pos = quote_pos + 1
	end
	if bad_expr then break end
end
-- @@@
	end;
}
