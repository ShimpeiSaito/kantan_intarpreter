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
    '真' => true,
    '偽' => false
  }

  @@space = {}

  def initialize
    @scanner = StringScanner.new(ARGV[0])
    puts eval(parse) # 意味解析（計算）
  rescue StandardError => e
    puts e.message.to_s
    exit
  end

  # 意味解析
  def eval(exp)
    if exp.instance_of?(Array)
      case exp[0]
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
      when :variable
        exp[1]
      when :integer
        exp[1]
      when :boolean
        exp[1]
      when :string
        exp[1]
      else
        raise SyntaxError, 'Error: SyntaxError'
      end
    else
      exp
    end
  end

  # パーサー
  def parse
    sentences
  end

  def sentences()
    unless s = sentence()
      raise Exception, “あるべき文が見つからない”
    end
    result = [:block, s]
    while s = sentence()
      result << s
    end
    result
  end

  # Expr -> Term (('+'|'-') Term)*
  def expression
    result = term
    token = get_token
    while (token == :add) || (token == :sub)
      result = [token, result, term]
      token = get_token
      p result
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
        p result
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
    when :lpar
      result = expression
      t = get_token # 閉じカッコを取り除く(使用しない)
      raise SyntaxError, 'Error: SyntaxError' unless t == :rpar
    else
      raise SyntaxError, 'Error: SyntaxError'
    end
    result
  end

  # tokenを取得
  def get_token
    token = @scanner.scan(%r{([+\-*/()])})
    return @@keywords[token] if token

    token = @scanner.scan(/([0-9]+)/)
    token.to_i
  end

  # tokenを押し戻す
  def unget_token
    @scanner.unscan
  rescue StringScanner::Error
    # Ignored
  end
end

Kantan.new
