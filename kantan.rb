require 'strscan'
require 'pp'

class Kantan
  # 予約語表
  @@keywords = {
    '+' => :add,
    '-' => :sub,
    '*' => :mul,
    '/' => :div,
    '>' => :greater,
    '<' => :less,
    '=' => :equal,
    '(' => :lpar,
    ')' => :rpar,
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
    '「' => :string_start,
    '」' => :string_end,
    '能' => :function,
    '呼' => :call_function,
    '引' => :argument_start,
    '区' => :separator,
    '数' => :argument_end
  }

  @@code = '' # 入力されたソースコードの格納場所

  @@space = {} # グローバル変数及び関数ごとのローカル変数の格納場所

  @@functions = {} # 関数のブロック(中身)の格納場所

  @@func_names = [] # 実行中の関数名の格納場所

  def initialize
    # 実行ファイルの読み取り
    file = ARGV[0]
    lines = []
    unless file.nil?
      File.foreach(file) do |line|
        lines.push(line)
      end
      @@code = lines.join
    end
    # puts @@code # 確認用

    @scanner = StringScanner.new(@@code) # スキャナーインスタンスの生成

    eval(parse) # 意味解析
  rescue StandardError => e
    # TODO: ちゃんとしたエラーハンドリング
    puts e.message.to_s
    exit
  end

  # 意味解析
  def eval(exp)
    if exp.instance_of?(Array)
      case exp[0]
      when :block
        exp.each do |e|
          eval(e)
        end
      when :add # 加算
        eval(exp[1]) + eval(exp[2])
      when :sub # 減算
        eval(exp[1]) - eval(exp[2])
      when :mul # 乗算
        eval(exp[1]) * eval(exp[2])
      when :div # 除算
        eval(exp[1]) / eval(exp[2])
      when :greater # 大なり
        eval(exp[1]) > eval(exp[2])
      when :less # 小なり
        eval(exp[1]) < eval(exp[2])
      when :equal # イコール
        eval(exp[1]) == eval(exp[2])
      when :assignment # 変数への代入
        return @@space[@func_name][exp[1]] = eval(exp[2]) unless @@space[@func_name].nil? # 関数ないならローカル変数とする

        @@space[exp[1]] = eval(exp[2]) # グローバル変数へ代入
      when :global_assignment # グローバル変数への代入
        @@space[exp[1]] = eval(exp[2])
      when :print # 標準出力
        # 区切り文字で複数個並んでいる場合は結合して出力
        result = []
        exp[1].each do |e|
          result << eval(e).to_s.gsub(/改~/, "\n").gsub(/空~/, ' ')
        end
        result = result.join('')
        print result
      when :read # 標準入力
        $stdin.gets.chomp
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
        @@space[exp[1]] = exp[2] # 引数の変数名を格納
        @@functions[exp[1]] = exp[3] # 関数ないの処理(ブロック)を格納
      when :call_function # 関数呼び出し
        @func_name = exp[1] # 実行する関数名を格納
        raise SyntaxError, 'Error: Different number of arguments' if @@space[@func_name].length != exp[2].length # 定義した引数の数と合わない場合はエラー

        # 関数内で他の関数を呼び出した場合の対処
        # 呼び出し元の関数のローカル変数の中で、呼び出し先の関数の引数に設定されているものがあれば、呼び出し元の関数の変数と値を追加or上書きする
        merged_keys = [] # 追加した変数のキーの格納場所
        if @@func_names.length.positive? # 関数内で呼び出されているか
          @@space[@@func_names.last].each do |h| # 呼び出し元の変数表を参照
            if exp[2].include?(h[0]) # 現在の関数の引数に呼び出し元の変数が使われているか
              @@space[@func_name].merge!(Hash[*h]) # 追加または書き換え
              merged_keys << h[0] # 追加または書き換えた変数のキーを格納
            end
          end
        end
        @@func_names << exp[1] # 現在の関数名を格納

        # 引数に指定された値の格納と余分な呼び出し元のローカル変数の削除
        @@space[@func_name].each_with_index do |h, i|
          @@space[@func_name][h[0]] = eval(exp[2][i]) unless exp[2][i].nil? # 指定された引数を現在の関数のローカル変数として格納
          @@space[@func_name].delete_if { |key, _| merged_keys.include?(key) } if exp[2][i].nil? # 呼び出し元の変数のうち、引数の値としてのみ使われている変数を削除（同じローカル変数名だったら消さない）
        end

        eval(@@functions[@func_name]) # 関数の中身(ブロック)の実行

        @@func_names.pop # 実行が終わったら、@@func_namesから削除
        @func_name = @@func_names.last # @func_nameを呼び出し元の関数名に戻す（呼び出し元がなければnil）
      when :string # 文字列
        exp[1] # 文字列なら値だけを返す
      when :true # 真偽値(真)
        true # trueを返す
      when :false # 真偽値(偽)
        false # falseを返す
      else
        # TODO: ちゃんとしたエラーハンドリング
        raise SyntaxError, 'Error: SyntaxError'
      end
    else
      return @@space[@func_name][exp] if !@@space[@func_name].nil? && @@space[@func_name].key?(exp) # ローカル変数があれば、その関数のローカル変数での値を返す
      return @@space[exp] if @@space.key?(exp) # グローバル変数の値を返す

      # TODO: ちゃんとしたエラーハンドリング
      raise SyntaxError, 'Error: Variable is not defined' if exp.is_a?(String) # 数値以外ならエラー（変数以外の文字列ならエラー）

      exp # 数値はそのまま返す
    end
  end

  # パーサー
  def parse
    pp sentences
  end

  # 文列の要素を一つの配列として返す
  # 文列 = 文 (文)*
  def sentences
    unless (s = sentence)
      # TODO: ちゃんとしたエラーハンドリング
      raise Exception, 'あるべき文が見つからない'
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
  end

  # 文を配列として返す
  # 文 = 入文 | 世入文 | 如文 | 循文 | 刷文 | 読文 | 塊文
  def sentence
    token = get_token
    return if token == :bad_token # TODO: ちゃんとしたエラーハンドリング

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
  end

  # 如文(if文)
  # 如文 = '如' 式 '則' 文 '異' 文 '了'
  def conditionals
    con_exp = comparison_operation
    token = get_token
    true_block = sentences if token == :then

    token = get_token
    if token == :else
      false_block = sentences
    else
      unget_token
    end
    get_token # :endの削除

    [:if, con_exp, true_block, false_block]
  end

  # 循文(loop文)
  # 循文 = '循' 式 '開' 文 '了'
  def repetition
    con_exp = comparison_operation
    token = get_token
    block = sentences if token == :loop_start

    get_token # :endの削除

    [:loop, con_exp, block]
  end

  # 刷文(print文)
  # 刷文 = '刷' ((式 | 文字列 | 真偽値 | 読文) '区')* (式 | 文字列 | 真偽値 | 読文) '了'
  def printing
    val = []
    while true do
      token = get_token
      case token
      when :string_start
        val << [:string, get_token]
        get_token # "」"の削除
      when :read
        val << [:read]
      else
        unget_token
        val << expression
      end

      token = get_token
      next if token == :separator
      break if token == :end

      raise SyntaxError
    end

    [:print, val]
  end

  # 関数定義
  # 関数定義 = '能' 関数 '引' (変数'区')* 変数 '数' '始' 文列  '終'
  def function
    func_name = get_token

    raise Exception, '関数名が正しくない' unless func_name.instance_of?(String)

    token = get_token
    raise Exception, '引がない' unless token == :argument_start

    private_variables = {}

    token = get_token
    while token != :argument_end
      private_variables[token] = nil unless token == :separator
      token = get_token
    end

    token = get_token
    if token == :block_start
      unget_token
      block = sentences
    end

    [:function, func_name, private_variables, block]
  end

  # 関数呼出
  # 関数呼出 = '呼' 関数 '引' (式 | 文字列 | 真偽値)'区')* (式 | 文字列 | 真偽値) '数' '了'
  def call_function
    func_name = get_token

    token = get_token
    raise Exception, '引がない' unless token == :argument_start

    private_variables = []

    token = get_token
    while token != :argument_end
      unless token == :separator
        unget_token
        private_variables << expression
      end
      token = get_token
    end

    get_token # :endの削除

    [:call_function, func_name, private_variables]
  end

  # 入文(代入文)
  # 入文 = 変数 '入' (式 | 文字列 | 真偽値 | 読文) '了'
  def assignment
    var = get_token
    raise Exception, '変数名が正しくない' unless var.instance_of?(String)

    token = get_token
    raise Exception, '入がない' unless token == :assign

    token = get_token
    case token
    when :string_start
      val = [:string, get_token]
      get_token # "」"の削除
    when :read
      val = [:read]
    else
      unget_token
      val = expression
    end
    get_token # :endの削除

    [:assignment, var, val]
  end

  # 世入文(明示的なグローバル変数への代入文)
  # 世入文 = '世' 変数 '入' (式 | 文字列 | 真偽値 | 読文) '了'
  def global_assignment
    result = assignment
    result[0] = :global_assignment
    result
  end

  # 比較式
  # 比較式 = 式 ('>'|'<'|'=') 式
  def comparison_operation
    exp = expression
    token = get_token
    raise SyntaxError unless (token == :greater) || (token == :less) || (token == :equal)

    [token, exp, expression]
  end

  # 式
  # 式 = 項 (('\+'|'-') 項)*
  def expression
    result = term
    token = get_token

    while (token == :add) || (token == :sub)
      result = [token, result, term]
      token = get_token
      # p result
    end
    unget_token
    result
  end

  # 項
  # 項 = 因子 (('\*'|'/') 因子)*
  def term
    begin
      result = factor
      token = get_token
      # p token
      while (token == :mul) || (token == :div)
        result = [token, result, factor]
        token = get_token
        # p result
      end
    rescue SyntaxError => e
      puts e.message.to_s
      exit
    end
    unget_token
    result
  end

  # 因子
  # 因子 = 数値リテラル | 変数 | 真偽値 | '(' 式 ')'
  def factor
    token = get_token

    case token
    when String
      token
    when Numeric
      token
    when :true
      token
    when :false
      token
    when :lpar
      result = expression
      t = get_token # 閉じカッコを取り除く(使用しない)
      raise SyntaxError, 'Error: SyntaxError' unless t == :rpar

      result
    else
      raise SyntaxError, 'Error: SyntaxError1'
    end
  end

  # tokenを取得する
  def get_token
    token = @scanner.scan(/\A\s*(-?\d+)/)
    return token.strip.to_i if token

    token = @scanner.scan(/\A\s*(#{@@keywords.keys.map { |t| t }})\s+/)
    return @@keywords[token.strip] if token && (@@keywords[token.strip])

    token = @scanner.scan(/\A\s*([a-zA-Z]|\p{Hiragana}|\p{Katakana}|[ー－]|[一-龠々])([a-zA-Z]|[0-9]|_|\p{Hiragana}|\p{Katakana}|[ー－]|[一-龠々]|~)*/)
    return token.strip if token

    :bad_token
  end

  # tokenを押し戻す
  def unget_token
    @scanner.unscan
  rescue StringScanner::Error
    # Ignored
  end
end

Kantan.new
