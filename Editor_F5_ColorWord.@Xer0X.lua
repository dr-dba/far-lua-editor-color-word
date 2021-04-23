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

Включено по умолчанию, отключается настройкой USE_HiLi_CW_AUTO в скрипте

TODO
Сделать так чтобы редактор с последующими нажатиям AltF7/ShiftF7 искал этот текст (выделенный по F5)
Принимаются предложения как это лучше сделать
]]

-- ### INFO BLOCK ###

local Info = package.loaded.regscript or function(...) return ... end
local nfo = Info { _filename or ...,
	name		= "Editor_F5_ColorWord.@Xer0X.lua";
	description	= "выделить все вхождения слова под курсором";
	version		= "unknown"; -- http://semver.org/lang/ru/
	version_mod	= "0.9.1";
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
		ACTKEY_HiLi_QUOT = "F5",
		ACTKEY_PREV_QUOT = "AltF5",
		ACTKEY_NEXT_QUOT = "ShiftF5",
		ACTKEY_HiLi_AUTO = "CtrlF5",
		USE_HiLi_CW_AUTO = false,
		SHOW_REGEX_ERROR = true,
		QuoteColorFore	 = 0x0,
		QuoteColorBack	 = 0xF,
	};
}

-- @@@ END OF THE INFO BLOCK @@@

-- ### CONSTANTS DECLARATION @@@

if not Xer0X then Xer0X = { } end
local opts = nfo.options
local F = far.Flags
local ACTL_GETCOLOR	= F.ACTL_GETCOLOR
local EE_CHANGE		= F.EE_CHANGE	
local EE_KILLFOCUS	= F.EE_KILLFOCUS
local EE_GOTFOCUS	= F.EE_GOTFOCUS	
local EE_CLOSE		= F.EE_CLOSE	
local EE_REDRAW		= F.EE_REDRAW	
local EE_SAVE           = F.EE_SAVE	
local EE_READ		= F.EE_READ	
local ECF_AUTODELETE	= F.ECF_AUTODELETE

local EDITOR_COLOR_TEXT = far.AdvControl(ACTL_GETCOLOR, far.Colors.COL_EDITORTEXT)
--[[ invert colors:
color.ForegroundColor, color.BackgroundColor = color.BackgroundColor, color.ForegroundColor --]]
local QUOTE_COLOR_GUID	= win.Uuid("507CFA2A-3BA3-4f2b-8A80-318F5A831235")
local USE_HiLi_CW_AUTO	= opts.USE_HiLi_CW_AUTO
local ACTKEY_HiLi_QUOT	= opts.ACTKEY_HiLi_QUOT
local ACTKEY_PREV_QUOT	= opts.ACTKEY_PREV_QUOT
local ACTKEY_NEXT_QUOT	= opts.ACTKEY_NEXT_QUOT
local ACTKEY_HiLi_AUTO	= opts.ACTKEY_HiLi_AUTO

-- @@@ END OF CONSTANTS DECLARATION @@@

-- ### SETTINGS SECTION ###

local SHOW_REGEX_ERROR	= opts.SHOW_REGEX_ERROR

-- @@@ END OF SETTINGS SECTION @@@
local tbl_quotes = { }
local stop_redraws
local function fnc_trans_msg(msg_status, msg_title, msg_flags, msg_buttons)
	local is_transient = (msg_buttons or "") == ""
	stop_redraws = is_transient
	far.Message(msg_status, msg_title, msg_buttons, msg_flags)
	if is_transient
	then far.Timer(5000, function(caller) far.AdvControl("ACTL_REDRAWALL"); caller:Close(); stop_redraws = false end)
	end
end

local function fnc_cfind_safe(line, the_quote, line_pos, plain)
	local	res, quote_pos, quote_end, quote_str
			= pcall(utf8.cfind, line, the_quote, line_pos, plain)
	return	res,
	not	res and quote_pos or nil,
		res and quote_pos or nil,
		quote_end, quote_str
end

local RAND_CHK_STR = utf8.upper(win.Uuid(win.Uuid()))
local function fnc_regex_check(expr)
-- is the "expr" plain text or valid regular expression?
	local	str = RAND_CHK_STR..expr..RAND_CHK_STR
	local	res, msg, found_pos, found_end, found_str = fnc_cfind_safe(str, expr)
	if	res
	then	return not found_str 
	else	return true, msg
	end
end

local function fnc_curr_expr_hili(edid, edin, line_str, char_pos)
	local	line = line_str or Editor.Value
	local	pos  = char_pos or Editor.RealPos
	if	pos <= line:len() + 1
	then
		local	slab = pos > 1 and line:sub(1, pos - 1):match('[%w_]+$') or ""
		local	tail = line:sub(pos):match('^[%w_]+') or ""
		local	value_to_color = slab..tail
		if	value_to_color == ""
		then	return
		end
		local value_pos = pos - slab:len()
		local value_end = pos + tail:len() - 1
		return value_to_color, Editor.CurLine, value_pos, value_end
	end
end -- fnc_curr_expr_hili

function fnc_edit_curr_wind_hili_info(edid, edin, inf_quote, ed_evt_num, ed_evt_arg)
-- ###
local	is_new, info_prev
local	ed_cur_pos_char = edin and edin.CurPos	or Editor.RealPos
local	ed_cur_pos_line = edin and edin.CurLine or Editor.CurLine
local	ed_val_sel_text	= Editor.SelValue
local	ed_cur_str_text	= Editor.Value
local	ed_pos_chg =
		ed_cur_pos_char ~= inf_quote.CurPosChar or
		ed_cur_pos_line ~= inf_quote.CurPosLine
if 	ed_pos_chg
then	inf_quote.CurPosChar = ed_cur_pos_char
	inf_quote.CurPosLine = ed_cur_pos_line
end
if	ed_pos_chg 
and not(ed_cur_pos_line == inf_quote.last_word_line
and	ed_cur_pos_char >= inf_quote.last_word_pos
and	ed_cur_pos_char <= inf_quote.last_word_end)
or	ed_val_sel_text ~= ""
and(not inf_quote.last_word_sel
or	inf_quote.last_word_str ~= ed_val_sel_text)
then
	local	curr_word_str,
		curr_word_line,
		curr_word_pos,
		curr_word_end,
		curr_word_sel
	if	ed_val_sel_text	== ""
	or not	ed_val_sel_text
	then	-- no selection, work on current word
		curr_word_sel	= false
		curr_word_str,
		curr_word_line,
		curr_word_pos,
		curr_word_end
			= fnc_curr_expr_hili(edid, edin, ed_cur_str_text, ed_cur_pos_char)
	else    -- work on current selection
		local	tbl_sel	= editor.GetSelection(edid)
		if not	tbl_sel
		then	local	f_res, f_msg, f_pos, f_end = fnc_cfind_safe(ed_cur_str_text, ed_cur_str_text, 1, true)
			if	f_pos
			then	tbl_sel = {
					StartPos= f_pos,
					EndPos	= f_end
				}
			else	fmsg("???")
			end
		end
		curr_word_sel	= true
		curr_word_str	= ed_val_sel_text
		curr_word_line	= ed_cur_pos_line
		curr_word_pos	= tbl_sel.StartPos
		curr_word_end	= tbl_sel.EndPos
	end
	if	curr_word_str
	and (	curr_word_sel or
	utf8.len(curr_word_str) > 1
			)
	then
		info_prev = { }
		for ii_k, ii_v in pairs(inf_quote) do info_prev[ii_k] = ii_v end
		if	inf_quote.last_word_str ~= curr_word_str
		then	inf_quote.clr_dat = { }
			is_new = true
		end
		inf_quote.last_word_sel	= curr_word_sel
		inf_quote.last_word_str	= curr_word_str
		inf_quote.last_word_line= curr_word_line
		inf_quote.last_word_pos	= curr_word_pos
		inf_quote.last_word_end	= curr_word_end
	end
end
return is_new, info_prev
-- @@@
end -- fnc_edit_curr_wind_hili_info

local function fnc_edit_curr_wind_hili_make(ed_id, edinf, inf_quote, char_pos_from, line_num_from, line_num_last, line_find_dir, do_paint, do_1st_res)
-- ###
edinf	= edinf or editor.GetInfo(ed_id)
ed_id	= ed_id or edinf.EditorID
do_paint= do_paint == nil and true or do_paint
local det_mode	=	inf_quote.is_on and inf_quote.detect_mode  or "CaseInS"
local the_quote	=	inf_quote.is_on and inf_quote.val_to_color or inf_quote.last_word_str
local line_num_home =	inf_quote.is_on and inf_quote.val_line_num or inf_quote.last_word_line
local the_quote_low =	the_quote:lower()
local char_from	=	char_pos_from or 1
local line_wnd_beg =	edinf.TopScreenLine
local line_wnd_end =	math.min(line_wnd_beg + edinf.WindowSizeY, edinf.TotalLines)
local line_dir	=	line_find_dir or 1
local line_from =	line_num_from or do_1st_res and edinf.CurLine or line_dir > 0 and line_wnd_beg or line_wnd_end
local line_last =	line_num_last or do_1st_res and (line_dir > 0 and edinf.TotalLines or 1) or (line_dir > 0 and line_wnd_end or line_wnd_beg)
local found_clr -- return value
for ii_line = line_from, line_last, line_dir
do
	local line = editor.GetString(ed_id, ii_line).StringText
	local line_low = line:lower()
	if	inf_quote.val_line_num == ii_line
	and	inf_quote.is_on
	then 	editor.AddColor(
			ed_id, ii_line, inf_quote.val_char_pos, inf_quote.val_char_end, ECF_AUTODELETE,
			{
				Flags = 3,
				BackgroundColor = opts.QuoteColorBack,
				ForegroundColor = opts.QuoteColorFore,
			},
			100,
			QUOTE_COLOR_GUID
				)
	end
	local 	do_search
	local	tbl_clr_line = inf_quote.clr_dat[ii_line]
	if not	tbl_clr_line
	then	tbl_clr_line = { }
		inf_quote.clr_dat[ii_line] = tbl_clr_line
		do_search = true
	end
	while	do_search
	do
		local	find_res, find_msg, quote_pos, quote_end, quote_str, case_diff
		if	det_mode == "CaseInS"
		or	det_mode == "CaseSen"
		then
			find_res, find_msg, quote_pos, quote_end, quote_str = fnc_cfind_safe(line_low,	the_quote_low,	char_from, true)
		elseif
			det_mode == "RegExpr"
		then
			find_res, find_msg, quote_pos, quote_end, quote_str = fnc_cfind_safe(line,	the_quote,	char_from, false)
			if not find_res --[[ should not be here,
			since "false" for "find_res" means bad expression,
			which should be checked beforehand in the F5 proc.]]
			then	mf.postmacro(fnc_trans_msg, find_msg:gsub(":", "\n"), "(Ooops!?) incorrect expression: # "..the_quote.." #", "w", "OK")
				break
			end --]]
		end
		if not	quote_pos then break end
		if not	quote_str
		then	quote_str = line:sub(quote_pos, quote_end)
		end
		case_diff = det_mode ~= "RegExpr" and quote_str ~= the_quote
		if	ii_line	  ~= inf_quote.val_line_num
		or	quote_pos ~= inf_quote.val_char_pos
		or	quote_end ~= inf_quote.val_char_end
		then 	tbl_clr_line[#tbl_clr_line + 1] = {
				beg	= quote_pos,
				fin	= quote_end,
				clr	= {
					Flags = 3,
					BackgroundColor = case_diff and bnot(EDITOR_COLOR_TEXT.BackgroundColor) or EDITOR_COLOR_TEXT.ForegroundColor,
					ForegroundColor = case_diff and bnot(EDITOR_COLOR_TEXT.ForegroundColor) or EDITOR_COLOR_TEXT.BackgroundColor,
				},
			}
		end
		char_from = quote_end + 1
	end -- of "while do_search" loop on single line
	if	do_search
	and	#tbl_clr_line == 0
	then	tbl_clr_line.no_match = true
	elseif	#tbl_clr_line > 0
	then
		if	do_paint
		then	for ii_clr, clr in pairs(tbl_clr_line)
			do editor.AddColor(ed_id, ii_line, clr.beg, clr.fin, ECF_AUTODELETE, clr.clr, 100, QUOTE_COLOR_GUID)
			end
		end
		if	do_1st_res
		then
			local anchor_pos = ii_line == edinf.CurLine and edinf.CurPos or line_find_dir > 0 and 0 or (#line + 1)
			if	line_find_dir > 0
			then	for ii_clr = 1, #tbl_clr_line,  1 do if tbl_clr_line[ii_clr].beg > anchor_pos then found_clr = tbl_clr_line[ii_clr]; break end end
			else	for ii_clr = #tbl_clr_line, 1, -1 do if tbl_clr_line[ii_clr].fin < anchor_pos then found_clr = tbl_clr_line[ii_clr]; break end end
			end
			if	found_clr
			then	local ed_pos_new = {
					CurPos = line_find_dir > 0 and found_clr.beg or found_clr.fin,
					CurLine = ii_line
				}
				if	ii_line < line_wnd_beg
				then	ed_pos_new.TopScreenLine = math.max(ii_line - 1, 1)
				elseif	ii_line > line_wnd_end
				then	ed_pos_new.TopScreenLine = math.min(ii_line + 3, edinf.TotalLines) - edinf.WindowSizeY
				end
				if	editor.SetPosition(ed_id, ed_pos_new)
				then	edinf.CurPos = ed_pos_new.CurPos or	edinf.CurPos
					edinf.CurLine= ed_pos_new.CurLine or	edinf.CurLine
				end
				break
			end
		else
			found_clr = tbl_clr_line[line_dir > 0 and #tbl_clr_line or 1]
		end
	end
	--[[ for the next line always from the start or end,
	"-1" interpreted as detect expression from the end to beginning]]
	char_from = 1
end -- of "for <each line>" loop
return found_clr
-- @@@
end -- fnc_edit_curr_wind_hili_make

local function fnc_inf_expr(inf_quote) return inf_quote.is_on and inf_quote.val_to_color or inf_quote.last_word_str end

local function fnc_edit_curr_wind_hili(ed_id, edinf, inf_quote, ed_evt_num, ed_evt_arg)
	local isNew,tPrv= fnc_edit_curr_wind_hili_info(ed_id, edinf, inf_quote, ed_evt_num, ed_evt_arg)
	if not(	inf_quote.is_on
	or	inf_quote.last_word_str)
	then return
	end
	local found_clr = fnc_edit_curr_wind_hili_make(ed_id, edinf, inf_quote)
end -- fnc_edit_curr_wind_hili

local function fnc_edit_expr_find(ed_id, edinf, inf_quote, find_direction)
	if not(	inf_quote.is_on
	or	inf_quote.last_word_str)
	then return
	end
	local	find_dir = find_direction or 1
	local	foundClr = fnc_edit_curr_wind_hili_make(ed_id, edinf, inf_quote, nil, nil, find_dir > 0 and edinf.TotalLines or 1, find_dir, false, true)
	if	foundClr
	then	inf_quote.in_search = true
		far.Timer(0, function(caller) caller:Close();
			far.AdvControl("ACTL_REDRAWALL");
			local	sz_vk = mf.waitkey()
			if	sz_vk:match("^R?"..ACTKEY_NEXT_QUOT.."$")
			or	sz_vk:match("^R?"..ACTKEY_PREV_QUOT.."$")
			then
			else	inf_quote.in_search = false
			end
			local	ok_post = mf.postmacro(eval, "Editor/"..sz_vk, 2)
			if not	ok_post
			then	fmsg(sz_vk, "postmacro problem:")
			end
		end)
	else	mf.postmacro(fnc_trans_msg, fnc_inf_expr(inf_quote), "Not found:", "w", "")
	end
end -- fnc_edit_expr_find

local function fnc_expr_proc(ed_id, edinf, force_status)
-- ###
edinf = edinf or editor.GetInfo(ed_id)
ed_id = ed_id or edinf.EditorID
local	value_selected  = Editor.SelValue
local	inf_quote	= tbl_quotes[ed_id]
if not	inf_quote
then	inf_quote = { }
	tbl_quotes[ed_id]= inf_quote
end
local	value_to_color	=
		inf_quote	and
		inf_quote.is_on and
		inf_quote.val_to_color
if 	value_to_color
and	value_to_color ~= ""
and (	value_selected == value_to_color
or	value_selected == "" )
or	force_status
then    -- pre-existing value to color, switch detect mode
	if not	inf_quote.detect_mode
	then	inf_quote.detect_mode = ""
	end
	if	inf_quote.detect_mode == ""
	and not force_status
	or	force_status == "CaseInS"
	then	inf_quote.detect_mode = "CaseInS"
	elseif	inf_quote.detect_mode == "CaseInS"
	and not force_status
	or	force_status == "RegExpr"
	then	if	inf_quote.val_is_plain
		then	inf_quote.is_on = false
			inf_quote.detect_mode = nil
		else	inf_quote.detect_mode = "RegExpr"
		end
	elseif	inf_quote.detect_mode == "RegExpr"
	and not force_status
	or	force_status == "OFF"
	then	
		inf_quote.detect_mode = nil
		inf_quote.is_on	=	false
		inf_quote.clr_dat =	{ }
	end
else	-- new value to color initialize
	local value_line_num, value_line_pos, value_line_end
	if	value_selected
	and	value_selected	~= ""
	then	value_to_color	= value_selected
		local tbl_sel	= editor.GetSelection(ed_id)
		value_line_num	= tbl_sel.StartLine
		value_line_pos	= tbl_sel.StartPos
		value_line_end	= tbl_sel.EndPos
	else	-- no selection, take the current quote:
		value_to_color,
		value_line_num,
		value_line_pos,
		value_line_end
			= fnc_curr_expr_hili(ed_id, edinf)
	end
	if	value_to_color
	and	value_to_color ~= ""
	then	local	expr_is_plain, expr_err_msg = fnc_regex_check(value_to_color)
		if	expr_is_plain
		and	expr_err_msg
		then	mf.postmacro(
				fnc_trans_msg,
				expr_err_msg:gsub(":", "\n"),
				"incorrect expression: # "..value_to_color.." #",
				"w",
				SHOW_REGEX_ERROR and "OK" or ""
					)
		end
		inf_quote.detect_mode	= "CaseInS"
		inf_quote.is_on		= true
		inf_quote.clr_dat	= { }
		inf_quote.val_to_color	= value_to_color
		inf_quote.val_line_num	= value_line_num
		inf_quote.val_char_pos	= value_line_pos
		inf_quote.val_char_end	= value_line_pos + value_to_color:len() - 1
		inf_quote.val_is_plain	= expr_is_plain
		inf_quote.val_expr_err	= expr_err_msg
	elseif	inf_quote.value_to_color
	and not inf_quote.is_on
	then	inf_quote.detect_mode	= "CaseInS"
		inf_quote.is_on		= true
		inf_quote.clr_dat	= { }
	end
end
-- @@@
end -- fnc_expr_proc

Event { description = "[select quote:] editor events (CLOSE, REDRAW)",
	id = "B3E432CD-E0D4-4DBB-A36E-0E362C9154A1";
	condition = function() return not nfo.disabled end,
	group = "EditorEvent",
	action = function(ed_id, event, param)
-- ###
if	event == EE_CLOSE
then	tbl_quotes[ed_id] = nil
	return
end
local	inf_quote = tbl_quotes[ed_id]
if not	inf_quote
then	inf_quote = { clr_dat = { } }
	tbl_quotes[ed_id] = inf_quote
end
if	event ~= EE_REDRAW
or	stop_redraws
or	inf_quote.detect_mode == "RegExpr"
and	inf_quote.expr_err_msg
then	return
elseif	inf_quote.is_on
or	USE_HiLi_CW_AUTO
then	-- go on
else	return
end
fnc_edit_curr_wind_hili(ed_id, editor.GetInfo(ed_id), inf_quote, event, param)
-- @@@
	end;
} 

Macro { description = "[select quote:] HighLight",
	id = "D23057B8-868B-40A2-992D-4B8C21229D7B",
	area = "Editor",
	key = ACTKEY_HiLi_QUOT,
	condition = function() return not nfo.disabled end,
	action = function()
		fnc_expr_proc()
	end
}

Macro { description = "[select quote:] Go to the next",
	id = "06505D40-EE3E-4DB6-B1CB-B3E8E7BB41FC",
	area = "Editor",
	key = ACTKEY_NEXT_QUOT,
	condition = function() return not nfo.disabled end,
	action = function()
		local edinf = editor.GetInfo()
		fnc_edit_expr_find(edinf.EditorID, edinf, tbl_quotes[edinf.EditorID])
	end
}

Macro { description = "[select quote:] Go to the prev",
	id = "06505D40-EE3E-4DB6-B1CB-B3E8E7BB41FC",
	area = "Editor",
	key = ACTKEY_PREV_QUOT,
	condition = function() return not nfo.disabled end,
	action = function()
		local edinf = editor.GetInfo()
		fnc_edit_expr_find(edinf.EditorID, edinf, tbl_quotes[edinf.EditorID], -1)
	end
}

Macro { description = "[select quote:] Toggle current word highliting",
	id = "3CF742E5-8C1E-4D94-B30F-959D727B6340",
	area = "Editor",
	key = ACTKEY_HiLi_AUTO,
	condition = function() return not nfo.disabled end,
	action = function()
		local edinf = editor.GetInfo()
		local inf_quote = tbl_quotes[edinf.EditorID]
		USE_HiLi_CW_AUTO = not USE_HiLi_CW_AUTO or inf_quote.is_on
		if USE_HiLi_CW_AUTO
		then	fnc_expr_proc(edinf.EditorID, edinf, "OFF")
			far.AdvControl("ACTL_REDRAWALL")
		end
	end
}

-- @@@@@
