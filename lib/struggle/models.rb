## EXAMPLE MODELS

### Moves

class Move
  attr_accessor :player, :instruction

  def initialize(player: nil, instruction: nil)
    self.player = player
    self.instruction = instruction
  end

  def execute
    instruction.execute
  end

  def executed?
    noimpl
  end
end


### Misc

def noimpl() raise("%s Not Implemented" % [caller_locations.first.to_s]) end

### WorkItem

class WorkItem
  extend Injectible
  extend Arguments

  def initialize(**args)
    @complete = false

    ap = ArgumentProvider.new(self)
    ap.provide(args)

    after_init
  end

  def after_init
  end

  def complete?() @complete end
  def incomplete?() !complete?() end

  private

  def complete
    @complete = true
  end
end


### Instructions

module Instructions
  class Instruction < WorkItem
    def execute
      returning action do
        complete
      end
    end

    def action
      noimpl
    end

    ##
    # Returns +obj+ after calling +block+.
    #
    def returning(obj, &block)
      obj.tap(&block)
    end

    def inspect
      args = self.class.arguments.map do |a|
        "%s: %s" % [a, send(a).inspect]
      end

      "%s(%s)" % [self.class.name.sub(/^Instructions/, "I"), args.join(", ")]
    end
  end

  # Used for testing.
  class EmptyInstruction < Instruction
    def action
    end
  end

  # Used for testing.
  class LambdaInstruction < Instruction
    def initialize(*, &block)
      @block = block
    end

    def action
      @block.call
    end
  end

  class NestingInstruction < Instruction
    def initialize(*instructions)
      unless instructions.all? { |i| WorkItem === i }
        bad = instructions.reject { |i| i.is_a? WorkItem }
        raise "Bad list items: #{bad.inspect}"
      end

      @instructions = instructions
    end

    def action
      @instructions
    end
  end

  class AwardVictoryPoints < Instruction
    arguments :player, :amount

    needs :victory_point_track

    def action
      victory_point_track.award(player, amount)
    end
  end

  ##
  # Adds influence markers to a country, no questions asked.
  #
  # +Amount+ refers to the number of markers to be placed, not the amount
  # of points to be spent.
  #
  # Requires the Countries registry.
  #
  class AddInfluence < Instruction
    arguments :influence, :amount, :country_name

    needs :countries

    def action
      countries.find(country_name).add_influence(influence, amount)
    end
  end

  class AddToDeck < Instruction
    arguments :phase

    needs :cards, :deck

    def action
      deck.add(cards.select { |c| c.phase == phase && !c.china_card? })
    end
  end

  class ClaimChinaCard < Instruction
    arguments :player, :playable

    needs :china_card

    def action
      china_card.holder = player
      china_card.playable = playable
    end
  end

  class SurrenderChinaCard < Instruction
    needs :china_card

    def action
      china_card.holder = china_card.holder.opponent
      china_card.playable = false
    end
  end

  class SetPhasingPlayer < Instruction
    arguments :player

    needs :phasing_player

    def action
      phasing_player.player = player
    end
  end

  class ImproveDefcon < Instruction
    needs :defcon

    def action
      defcon.improve(1)
    end
  end

  ##
  # Deals cards from the deck. If there are no more cards in the deck,
  # the +discard+ pile is transferred into the deck.
  #
  class DealCards < Instruction
    arguments :target

    needs :deck, :hands, :discards

    def action
      satisfied = { US => false, USSR => false }

      until satisfied.values.all? do
        [USSR, US].each do |player|
          if hands.get(player).size < target
            if deck.empty?
              deck.add discards
              discards.clear
            end

            hands.add(player, deck.draw)
          else
            satisfied[player] = true
          end
        end
      end
    end
  end

  class FlipChinaCard < Instruction
    needs :china_card

    def action
      china_card.flip_up
    end
  end

  class AdvanceTurn < Instruction
    needs :turn

    def action
      turn.advance
    end
  end

  class CheckHeldCards < Instruction
    needs :hands

    def action
      # Order is important here -- if both players are holding scoring cards
      # then USSR loses.

      return winner(US)   if hands.get(USSR).any?(&:scoring?)
      return winner(USSR) if hands.get(US).any?(&:scoring?)
    end

    def winner(player)
      [DeclareWinner.new(player: player), EndGame.new]
    end
  end

  class CheckMilitaryOps < Instruction
    needs :military_ops, :defcon

    def action
      result = military_ops.calculate_vp(defcon)

      if result.vp > 0
        return AwardVictoryPoints(player: result.player, amount: result.vp)
      end
    end
  end

  class ResetMilitaryOps < Instruction
    needs :military_ops

    def action
      military_ops.reset
    end
  end

  class DeclareWinner < Instruction
    arguments :player

    needs :victory

    def action
      victory.winner = player
    end
  end

  class FinalScoring < Instruction

    def action
    end
  end

  class EndGame < Instruction
    needs :victory

    # Set game.over = true. Winner should be set by another instruction. if
    # not set, then winner will be nil and a draw is assumed.
    def action
      puts "GAME OVER: Winner #{victory}"
    end
  end

  ##
  # Encapsulates playing a card. Returns the appropriate
  # instructions/arbitrators for the selected card action.
  #
  class PlayCard < Instruction
    arguments :player, :card_ref, :card_action

    VALID_CARD_ACTIONS = %i(event influence coup realignment space)

    def after_init
      unless VALID_CARD_ACTIONS.include?(card_action)
        raise "bad card_action #{card_action.inspect}"
      end
    end

    def action
      remove_from_hand = Instructions::RemoveCardFromHand.new(
        player: player, card_ref: card_ref
      )

      add_to_current_cards = Instructions::AddCurrentCard.new(
        card_ref: card_ref
      )

      action_instructions = send card_action

      [remove_from_hand, add_to_current_cards, *action_instructions]
    end

    # TODO lookup event instruction list
    def event
      Noop.new
    end

    def influence
      Arbitrators::AddRestrictedInfluence.new(
        player: player,
        influence: player,
        operation_points: ops #TODO determine card ops
      )
    end

    #TODO all of the below

    def coup
      Arbitrators::Coup.new
    end

    def realignment
      Arbitrators::RealignmentRoll.new
    end

    def space
      Arbitrators::SpaceRace.new
    end
  end

  ##
  # Removes cards from +current_cards+, discarding if needed.
  #
  # In the case of the China Card, it is handed to the opponent.
  #
  class DisposeCurrentCards < Instruction
    needs :current_cards

    def action
      instructions = []

      current_cards.each do |card|
        remove_from_current_cards = Instructions::RemoveCurrentCard.new(
          card_ref: card.ref
        )

        discard_or_surrender = card.china_card? ?
          Instructions::SurrenderChinaCard.new :
          Instructions::Discard.new(card_ref: card.ref)

        instructions.push remove_from_current_cards, discard_or_surrender
      end

      instructions
    end
  end

  card_dumpers = [
    %i(Discard discards),
    %i(Remove  removed),
    %i(Limbo   limbo)
  ]

  # Defines:
  #
  #   class Discard < Instruction
  #   class Remove  < Instruction
  #   class Limbo   < Instruction
  #
  # Discards/Removes/Limbos the specified card, unless it is already in any
  # of the three piles.
  #
  card_dumpers.each do |class_name, card_pile_name|
    klass = Class.new(Instruction) do
      arguments :card_ref

      needs :cards, :discards, :removed, :limbo

      define_method :action do
        card = cards.find_by_ref(card_ref)

        already_disposed = %i(discards removed limbo).any? do |pile|
          send(pile).include?(card)
        end

        send(card_pile_name) << card unless already_disposed
      end
    end

    const_set(class_name, klass)
  end

  class RemoveCardFromHand < Instruction
    arguments :player, :card_ref

    needs :cards, :hands

    def action
      card = cards.find_by_ref(card_ref)

      hands.hand(player).remove(card)
    end
  end

  class AddCurrentCard < Instruction
    arguments :card_ref

    needs :cards, :current_cards

    def action
      card = cards.find_by_ref(card_ref)

      current_cards << card
    end
  end

  class RemoveCurrentCard < Instruction
    arguments :card_ref

    needs :cards, :current_cards

    def action
      card = cards.find_by_ref(card_ref)

      current_cards.delete card
    end
  end

  ##
  # An instruction that does nothing. Typically used to signal that a player
  # is either unable or is electing not to play.
  #
  class Noop < Instruction
  end

end

### MoveArbitrators

module Arbitrators
  class MoveArbitrator < WorkItem
    def initialize(**args)
      super

      @stashed_moves = []
      @executed_moves = []
    end

    def accepts?(move) noimpl end

    def accept(move)
      before_execute(move)
      move.execute
      after_execute(move)
    end

    # Override in subclasses.
    def after_execute(move)
      complete
    end

    # Override in subclasses.
    def before_execute(move)
    end

    def stash(move)
      @stashed_moves.push move
    end

    def execute_stashed_moves
      while move = @stashed_moves.pop do
        accept move
        @executed_moves.push move
      end
    end

    def correct_player?(move)
      # XXX
      #
      # UGH - this surfaces the whole 'do we need a player attr on Move and
      # sometimes on the Instruction as well' problem. At least ringfence it
      # into here for now.
      #
      # XXX
      instruction_player =
        move.instruction &&
        move.instruction.respond_to?(:player) &&
        move.instruction.player

      instruction_player ?
        player == instruction_player && player == move.player :
        player == move.player
    end

    def hint() noimpl end
  end

  class AddInfluence < MoveArbitrator
    arguments :player, :influence, :country_names, :total_influence

    attr_reader :remaining_influence

    def after_init
      @remaining_influence = total_influence
    end

    def after_execute(move)
      @remaining_influence -= move.instruction.amount

      complete if @remaining_influence.zero?
    end

    # TODO use minitest assertions?
    def accepts?(move)
      correct_player?(move) &&
        move.instruction.influence == influence &&
        country_names.include?(move.instruction.country_name) &&
        move.instruction.amount <= remaining_influence
    end
  end

  class AddRestrictedInfluence < MoveArbitrator
    arguments :player, :influence, :operation_points

    needs :countries

    # The 'working set' for countries during the execution of this
    # arbitrator.
    #
    # The countries snapshot is used for calculating influence cost as
    # placement of influence changes throughout the play.
    #
    # The countries snapshot is updated when adding influence
    # to a country where influence is already placed. This keeps cost
    # calculation accurate as influence quantity changes.

    attr_accessor :countries_snapshot

    # The state of the countries when the arbitrator is first invoked.
    #
    # Used to detect influence creep.
    #
    # The countries in this list should never be updated.

    attr_accessor :original_countries

    attr_reader :remaining_operation_points

    attr_reader :operation_points_to_deduct

    def after_init
      @remaining_operation_points = operation_points
    end

    def before_execute(move)
      country = countries.find(move.instruction.country_name)

      @operation_points_to_deduct =
        add_influence_with_price!(move.instruction.amount, country)
    end

    def after_execute(move)
      @remaining_operation_points -= @operation_points_to_deduct

      complete if @remaining_operation_points.zero?
    end

    def accepts?(move)
      correct_player?(move) &&
        valid_country?(move) &&
        valid_influence?(move) &&
        within_spending_limit?(move)
    end

    # Is the target a country where influence can be placed in accordance
    # to geographical restrictions?
    #
    # Satisfy one of:
    #
    #  * Does the player have influence in the country?
    #  * Does the player have influence in a neighboring country?
    #  * Is the country adjacent to the player's superpower?
    #

    def valid_country?(move)
      country   = original_countries.find(move.instruction.country_name)
      neighbors = country.neighbors.lazy.map { |n| original_countries.find(n) }

      return true if country.presence?(player)
      return true if country.adjacent_superpower?(player)
      return true if neighbors.any? { |n| n.presence?(player) }
      return false
    end

    def valid_influence?(move)
      influence == move.instruction.influence
    end

    def within_spending_limit?(move)
      country = countries.find(move.instruction.country_name)

      price =
        add_influence_with_price(move.instruction.amount, country)

      price <= @remaining_operation_points
    end

    # Adds the specified number of influence markers to the country using
    # the current price of influence for each increment.
    #
    # Returns the cost placing influence.
    #
    # Careful, this method has side effects -- actually places influence
    # into the country.

    def add_influence_with_price!(num_markers, country)
      spent = 0

      while num_markers > 0 do
        spent += country.price_of_influence(influence)

        num_markers -= 1
        country.add_influence(influence, 1)
      end

      spent
    end

    # Non-destructive version of 'add_influence_with_price!'.

    def add_influence_with_price(num_markers, country)
      add_influence_with_price!(num_markers, country.dup)
    end

    # Overwrite the countries setter to store a one-time snapshot
    # of the countries. Duplicated so that changes are not written
    # back to the game state.

    undef countries=
    def countries=(countries)
      self.countries_snapshot ||= countries.dup
      self.original_countries ||= countries.dup
    end

    undef countries
    alias countries countries_snapshot

  end

  class CardPlay < MoveArbitrator
    OPERATIONS = %i(coup realignment influence space)

    arguments :player

    needs :deck, :china_card, :space_race, :hands, :cards

    # used for tracking state over two-instruction plays
    attr_accessor :previous_card, :previous_action

    def after_execute(move)
      if noop?(move) || second_part?
        complete
      else
        card = cards.find_by_ref(move.instruction.card_ref)

        if card.side == player.opponent && !space?(move)
          self.previous_card   = move.instruction.card_ref
          self.previous_action = move.instruction.card_action
        else
          complete
        end
      end
    end

    ##
    # Checks the move is valid against numerous conditions.
    #
    # If the player is unable to play a card (i.e. empty hand) then accept
    # a noop instruction.
    #
    # Otherwise, check the move contains a CardPlay instruction and that the
    # player has the card in hand (or is playable in the case of the china
    # card).
    #
    # If the card contains an opponent event, then also verify that two moves
    # are played -- one for an event and one for an operation, in either order
    # and using the same card.
    #
    # If the card contains an opponent event, but is being spaced, then ensure
    # a one part move.
    #
    # Other conditions, such as space race eligiblity are validated upstream
    # by permission modifiers.
    #
    def accepts?(move)
      return false unless correct_player?(move)

      if able_to_play?
        card_play?(move) && valid_card?(move)
      else
        noop?(move)
      end
    end

    ##
    # The player is able to play if this is the second part of a card play,
    # or their hand is not empty.
    #
    def able_to_play?
      second_part? || !hands.hand(player).empty?
    end

    def noop?(move)
      Instructions::Noop === move.instruction
    end

    def card_play?(move)
      Instructions::PlayCard === move.instruction
    end

    def valid_card?(move)
      if second_part?
        same_card_as_previous?(move) && opposing_action?(move)
      else
        card_in_possession?(move)
      end
    end

    def space?(move)
      move.instruction.card_action == :space
    end

    def opposing_action?(move)
      action = move.instruction.card_action

      if action == :event
        OPERATIONS.include?(previous_action)
      else
        previous_action == :event
      end
    end

    def same_card_as_previous?(move)
      previous_card && previous_card == move.instruction.card_ref
    end

    def card_in_possession?(move)
      card = cards.find_by_ref(move.instruction.card_ref)

      if card.china_card?
        china_card.playable_by?(player)
      else
        hands.hand(player).include?(card)
      end
    end

    ##
    # Is this the second part of a two-part move?
    #
    # This is only known for sure once the first move has been executed.
    #
    def second_part?
      previous_card || previous_action
    end
  end
end

### Modifiers

##
# Always says no to every move.
#
# Used for testing.
#
class NegativePermissionModifier
  def allows?(move)
    false
  end
end

class StackModifier
  def initialize(*items_to_insert)
    @items_to_insert = items_to_insert
    @executed = false # execute this only once
  end

  def notify(event, move, work_items)
    return if @executed

    work_items.push(*@items_to_insert)

    @executed = true
  end
end


class PermissionModifier
  extend Injectible

  def allows?(move)
    noimpl
  end
end

##
# Updates and consults with the SpaceRace class to ensure each move is
# made in compliance with current space race restrictions.
#
class SpaceRacePermissionModifier < PermissionModifier

  needs :space_race

  def allows?(move)
    return true # TODO
    # note move and see if space race will allow it.
    #
    # update space race component.
    #
    # if spacing and player has used up space race, return false.
  end
end

##
# Rejects any attempt to play the China Card as an event.
#
# Should be present as a permission modifier throughout the game.
#
class ChinaCardPermissionModifier < PermissionModifier

  needs :cards, :china_card

  def allows?(move)
    !eventing_china_card?(move)
  end

  def eventing_china_card?(move)
    return false unless Instructions::PlayCard === move

    card = cards.find_by_ref(move.instruction.card_ref)

    card.china_card? && move.instruction.card_action == :event
  end
end

