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
    '了' => :end,
    '始' => :block_start,
    '終' => :block_end,
    '如' => :if,
    '則' => :then,
    '異' => :else,
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
      when :greater
        eval(exp[1]) > eval(exp[2])
      when :less
        eval(exp[1]) < eval(exp[2])
      when :equal
        eval(exp[1]) == eval(exp[2])
      when :assignment
        @@space[exp[1]] = eval(exp[2])
        # p @@space
      when :print
        val = eval(exp[1])
        puts val
      when :if
        judge = case exp[1]
                when true
                  true
                when false
                  false
                else
                  eval(exp[1])
                end

        if judge
          eval(exp[2])
        else
          eval(exp[3]) unless exp[3].nil?
        end
      when :loop
        judge = case exp[1]
                when true
                  true
                when false
                  false
                else
                  eval(exp[1])
                end
        while judge
          eval(exp[2])
          judge = case exp[1]
                  when true
                    true
                  when false
                    false
                  else
                    eval(exp[1])
                  end
          # break
        end
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
      return @@space[exp] if @@space.key?(exp)

      exp
    end
  end

  # パーサー
  def parse
    pp sentences
  end

  def sentences
    unless (s = sentence)
      raise Exception, 'あるべき文が見つからない'
    end

    result = if s.empty?
               [:block]
             else
               [:block, s]
             end

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
      return loop
    when :print
      return print
    when :block_start
      return ''
    when :block_end
      return nil
    when :end
      return sentence
    else
      unget_token
      return assignment
    end
  end

  def loop
    con_exp = comparison_operation
    token = get_token
    block = sentences if token == :loop_start

    get_token # :endの削除

    return [:loop, con_exp, block]
  end

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

    return [:if, con_exp, true_block, false_block]
  end

  def assignment
    var = get_token
    # p var
    raise Exception, '変数名が正しくない' unless var.instance_of?(String)

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
      get_token # "」"の削除
    else
      unget_token
      val = expression
    end
    @@variables[var] = val
    get_token # :endの削除

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
      get_token # "」"の削除
    when :bad_token
      p 'きゃー！！！！'
    else
      unget_token
      val = expression
    end
    get_token # :endの削除
    return [:print, val]
  end

  def comparison_operation
    result = expression
    token = get_token

    while (token == :greater) || (token == :less) || (token == :equal)
      result = [token, result, expression]
      token = get_token
      # p result
    end
    unget_token
    result
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

  # Fctr -> '(' Expr ')' | Num
  def factor
    token = get_token

    return token if @@variables.key?(token)

    case token
    when Numeric
      result = token
    when :lpar
      result = expression
      t = get_token # 閉じカッコを取り除く(使用しない)
      raise SyntaxError, 'Error: SyntaxError' unless t == :rpar
    when :true
      result = true
    when :false
      result = false
    else
      # p token
      raise SyntaxError, 'Error: SyntaxError1'
    end
    result
  end

  # tokenを取得
  def get_token
    token = @scanner.scan(/\A\s*(-?\d+)/)
    # p token
    return token.strip.to_i if token

    # p @@keywords.keys.map{|t|t}
    token = @scanner.scan(/\A\s*(#{@@keywords.keys.map { |t| t }})/)
    return @@keywords[token.strip] if token && (@@keywords[token.strip])

    token = @scanner.scan(/\A\s*([a-zA-Z]|\p{Hiragana}|\p{Katakana}|[ー－]|[一-龠々])([a-zA-Z]|[0-9]|_|\p{Hiragana}|\p{Katakana}|[ー－]|[一-龠々])*/)
    # p token
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
