require 'delegate'
require 'pp'
require 'set'

require "struggle/constants"

require "struggle/stack"
require "struggle/engine"
require "struggle/injection"
require "struggle/arguments"
require "struggle/observer"
require "struggle/observers"

require "struggle/move"
require "struggle/work_item"
require "struggle/instruction"
require "struggle/move_arbitrator"
require "struggle/guard_resolver"
require "struggle/guard"
require "struggle/scoring"

require "struggle/ops_counter"
require "struggle/ops_modifier"
require "struggle/war_resolver"

require "struggle/instructions"
require "struggle/arbitrators"
require "struggle/guards"
require "struggle/events"
require "struggle/modifiers"

# TODO delete or graduate components out of here.
require "struggle/models"

require "struggle/data/countries"

require "struggle/card"
require "struggle/cards"
require "struggle/china_card"
require "struggle/countries"
require "struggle/country"
require "struggle/deck"
require "struggle/defcon"
require "struggle/die"
require "struggle/events_in_effect"
require "struggle/hands"
require "struggle/military_ops"
require "struggle/phasing_player"
require "struggle/region"
require "struggle/space_race"
require "struggle/superpowers"
require "struggle/turn_marker"
require "struggle/victory"
require "struggle/victory_track"

class Struggle
  VERSION = "1.0.0"
end

DEBUG_ENGINE = ENV["STRUGGLE_DEBUG_ENGINE"]

def log(*stuff)
  puts(*stuff.map { |line| ">> " + line }) if $logging
end

