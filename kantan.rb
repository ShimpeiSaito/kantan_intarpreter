require 'strscan'

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
    '刷' => :print,
    '「' => :string_start,
    '」' => :string_end,
    '能' => :function,
    '引' => :argument_start,
    '区' => :separator,
    '数' => :argument_end
  }

  @@space = {}

  @@code = "" #入力されたソースコードを格納

  @@variable = ''

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
        val = exp[1]
        if exp[1].nil?
          val = @@space[@@variable]
        end
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
      raise Exception, "あるべき文が見つからない"
    end
    result = [:block, s]
    while (s = sentence)
      result << s
    end
    result
  end

  def sentence
    token = get_token
    # p token
    case token
    when :if
      return 0
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

  def assignment
    var = get_token
    token = get_token
    if token == :assign
      token = get_token
      if token == :true
        val = true
      elsif token == :false
        val = false
      elsif token == :string_start
        val = get_token
        get_token
      else
        unget_token
        val = expression
      end
      return [:assignment, var, val]
    end
  end

  def print
      token = get_token
      if token == :true
        val = true
      elsif token == :false
        val = false
      elsif token == :string_start
        val = get_token
        get_token
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
    case token
    when Numeric
      result = token
    when /\A[a-zA-Z]([a-zA-Z]|[0-9]|_)*/
      @@variable = token
    when :lpar
      result = expression
      t = get_token # 閉じカッコを取り除く(使用しない)
      raise SyntaxError, 'Error: SyntaxError' unless t == :rpar
    else
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

    token = @scanner.scan(/\A\s*[a-zA-Z]([a-zA-Z]|[0-9]|_)*/)
    return token.strip if token
  end

  # tokenを押し戻す
  def unget_token
    @scanner.unscan
  rescue StringScanner::Error
    # Ignored
  end
end

Kantan.new
