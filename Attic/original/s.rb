# encoding: UTF-8

raise "zzzzzzzzzz"
require "country_data"

class Game

  # Things that hold cards
  attr_accessor :deck, :discarded, :removed

  # Current cards in possession
  attr_accessor :hands

  # A collection of all moves made to date
  attr_accessor :history

  # Variables tracking the current turn
  attr_accessor :turn, :round, :player

  # DEFCON level
  attr_accessor :defcon

  # China card status
  attr_accessor :china_card_playable # Flipped up?
  attr_accessor :china_card_holder   # US or USSR

  # Military Ops: 0-5
  attr_accessor :us_ops, :ussr_ops

  # Countries and their associated presence
  attr_accessor :countries

  # A victory track for victory points.
  attr_accessor :victory_track

  # The die to be used for generating numbers.
  attr_accessor :die

  # Modifiers that change certain underlying aspects of the gameplay for a
  # limited amount of time.
  attr_accessor :modifiers

  # Expectations. These are arrays of expected (i.e. allowable moves/actions).
  # Each expectation within an array can be accepted without regards of order
  # (if order_sensitive == false).
  # All expectations in the leading array must be met first before any in
  # the next array can be allowed.
  #
  # Thus:
  #
  #  [ [e1a, e1b, e1c], [e2a, e2b], [...] ]
  #
  # All of e1* must be completed before any e2* can be accepted, and so on.
  #
  # Once all expectations are completed in one array, the next array of
  # expectations are set by incrementing a pointer @current_index.
  attr_reader :all_expectations

  # Formal definitions
  alias phasing_player       player
  alias action_round         round
  alias china_card_playable? china_card_playable


  # Accepts actions or moves
  def accept(action_or_move)
    # assert that this action satisfies the immediate array of expectations.
    # execute as needed.

    puts "PLAYING: #{action_or_move}"

    inject_variables action_or_move

    action_or_move.before

    expectation = expectations.expecting?(action_or_move) or
      raise UnacceptableActionOrMove.new(expectations, action_or_move)

    results = [*expectation.execute(action_or_move)]

    modifiers.each { |m| inject_variables m }

    results.push *modifiers.executed(action_or_move)

    new_validators = results.grep(Validators::Validator)
    new_modifiers  = results.grep(Modifiers::Modifier)

    new_validators.each { |v| inject_variables v }

    add_immediate_expectations new_validators
    add_modifiers new_modifiers

    puts "DERPPPPPPPP"
    p action_or_move
    action_or_move.after

    history.add action_or_move

    # TODO possibly remove intervals
    #interval = expectations.interval
    #interval.execute(history) #if expectation.satisfied?

    # TODO: no results are collected from executions here, is this intentional?
    if expectations.satisfied?
      terminator = expectations.terminator

      inject_variables terminator

      more_expectations = terminator.execute

      modifiers.executed(terminator)

      add_expectations more_expectations if more_expectations

      history.add terminator

      next_expectation
    end
  end

  # Guesses what possible bits of context that the object may need in order
  # to go about its business. This should probably be less guess and more
  # object stating what it needs, and we provide it here.
  #
  # Suggested: add "def self.needs; [:countries]; end" to the object
  # receiving the injections.
  def inject_variables(target)
    injections = %w(countries defcon current_card current_turn die
                    score_resolver history victory_track
                    hands discarded removed)

    injections.each do |name|
      if target.respond_to?(:"#{name}=")
        target.send(:"#{name}=", send(name.to_sym))
      end
    end
  end

  def next_expectation
    @current_index += 1
  end

  # Returns the current Expectations object.
  def expectations
    all_expectations[@current_index] or fail "Ran out of expectations!"
  end

  # Add the provided validators (TODO or should these be a new set of nested
  # expectations?) into the current set of expectations, right after the
  # current validation.
  def add_immediate_expectations(validators)
    expectations.insert(*validators)
  end

  def add_modifiers(modifiers)
    self.modifiers.insert *modifiers
  end

  def current_card
    history.current_card
  end

  def current_turn
    history.current_turn
  end

end

class UnacceptableActionOrMove < StandardError
  def initialize(expectations, action_or_move)
    @expectations = expectations
    @action_or_move = action_or_move
  end

  def to_s
    <<-ERR.strip.squeeze
    Invalid move or action.
    Move: #{@action_or_move.inspect}
    could not be matched against:
    #{@expectations.inspect}
    ERR
  end
end

class Expectations
  attr_accessor :expectations

  # Code to run once all has been satisfied.
  # Advance turn markers, etc?
  attr_accessor :terminator

  # Code to run after each satisfaction, switch phasing player etc?
  attr_accessor :interval

  # Order sensitive - if true, expectations must be
  # satisfied in the order they are stored. (the default.)
  attr_accessor :order_sensitive

  DefaultTerminator = Class.new { def execute(*); puts self.class.name; end }
  DefaultInterval   = Class.new { def execute(*); puts "="*80; end }

  DEFAULT_ARGS = {
    :terminator      => DefaultTerminator.new,
    :interval        => DefaultInterval.new,
    :order_sensitive => true
  }

  def initialize(expectations, args = {})
    self.expectations = [*expectations]

    args = DEFAULT_ARGS.merge(args)

    self.interval = args[:interval]
    self.terminator = args[:terminator]
    self.order_sensitive = args[:order_sensitive]
  end

  def satisfied?
    expectations.all? &:satisfied?
  end

  # TODO rename - a bool method should not have a required obj return
  def expecting?(action_or_move)
    if order_sensitive?
      # if order sensitive, find the first unsatisfied expectation.
      unsatisfied_expectation = expectations.detect { |x| !x.satisfied? }

      if unsatisfied_expectation.valid?(action_or_move)
        unsatisfied_expectation
      else
        raise UnacceptableActionOrMove.new(
          unsatisfied_expectation, action_or_move)
      end
    else
      expectations.detect { |x| !x.satisfied? && x.valid?(action_or_move) }
    end
  end

  ##
  # Expectations that are yet to be satisifed.
  #
  def outstanding
    expectations.reject(&:satisfied?)
  end

  def explain
    outstanding.map(&:explain)
  end

  # Inserts a validator after the last satisfied validator, or put it on the
  # end if all are satisfied.
  def insert(*validators)
    index = expectations.index { |v| !v.satisfied? } || expectations.size

    expectations.insert(index, *validators)
  end

  alias order_sensitive? order_sensitive
end

class Superpower
  class << self
    def opponent; fail NotImplementedError; end
    def ussr?; false; end
    def us?; false; end
    def to_s; name; end
    def name; super.upcase; end
    def symbol; end
  end

  def initialize; fail "Cannot instantiate a Superpower!"; end
end

class Us < Superpower; end
class Ussr < Superpower; end

US   = Us
USSR = Ussr

class Us < Superpower
  class << self
    def opponent; USSR; end
    def us?; true; end
    def symbol; "☆"; end
  end
end

class Ussr < Superpower
  class << self
    def opponent; US; end
    def ussr?; true; end
    def symbol; "☭"; end
  end
end

class VictoryTrack

  # +20 = USSR victory, -20 = US victory
  attr_reader :points

  def initialize
    @points = 0
  end

  def add(player, amount)
    raise ArgumentError, "Must be positive" if amount < 0

    @points += (player.us? ? -amount : amount)
  end

  def subtract(player, amount)
    raise ArgumentError, "Must be positive" if amount < 0

    @points += (player.us? ? amount : -amount)
  end
end

class Defcon
  attr_reader :value, :destroyed_by

  def initialize
    @value = 5
    @destroyed_by = nil
  end

  def change(player, amount)
    puts "%s to %s DEFCON by %s" % [
      player, amount < 0 ? "reduce" : "increase", amount.abs
    ]

    set(player, value + amount)
  end

  def increase(player, amount)
    raise ArgumentError, "Must be positive" if amount < 0

    change(player, amount)
  end

  alias improve increase

  def decrease(player, amount)
    raise ArgumentError, "Must be positive" if amount < 0

    change(player, -amount)
  end

  alias degrade decrease

  def set(player, requested_value)
    raise ArgumentError, "Need a player" unless [US, USSR].include?(player)
    raise ImmutableDefcon, "DEFCON can no longer be changed." if nuclear_war?

    # limit the value to 1..5.
    bounded_value = [[requested_value, 5].min,1].max

    puts "%s sets DEFCON to %s" % [player, bounded_value]

    @value = bounded_value

    declare_nuclear_war(player) if value <= 1

    self
  end

  def declare_nuclear_war(player)
    @destroyed_by = player
  end

  def nuclear_war?
    destroyed_by
  end

  ImmutableDefcon = Class.new(StandardError)
end

class Die
  attr_accessor :prng

  def initialize
    self.prng = Random.new
  end

  def roll
    [1,2,3,4,5,6].sample(random: prng)
  end
end

class History
  attr_accessor :entries

  def initialize
    self.entries = []
  end

  def add(entry)
    self.entries << entry
  end

  # Has the card been played as an event?
  # (This does not mean the event is necessarily in effect...)
  def played?(card)
    entries.any? { |e| Moves::CardPlay === e && e.card == card && e.event? }
  end

  def current_card
    x = entries.reverse.detect { |entry| entry.respond_to?(:card) }
    x.card
  end

  def current_turn
    entry = entries.reverse.detect { |entry| entry.respond_to?(:turn) }

    entry ? entry.turn : Turn.new(1)
  end

  # Returns the most recent headline plays.
  def headlines
    entries.grep(Moves::HeadlineCardPlay).last(2)
  end

end

module Moves
  class Move
    def to_s
      "Move#to_s TODO in #{self.class.name}"
    end

    def execute
      raise "Not Implemented!"
    end

    def amount
      raise NotImplementedError
    end

    # Called before execution and after initialization and injection.
    def before
    end

    # Called after execution.
    def after
    end
  end

  # The representation of playing a card. The resulting moves the player
  # may make are not part of a CardPlay.
  class CardPlay < Move

    # The player taking the action.
    attr_accessor :player

    # The card being played.
    attr_accessor :card

    # The action(s) the player wants to take as a result of playing the card.
    # If playing an opponent card, the player must specify :event and some
    # other action in the order they want to play them.
    #
    # This is affected by a case ruling, see Ruling #2.
    attr_accessor :actions_and_modifiers

    # Tracks whether the event on this card was executed on this play.
    attr_accessor :event_executed

    # injected as needed.
    attr_accessor :countries, :defcon, :score_resolver, :history,
      :hands, :discarded, :removed

    # actions_and_modifiers may be one of:
    #   - a single symbol representing a single action,
    #   - an array of symbols representing an order of actions.
    #   - a hash keyed on action with each value being one or more
    #     modifiers to be applied with that action
    #
    # Examples:
    #
    #   :influence
    #   [:influence, :event]
    #   { :influence => [modifier1, modifier2], :event => nil }
    #
    def initialize(player, card, actions_and_modifiers)
      self.player = player
      self.card = card

      self.actions_and_modifiers = convert_to_hash(actions_and_modifiers)

      validate_actions(player, card)

      validate_modifiers(self.actions_and_modifiers)
      apply_modifiers_for(self.actions_and_modifiers.values.flatten, self)
    end

    # Convert input as described in constructor.
    def convert_to_hash(actions_and_modifiers)
      hash = case actions_and_modifiers
      when Hash   then actions_and_modifiers
      when Symbol then { actions_and_modifiers => nil }
      when Array  then Hash[actions_and_modifiers.zip([nil])]
      else raise "Unknown format: #{actions_and_modifiers}"
      end

      Hash[hash.map { |k,v| [k,[*v].compact] }]
    end

    def actions
      actions_and_modifiers.keys
    end

    def validate_actions(player, card)
      if exclusively_space_race?
        raise "Cannot space race." unless can_space_race?(player, card)

      elsif playing_opponent_card?(player, card)
        raise "Must be two actions" unless actions.size == 2
        raise "Must include event" unless event?
        raise "Must include an action" unless action?

      elsif card.score!.zero? # A scoring card...
        raise "Player can only specify one action" unless actions.size == 1
        raise "Scoring card can only be played for event" unless event?

      else
        raise "Player can only specify one action" unless actions.size == 1

        unless action? || event?
          raise "Must include an action or event"
        end
      end
    end

    def validate_modifiers(actions_and_modifiers)
      # TODO can these be used by the player?
      # i.e. is in game.modifiers and the current player owns them
      # and are active

      actions_and_modifiers.each do |action, modifiers|
        modifiers.each do |m|
          raise "Cannot use an expired modifier: #{m.inspect}" if m.expired?

          if m.unplayable?(action)
            raise "This modifier would cause an unplayable state"
          end
        end
      end
    end

    def apply_modifiers_for(modifiers, obj)
      suitable_modifiers = modifiers.select { |m| m.modifies?(obj.class) }

      suitable_modifiers.each do |m|
        obj.singleton_class.send :include, m.modifier_for(obj.class)
      end
    end

    def exclusively_space_race?
      actions == [:space_race]
    end

    def event?
      actions.include?(:event)
    end

    # Any action (defined in Section 6) other than space race.
    def action?
      actions.any? { |e| [:influence, :coup, :realignment].include?(e) }
    end

    def playing_opponent_card?(player, card)
      card.side == player.opponent
    end

    # TODO
    def can_space_race?(*)
      true
    end

    def headline?; false; end

    def mark_event_executed
      self.event_executed = true
    end

    alias event_executed? event_executed

    # puts the card just played onto the expectation stack. Just like how
    # HeadlineCardRound does it after a couple of HeadlineCardPlays. BUT INSTEAD
    # IT DOES IT RIGHT NOW
    #
    # Returns one or more validators to be placed on the current set of
    # expectations.
    #
    # Execute can return a combination of validators and modifiers.
    def execute
      convert_actions(actions)
    end

    def convert_actions(actions)
      actions.
        map { |a| convert_action(a, card) }.
        flatten
    end

    # The rest of this smells a lot like a Factory...

    # Convert an action to a validator and/or modifier.
    def convert_action(action, card)

      results = []

      # If the event is playable, then fetch the validator and/or
      # modifier
      if action == :event
        if card.event_playable?(history)
          results.push *card.execute(player)
          mark_event_executed
        else
          puts "Event for #{card} does not execute!"
        end
      else
        validator_class = type_to_validator(action)
        number_of_moves = score_resolver.score(player, card)

        validator = instantiate_validator(validator_class, number_of_moves)

        results.push validator
      end

      results.each do |r|
        apply_modifiers_for(actions_and_modifiers.values.flatten, r)
      end

      results
    end

    def type_to_validator(type)
      class_name = type.to_s.split("_").map(&:capitalize).join

      Validators.const_get(class_name, false)
    end

    def instantiate_validator(validator_class, number_of_moves)
      # Doing a case on Class classes is not fun.
      case
      when validator_class == Validators::Influence
        validator_class.new(player, number_of_moves)

      when validator_class == Validators::Coup
        validator_class.new(player, defcon, number_of_moves)
      else
        raise "Don't know how to instantiate #{validator_class.inspect}!"
      end
    end

    def before
      take_card_from_hand
    end

    def take_card_from_hand
      hands.fetch(player).take(card)
    end

    def after
      puts "xxxxxxxxx"
      remove_or_discard_card
    end

    # Cards are either sent to the discard pile or permenently removed. If
    # the card should have any lasting effect after play, then this is
    # captured in a Modifier.
    def remove_or_discard_card
      p [card.remove_after_event, event_executed?]
      if card.remove_after_event? && event_executed?
        removed.add(card)
      else
        discarded.add(card)
      end
    end

    def to_s
      x = actions_and_modifiers.map do |action, modifiers|
        [action, *modifiers].join(" with ")
      end

      "%s plays %s for %s" % [player, card, x.join(" then ")]
    end

    def amount
      raise "An amount is not required for a #{self.class.name}."
    end

  end

  # Deferred kind of CardPlay. They encapsulate the playing of a headline card
  # but will not be revealed or acted upon until the HeadlineEnd terminator
  # displays them.
  class HeadlineCardPlay < CardPlay

    def initialize(player, card)
      super(player, card, :event)
    end

    def headline?; true; end

    def execute
      mark_event_executed
    end

    def to_s
      "%s headlines %s" % [player, card]
    end
  end


  #TODO: give influence classes a common abstract class.

  class UnrestrictedInfluence < Move
    attr_accessor :player, :country, :amount

    def initialize(player, country, amount)
      self.player = player
      self.country = country
      self.amount = amount
    end

    def to_s
      adds_or_subtracts = amount > 0 ? "adds" : "subtracts"

      "%s %s %s influence points in %s" % [
        player, adds_or_subtracts, amount.abs, country
      ]
    end

    def execute
      country.add_influence!(player, amount)
    end

    def resulting_influence
      country.influence(US) + amount
    end
  end

  class OpponentInfluence < UnrestrictedInfluence
    def execute
      country.add_influence!(player.opponent, amount)
    end
  end

  class Influence < Move
    attr_accessor :player, :country, :amount

    def initialize(player, country, amount)
      self.player = player
      self.country = country
      self.amount = amount
    end

    def to_s
      adds_or_subtracts = amount > 0 ? "adds" : "subtracts"

      "%s %s %s influence points in %s" % [
        player, adds_or_subtracts, amount.abs, country
      ]
    end

    def execute
      country.add_influence!(player, 1)
    end

    # Ignoring all other factors except occupiers of the country, this method
    # returns true if the move has enough influence points for the player to
    # place influence in the target country. This is not always a pertinent
    # question to ask -- such as placing influence during most events.
    def affordable?
      amount == country.price_of_influence(player)
    end
  end

  class Event < Move
    def initialize(player, todo)
    end

    def execute
      # ...
    end
  end

  class Coup < Move
    attr_accessor :player, :country

    # inject
    attr_accessor :current_card, :die, :score_resolver, :defcon

    def initialize(player, country)
      self.player = player
      self.country = country
    end

    def can_coup?(defcon)
      country.presence?(player.opponent) &&
        country.defcon_permits_coup?(defcon)
    end

    def execute
      defcon.decrease(player, 1) if country.battleground?

      todo "increase military ops by score" # if not a free coup

      stability = country.stability * 2

      n = die.roll

      score = score_resolver.score(player, current_card)

      modified_roll = n + score

      puts "%s rolls %s + %s = %s against a required %s modified stability" % [
        player, n, score, modified_roll, stability
      ]

      difference = modified_roll - stability

      if difference > 0
        puts "%s coups with %s point-win in %s" % [player, difference, country]

        country.successful_coup(player, difference)
      end
    end

    def to_s
      "%s attempts a coup in %s" % [player, country]
    end
  end

  # An alternate version of a Coup used in "free coup" moves that doesn't
  # test for geographic/defcon qualifiers (Section 6.3.5)
  #
  # Does not count toward milary ops (Section 8.2.5)
  #
  class FreeCoup < Coup
    def can_coup?(defcon)
      country.presence?(player.opponent)
    end

    def to_s
      "%s attempts a FREE coup in %s" % [player, country]
    end
  end

  class Realignment
    def initialize(player, country)
    end
  end

  class SpaceRace
    def initialize(player, card)
    end
  end

  class Scoring < Move
    attr_accessor :player

    # inject
    attr_accessor :countries

    def initialize(player)
      self.player = player
    end

    def execute
      # TODO check for auto victory

      region = Region.new(countries.select{ |c| c.in?(target_region) })

      us_vp, ussr_vp = [US, USSR].map do |superpower|
        presence   = region.presence?(superpower)
        domination = region.domination?(superpower)
        control    = region.control?(superpower)

        level = case
                when control    then :control
                when domination then :domination
                when presence   then :presence
                end

        puts "#{superpower} has #{level || 'nothing'} in scoring"


        points = [
          points(level),
          region.controlled_adjacent_to_superpower(superpower).size,
          region.controlled_battlegrounds(superpower).size
        ]

        puts "Scoring synopsis: #{points.inspect}"

        points.reduce(:+)
      end

      todo "US SCORES #{us_vp} VP"
      todo "USSR SCORES #{ussr_vp} VP"
    end

    def target_region
      raise NotImplementedError
    end

    def points(level)
      level ? send(level) : 0
    end

    def presence;   raise NotImplementedError; end
    def domination; raise NotImplementedError; end
    def control;    raise NotImplementedError; end
  end

  class AsiaScoring < Scoring
    def presence;   3; end
    def domination; 7; end
    def control;    9; end

    def target_region
      Asia
    end
  end

  class EuropeScoring < Scoring
    def presence;   3; end
    def domination; 7; end
    def control;    raise NotImplementedError; end # TODO

    def target_region
      Europe
    end
  end

  class MiddleEastScoring < Scoring
    def presence;   3; end
    def domination; 5; end
    def control;    7; end

    def target_region
      MiddleEast
    end
  end

  ### Misc, specialized moves

  class Discard < Move
    attr_accessor :player, :card

    def initialize(player, card)
      self.player = player
      self.card = card
    end

    def execute
      todo "discard the card from the player's hand"
    end

    def to_s
      "%s discards %s from their hand" % [player, card]
    end

  end

  class OlympicSponsorOrBoycott < Move
    attr_accessor :player, :sponsor_or_boycott

    def initialize(opponent, sponsor_or_boycott)
      unless [:sponsor, :boycott].include?(sponsor_or_boycott)
        raise "sponsor_or_boycott must be one of :sponsor or :boycott"
      end

      self.player = opponent
      self.sponsor_or_boycott = sponsor_or_boycott
    end

    def execute
      if boycott?
        defcon.decrease(sponsor, 1)
        todo "play_as_4_op_card"
      else # sponsors
        todo "roll_dice"
        todo "award_vp"
      end
    end

    def boycott?
      sponsor_or_boycott == :boycott
    end

    # The player who instigated the Olympic Games.
    def sponsor
      player.opponent
    end

    # The opponent is the player making the decision to sponsor or boycott.
    alias opponent player

    def to_s
      "The %s %ss the Olympic Games." % [opponent, sponsor_or_boycott]
    end
  end

  class FiveYearPlan < Move
    attr_accessor :player

    def initialize(player)
      self.player = player
    end

    def execute
      # TODO pick a random card from ussr hand
      # TODO ensure this card cant be picked (i.e. hand management should
      # have already removed FiveYearPlan from hand before executing...)
      card = ::DuckAndCover

      puts "Chosen card is #{card}"

      # TODO discard card

      # execute it as player if us event
      return card.execute(player) if card.side == US
    end
  end

  class DuckAndCover < Move
    attr_accessor :player

    # inject
    attr_accessor :defcon

    def initialize(player)
      self.player = player
    end

    # lower defcon
    # award us vps equal to 5 - defcon
    def execute
      defcon.decrease(player, 1)

      award = 5 - defcon.value

      todo "AWARD US #{award} VPs"
    end
  end
end

class Turn
  attr_reader :number

  def initialize(number)
    @number = number
  end

  def name
    case number
    when 1..3  then :early
    when 4..7  then :mid
    when 8..10 then :late
    end
  end

  def early?
    name == :early
  end

  def mid?
    name == :mid
  end

  def late?
    name == :late
  end

  alias early_war? early?
  alias mid_war?   mid?
  alias late_war?  late?

  def next
    Turn.new(number + 1)
  end
end

module Terminators
  # A class that shows and queues up the headline events that have been placed
  # by each player.
  class HeadlineCardRound

    attr_accessor :turn

    # injected
    attr_accessor :history

    def initialize(turn = Turn.new(1))
      self.turn = turn
    end

    # Works out how to resolve the headline play that occurred.
    # Returns the next stack of expectations for appending?
    def execute
      # TODO: if a tie on card score, US goes first (Rule 4.5 Subsection C)
      # Starting with the highest score, build up expectations
      validators = history.headlines.
        sort_by { |h| h.card.score! }.
        map     { |h| h.card.validator.new }.
        reverse

      puts "HEADLINE CARDS PLAYED!"

      # TODO: maybe update game status here about cards played

      Expectations.new(validators,
                       :terminator => HeadlineEventsEnd.new(turn))
    end
  end

  # A class for processing the end of events being played in the headline
  # round.
  class HeadlineEventsEnd

    attr_accessor :turn

    def initialize(turn)
      self.turn = turn
    end

    def execute
      puts "HEADLINE PHASE ENDED!"

      validators = [
        Validators::CardPlay.new(USSR),
        Validators::CardPlay.new(US)
      ]

      Expectations.new(
        validators,
        :terminator => Terminators::ActionRoundEnd.new(turn)
      )
    end
  end

  # Handles the end of each action round. There are multiple action rounds
  # per turn.
  class ActionRoundEnd

    attr_accessor :turn, :counter

    def initialize(turn, counter = 1)
      self.turn = turn
      self.counter = counter
    end

    def execute
      puts "ACTION ROUND ENDED!"

      t = if (turn.early? && counter == 6) || (!turn.early? && counter == 7)
        Terminators::TurnEnd.new(turn)
      else
        Terminators::ActionRoundEnd.new(turn, counter + 1)
      end

      validators = [
        Validators::CardPlay.new(USSR),
        Validators::CardPlay.new(US)
      ]

      Expectations.new(validators, :terminator => t)
    end
  end

  # Handles the end of each turn. There are multiple turns per phase.
  class TurnEnd
    attr_accessor :turn

    def initialize(turn)
      self.turn = turn
    end

    def execute
      puts "TURN ENDED!"

      if turn.number == 10 then
        Expectations.new([], :terminator => Terminators::GameEnd.new)
      else
        # if *end of* turn 3 ... etc
        if turn.number == 3 then
          todo "merge in mid war cards"
        elsif turn.number == 7 then
          todo "merge in late war cards"
        end

        Expectations.new([],
          :terminator => Terminators::HeadlineCardRound.new(turn.next))
      end
    end
  end

  class GameEnd
    def turn
      Turn.new(nil)
    end

    def execute
      puts "GAME ENDED"
    end
  end
end

module Validators
  class Validator
    def satisfied?
      fail NotImplementedError, "#{self.class.name} did not impl"
    end

    def execute(move)
      retval = move.execute
      executed(move)
      retval
    end

    def executed(move)
    end

    def valid?(move)
      fail NotImplementedError, "#{self.class.name} did not impl"
    end
  end

  # Validation that is only satisfied when all remaining influence has been
  # used up. For validating the typical "player places N influence" case.
  #
  # Set remaining_influence in your constructor.
  module TypeAgnosticInfluenceHelper
    attr_accessor :remaining_influence

    def initialize(*)
      fail "Set self.remaining_influence in #{self.class.name}!"
    end

    def valid?(move)
      move.amount > 0 &&
        remaining_influence > 0 &&
        move.amount <= remaining_influence
    end

    def executed(move)
      self.remaining_influence -= move.amount
    end

    def satisfied?
      remaining_influence.zero?
    end
  end

  module InfluenceHelper
    include TypeAgnosticInfluenceHelper

    def valid?(move)
      Moves::Influence === move && super
    end
  end

  module UnrestrictedInfluenceHelper
    include TypeAgnosticInfluenceHelper

    def valid?(move)
      Moves::UnrestrictedInfluence === move && super
    end
  end

  # A module that sets the Validator to a satisfied state once it has been
  # executed exactly once.
  module SingleExecutionHelper
    attr_accessor :satisfied

    def initialize(*)
      self.satisfied = false
    end

    def executed(move)
      self.satisfied = true
    end

    def satisfied?
      satisfied
    end

    def valid?(move)
      fail NotImplementedError, "not impl in #{self.class.name}"
    end
  end

  # Allows four USSR moves, ensuring each move is:
  #  in a unique country
  #  in a country in Eastern Europe
  #  in a country that is not US-controlled
  class Comecon < Validator

    # Countries that have been used in prior moves.
    attr_reader :countries

    include UnrestrictedInfluenceHelper

    def initialize(*)
      self.remaining_influence = 4
      @countries = []
    end

    def valid?(move)
      super &&
        move.amount == 1 &&
        move.country.in?(EasternEurope) &&
        !move.country.controlled_by?(US) &&
        !countries.include?(move.country)
    end

    def executed(move)
      super
      @countries << move.country
    end

  end

  # Allows removal of 1 USSR influence from 3 Eastern European countries.
  # Becomes 2 per country in late war.
  class EastEuropeanUnrest < Validator

    # Countries that have been used in prior moves.
    attr_reader :used_countries

    # inject
    attr_accessor :current_turn, :countries

    def initialize(*)
      @used_countries = Hash.new(0)
    end

    def valid?(move)
      move.amount == -1 &&
        move.country.presence?(USSR) &&
        move.country.in?(EasternEurope) &&
        @used_countries.size < 3 &&
        @used_countries[move.country] < limit
    end

    def limit
      current_turn.late_war? ? 2 : 1
    end

    def executed(move)
      @used_countries[move.country] += 1
    end

    def satisfied?
      @used_countries.size == 3 || no_more_suitable_countries?
    end

    def no_more_suitable_countries?
      countries.
        select { |c| c.in?(EasternEurope) && c.presence?(USSR) }.
        empty?
    end
  end

  # Allows US to remove all USSR influence in an uncontrolled country in
  # Europe once.
  #
  # Precedents:
  #
  # Must be uncontrolled by *both* players, see Ruling #1.
  class TrumanDoctrine < Validator

    include SingleExecutionHelper

    def valid?(move)
      Moves::OpponentInfluence === move &&
        move.player.us? &&
        move.country.in?(Europe) &&
        move.country.uncontrolled? &&
        move.amount + move.country.influence(USSR) == 0
    end
  end

  # Card Text
  # ---------
  #
  # This player sponsors the Olympics. The opponent must either participate
  # or boycott. If the opponent participates, each player rolls a die and
  # the sponsor adds 2 to their roll. The player with the highest modified
  # die roll receives 2 VP (reroll ties). If the opponent boycotts, degrade
  # the DEFCON level by 1 and the sponsor may conduct Operations as if they
  # played a 4 Ops card.
  #
  #
  class OlympicGames < Validator
    attr_accessor :player

    include SingleExecutionHelper

    def initialize(player)
      self.player = player
      self.satisfied = false
    end

    def valid?(move)
      # accept a boycott or sponsor decision from the opponent
      Moves::OlympicSponsorOrBoycott === move && move.player == player.opponent
    end
  end

  # Card Text
  # ---------
  #
  # Unless the US immediately discards a card with an Operations value of 3
  # or more, remove all US Influence from West Germany.
  #
  class Blockade < Validator

    include SingleExecutionHelper

    # Move is valid if any of:
    #  - discards a card >= 3 ops
    #  - requests to remove *all* influence from west germany
    def valid?(move)
      move.player.us? && (discard?(move) || deinfluences?(move))
    end

    def discard?(move)
      # TODO test the card score using score_resolver
      Moves::Discard === move && move.card.score >= 3
    end

    def deinfluences?(move)
      Moves::UnrestrictedInfluence === move &&
        move.country.name == "West Germany" &&
        move.resulting_influence.zero?
    end
  end

  class VietnamRevolts < Validator

    include UnrestrictedInfluenceHelper

    def initialize(*)
      self.remaining_influence = 2
    end

    def valid?(move)
      super && move.player.ussr? && move.country.name == "Vietnam"
    end
  end

  class BasicMoveValidator < Validator

    attr_accessor :expected_player

    include SingleExecutionHelper

    def initialize(expected_player)
      self.expected_player = expected_player
      self.satisfied = false
    end

    def valid?(move)
      move_class === move && move.player == expected_player
    end

    def move_class
      fail NotImplementedError
    end
  end

  # A basic validator that finds the move of the same name.
  class ResolvingBasicMoveValidator < BasicMoveValidator
    def move_class
      Moves.const_get(naked_class_name, false)
    end

    def naked_class_name
      self.class.name.split("::").last
    end

    def explain
      "%s to play %s" % [expected_player, naked_class_name]
    end
  end

  basic_validators = %w(
    FiveYearPlan DuckAndCover AsiaScoring EuropeScoring MiddleEastScoring)

  basic_validators.each do |const|
    const_set(const, Class.new(ResolvingBasicMoveValidator))
  end

  # Allows six USSR placements of influence within Eastern Europe.
  class OpeningUssrInfluence < Validator

    include UnrestrictedInfluenceHelper

    def initialize(*)
      self.remaining_influence = 6
    end

    def explain
      "USSR to place 6 influence points within Eastern Europe."
    end

    def valid?(move)
      super && move.player.ussr? && move.country.in?(EasternEurope)
    end
  end

  # Allows seven US placements of influence within Western Europe.
  class OpeningUsInfluence < Validator

    include UnrestrictedInfluenceHelper

    def initialize(*)
      self.remaining_influence = 7
    end

    def explain
      "US to place 7 influence points within Western Europe."
    end

    def valid?(move)
      super && move.player.us? && move.country.in?(WesternEurope)
    end
  end

  class Headline < Validator
    attr_accessor :expected_player

    include SingleExecutionHelper

    def initialize(expected_player)
      super
      self.expected_player = expected_player
    end

    def valid?(move)
      # TODO: ensure china card cannot be played (Rule 4.5 Subsection C)
      Moves::HeadlineCardPlay === move && move.player == expected_player
    end

    def explain
      "#{expected_player} headline"
    end
  end

  # TODO: Having two classes named CardPlay is bad -- fix
  class CardPlay < Validator
    attr_accessor :expected_player

    include SingleExecutionHelper

    def initialize(expected_player)
      super
      self.expected_player = expected_player
    end

    def valid?(move)
      Moves::CardPlay === move && move.player == expected_player
    end

    def explain
      "%s to play a card." % expected_player
    end
  end

  # An Influence validator that applies the rules of placing influence during
  # operations. It will test for the target country being whitelisted, as well
  # as ensuring 2:1 cost of entry during opponent control.
  class Influence < Validator
    attr_accessor :expected_player

    # injected
    attr_accessor :countries

    include InfluenceHelper

    def initialize(expected_player, number_of_moves)
      self.expected_player = expected_player
      self.remaining_influence = number_of_moves
    end

    def accessible_countries
      Country.accessible(expected_player, countries).
        map { |name| Country.find(name, countries) }
    end

    def valid?(move)
      super &&
        expected_player == move.player &&
        accessible_countries.include?(move.country) &&
        move.affordable?
    end

    def explain
      "%s to place influence per regular influence-placement rules" %
        expected_player
    end
  end

  class Coup < Validator
    attr_accessor :expected_player, :defcon, :points

    include SingleExecutionHelper

    def initialize(expected_player, defcon, points)
      self.expected_player = expected_player
      self.points = points
      self.defcon = defcon
    end

    def valid?(move)
      move.player == expected_player && move.can_coup?(defcon)
    end
  end
end

class Modifiers
  attr_accessor :modifiers

  include Enumerable

  def initialize
    self.modifiers = []
  end

  def each(&block)
    modifiers.select(&:active?).each(&block)
  end

  def insert(*modifiers)
    self.modifiers.push(*modifiers)
  end

  def executed(something)
    map { |m| m.executed(something) }
  end
end

class Modifiers
  # A Modifier is a persistent object that will stay around modifying certain
  # aspects of gameplay until it renders itself to be no longer active.
  #
  # Modifiers receive notifications of all actions, move and terminators that
  # are executed in order to manage their internal state over multiple plays.
  class Modifier
    def executed(something)
    end

    def modifies?(klass)
      modifier_for(klass)
    end

    def modifier_for(klass)
    end

    def active?
      raise NotImplementedError
    end

    def expired?
      !active?
    end

  end

  module ScoreModifier
    def score(current_player, card)
      raise NotImplementedError
    end
  end

  # Card Text
  # ---------
  #
  # All Operations cards played by the opponent, for the remainder of this
  # turn, receive -1 to their Operations value (to a minimum value of 1
  # Operations point).
  #
  class RedScarePurge < Modifier

    include ScoreModifier

    # The player that activated this modifier.
    attr_accessor :activating_player

    def initialize(activating_player)
      self.activating_player = activating_player

      @active = true
    end

    def score(current_player, card)
      current_player == activating_player.opponent && card.score! > 1 ? -1 : 0
    end

    def executed(something)
      @active = false if Terminators::TurnEnd === something
    end

    def active?
      @active
    end

    def to_s
      "%s reduces card ops by 1 point for %s" % [
        self.class.name, activating_player.opponent]
    end
  end

  class Containment < Modifier

    include ScoreModifier

    def initialize(*)
      @active = true
    end

    def score(current_player, card)
      current_player.us? && card.score! < 4 ? 1 : 0
    end

    def executed(something)
      @active = false if Terminators::TurnEnd === something
    end

    def active?
      @active
    end

    def to_s
      "%s increases card ops by 1 point for US" % self.class.name
    end

  end

  class VietnamRevolts < Modifier

    attr_accessor :activating_player

    # injected
    attr_accessor :score_resolver, :countries

    def initialize(activating_player)
      self.activating_player = activating_player

      @active = true
    end

    def executed(something)
      @active = false if Terminators::TurnEnd === something
    end

    def active?
      @active
    end

    # In order to be playable as influence, the activating player
    # must have presence in at least one country in SE Asia.
    #
    # In order to be playable with a coup or realignment, then the
    # same rule must be true for the opponent.
    def playable?(action)
      player = case action
      when :influence          then activating_player
      when :realignment, :coup then activating_player.opponent
      else false
      end

      Country.accessible(player, countries).
        map  { |c| Country.find(c, countries) }.
        any? { |c| c.in?(SoutheastAsia) }
    end

    def unplayable?(action)
      !playable?(action)
    end

    # Methods that overlay CardPlay
    module CardPlayModifier
      def instantiate_validator(validator_class, number_of_moves)
        super(validator_class, number_of_moves + 1)
      end
    end

    module InfluenceValidatorModifier
      def accessible_countries
        super.select { |c| c.in?(SoutheastAsia) }
      end
    end

    def modifier_for(klass)
      return CardPlayModifier if klass == Moves::CardPlay
      return InfluenceValidatorModifier if klass == Validators::Influence
    end

    def to_s
      "%s increases ops by 1 point for %s card play entirely within SE Asia" % [
        self.class.name, activating_player
      ]
    end
  end

  class Nato < Modifier

    def initialize(*)
      @active = true
    end

    def active?
      @active
    end

    # TODO: Implement NATO patches
    #
    # Remove european us-controlled countries from accessible_countries
    # for coups, realignment and brush war.
    #
    # patch Moves::Coup, Moves::Realignment and Moves::CardPlay (for BrushWar)
  end
end

class ScoreResolver

  attr_accessor :modifiers

  def initialize(modifiers)
    self.modifiers = modifiers
  end

  def score(player, card)
    score = card.score!

    score_modifiers = modifiers.grep(Modifiers::ScoreModifier)

    score_modifiers.each do |m|
      adjustment = m.score(player, card)

      puts "%s adjusts ops points by %s for %s" % [
        m.class.name, adjustment, player
      ]

      score += adjustment
    end

    score
  end
end


# A registry for cards.
class Cards
  class << self
    def all
      @cards || []
    end

    def add(card)
      @cards ||= []
      @cards << card
    end

    def early_war
      all.select { |c| c.phase == :early }
    end
  end
end

class Card

  FIELDS = [
    :id, :name, :ops, :side, :phase, :remove_after_event, :validator, :modifier
  ]

  attr_accessor *FIELDS

  alias remove_after_event? remove_after_event

  def initialize(args)
    # Don't require modifier
    args[:modifier] ||= nil

    unless (FIELDS - args.keys).empty?
      raise ArgumentError, "missing args: #{(FIELDS - args.keys).join(',')}"
    end

    args.each { |key, value| send("#{key}=", value) }
    add_to_registry
  end

  def add_to_registry
    Cards.add(self)
  end

  # If the card is played for the event, is the event executable given the
  # current history?
  def event_playable?(history)
    true
  end

  def ops
    raise "Don't get the score here. Use a ScoreResolver."
  end

  alias score ops

  def ops!
    @ops
  end

  alias score! ops!

  def execute(player)
    v = validator && validator.new(player)
    m = modifier && modifier.new(player)

    [v, m].compact
  end

  def to_s
    asterisk = remove_after_event ? "*" : nil

    "%s%s (%s) [%s, %s]" % [name, asterisk, ops!, side || "neutral", phase]
  end
end

# Nato is special, it:
#
#  can be played for an event, but the event may not execute, depending on
#  previous card plays
#
#  must be discarded after the event has run (card can be played for event,
#  but if the event doesnt execute due to above conditions, discard should
#  not occur)
#
#
class NatoCard < Card

  # TODO: remove these ghost classes once cards are defined
  class WarsawPact; end
  class MarshallPlan; end

  def event_playable?(history)
    history.played?(WarsawPact) || history.played?(MarshallPlan)
  end

end

# Sample cards
# TODO: namespace... module Cards?
require "allcards"

class Deck
  attr_accessor :cards, :backup

  def initialize(cards = [], backup = nil)
    self.cards = cards
    self.backup = backup
  end

  def draw
    card = cards.delete(cards.sample)

    if card
      card
    elsif backup
      # TODO not good enough simply draw from back up deck - understanding
      # is this should become the new primary deck (and shuffle it!)
      backup.draw or fail NoCardsError, "No cards in deck or backup."
    else
      fail NoCardsError, "No cards in deck and no backup provided."
    end
  end

  def add(card)
    cards.push card
  end

  NoCardsError = Class.new(StandardError)
end

class Hand
  attr_reader :cards

  def initialize(cards = [])
    @cards = cards
  end

  def take(card)
    @cards.delete(card) or fail "Card #{card.inspect} not found in hand."
  end

  def add(*cards)
    @cards.push *cards
  end
end

# A Region is an arbitrary collection of countries that can be queried for
# region-scoring purposes.
class Region
  attr_accessor :countries

  def initialize(countries)
    self.countries = countries
  end

  def presence?(player)
    countries.any? { |c| c.controlled_by?(player) }
  end

  # Domination: A superpower achieves Domination of a Region if it Controls
  # more countries in that Region than its opponent, and it Controls more
  # Battleground countries in that Region than its opponent.
  #
  # A superpower must Control at least one non-Battleground and one
  # Battleground country in a Region in order to achieve Domination of that
  # Region.
  def domination?(player)
    num_countries = 0
    num_bg_countries = 0
    num_opp_countries = 0
    num_opp_bg_countries = 0

    controls_non_bg, controls_bg = false

    countries.each do |country|
      if country.controlled_by?(player)
        if country.battleground?
          num_bg_countries += 1
          controls_bg = true
        else
          num_countries += 1
          controls_non_bg = true
        end
      elsif country.controlled_by?(player.opponent)
        num_opp_countries += 1
        num_opp_bg_countries += 1 if country.battleground?
      end
    end

    num_countries > num_opp_countries &&
      num_bg_countries > num_opp_bg_countries &&
      controls_non_bg && controls_bg
  end

  # Control: A superpower has Control of a Region if it Controls more
  # countries in that Region than its opponent, and Controls all of the
  # Battleground countries in that Region.
  def control?(player)
    num_countries = 0
    num_opp_countries = 0

    countries.each do |country|
      num_countries +=1 if country.controlled_by?(player)
      num_opp_countries +=1 if country.controlled_by?(player.opponent)
    end

    num_countries > num_opp_countries && controls_all_battlegrounds?(player)
  end

  def controls_all_battlegrounds?(player)
    countries.
      select(&:battleground?).
      all? { |c| c.controlled_by?(player) }
  end

  def controlled_adjacent_to_superpower(player)
    countries.select do |c|
      c.controlled_by?(player) && c.adjacent_superpower == player.opponent
    end
  end

  def controlled_battlegrounds(player)
    battlegrounds.select { |c| c.controlled_by?(player) }
  end

  def battlegrounds
    countries.select(&:battleground?)
  end
end

class Country

  NO_COUPS = {
    5 => [],
    4 => [Europe],
    3 => [Europe, Asia],
    2 => [Europe, Asia, MiddleEast]
  }

  attr_reader :name, :stability, :battleground, :regions, :neighbors
  attr_reader :influence, :adjacent_superpower


  def initialize(name, stability, battleground, regions, neighbors,
                 adjacent_superpower = nil)

    @name = name
    @stability = stability
    @battleground = battleground
    @regions = regions
    @neighbors = neighbors
    @adjacent_superpower = case adjacent_superpower
                           when "US"   then US
                           when "USSR" then USSR
                           end

    @influence = { US => 0, USSR => 0 }
  end

  def in?(region)
    regions.include? region
  end

  def neighbor?(country)
    neighbors.include? country.name
  end

  def influence(player)
    @influence.fetch(player)
  end

  def add_influence!(player, amount = 1)
    influence = @influence.fetch(player)

    if influence + amount < 0
      raise ArgumentError, "Influence cannot be set to a negative value"
    end

    @influence[player] += amount
  end

  def presence?(player)
    influence(player) > 0
  end

  def controlled_by?(player)
    influence(player) >= stability + influence(player.opponent)
  end

  def controlled?
    controlled_by?(US) || controlled_by?(USSR)
  end

  def uncontrolled?
    !controlled?
  end

  # TODO: this method should go away now Validators::Influence exists.
  # def add_influence(player, countries, amount = 1)
  #   amount.times do
  #     if can_add_influence?(player, countries)
  #       add_influence!(player)
  #     end
  #   end
  # end

  # Checks if the given player can add influence to this country by checking
  # for presence in or around the country.
  #
  # This country must also be in the list of countries in order to consider
  # itself a valid target for influence.
  #
  # TODO this may not be needed - use Country.accessible to build a whitelist
  # of countries that can receive influence
  def can_add_influence?(player, countries)
    if countries.include?(self)
      presence?(player) || player_in_neighboring_country?(player, countries)
    end
  end

  def player_adjacent_to_superpower?(player)
    adjacent_superpower == player
  end

  def player_in_neighboring_country?(player, countries)
    neighbors.any? do |neighbor|
      countries.detect do |c|
        c.name == neighbor && c.presence?(player)
      end
    end
  end

  def price_of_influence(player)
    controlled_by?(player.opponent) ? 2 : 1
  end

  # Coup methods

  def defcon_prevents_coup?(defcon)
    return true if defcon.nuclear_war? # should you even be asking?

    regions = NO_COUPS[defcon.value]

    # Is this country in any of the DEFCON-affected regions?
    regions.any? { |region| in?(region) }
  end

  def defcon_permits_coup?(defcon)
    !defcon_prevents_coup?(defcon)
  end

  # Effect the change of a successful coup by the given player with given
  # margin of victory.
  def successful_coup(player, amount)
    raise ArgumentError, "must be positive" if amount < 0

    amount.times do
      if presence?(player.opponent)
        add_influence! player.opponent, -1
      else
        add_influence! player, 1
      end
    end
  end


  alias battleground? battleground

  def to_s
    swords = battleground? ? "⚔" : ""
    adjacent = adjacent_superpower && "#{adjacent_superpower.symbol}"

    basic = "%s %s%s (US:%s, USSR:%s)" % [
      name, swords, adjacent, influence(US), influence(USSR)
    ]

    extra = if controlled_by?(US)
      "Controlled by US"
    elsif controlled_by?(USSR)
      "Controlled by USSR"
    end

    [basic, extra].compact.join(" ")
  end

  class << self
    def initialize_all
      COUNTRY_DATA.map do |row|
        Country.new(*row)
      end
    end

    # Looks through the given array of countries for an unambiguous
    # match on country name. Name can be a String or Symbol.
    #
    # Not finding a country with the given name is considered an error.
    def find(name, countries)
      name = Regexp.new(name.to_s.gsub(/_/, " "), :i)

      results = countries.select do |country|
        country.name =~ name
      end

      if results.size == 1
        return results.first
      else
        raise AmbiguousName, "No country found for #{name.inspect}"
      end
    end

    # Returns a list of country names that the given player can "access" for
    # the purpose of placing influence, given the current countries and their
    # state of play.
    def accessible(player, all_countries)
      accessible_countries = []

      all_countries.each do |country|
        if country.presence?(player)
          accessible_countries.push country.name
          accessible_countries.push *country.neighbors
        elsif country.player_adjacent_to_superpower?(player)
          accessible_countries.push country.name
        end
      end

      accessible_countries.uniq
    end
  end

  AmbiguousName = Class.new(RuntimeError)
end

# Real bits of mostly unimportant code
class Game

  # Start a new game
  def initialize
    self.discarded = Deck.new
    self.removed = Deck.new

    self.deck = Deck.new(Cards.early_war, discarded)

    self.hands = {
      US   => Hand.new,
      USSR => Hand.new
    }

    self.history = History.new

    self.turn = 0 # headline
    self.round = 1
    self.player = USSR

    self.defcon = Defcon.new

    self.china_card_playable = true
    self.china_card_holder = USSR

    self.us_ops = 0
    self.ussr_ops = 0

    self.countries = Country.initialize_all

    self.victory_track = VictoryTrack.new

    self.die = Die.new

    self.modifiers = Modifiers.new

    @starting_influence_placed = false
    @all_expectations = []
    @current_index = 0

    place_starting_influence

    deal_cards

    # Require placement of USSR influence.
    add_expectations Expectations.new(Validators::OpeningUssrInfluence.new)

    # Once complete, require placement of US influence.
    add_expectations Expectations.new(Validators::OpeningUsInfluence.new)

    # Once complete, start a regular headline round.
    add_expectations Expectations.new(headline,
      :terminator => Terminators::HeadlineCardRound.new,
      :order_sensitive => false
    )
  end

  def add_expectations(expectations)
    @all_expectations << expectations
  end

  def headline
    [Validators::Headline.new(USSR), Validators::Headline.new(US)]
  end

  def deal_cards
    puts "dealing cards..."

    # TODO: make this 8
    6.times do
      hand(US).add(deck.draw)
      hand(USSR).add(deck.draw)
    end
  end

  def hand(player)
    hands.fetch(player)
  end

  def status
    puts "game status..."
  end

  def score_resolver
    ScoreResolver.new(modifiers)
  end

  def place_starting_influence
    fail "Called more than once!" if @starting_influence_placed

    Country.find(:syria, countries).add_influence!(USSR, 1)
    Country.find(:iraq, countries).add_influence!(USSR, 1)
    Country.find(:north_korea, countries).add_influence!(USSR, 3)
    Country.find(:east_germany, countries).add_influence!(USSR, 3)
    Country.find(:finland, countries).add_influence!(USSR, 1)

    Country.find(:iran, countries).add_influence!(US, 1)
    Country.find(:israel, countries).add_influence!(US, 1)
    Country.find(:japan, countries).add_influence!(US, 1)
    Country.find(:australia, countries).add_influence!(US, 4)
    Country.find(:philippines, countries).add_influence!(US, 1)
    Country.find(:south_korea, countries).add_influence!(US, 1)
    Country.find(:panama, countries).add_influence!(US, 1)
    Country.find(:south_africa, countries).add_influence!(US, 1)
    Country.find(:united_kingdom, countries).add_influence!(US, 5)

    @starting_influence_placed = true
  end

  # TODO utility method for debugging -- remove.
  def _debug_cards
    require 'pp'

    puts "HAND/CARD STATUS", ""

    %w(deck discarded removed hands).each do |attr|
      puts attr.capitalize, "-"*attr.size
      pp send(attr)
      puts
    end
  end
end

def todo(thing)
  puts "TODO: #{thing}"
  puts caller if ENV["TODO"]
end