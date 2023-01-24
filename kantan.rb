require 'strscan'
require 'pp'

class Kantan
  # 演算記号表
  @@keywords = {
    '+' => :add,
    '-' => :sub,
    '*' => :mul,
    '/' => :div,
    '(' => :lpar,
    ')' => :rpar,
    '真' => :true,
    '偽' => :false,
    '入' => :assign,
    '了' => :end,
    '始' => :block_start,
    '終' => :block_end,
    '如' => :if,
    '循' => :loop,
    '開' => :loop_start,
    '刷' => :print,
    '「' => :string_start,
    '」' => :string_end,
    '能' => :function,
    '引' => :argument_start,
    '区' => :separator,
    '数' => :argument_end
  }

  @@space = {}

  @@code = '' # 入力されたソースコードを格納

  @@variables = {}

  def initialize
    file = ARGV[0]
    lines = []
    unless file.nil?
      File.foreach(file) do |line|
        lines.push(line)
      end
      @@code = lines.join
    end

    @scanner = StringScanner.new(@@code)

    puts @@code

    eval(parse) # 意味解析（計算）
  rescue StandardError => e
    puts e.message.to_s
    exit
  end

  # 意味解析
  def eval(exp)
    if exp.instance_of?(Array)
      # p exp[0]
      case exp[0]
      when :block
        exp.each do |e|
          eval(e)
        end
      when :add
        eval(exp[1]) + eval(exp[2])
      when :sub
        eval(exp[1]) - eval(exp[2])
      when :mul
        eval(exp[1]) * eval(exp[2])
      when :div
        eval(exp[1]) / eval(exp[2])
      when :assignment
        @@space[eval(exp[1])] = eval(exp[2])
        # p @@space
      when :print
        val = eval(exp[1])
        puts val
      when :boolean
        exp[1]
      when :string
        exp[1]
      when :true
        true
      when :false
        false
      else
        raise SyntaxError, 'Error: SyntaxError'
      end
    else
      exp
    end
  end

  # パーサー
  def parse
    p sentences
  end

  def sentences
    unless (s = sentence)
      raise Exception, 'あるべき文が見つからない'
    end

    result = [:block, s]
    while (s = sentence)
      result << s
    end
    result
  end

  def sentence
    token = get_token
    return if token == :bad_token

    # p token
    case token
    when :if
      return conditionals
    when :loop
      return 0
    when :print
      return print
    when :block_start
      return 0
    when :end
      return sentence
    else
      unget_token
      return assignment
    end
  end

  def conditionals
    con_exp = get_token
    true_block = get_token
    false_block = get_token
    # 条件式の左辺、比較演算子、条件式の右辺。ブロック
    return [:if, con_exp, true_block, false_block]
  end

  def assignment
    var = get_token
    # p var
    raise Exception, '変数が正しくない' unless var.instance_of?(String)

    token = get_token
    raise Exception, '入がない' unless token == :assign

    token = get_token
    case token
    when :true
      val = true
    when :false
      val = false
    when :string_start
      val = get_token
      get_token
    else
      unget_token
      val = expression
    end
    @@variables[var] = val
    return [:assignment, var, val]
  end

  def print
    token = get_token
    case token
    when :true
      val = true
    when :false
      val = false
    when :string_start
      val = get_token
      get_token
    when :bad_token
      p 'きゃー！！！！'
    else
      val = expression
    end
    return [:print, val]
  end

  # Expr -> Term (('+'|'-') Term)*
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

  # Term -> Fctr (('*'|'/') Fctr)*
  def term
    begin
      result = factor
      token = get_token
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

  # Fctr -> '(' Expr ')' | Num
  def factor
    token = get_token
    if @@variables.key?(token)
      return @@variables[token]
    end

    case token
    when Numeric
      result = token
    when :lpar
      result = expression
      t = get_token # 閉じカッコを取り除く(使用しない)
      raise SyntaxError, 'Error: SyntaxError' unless t == :rpar
    else
      pp @@variables
      raise SyntaxError, 'Error: SyntaxError1'
    end
    result
  end

  # tokenを取得
  def get_token
    token = @scanner.scan(/\A\s*(-?\d+)/)
    # p token
    return token.strip.to_i if token

    token = @scanner.scan(/\A\s*(#{@@keywords.keys.map{|t|t}})/)
    # p token
    return @@keywords[token.strip] if token

    token = @scanner.scan(/\A\s*([a-zA-Z]|\p{Hiragana}|\p{Katakana}|[ー－]|[一-龠々])([a-zA-Z]|[0-9]|_|\p{Hiragana}|\p{Katakana}|[ー－]|[一-龠々])*/)
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
