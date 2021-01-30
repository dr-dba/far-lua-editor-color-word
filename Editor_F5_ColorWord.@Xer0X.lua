--[[
if 1 then return end --]]

--[[
Based on the @ZG code from:
выделить все вхождения слова под курсором
https://forum.farmanager.com/viewtopic.php?t=3733
%FarHome%\Addons\Macros\Editor.ColorWord.moon

@Xer0X mod (source) home:
https://github.com/dr-dba/far-lua-editor-color-word

Eсть три режима последовательно (по нажатию F5) включаемые:
1.) Простое выделение, НЕ-чувствительно к регистру
2.) Чувствительное к регистру выделение, текст отличное регистром тоже выделяется, но другим цветом
3.) Выделение по Луа-РегЕкспу, т.е. можно написать луа-регексп в редакторе,
и таким образом протестировать его в том же редакторе, что удобно

!!UPDATE
Все таки сделал только два переключаемых зацикленных режима:
1.) Простой, с отдельным цветом если отличается по буквенному регистру
2.) Луа РегЕксп
Но еще не решил, может вернусь к как до этого было

TODO
Сделать так чтобы редактор с последующими нажатиям AltF7/ShiftF7 искал этот текст (выделенный по F5)
Принимаются предложения как это лучше сделать
]]
local F = far.Flags
local color = far.AdvControl(F.ACTL_GETCOLOR, far.Colors.COL_EDITORTEXT)
--[[ invert colors:
color.ForegroundColor, color.BackgroundColor = color.BackgroundColor, color.ForegroundColor --]]
local colorguid = win.Uuid("507CFA2A-3BA3-4f2b-8A80-318F5A831235")
local tbl_quotes = { }
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
local inf_quote = tbl_quotes[edid]
local	value_to_color = inf_quote and inf_quote.val_to_color
if 	value_to_color
and	value_to_color ~= ""
and (	value_selected == value_to_color
or	value_selected == "")
then
	if	detect_mode == ""
	or not	detect_mode
	then	detect_mode  = "CaseInS"
	elseif	detect_mode == "CaseInS"
	then	detect_mode  = "RegExpr"
	elseif	detect_mode == "RegExpr"
	then	tbl_quotes[edid] = nil
		detect_mode  = nil
	end
else
	if	value_selected ~= ""
	then	value_to_color = value_selected
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
	then	detect_mode = "CaseInS"
		tbl_quotes[edid] = {
			val_to_color = value_to_color,
			val_line_num = edin.CurLine,
			val_char_pos = edin.CurPos,
			val_char_end = edin.CurPos + value_to_color:len() - 1,
		}
	end
	bad_expr = false
end
-- @@@
	end
}

local function fnc_cfind_quote(line, the_quote, line_pos, plain)
	local	quote_pos, quote_end, got_quote
			= line:cfind(the_quote, line_pos, plain)
	return	quote_pos, quote_end, got_quote
end

local function fnc_cfind_quote_safe(line, the_quote, line_pos, plain)
	local	res, quote_pos, quote_end, got_quote
			= pcall(fnc_cfind_quote, line, the_quote, line_pos, plain)
	return	res,
		not res and quote_pos or nil,
		res and quote_pos or nil,
		quote_end, got_quote
end

Event { description = "<file:> "..mf.replace(mf.fsplit((...), 4), "_", " ");
	id = "B3E432CD-E0D4-4DBB-A36E-0E362C9154A1";
	group = "EditorEvent",
	action = function(edid, event, param)
-- ###
if	event == F.EE_CLOSE
then	tbl_quotes[edid] = nil
	return
end
if	event ~= F.EE_REDRAW
or not	tbl_quotes[edid]
or	detect_mode == "RegExpr"
and	bad_expr
then	return
end
local edin = editor.GetInfo(edid)
local line_from = edin.TopScreenLine
local line_last = math.min(edin.TopScreenLine + edin.WindowSizeY, edin.TotalLines)
local inf_quote = tbl_quotes[edid]
local the_quote = inf_quote.val_to_color
local the_quote_low = the_quote:lower()
for ii_line = line_from, line_last
do
	local line = editor.GetString(edid, ii_line).StringText
	local line_low = line:lower()
	local line_pos = 1
	if ii_line == inf_quote.val_line_num
	then 	editor.AddColor(
			edid, ii_line, inf_quote.val_char_pos, inf_quote.val_char_end, F.ECF_AUTODELETE,
			{
				Flags = 3,
				BackgroundColor = 15,
				ForegroundColor = 0,
			},
			100,
			colorguid)
	end
	while true
	do
		
		local	find_res, find_msg, quote_pos, quote_end, got_quote, case_diff
		
		if	detect_mode == "CaseInS"
		or	detect_mode == "CaseSen"
		then
			find_res, find_msg, quote_pos, quote_end, got_quote = fnc_cfind_quote_safe(line_low, the_quote_low, line_pos, true)
		elseif
			detect_mode == "RegExpr"
		then
			find_res, find_msg, quote_pos, quote_end, got_quote = fnc_cfind_quote_safe(line, the_quote, line_pos, false)
			if not find_res
			then	bad_expr = true
				mf.postmacro(fnc_msg, find_msg:gsub(":", "\n"), "incorrect expression: # "..the_quote.." #", "w", "OK")
				break;
			end
		end
		if not	quote_pos then break end
		if not	got_quote
		then	got_quote = line:sub(quote_pos, quote_end)
		end
		case_diff = detect_mode ~= "RegExpr" and got_quote ~= the_quote
		if	ii_line	  ~= inf_quote.val_line_num
		or	quote_pos ~= inf_quote.val_char_pos
		or	quote_end ~= inf_quote.val_char_end
		then 	editor.AddColor(
				edid, ii_line, quote_pos, quote_end, F.ECF_AUTODELETE,
				{
					Flags = 3,
					BackgroundColor = case_diff and bnot(color.BackgroundColor) or color.ForegroundColor,
					ForegroundColor = case_diff and bnot(color.ForegroundColor) or color.BackgroundColor,
				},
				100,
				colorguid)
		end
		line_pos = 1 +
			quote_end
	end
	if	bad_expr
	and	detect_mode == "RegExpr"
	then	detect_mode = nil
		break
	end
end
-- @@@
	end;
}

-- @@@@@
