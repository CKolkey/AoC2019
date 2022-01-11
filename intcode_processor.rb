# frozen_string_literal: true

# Set of opcodes for IntcodeProcessor. Functions can be overloaded via hash provided to constructor
class Opcodes
  DEFAULTS = {
    1 => ->(a, b, c) { write!(c, value(a, 0) + value(b, 1)) and next! },            # write sum of a + b to c
    2 => ->(a, b, c) { write!(c, value(a, 0) * value(b, 1)) and next! },            # write product of a * b to c
    3 => ->(a)       { print('Input > ') or write!(a, gets.chomp.to_i) and next! }, # get and write user input
    4 => ->(a)       { puts("Output: #{value(a, 0)}") or next! },                   # print value to stdout
    5 => ->(a, b)    { !value(a, 0).zero? ? jump!(value(b, 1)) : next! },           # jump if true (non-zero)
    6 => ->(a, b)    { value(a, 0).zero? ? jump!(value(b, 1)) : next! },            # jump if false (zero)
    7 => ->(a, b, c) { write!(c, (value(a, 0) < value(b, 1) ? 1 : 0)) and next! },  # less than
    8 => ->(a, b, c) { write!(c, (value(a, 0) == value(b, 1) ? 1 : 0)) and next! }, # check equality
    99 => ->         { halt! }                                                      # halt
  }.freeze

  def initialize(overloads = {})
    @opcodes = DEFAULTS.merge(overloads)
  end

  def overload_fn(opcode, func)
    @opcodes[opcode] = func
  end

  def fn(opcode)
    @opcodes[opcode]
  end
end

class IntcodeProcessor
  attr_reader :program, :pointer, :opcodes

  def initialize(program, opcodes = Opcodes.new)
    @program = program.split(',').map(&:to_i)
    @opcodes = opcodes
    @pointer = 0
    @state   = :uninitialized
  end

  def run!
    @state = :running

    until halted? || suspended?
      @function = opcodes.fn(opcode)
      @params   = read((pointer + 1)..(pointer + @function.arity))

      instance_exec(*@params, &@function)
    end

    self
  end

  def result = read(0)

  def read_last = read(-1)

  def halted? = @state == :halted

  def suspended? = @state == :suspended

  def running? = @state == :running

  def uninitialized? = @state == :uninitialized

  private

  def opcode
    instruction.digits[..1].reverse.join.to_i
  end

  def value(param, position)
    case p_mode(position)
    when 0 then read(param)
    when 1 then param
    end
  end

  def p_mode(position)
    (instruction.digits[2..] || []).slice(position) || 0
  end

  def instruction
    read pointer
  end

  def halt! = @state = :halted

  def suspend! = @state = :suspended

  def read(...)
    @program.slice(...)
  end

  def write!(address, value)
    @program[address] = value
  end

  def next!
    jump!(@pointer + @params.size + 1)
  end

  def jump!(address)
    @pointer = address
  end
end

if ARGV.delete('--test')
  def test(input, result: nil, state: nil, opcodes: Opcodes.new)
    process = IntcodeProcessor.new(input, opcodes).run!

    if result
      if process.result == result
        puts 'Good'
      else
        puts "FAILED! Expected: #{expected}, Actual: #{process.result}"
      end
    end

    if state
      if process.program == state
        puts 'Good'
      else
        puts 'FAILED STATE!'
        print 'Expected: '
        p state
        print 'Actual:   '
        p process.program
      end
    end
  end

  opcode_overload_a = Opcodes.new({ 3 => ->(a) { (puts 'Input > 1' or write! a, 1) and next! } })
  test File.read('5.input'), opcodes: opcode_overload_a # input 1 -> all 0's & 6745903

  opcode_overload_b = Opcodes.new({ 3 => ->(a) { (puts 'Input > 5' or write! a, 5) and next! } })
  test File.read('5.input'), opcodes: opcode_overload_b # input 5 -> 9168267

end
