# 漢単（kantan）チュートリアル



## 漢単（kantan）とは

漢単は、構文に漢字を用いたプログラミング言語である。日本人ならば漢字を見ただけで、何となく意味を理解できる。それを利用し、日本人が直感的にコーディングできる言語を目指して開発した。（おそらく中国人も理解できるであろう。）漢単という名前は、漢字一文字で構文を表してることから、単一の漢字を表す造語、"漢単"と"簡単"に理解できるという意味を込めて付けられている。

漢単は手続き型言語の基本構造である逐次実行と如文（一般的にif文）による分岐、循文（一般的にwhile文）による繰り返し、複数の式をまとめるブロック化の機能、関数定義・呼出機能の5つの機能のみを持つ。変数や代入文の使用は可能であるが、入出力は特別な文の読文、刷文として表現される。拡張子は"*.kan"。

*hello_world.kan*

```kantan
言 "Hello World!"という文字を出力
刷 文 Hello,殊空World!殊改 字 了

```



## 構文ルール

- 文列 = 文 (文)<span>\*</span>
- 文 = 入文 | 世入文 | 如文 | 循文 | 刷文 | 読文 | 塊文
- 入文 = 変数 '入' (式 | 文字列 | 読文) '了'
- 世入文 = '世' 変数 '入' (式 | 文字列 | 読文) '了'
- 如文 = '如' 式 '則' 文 '異' 文 '了'
- 循文 = '循' 式 '開' 文 '了'
- 刷文 = '刷' ((式 | 文字列 | 読文) '区')\* (式 | 文字列 | 読文) '了'
- 読文 = '読'
- 塊文 = '始' 文列 '終'
- 比較式 = 式 ('大'|'小'|'同') 式
- 式 = 項 (('加'|'減') 項)<span>\*</span>
- 項 = 因子 (('乗'|'除') 因子)<span>\*</span>
- 因子 = 数値リテラル | 変数 | 真偽値 | '括' 式 '弧'
- 文字列 = '文' 文字リテラル '字'
    - 改行 = '殊改'
    - 半角空白 = '殊空'

- 真偽値 = '真' | '偽'
- 変数 = /^([a-zA-Z]|\p{Hiragana}|\p{Katakana}|\p{Han})\S\*$/
- 関数定義 = '能' 関数 '引' (変数'区')\* 変数 '数' '始' 文列  '終'
- 関数呼出 = '呼' 関数 '引' (式 | 文字列)'区')\* (式 | 文字列) '数' '了'
- 関数 = /^([a-zA-Z]|\p{Hiragana}|\p{Katakana}|\p{Han})\S\*$/
- 言文(コメントアウト) = /^言 \*.\*\n$/

