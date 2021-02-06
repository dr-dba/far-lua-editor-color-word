--[[
if 1 then return end --]]

--[[
Based on the @ZG code from:
выделить все вхождения слова под курсором
https://forum.farmanager.com/viewtopic.php?t=3733
%FarHome%\Addons\Macros\Editor.ColorWord.moon

@Xer0X mod (source) home:
https://github.com/dr-dba/far-lua-editor-color-word

Есть три режима последовательно (по нажатию F5) включаемые:
1.) Простое выделение, НЕ-чувствительно к регистру
2.) Чувствительное к регистру выделение, текст отличное регистром тоже выделяется, но другим цветом
3.) Выделение по Луа-РегЕкспу, т.е. можно написать луа-регексп в редакторе,
и таким образом протестировать его в том же редакторе, что удобно

!!UPDATE
Все таки сделал только два переключаемых зацикленных режима:
1.) Простой, с отдельным цветом если отличается по буквенному регистру
2.) Луа РегЕксп
Но еще не решил, может вернусь к как до этого было

добавил авто-выделение слова на котором стоим по всему тексту
Это наподобие как по Ф5 (без регекспа), но автоматически.
Так же как во всех адекватных IDE реализовано.
Т.е., сейчас так:
* Если мы в одном из режимов по Ф5, то игноруется текущее слово 
	(если оно не является заданным по Ф5 конечно)
* Если мы в без режима Ф5, т.е. в нормальном режиме, 
	то подсвечиваем все слова как то на котором стоим.

Включено по умолчанию, отключается настройкой HIGH_CURR_WORD в скрипте

TODO
Сделать так чтобы редактор с последующими нажатиям AltF7/ShiftF7 искал этот текст (выделенный по F5)
Принимаются предложения как это лучше сделать
]]

-- ### INFO BLOCK ###

local Info = package.loaded.regscript or function(...) return ... end
local nfo = Info { _filename or ...,
	name		= "Editor_F5_ColorWord.@Xer0X.lua";
	description	= "выделить все вхождения слова под курсором";
	version		= "unknown";
	version_mod	= "0.7";
	author		= "ZG";
	author_mod	= "Xer0X";
	url		= "https://forum.farmanager.com/viewtopic.php?t=3733";
	url_mod		= "https://github.com/dr-dba/far-lua-editor-color-word";
	id		= "B86AA186-3F33-4929-894A-9AE5CDC5C1D1";
--	parent_id	= "";
	minfarversion	= { 3, 0, 0, 4744, 0 };
--	files		= "*.cfg;*.ru.lng";
--	config		= function(nfo, name) end;
--	help		= function(nfo, name) end;
--	execute		= function(nfo, name) end;
--	disabled	= true;
	options		= {
		ACTION_KEY	= "F5",
		SHOW_REGEX_ERR	= true,
		HIGH_CURR_WORD	= true,
		QuoteColorFore	= 0x0,
		QuoteColorBack	= 0xF,
	};
}

-- @@@ END OF THE INFO BLOCK @@@

-- ### CONSTANTS DECLARATION @@@

if not Xer0X then Xer0X = { } end
local opts = nfo.options
local F = far.Flags
local ACTL_GETCOLOR	= F.ACTL_GETCOLOR
local EE_CLOSE		= F.EE_CLOSE
local EE_REDRAW		= F.EE_REDRAW
local ECF_AUTODELETE	= F.ECF_AUTODELETE
local EDITOR_COLOR_TEXT = far.AdvControl(ACTL_GETCOLOR, far.Colors.COL_EDITORTEXT)
--[[ invert colors:
color.ForegroundColor, color.BackgroundColor = color.BackgroundColor, color.ForegroundColor --]]
local QUOTE_COLOR_GUID = win.Uuid("507CFA2A-3BA3-4f2b-8A80-318F5A831235")

-- @@@ END OF CONSTANTS DECLARATION @@@

-- ### SETTINGS SECTION ###

local SHOW_REGEX_ERR	= opts.SHOW_REGEX_ERR

-- @@@ END OF SETTINGS SECTION @@@

local bad_expr, detect_mode
local tbl_quotes = { }

local function fnc_trans_msg(msg_status, msg_title, msg_flags, msg_buttons)
	far.Message(msg_status, msg_title, msg_buttons, msg_flags)
	if	(msg_buttons or "") == ""
	then	far.Timer(5000, function(caller) far.AdvControl("ACTL_REDRAWALL"); caller:Close(); end)
	end
end

local function fnc_cfind_safe(line, the_quote, line_pos, plain)
	local	res, quote_pos, quote_end, got_quote
			= pcall(utf8.cfind, line, the_quote, line_pos, plain)
	return	res,
		not res and quote_pos or nil,
		res and quote_pos or nil,
		quote_end, got_quote
end

local RAND_CHK_STR = win.Uuid(win.Uuid())
local function fnc_regex_check(expr)
-- is the "expr" plain text or valid regular expression?
	local	str = RAND_CHK_STR..expr..RAND_CHK_STR
	local	res, msg, found_pos, found_end, found = fnc_cfind_safe(str, expr)
	if	res
	then	return not found
	else	return true, msg
	end
end

local function fnc_current_word(line_str, char_pos)
	
	local	line = line_str or Editor.Value
	local	pos  = char_pos or Editor.RealPos
	if	pos <= line:len() + 1
	then
		local	slab = pos > 1 and line:sub(1, pos - 1):match('[%w_]+$') or ""
		local	adj_tried
		::with_adj_shift::
		local	tail = line:sub(pos):match('^[%w_]+') or ""
		local	value_to_color = slab..tail
		if	value_to_color == ""
		then	if not	adj_tried
			then	pos = pos + 1
				adj_tried = true
				goto with_adj_shift
			else	return
			end
		end
		local value_pos = pos - slab:len()
		local value_end = pos + tail:len() - 1
		return value_to_color, Editor.CurLine, value_pos, value_end
	end
end

local last_word_str, last_word_line, last_word_pos, last_word_end
local t_curr_word_check = Far.UpTime

Event { description = "<file:> "..mf.replace(mf.fsplit(..., 4), "_", " ");
	id = "B3E432CD-E0D4-4DBB-A36E-0E362C9154A1";
	condition = function() return not nfo.disabled end,
	group = "EditorEvent",
	action = function(edid, event, param)
-- ###
if	event == EE_CLOSE
then	tbl_quotes[edid] = nil
	return
end
local	inf_quote = tbl_quotes[edid]
if not	inf_quote
then	inf_quote = { }
	tbl_quotes[edid] = inf_quote
end
if	event ~= EE_REDRAW
or	detect_mode == "RegExpr"
and	bad_expr
then	return
elseif	inf_quote.is_on
or	opts.HIGH_CURR_WORD
then	-- go on
else	return
end
local	ed_pos_chg
local	ed_cur_pos_char = Editor.RealPos
local	ed_cur_pos_line = Editor.CurLine
if 	ed_cur_pos_char ~= inf_quote.CurPosChar
or	ed_cur_pos_line ~= inf_quote.CurPosLine
then	inf_quote.CurPosChar = ed_cur_pos_char
	inf_quote.CurPosLine = ed_cur_pos_line
	ed_pos_chg = true
end
local	det_mode = detect_mode
local	t_now = Far.UpTime
if	ed_pos_chg
and not(ed_cur_pos_line == last_word_line
and	ed_cur_pos_char >= last_word_pos
and	ed_cur_pos_char <= last_word_end)
then 	t_curr_word_check = t_now
	local	curr_word_str,
		curr_word_line,
		curr_word_pos,
		curr_word_end
			= fnc_current_word(Editor.Value, ed_cur_pos_char)
	if	curr_word_str
	then	last_word_str	= curr_word_str
		last_word_line	= curr_word_line
		last_word_pos	= curr_word_pos
		last_word_end	= curr_word_end
	end
end
if not	inf_quote.is_on
then	if	last_word_str
	then	inf_quote = {
			val_to_color = last_word_str,
			val_line_num = last_word_line,
			val_char_pos = last_word_pos,
			val_char_end = last_word_end,
			val_is_plain = true,
			is_on = false
		}
		det_mode = "CaseInS"
	else	return
	end
end
local	the_quote = inf_quote.val_to_color
local	the_quote_low = the_quote:lower()
local	edin = editor.GetInfo(edid)
local	line_from = edin.TopScreenLine
local	line_last = math.min(line_from + edin.WindowSizeY, edin.TotalLines)
for ii_line = line_from, line_last
do
	local line = editor.GetString(edid, ii_line).StringText
	local line_low = line:lower()
	local line_pos = 1
	if	inf_quote.val_line_num == ii_line
	and	inf_quote.is_on
	then 	editor.AddColor(
			edid, ii_line, inf_quote.val_char_pos, inf_quote.val_char_end, ECF_AUTODELETE,
			{
				Flags = 3,
				BackgroundColor = opts.QuoteColorBack,
				ForegroundColor = opts.QuoteColorFore,
			},
			100,
			QUOTE_COLOR_GUID
				)
	end
	while true
	do
		
		local	find_res, find_msg, quote_pos, quote_end, got_quote, case_diff
		
		if	det_mode == "CaseInS"
		or	det_mode == "CaseSen"
		then
			find_res, find_msg, quote_pos, quote_end, got_quote = fnc_cfind_safe(line_low, the_quote_low, line_pos, true)
		elseif
			det_mode == "RegExpr"
		then
			find_res, find_msg, quote_pos, quote_end, got_quote = fnc_cfind_safe(line, the_quote, line_pos, false)
			if not	find_res
			then	bad_expr = true
				mf.postmacro(fnc_trans_msg, find_msg:gsub(":", "\n"), "incorrect expression: # "..the_quote.." #", "w", "OK")
				break;
			end
		end
		if not	quote_pos then break end
		if not	got_quote
		then	got_quote = line:sub(quote_pos, quote_end)
		end
		case_diff = det_mode ~= "RegExpr" and got_quote ~= the_quote
		if	ii_line	  ~= inf_quote.val_line_num
		or	quote_pos ~= inf_quote.val_char_pos
		or	quote_end ~= inf_quote.val_char_end
		then 	editor.AddColor(
				edid, ii_line, quote_pos, quote_end, ECF_AUTODELETE,
				{
					Flags = 3,
					BackgroundColor = case_diff and bnot(EDITOR_COLOR_TEXT.BackgroundColor) or EDITOR_COLOR_TEXT.ForegroundColor,
					ForegroundColor = case_diff and bnot(EDITOR_COLOR_TEXT.ForegroundColor) or EDITOR_COLOR_TEXT.BackgroundColor,
				},
				100,
				QUOTE_COLOR_GUID
					)
		end
		line_pos = quote_end + 1
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

Macro { description = "Highlight the selected quote",
	id = "D23057B8-868B-40A2-992D-4B8C21229D7B",
	area = "Editor",
	condition = function() return not nfo.disabled end,
	key = opts.ACTION_KEY,
	action = function()
-- ###
local edin = editor.GetInfo()
local edid = edin.EditorID
local value_selected = Editor.SelValue
local inf_quote = tbl_quotes[edid]
local	value_to_color = inf_quote and inf_quote.is_on and inf_quote.val_to_color
if 	value_to_color
and	value_to_color ~= ""
and (	value_selected == value_to_color
or	value_selected == "" )
then
	if	detect_mode == ""
	or not	detect_mode
	then	detect_mode  = "CaseInS"
	elseif	detect_mode == "CaseInS"
	then	if	inf_quote.val_is_plain
		then	tbl_quotes[edid].is_on = false
			detect_mode = nil
		else	detect_mode = "RegExpr"
		end
	elseif	detect_mode == "RegExpr"
	then	tbl_quotes[edid].is_on = false
		detect_mode = nil
	end
else
	local value_line_num, value_line_pos, value_line_end
	if	value_selected ~= ""
	then	value_to_color = value_selected
		local tbl_sel = editor.GetSelection(edid)
		value_line_pos = tbl_sel.StartPos
		value_line_end = tbl_sel.EndPos
	else	-- no selection, take the current quote:
		value_to_color, value_line_num, value_line_pos, value_line_end = fnc_current_word()
	end
	if	value_to_color
	and	value_to_color ~= ""
	then	detect_mode = "CaseInS"
		local expr_is_plain, expr_err_msg = fnc_regex_check(value_to_color)
		if expr_is_plain and expr_err_msg
		then mf.postmacro(fnc_trans_msg, expr_err_msg:gsub(":", "\n"), "incorrect expression: # "..value_to_color.." #", "w", SHOW_REGEX_ERR and "OK" or "")
		end
		tbl_quotes[edid] = {
			val_to_color = value_to_color,
			val_line_num = value_line_num,
			val_char_pos = value_line_pos,
			val_char_end = value_line_pos + value_to_color:len() - 1,
			val_is_plain = expr_is_plain,
			val_expr_err = expr_err_msg,
			is_on = true
		}
	elseif	inf_quote
	and	inf_quote.value_to_color
	and not inf_quote.is_on
	then	inf_quote.is_on = true
		detect_mode = "CaseInS"
	end
	bad_expr = false
end
-- @@@
	end
}

-- @@@@@
