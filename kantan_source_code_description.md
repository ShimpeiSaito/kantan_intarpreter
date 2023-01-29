# kantan ソース解説

##### ソース全体はこちら

https://github.com/ShimpeiSaito/kantan_intarpreter/blob/master/kantan.rb



## メンバ変数

#### @@keywords

```ruby
# 予約語表
@@keywords = {
  '加' => :add,
  '減' => :sub,
  '乗' => :mul,
  '除' => :div,
  '大' => :greater,
  '小' => :less,
  '同' => :equal,
  '括' => :lpar,
  '弧' => :rpar,
  '真' => :true,
  '偽' => :false,
  '入' => :assign,
  '世' => :global_assign,
  '了' => :end,
  '始' => :block_start,
  '終' => :block_end,
  '如' => :if,
  '則' => :then,
  '異' => :else,
  '循' => :loop,
  '開' => :loop_start,
  '刷' => :print,
  '読' => :read,
  '文' => :string_start,
  '字' => :string_end,
  '能' => :function,
  '呼' => :call_function,
  '引' => :argument_start,
  '区' => :separator,
  '数' => :argument_end
}
```

kantanの予約語のリスト。終端記号をキー とし、トークン(Symbol)を値とするハッシュで表現。



#### @@code

```ruby
@@code = '' # 入力されたソースコードの格納場所
```

入力されたkantanのソースコードを格納するため の変数。空文字列で初期化。



#### @@space

```ruby
@@space = {} # グローバル変数及び関数ごとのローカル変数の格納場所
```

グローバル変数及び関数ごとのローカル変数の名前とその値を格納するための空間。変数名をキー(又は関数名)、変数の値(又はハッシュの変数表)を値とするハッシュ。



#### @@functions

```ruby
@@functions = {} # 関数のブロック(中身)の格納場所
```

定義された関数名とその中身であるブロックを格納するための空間。関数名をキー、その関数のブロックを値とするハッシュ。



#### @@func_names

```ruby
@@func_names = [] # 実行中の関数名の格納場所
```

現在実行されている関数名を一時的に格納するための空間。関数名の配列。





#### @scanner

```ruby
@scanner = StringScanner.new(@code) # スキャナーインスタンスの生成
```

コードをスキャンするためのスキャナー。initializeで定義している。get_tokenとunget_tokenで使われる。



## メソッド

#### initialize

```ruby
def initialize
  # 実行ファイルの読み取り
  file = ARGV[0]
  lines = []
  raise LoadError, 'No such file or directory' if file.nil? # 実行ファイルが見つからなければエラー

  File.foreach(file) do |line|
    lines.push(line)
  end
  @code = lines.join # @codeにファイルの中身を格納

  @scanner = StringScanner.new(@code) # スキャナーインスタンスの生成

  eval(parse) # 意味解析
rescue StandardError => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

コマンドライン引数に指定されたファイル名のファイルを読み取り、ファイルの中身を@codeに格納している。ファイルが見つからない場合はエラーを発生させる。そして、@codeのスキャナーインスタンスを作成している。ここで、構文解析を行うparseと意味解析を行うevalを呼び出している。



#### eval(exp)

```ruby
# 意味解析
def eval(exp)
  if exp.instance_of?(Array)
    case exp[0]
    when :block
      exp[1..].each do |e|
        eval(e)
      end
    when :add # 加算
      eval(exp[1]) + eval(exp[2])
    when :sub # 減算
      eval(exp[1]) - eval(exp[2])
    when :mul # 乗算
      eval(exp[1]) * eval(exp[2])
    when :div # 除算
      eval(exp[1]).fdiv(eval(exp[2]))
    when :greater # 大なり
      eval(exp[1]) > eval(exp[2])
    when :less # 小なり
      eval(exp[1]) < eval(exp[2])
    when :equal # イコール
      eval(exp[1]) == eval(exp[2])
    when :assignment # 変数への代入
      return @space[@func_name][exp[1]] = eval(exp[2]) unless @space[@func_name].nil? # 関数内ならローカル変数とする

      @space[exp[1]] = eval(exp[2]) # グローバル変数へ代入
    when :global_assignment # グローバル変数への代入
      @space[exp[1]] = eval(exp[2])
    when :print # 標準出力
      # 区切り文字で複数個並んでいる場合は結合して出力
      result = []
      exp[1].each do |e|
        result << eval(e).to_s.gsub(/殊改/, "\n").gsub(/殊空/, ' ')
      end
      result = result.join('')
      print result
    when :read # 標準入力
      begin
        input = $stdin.gets.chomp # 入力を受け取る
        float = Float(input) # floatへの変換を試みる
        return Integer(input) if (float - float.to_i).zero? # 整数値かを確認、整数ならintegerとする

        float
      rescue StandardError
        input # 数値への変換に失敗した場合は文字列のまま返す
      end
    when :if # 条件分岐
      # 条件式により処理を分岐
      judge = eval(exp[1])
      if judge
        eval(exp[2])
      else
        eval(exp[3]) unless exp[3].nil? # 異句があるば実行
      end
    when :loop # 繰り返し
      # 条件式の条件を満たしている間ループする
      loop do
        break unless eval(exp[1])

        eval(exp[2])
      end
    when :function # 関数定義
      @space[exp[1]] = exp[2] # 引数の変数名を格納
      @functions[exp[1]] = exp[3] # 関数内の処理(ブロック)を格納
    when :call_function # 関数呼び出し
      @func_name = exp[1] # 実行する関数名を格納
      raise NameError, 'This function is not defined' if @space[@func_name].nil?

      arguments = @space[@func_name].dup
      raise SyntaxError, 'Different number of arguments' if arguments.length != exp[2].length # 定義した引数の数と合わない場合はエラー

      # 関数内で他の関数を呼び出した場合の対処
      # 呼び出し元の関数のローカル変数の中で、呼び出し先の関数の引数に設定されているものがあれば、呼び出し元の関数の変数と値を追加or上書きする
      merged_keys = [] # 追加した変数のキーの格納場所
      if @func_names.length.positive? # 関数内で呼び出されているか
        @space[@func_names.last].each do |h| # 呼び出し元の変数表を参照
          if exp[2].include?(h[0]) # 現在の関数の引数に呼び出し元の変数が使われているか
            @space[@func_name].merge!(Hash[*h]) # 追加または書き換え
            merged_keys << h[0] # 追加または書き換えた変数のキーを格納
          end
        end
      end
      @func_names << exp[1] # 現在の関数名を格納

      # 引数に指定された値の格納と余分な呼び出し元のローカル変数の削除
      @space[@func_name].each_with_index do |h, i|
        @space[@func_name][h[0]] = eval(exp[2][i]) unless exp[2][i].nil? # 指定された引数を現在の関数のローカル変数として格納
        if exp[2][i].nil?
          @space[@func_name].delete_if { |key, _| merged_keys.include?(key) } # 呼び出し元の変数のうち、引数の値としてのみ使われている変数を削除（同じローカル変数名だったら消さない）
        end
      end

      eval(@functions[@func_name]) # 関数の中身(ブロック)の実行

      @space[@func_name] = arguments # 関数内で定義したローカル変数を初期化
      @func_names.pop # 実行が終わったら、@func_namesから削除
      @func_name = @func_names.last # @func_nameを呼び出し元の関数名に戻す（呼び出し元がなければnil）
    when :string # 文字列
      exp[1] # 文字列なら値だけを返す
    when :true # 真偽値(真)
      true # trueを返す
    when :false # 真偽値(偽)
      false # falseを返す
    else
      raise SyntaxError, 'Incorrect syntax'
    end
  else
    if !@space[@func_name].nil? && @space[@func_name].key?(exp) && !@space[@func_name][exp].nil?
      return @space[@func_name][exp] # ローカル変数があれば、その関数のローカル変数での値を返す
    end
    return @space[exp] if @space.key?(exp) # グローバル変数の値を返す

    raise NameError, 'Variable is not defined' if exp.is_a?(String) # 数値以外ならエラー（変数以外の文字列ならエラー）

    exp # 数値はそのまま返す
  end
rescue Exception => e
  if e.class == NoMethodError
    puts "#{e.class}: Incorrect value"
  else
    puts "#{e.class}: #{e.message}"
  end
  exit!
end
```

意味解析を行う関数。引数に渡される構文木のノード(exp)が配列ならばexp[0]要素ごとの処理を行う。配列でなければ、変数か数値であるので、変数の値または数値を返す。exp[0]が:blookならexp[1]以降の要素数分evalを再帰する。

:add, :sub, :mul, :divなら各算術演算を行う。 :greater, :less, :equalなら各比較演算を行う。

:assignmentなら変数への代入を行う。関数内での呼び出しならローカル変数とし、それ以外ならグローバル変数とする。

:global_assignmentはグローバル変数への代入を行う。

:printなら標準出力を行う。複数の要素がある場合は結合して出力する。文字列中の"殊改"と"殊空"はそれぞれ改行と半角空白を表す特殊文字である。

:readなら標準入力を受け取る。受け取った値がfloatに変換できればfloatとして、それがintegerならばintegerに変換する。数値への変換ができない場合は文字列として返す。

:ifなら条件分岐を行う。条件式の解析の結果から処理を分ける。条件を満たさず、異句があれば異句のブロックを実行する。

:loopなら条件式の条件を満たしている間処理を繰り返す。

:functionなら関数定義を行う。@@spaceに関数名をキー、引数の変数名のハッシュ(値はnil)を格納する。@@functionsに関数名をキー、関数内の処理(ブロック)を値として格納する。

:call_functionなら関数呼び出しを行う。@func_nameに実行する関数名を格納する。関数内で他の関数を呼び出した場合の対処として、呼び出し元の関数のローカル変数の中で、呼び出し先の関数の引数に設定されているものがあれば、呼び出し元の関数の変数と値を実行する関数の変数表に追加または上書きする。@@func_namesに現在の関数名を格納する。実行する関数の変数表に対して、引数に指定された値の格納と余分な呼び出し元のローカル変数(呼び出し元の変数のうち引数の値としてのみ使われている変数)の削除を行う。関数の中身(ブロック)を実行する。関数内で定義したローカル変数を初期化(関数定義時の引数のみにする)を行う。@@func_namesから削除し、@func_nameを呼び出し元の関数名(呼び出し元がなければnil)に戻す。

:string, :true, :falseなら文字列は値をそのまま返し、真偽値ならtrueまたはfalseを返す。



#### parse

```ruby
# パーサー
def parse
  # pp sentences
  sentences
end
```

構文解析を行う。sentencesを呼び出している。initializeで呼ばれる。構文解析をした結果(例)は次のようになる。

```ruby
[:block,
 [:function,
  "階乗計算",
  {"num"=>nil},
  [:block,
   [:assignment, "fact", 1],
   [:assignment, "i", 1],
   [:loop,
    [:less, "i", [:add, "num", 1]],
    [:block,
     [:assignment, "fact", [:mul, "fact", "i"]],
     [:assignment, "i", [:add, "i", 1]]]],
   [:global_assignment, "階乗の結果", "fact"]]],
 [:print, [[:string, "自然数を入力してください殊改"]]],
 [:assignment, "input", [:read]],
 [:call_function, "階乗計算", ["input"]],
 [:print, ["input", [:string, "の階乗は"], "階乗の結果", [:string, "です殊改"]]]]
```



#### sentences

```ruby
# 文列の要素を一つの配列として返す
# 文列 = 文 (文)*
def sentences
  unless (s = sentence)
    raise SyntaxError, 'Incorrect syntax'
  end

  # 最初に呼ばれたのか、プログラム中で呼ばれたのかで用意する配列を分ける
  result = if s.empty?
             [:block]
           else
             [:block, s]
           end
  # 文がある間、構文木を作り続ける
  while (s = sentence)
    result << s
  end
  result
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

文列の要素を一つの配列として返す。最初に呼ばれたのか、プログラム中で呼ばれたのかで用意する配列を分ける。そして、その配列に文がある間構文木を作り続けて、配列を返す。



#### sentence

```ruby
# 文を配列として返す
# 文 = 入文 | 世入文 | 如文 | 循文 | 刷文 | 読文
def sentence
  return if @scanner.eos?

  token = get_token
  raise SyntaxError, 'Incorrect syntax' if token == :bad_token

  case token
  when :if # 如文のとき
    conditionals
  when :loop # 循文のとき
    repetition
  when :print # 刷文のとき
    printing
  when :function # 関数定義のとき
    function
  when :call_function # 関数呼び出しのとき
    call_function
  when :block_start # 塊文の開始時
    ''
  when :block_end # 塊文の終了時
    nil
  when :end # 了(文の終わり)のとき
    sentence
  when :global_assign # 世入文のとき
    global_assignment
  else # 入文のとき
    unget_token
    assignment
  end
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

token(構文)ごとにメソッドを呼び出し、その結果(構文木のノード)を返している。塊文の開始時のトークンの場合は''(空文字)を返し、塊文の終了時はnilを返している。これはプログラム中でブロックの構文解析を行う際に解析の開始と終了を示すためである。



#### conditionals

```ruby
# 如文(if文)
# 如文 = '如' 式 '則' 文 '異' 文 '了'
def conditionals
  con_exp = comparison_operation # 比較式をパージング
  raise SyntaxError, 'Incorrect syntax, expecting 則 in 如文' unless get_token == :then # 比較式の後に則が来なければエラー

  true_block = sentences # 真のときの文をパージング
  if get_token == :else # 異句が続くか判定
    false_block = sentences # 偽のときの文をパージング
  else
    unget_token
  end

  raise SyntaxError, 'Unexpected end-of-input, expecting 了 in 如文' unless get_token == :end # :endの削除

  [:if, con_exp, true_block, false_block]
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

如文(if文)の構文解析を行なっている。[:if, 比較式, 真の場合のブロック, 偽の場合のブロック]の形の配列を返す。comparison_operationメソッドを呼び出し、比較式の構文解析を行う。次に真のときの文の構文解析を行い、異句があれば偽のときの文の構文解析を行う。



#### repetition

```ruby
# 循文(loop文)
# 循文 = '循' 式 '開' 文 '了'
def repetition
  con_exp = comparison_operation # 比較式をパージング
  raise SyntaxError, 'Incorrect syntax, expecting 開 in 循文' unless get_token == :loop_start # 比較式の後に開が来なければエラー

  block = sentences # 循文の中身をパージング
  raise SyntaxError, 'Unexpected end-of-input, expecting 了 in 循文' unless get_token == :end # :endの削除

  [:loop, con_exp, block]
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

循文(loop文)の構文解析を行なっている。[:loop, 比較式, ブロック]の形の配列を返す。comparison_operationメソッドを呼び出し、比較式の構文解析を行う。次に循文の中身の構文解析を行う。



#### printing

```ruby
# 刷文(print文)
# 刷文 = '刷' ((式 | 文字列 | 読文) '区')* (式 | 文字列 | 読文) '了'
def printing
  val = [] # 出力する値の格納場所
  loop do
    case get_token
    when :string_start # tokenが文字列のとき
      val << [:string, get_token]
      get_token # "」"の削除
    when :read # tokenが読文のとき
      val << [:read]
    else # tokenが式のとき
      unget_token
      val << expression # 式をパージングして格納
    end

    case get_token
    when :separator # 区があるならループ続行
      next
    when :end # 了が来たらブレイク
      break
    end

    raise SyntaxError, '区 are not inserted correctly or Unexpected end-of-input, expecting 了 in 刷文'
  end

  [:print, val]
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

刷文(print文)の構文解析を行なっている。[:print, 出力する値の配列]の形の配列を返す。tokenが文字列のときは[:string, 文字列]を、読文のときは[:read]を、式のときは式を構文解析した結果をvalに格納する。これを了が来るまで(区が続く限り)繰り返す。



#### function

```ruby
# 関数定義
# 関数定義 = '能' 関数 '引' (変数'区')* 変数 '数' '始' 文列  '終'
def function
  func_name = get_token # 関数名を取得
  raise SyntaxError, 'Incorrect function name' unless func_name.instance_of?(String) # 関数名がStringでなければエラー

  raise SyntaxError, 'Incorrect syntax, expecting 引 in 関数定義' unless get_token == :argument_start # 関数名の後に引が来なければエラー

  private_variables = {} # ローカル変数(引数)の格納場所
  loop do
    private_variables[get_token] = nil # 引数(変数)をハッシュとしてキーだけ格納

    token = get_token
    unless %i[separator argument_end].include?(token)
      raise SyntaxError, '区 or 数 are not inserted correctly in 関数定義' # 区か数が来なければエラー
    end

    break if token == :argument_end # 了が来たらブレイク
  end
  raise SyntaxError, 'Incorrect syntax, expecting 始 in 関数定義' unless get_token == :block_start # 引数のあとに始が来なければエラー

  unget_token

  [:function, func_name, private_variables, sentences] # 関数の中身をパージングして返す
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

関数定義の構文解析を行なっている。[:function, 関数名, 引数(ローカル変数)のハッシュ, ブロック]の形の配列を返す。ローカル変数(引数)の格納場所を用意し、引数の数だけ引数(変数)をハッシュとしてキーだけ格納する。そして、関数の中身の構文解析を行う。



#### call_function

```ruby
# 関数呼出
# 関数呼出 = '呼' 関数 '引' (式 | 文字列)'区')* (式 | 文字列) '数' '了'
def call_function
  func_name = get_token # 関数名を取得
  raise SyntaxError, 'Incorrect syntax, expecting 引 in 関数呼出' unless get_token == :argument_start # 関数名の後に引が来なければエラー

  private_variables = [] # ローカル変数の格納場所
  loop do
    private_variables << expression # 引数に指定された値を格納

    token = get_token
    unless %i[separator argument_end].include?(token)
      raise SyntaxError, '区 or 数 are not inserted correctly in 関数呼出' # 区か数が来なければエラー
    end

    break if token == :argument_end # 了が来たらブレイク
  end
  raise SyntaxError, 'Unexpected end-of-input, expecting 了 in 関数呼出' unless get_token == :end # :endの削除

  [:call_function, func_name, private_variables]
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

関数呼出の構文解析を行なっている。[:call_function, 関数名, 引数(ローカル変数)の配列]の形の配列を返す。ローカル変数(引数)の格納場所を用意し、引数の数だけ引数(変数)の値を格納する。



#### assignment

```ruby
# 入文(代入文)
# 入文 = 変数 '入' (式 | 文字列 | 読文) '了'
def assignment
  var = get_token # 変数名を取得
  raise SyntaxError, 'Incorrect variable name' unless var.instance_of?(String) # 変数名ががStringでなければエラー

  raise SyntaxError, 'Incorrect syntax' unless get_token == :assign # 変数名の後に入が来なければエラー

  case get_token
  when :string_start # tokenが文字列のとき
    val = [:string, get_token]
    get_token # "」"の削除
  when :read # tokenが読文のとき
    val = [:read]
  else # tokenが式のとき
    unget_token
    val = expression # 式をパージング
  end
  raise SyntaxError, 'Unexpected end-of-input, expecting 了 in 入文' unless get_token == :end # :endの削除

  [:assignment, var, val]
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

入文(代入文)の構文解析を行なっている。[:assignment, 変数名, 値]の形の配列を返す。tokenが文字列のときは[:string, 文字列]を、読文のときは[:read]を、式のときは式を構文解析した結果をvalに格納する。



#### global_assignment

```ruby
# 世入文(明示的なグローバル変数への代入文)
# 世入文 = '世' 変数 '入' (式 | 文字列 | 読文) '了'
def global_assignment
  result = assignment # 入文でパージングした結果を取得
  result[0] = :global_assignment # :assignmentを:global_assignmentに書き換え
  result
end
```

世入文(明示的なグローバル変数への代入文)の構文解析を行なっている。[:global_assignment, 変数名, 値]の形の配列を返す。第1引数のシンボル以外はassignmentの結果と同じである。



#### comparison_operation

```ruby
# 比較式
# 比較式 = 式 ('大'|'小'|'同') 式
def comparison_operation
  exp = expression # 式(左辺)をパージング
  token = get_token
  unless (token == :greater) || (token == :less) || (token == :equal)
    raise SyntaxError, 'Incorrect syntax, expecting 大 or 小 or 同' # 式の後に大, 小, 同が来なければエラー
  end

  [token, exp, expression]
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

比較式の構文解析を行なっている。[比較演算子のシンボル, 左辺の式, 右辺の式]の形の配列を返す。左辺の式を構文解析する。比較演算子を取得。右辺の式の構文解析を行なっている。



#### expression

```ruby
# 式
# 式 = 項 (('加'|'減') 項)*
def expression
  result = term # 項をパージング
  token = get_token
  while (token == :add) || (token == :sub) # 加と減がある限り入れ子していく
    result = [token, result, term]
    token = get_token
  end
  unget_token
  result
end
```

式の構文解析を行なっている。[算術演算子のシンボル, 左側の式, 右側の項]の形の配列を返す。最左の項を構文解析する。算術演算子を取得。右側の項の構文解析を行なっている。加と減がある限り入れ子していく。



#### term

```ruby
# 項
# 項 = 因子 (('乗'|'除') 因子)*
def term
  result = factor # 因子をパージング
  token = get_token
  while (token == :mul) || (token == :div) # 乗と除がある限り入れ子していく
    result = [token, result, factor]
    token = get_token
  end
  unget_token
  result
end
```

項の構文解析を行なっている。[算術演算子のシンボル, 左側の式, 右側の項]の形の配列を返す。最左の因子を構文解析する。算術演算子を取得。右側の項の構文解析を行なっている。乗と除がある限り入れ子していく。



#### factor

```ruby
# 因子
# 因子 = 数値リテラル | 変数 | 真偽値 | '括' 式 '弧'
def factor
  token = get_token
  case token
  when String # tokenがString(変数)のとき
    token
  when Numeric # tokenがNumeric(数値リテラル)のとき
    token
  when :true # tokenが真偽値(真)のとき
    token
  when :false # tokenが真偽値(偽)のとき
    token
  when :lpar # tokenが括のとき
    result = expression # 括弧内の式をパージング
    t = get_token # 弧を取り除く(使用しない)
    raise SyntaxError, 'Incorrect syntax, expecting ) in 因子' unless t == :rpar # 弧が来なければエラー

    result
  else
    raise SyntaxError, 'Incorrect syntax' # tokenが上のどれでもなければエラー
  end
rescue Exception => e
  puts "#{e.class}: #{e.message}"
  exit!
end
```

因子の構文解析を行なっている。変数名または数値または真偽値のシンボルまたは括弧内の式(の構文解析の結果)を返す。tokenがString, Numeric, :true, :false のときはtokenの値をそのまま返し、:lpar(左括弧)の場合は括弧内の式を構文解析した結果を返す。



#### get_token

```ruby
# tokenを取得する
def get_token
  @scanner.scan(/\A\s*言 *.*\n/) # コメントをスキャン(コメントを取り除く)

  token = @scanner.scan(/\A\s*(-?\d+(?:\.\d+)?)/) # 数値リテラルをスキャン
  return token.strip.to_i if token

  token = @scanner.scan(/\A\s*(#{@@keywords.keys.map { |t| t }})\s+/) # 予約語をスキャン
  return @@keywords[token.strip] if token && (@@keywords[token.strip])

  token = @scanner.scan(/\A\s*([a-zA-Z]|\p{Hiragana}|\p{Katakana}|\p{Han})\S*/) # 変数, 関数, 文字リテラルをスキャン
  return token.strip if token

  :bad_token # スキャン出来なければ:bad_tokenを返す
end
```

@@codeのスキャナーを用いて、スキャンした結果を整形したもの(token)を返す。コメントのスキャン(コメントの除去)を行なった上で、数値リテラル, 予約語, (変数, 関数, 文字リテラル)のスキャンを行う。マッチしたものがあった時点で返す。パーザー(群)から呼び出される。



#### unget_token

```ruby
# tokenを押し戻す
def unget_token
  @scanner.unscan # ポインタを前回のスキャン位置に戻す
rescue StringScanner::Error
  # Ignored
end
```

トークンを押し戻す。@@codeのスキャナーのポインタを前回のスキャン位置に戻す。パーザー(群)から呼び出される。

