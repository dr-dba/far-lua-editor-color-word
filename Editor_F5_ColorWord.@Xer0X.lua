--[[
if 1 then return end --]]

--[[
Based on the @ZG code from:
выделить все вхождения слова под курсором
https://forum.farmanager.com/viewtopic.php?t=3733
%FarHome%\Addons\Macros\Editor.ColorWord.moon

@Xer0X mod (source) home:
https://github.com/dr-dba/far-lua-editor-color-word

Eсть три режима последовательно (по нажатию Ф5) включаемые:
1.) Простое выделение, НЕ-чувствительно к регистру
2.) Чувствительное к регистру выделение, текст отличное регистром тоже выделяется, но другим цветом
3.) Выделение по Луа-РегЕкспу, т.е. можно написать луа-регексп в редакторе,
и таким образом протестировать его в том же редакторе, что удобно

TODO
Сделать так чтобы редактор с последующими нажатиям AltF7/ShiftF7 искал этот текст (выделенный по F5)
Принимаются предложения как это лучше сделать
]]
local F = far.Flags
local color = far.AdvControl(F.ACTL_GETCOLOR, far.Colors.COL_EDITORTEXT)
--[[ invert colors:
color.ForegroundColor, color.BackgroundColor = color.BackgroundColor, color.ForegroundColor --]]
local colorguid = win.Uuid("507CFA2A-3BA3-4f2b-8A80-318F5A831235")
local quotes = { }
local bad_expr, detect_mode

local fnc_msg = function(msg_status, msg_title, msg_flags, msg_buttons)
	far.Message(msg_status, msg_title, msg_buttons, msg_flags)
	if	(msg_buttons or "") == ""
	then	far.Timer(400, function(caller) far.AdvControl("ACTL_REDRAWALL"); caller:Close(); end)
	end
end

Macro { description = "Highlight the selected quote",
	id = "D23057B8-868B-40A2-992D-4B8C21229D7B",
	area = "Editor",
	key = "F5",
	action = function()
-- ###
local edin = editor.GetInfo()
local edid = edin.EditorID
local value_selected = Editor.SelValue
local value_to_color = quotes[edid]
if 	value_to_color
and	value_to_color ~= ""
and (	value_selected == value_to_color
or	value_selected == "")
then
	if	detect_mode == ""
	or not	detect_mode
	then	detect_mode  = "CaseIns"
	elseif	detect_mode == "CaseIns"
	then	detect_mode  = "CaseSen"
	elseif	detect_mode == "CaseSen"
	then	detect_mode  = "RegExpr"
	elseif	detect_mode == "RegExpr"
	then	quotes[edid] = nil
		detect_mode  = nil
	end
else
	if	value_selected ~= ""
	then
		value_to_color = value_selected
	else	-- no selection, take the current quote:
		local	line= editor.GetString().StringText
		local	pos = edin.CurPos
		if	pos <= line:len() + 1
		then
			local slab = pos > 1 and line:sub(1, pos - 1):match('[%w_]+$') or ""
			local tail = line:sub(pos):match('^[%w_]+') or ""
			value_to_color = slab..tail
		end
	end
	if	value_to_color 
	and	value_to_color ~= ""
	then	detect_mode = "CaseIns"
		quotes[edid] = value_to_color
	end
end
bad_expr = false
-- @@@
	end
}

Event { description = "<file:> "..mf.replace(mf.fsplit((...), 4), "_", " ");
	id = "B3E432CD-E0D4-4DBB-A36E-0E362C9154A1";
	group = "EditorEvent",
	action = function(edid, event, param)
-- ###
if	event == F.EE_CLOSE
then	quotes[edid] = nil
	return
end
if	event ~= F.EE_REDRAW
or not	quotes[edid]
or	bad_expr
then	return
end
local edin = editor.GetInfo(edid)
local line_from = edin.TopScreenLine
local line_last = math.min(edin.TopScreenLine + edin.WindowSizeY, edin.TotalLines)
local the_quote = quotes[edid]
local the_quote_low = the_quote:lower()
local line, line_low, line_pos, quote_pos, quote_end, got_quote, case_diff
for ii_line = line_from, line_last
do
	line = editor.GetString(edid, ii_line).StringText
	line_low = line:lower()
	line_pos = 1
	while true
	do	got_quote = nil
		quote_pos = nil
		if 	detect_mode == "CaseSen"
		then	quote_pos, quote_end = line:cfind(the_quote, line_pos, true)
		elseif	detect_mode == "CaseIns"
		then	quote_pos, quote_end = line_low:cfind(the_quote_low, line_pos, true)
		elseif	detect_mode == "RegExpr"
		then	local res, msg = pcall(function()
			quote_pos, quote_end, got_quote = line:cfind(the_quote, line_pos, false) end)
			if not res
			then
				bad_expr = true
				mf.postmacro(fnc_msg, msg:gsub(":", "\n"), "incorrect expression: # "..the_quote.." #", "w", "OK")
				break;
			end
		end
		if not quote_pos then break; end
		if not got_quote then got_quote = line:sub(quote_pos, quote_end) end
		case_diff = got_quote ~= the_quote
		editor.AddColor(
			edid, ii_line, quote_pos, quote_end, F.ECF_AUTODELETE,
			{
				Flags = 3,
				BackgroundColor = case_diff and bnot(color.BackgroundColor) or color.ForegroundColor,
				ForegroundColor = case_diff and bnot(color.ForegroundColor) or color.BackgroundColor,
			},
			100, colorguid)
		line_pos = quote_pos + 1
	end
	if bad_expr then break end
end
-- @@@
	end;
}
-- @@@@@
