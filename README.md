# far-lua-editor-color-word
<br /><br />
Based on the @ZG code from:<br />
выделить все вхождения слова под курсором<br />
https://forum.farmanager.com/viewtopic.php?t=3733<br />
%FarHome%\Addons\Macros\Editor.ColorWord.moon<br />
<br /><br />
@Xer0X mod (source) home:<br />
https://github.com/dr-dba/far-lua-editor-color-word<br />
<br />
Eсть три режима последовательно (по нажатию Ф5) включаемые:<br />
1.) Простое выделение, НЕ-чувствительно к регистру<br />
2.) Чувствительное к регистру выделение, текст отличное регистром тоже выделяется, но другим цветом<br />
3.) Выделение по Луа-РегЕкспу, т.е. можно написать луа-регексп в редакторе,<br />
и таким образом протестировать его в том же редакторе, что удобно<br />
<br /><br />
---------<br />
!! UPDATE<br />
Все таки сделал только два переключаемых зацикленных режима:<br />
1.) Простой, с отдельным цветом если отличается по буквенному регистру<br />
2.) Луа РегЕксп<br />
Но еще не решил, может вернусь к как до этого было<br />
или иными словами:<br />
1.) выделение и первый Ф5 - раскраска простых совпадений<br />
2.) второе Ф5 - переход на РегЕксп<br />
3.) Третье Ф5 - отмена выделений, конец цикл<br />
<br /><br />
добавил авто-выделение слова на котором стоим по всему тексту<br />
Это наподобие как по Ф5 (без регекспа), но автоматически.<br />
Так же как во всех адекватных IDE реализовано.<br />
Т.е., сейчас так:<br />
* Если мы в одном из режимов по Ф5, то игноруется текущее слово<br />
	(если оно не является заданнум по Ф5 конечно)<br />
* Если мы в без режима Ф5, т.е. в нормальном режиме,<br />
	то подсвечиваем все слова как то на которм стоим.<br />
<br />
Включено по умолчанию, отключается настройкой HIGH_CURR_WORD в скрипте<br />
