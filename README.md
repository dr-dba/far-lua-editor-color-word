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
<br />
Но еще не решил, может вернусь к как до этого было<br />

TODO<br />
Сделать так чтобы редактор с последующими нажатиям AltF7/ShiftF7 искал этот текст (выделенный по F5)<br />
<bold>Принимаются предложения как это лучше сделать</bold><br /><br />
