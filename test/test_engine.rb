require "helper"

class TestEngine < Struggle::Test

  include Instructions

  def test_basic_arbitrator_execution
    arbitrator = MoveAcceptor.new
    move = EmptyMove.new

    e = Engine.new
    e.work_items.push arbitrator

    e.accept move

    assert arbitrator.complete?, "Provided move should satisfy the arbitrator"
    assert move.executed?, "Move should be executed after approval"

    refute e.hint, "Should be nothing left to accept"
    # assert no more requirements
    # assert history has been filled
  end

  def test_instructions_execute_automatically
    instruction = EmptyInstruction.new
    arbitrator1 = MoveAcceptor.new
    arbitrator2 = MoveAcceptor.new

    move1 = EmptyMove.new
    move2 = EmptyMove.new

    e = Engine.new
    e.work_items.push arbitrator1, instruction, arbitrator2

    e.accept move1

    assert arbitrator1.complete?, "Should be satisfied by provided move"
    assert instruction.complete?, "Instruction should execute automatically"
    refute arbitrator2.complete?, "Second arbitrator should not be called yet"
    assert move1.executed?,       "Should be executed by first arbitrator"

    e.accept move2

    assert arbitrator2.complete?, "Second arbitrator should accept second move"
    assert move2.executed?, "Should be executed by second arbitrator"

    refute e.hint, "Should be nothing left to accept"
  end

  def test_nested_executables_execute_automatically
    instructions = []

    instruction1 = LambdaInstruction.new { instructions << "ex1" }
    instruction2 = LambdaInstruction.new { instructions << "ex2" }
    nested_instr = NestingInstruction.new(instruction1, instruction2)

    arbitrator = MoveAcceptor.new

    move = EmptyMove.new

    e = Engine.new
    e.work_items.push arbitrator, nested_instr

    e.accept move

    assert move.executed?, "Should be executed by arbitrator"

    assert arbitrator.complete?, "Should be satisfied by move provided"
    assert instruction1.complete?, "Should execute automatically"
    assert instruction2.complete?, "Should execute automatically"
    assert nested_instr.complete?, "Should be satifisfied by children"

    assert_equal %w(ex1 ex2), instructions, "Instructions should be in order"

    refute e.hint, "Should be nothing left to accept"
  end

  def test_game_hint_progresses_execution
    instruction = EmptyInstruction.new

    e = Engine.new
    e.work_items.push instruction

    refute e.hint, "Should be nothing left to accept"

    assert instruction.complete?, "Should execute automatically"

    refute e.hint, "Should be nothing left to accept"
  end

  ### MODIFIERS

  def test_permission_modifier_denies_move
    arbitrator = MoveAcceptor.new
    move = EmptyMove.new

    e = Engine.new
    e.add_permission_modifier NegativePermissionModifier.new

    e.work_items.push arbitrator

    e.accept move

    assert arbitrator.accepts?(move), "Expectation should still accept move"

    refute arbitrator.complete?, "arbitrator should not be satisfied"
    refute move.executed?, "Move should not be executed"

    assert_equal arbitrator, e.hint,
      "arbitrator should still be waiting for a move allowed by modifiers"
  end

  # Engine stack, with one stack modifier:
  #
  # [orig-arb]
  #
  # Upon move, the modifier fires and the stack becomes
  #
  # [new-instr, new-arb, orig-arb]
  #
  # This game will now need one extra move to empty the stack.
  #
  def test_stack_modifier_adds_items_to_stack
    orig_arbitrator = MoveAcceptor.new
    orig_move = EmptyMove.new

    new_instruction = EmptyInstruction.new
    new_arbitrator = MoveAcceptor.new

    mod = StackModifier.new(new_instruction, new_arbitrator)

    new_move = EmptyMove.new

    e = Engine.new
    e.add_stack_modifier mod
    e.work_items.push orig_arbitrator

    e.accept orig_move

    refute orig_arbitrator.complete?,
      "Original arbitrator should not be complete"

    refute orig_move.executed?,
      "Original move should not be executed"

    assert_equal new_instruction, e.work_items.peek,
      "Newly inserted instruction should be top of stack"

    e.accept new_move

    assert new_instruction.complete?, "New instruction should be complete"
    assert new_arbitrator.complete?, "New move should complete new arbitrator"
    assert new_move.executed?, "New move should be executed"

    assert orig_arbitrator.complete?, "Original arb should be complete"
    assert orig_move.executed?, "Original move should be executed"

    refute e.hint, "Should be nothing left in stack"
  end

  def xtest_modifier_lifecycle
  end

  # This test makes use of an unrealistic/naive way of managing score.
  # ScoreModifiers should probably be stored with and modify a centralized
  # ScoreResolver component.
  def xtest_score_modification
    arbitrator = MoveAcceptor.new
    arbitrator.derp

    move = AmountMove.new
    move.amount = 2

    e = Engine.new
    e.add_score_modifier NegativeScoreModifier.new
    e.add_expectations exp

    e.accept move

    assert exp.satisfied?
    assert move.executed?

    assert_equal 1, move.amount, "Amount should be reduced by modifier"
  end

  def xtest_score_modification_making_move_invalid
    exp = AmountMoveExpectation.new
    exp.amount = 2

    move = AmountMove.new
    move.amount = 2

    e = Engine.new
    e.add_score_modifier NegativeScoreModifier.new
    e.add_expectations exp

    e.accept move

    refute exp.allows?(move), "Move should now have an unacceptable amount"
    refute exp.satisfied?, "Expecation should not be satisified"
    refute move.executed?, "Modified move should not be executed"

    assert_equal 1, move.amount, "Amount should be reduced by modifier"
  end

  #  class Requirement
  #    def satisfied?() raise "notimpl" end
  #  end

  #  class MoveArbitrator < Requirement
  #    def initialize; @satisfied = false; @moves = [] end
  #    def allows?(move) true end
  #    def update(move) @updated = true end
  #    def satisfied?() @updated end
  #    def unsatisfied?() !satisfied? end
  #    def stash(move); @moves << move; end
  #    def moves() @moves; end
  #    def unexecuted_moves; @moves.select { |m| !m.executed? }; end
  #    def unexecuted_moves?; @moves.any? { |m| !m.executed? }; end
  #  end

  #  AcceptingMoveArbitrator = MoveArbitrator

  #  class AmountArbitrator < MoveArbitrator
  #    attr_accessor :amount

  #    def allows?(move)
  #      move.amount >= amount
  #    end
  #  end

  #  class SimpleTask
  #    def execute() @executed = true end
  #    def executed?() @executed end
  #  end

  #  class NegativePermissionModifier
  #    def allows?(move) false end
  #  end

  #  class NegativeScoreModifier
  #    def modify(move)
  #      move.amount -= 1
  #    end
  #  end

  #  class NewExpectationModifier
  #    def initialize(exp)
  #      @exp = exp
  #      @new_expectations = []
  #    end

  #    def notify(event, move)
  #      if event == :on && SimpleTask === move
  #        # convoluted example...
  #        @new_expectations << @exp
  #      end
  #    end

  #    def new_expectations
  #      @new_expectations
  #    end
  #  end

  #  class AmountMove < SimpleTask
  #    attr_accessor :amount
  #  end

  #  class EitherExpectation < MoveArbitrator

  #    def initialize(moves)
  #      @moved = false
  #      @moves = []
  #    end

  #    def allows?(move)
  #      @moves.include?(move)
  #    end

  #    def update(move)
  #      @moved = true
  #    end

  #    def satisfied?
  #      @moved
  #    end
  #  end

  #  # Evaluators return a list of expectations based on cond

  #  class IfEvaluator < Evaluator
  #    def initialize(cond, cond_true, cond_false)
  #    end

  #    def execute
  #    end
  #  end

end
