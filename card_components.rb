# Notes
# -----
#
# Because of dependence on a number of variables, some lambdas will need to
# become a first-class object with injection and an execute method.
# Particularly those related to Wars, and VP awards.
#
# Need a single point of truth for the removal of modifiers, this data is
# currently repeated in several places.
#
# TurnEnd is assumed to fire upon advancement of the turn marker (4.5 H).

def all_influence(player)
  lambda { |c| c.influence(player) }
end

Decolonization = [
  AddInfluence(
    player: USSR,
    influence: USSR,
    limit_per_country: 1,
    countries: [Africa, SoutheastAsia],
    total_influence: 4)
]

TrumanDoctrine = [
  RemoveInfluence(
    player: US,
    influence: USSR,
    countries: lambda { Europe.uncontrolled },
    limit_per_country: all_influence(USSR),
    total_countries: 1
  )
]

SuezCrisis = [
  RemoveInfluence(
    player: USSR,
    influence: US,
    countries: [France, UnitedKingdom, Israel],
    limit_per_country: 2,
    total_influence: 4
  )
]

SocialistGovernments = [
  PreventedBy(IronLady),
  RemoveInfluence(
    player: USSR,
    influence: US,
    countries: [WesternEurope],
    limit_per_country: 2,
    total_influence: 3
  )
]

EastEuropeanUnrest = [
  RemoveInfluence(
    player: US,
    influence: USSR,
    countries: [EasternEurope],
    limit_per_country: 1,
    total_countries: 3,
    phase: [Early, Mid]
  ),
  RemoveInfluence(
    player: US,
    influence: USSR,
    countries: [EasternEurope],
    limit_per_country: 2,
    total_countries: 3,
    phase: [Late]
  )
]

DeStalinization = [
  RelocateInfluence(
    player: USSR,
    influence: USSR,
    destination_countries: lambda {
      Countries.reject { |c| c.controlled_by?(US) }
    },
    limit_per_country: 2,
    total_influence: 4,
    must_use_all_influence: false # player can relocate *up to* 4 influence.
  )
]

IndependentReds = [
  AddInfluence(
    player: US,
    influence: US,
    countries: [Yugoslavia, Romania, Bulgaria, Hungary, Czechoslovakia],
    total_countries: 1,
    limit_per_country: all_influence(USSR)
  )
]

RomanianAbdication = [
  RemoveInfluence(
    player: USSR,
    influence: US,
    countries: [Romania],
    limit_per_country: all_influence(US)
  ),
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: [Romania],
    limit_per_country: Romania.stability
  )
]

Fidel = [
  RemoveInfluence(
    player: USSR,
    influence: US,
    countries: [Cuba],
    limit_per_country: all_influence(US)
  ),
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: [Cuba],
    limit_per_country: Cuba.stability
  )
]

Comecon = [
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: lambda {
      Countries.select { |c| c.in?(EasternEurope) && !c.controlled_by?(US) }
    },
    limit_per_country: 1,
    total_influence: 4
  )
]

Nasser = [
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: [Egypt],
    total_influence: 2
  ),
  RemoveInfluence(
    player: USSR,
    influence: US,
    countries: [Egypt],
    total_influence: lambda { (Egypt.influence(US) / 2.0).ceil }
  )
]

SouthAfricanUnrest = [
  Either(
    AddInfluence(
      player: USSR,
      influence: USSR,
      countries: [SouthAfrica],
      total_influence: 2
    ),
    [
      AddInfluence(
        player: USSR,
        influence: USSR,
        countries: [SouthAfrica],
        total_influence: 1
      ),
      AddInfluence(
        player: USSR,
        influence: USSR,
        countries: Countries.select { |c| c.neighbor?(SouthAfrica) },
        total_influence: 2
      )
    ]
  )
]

PanamaCanalReturned = [
  AddInfluence(
    player: US,
    influence: US,
    countries: [Panama, CostaRica, Venezuela],
    limit_per_country: 1
  )
]

MuslimRevolution = [
  AnyTwo(
    [Sudan, Iran, Iraq, Egypt, Libya, SaudiArabia, Syria, Jordan].map do |c|
      RemoveInfluence(
        player: USSR,
        influence: US,
        countries: [c],
        limit_per_country: all_influence(US)
      )
    end
  )
]

PuppetGovernments = [
  AddInfluence(
    player: US,
    influence: US,
    countries: lambda {
      Countries.select { |c| c.influence(US).zero? && c.influence(USSR).zero? }
    },
    limit_per_country: 1,
    total_influence: 3
  )
]

Allende = [
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: [Chile],
    total_influence: 2
  )
]

SadatExpelsSoviets = [
  RemoveInfluence(
    player: US,
    influence: USSR,
    countries: [Egypt],
    limit_per_country: all_influence(USSR)
  ),
  AddInfluence(
    player: US,
    influence: US,
    countries: [Egypt],
    total_influence: 1
  )
]

OasFounded = [
  AddInfluence(
    player: US,
    influence: US,
    countries: [CentralAmerica, SouthAmerica],
    total_influence: 2
  )
]

LiberationTheology = [
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: [CentralAmerica],
    limit_per_country: 2,
    total_influence: 3
  )
]

ColonialRearGuards = [
  AddInfluence(
    player: US,
    influence: US,
    countries: [Africa, SoutheastAsia],
    limit_per_country: 1,
    total_influence: 4
  )
]

PortugueseEmpireCrumbles = [
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: [SeAfricanStates, Angola],
    limit_per_country: 2,
  )
]

TheVoiceOfAmerica = [
  RemoveInfluence(
    player: US,
    influence: USSR,
    countries: Countries.reject { |c| c.in?(Europe) },
    limit_per_country: 2,
    total_influence: 4
  )
]

Solidarity = [
  Requires(JohnPaulIiElectedPope),
  AddInfluence(
    player: US,
    influence: US,
    countries: [Poland],
    limit_per_country: 3
  )
]

MarineBarracksBombing = [
  RemoveInfluence(
    player: USSR,
    influence: US,
    countries: [Lebanon],
    limit_per_country: all_influence(US)
  ),
  RemoveInfluence(
    player: USSR,
    influence: US,
    countries: [MiddleEast],
    total_influence: 2
  )
]

PershingIiDeployed = [
  AwardVictoryPoints(
    player: USSR,
    amount: 1
  ),
  RemoveInfluence(
    player: USSR,
    influence: US,
    countries: [WesternEurope],
    limit_per_country: 1,
    total_influence: 3
  )
]

TheIronLady = [
  AwardVictoryPoints(
    player: US,
    amount: 1
  ),
  AddInfluence(
    player: US,
    influence: USSR,
    countries: [Argentina],
    limit_per_country: 1
  ),
  RemoveInfluence(
    player: US,
    influence: USSR,
    countries: [UnitedKingdom],
    limit_per_country: all_influence(USSR)
  )
]

IranianHostageCrisis = [
  RemoveInfluence(
    player: USSR,
    influence: US,
    countries: [Iran],
    limit_per_country: all_influence(US)
  ),
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: [Iran],
    limit_per_country: 2
  )
]

CampDavidAccords = [
  AwardVictoryPoints(
    player: US,
    amount: 1
  ),
  AddInfluence(
    player: US,
    influence: US,
    countries: [Israel, Jordan, Egypt],
    limit_per_country: 1
  )
]

JohnPaulIiElectedPope = [
  RemoveInfluence(
    player: US,
    influence: USSR,
    countries: [Poland],
    limit_per_country: 2
  ),
  AddInfluence(
    player: US,
    influence: US,
    countries: [Poland],
    limit_per_country: 1
  )
]

MarshallPlan = [
  AddInfluence(
    player: US,
    influence: US,
    countries: lambda {
      Countries.select { |c| c.in?(WesternEurope) && !c.controlled_by?(USSR) }
    },
    limit_per_country: 1,
    total_influence: 7
  )
]

WarsawPactFormed = [
  Either(
    AnyFour(
      Countries.select { |c| c.in?(EasternEurope) }.map do |eeuc|
        RemoveInfluence(
          player: USSR,
          influence: US,
          countries: [eeuc],
          limit_per_country: all_influence(US)
        )
      end
    ),
    AddInfluence(
      player: USSR,
      influence: USSR,
      countries: [EasternEurope],
      limit_per_country: 2,
      total_influence: 5
    )
  )
]

AnEvilEmpire = [
  Cancels(FlowerPower),
  AwardVictoryPoints(
    player: US,
    amount: 1
  )
]

ReaganBombsLibya = [
  AwardVictoryPoints(
    player: US,
    amount: lambda { |game| game.country(:libya).influence(USSR) / 2 }
  )
]

Opec = [
  PreventedBy(NorthSeaOil),
  AwardVictoryPoints(
    player: USSR,
    amount: lambda do |game|
      [Egypt, Iran, Libya, SaudiArabia, Iraq, GulfStates, Venezuela].map do |c|
        c.controlled_by?(USSR) ? 1 : 0
      end.reduce(:+)
    end
  )
]

AllianceForProgress = [
  AwardVictoryPoints(
    player: US,
    amount: lambda do |game|
      game.countries.
        select { |c| c.in?(CentralAmerica) || c.in?(SouthAmerica) }.
        select { |c| c.battleground? }.
        select { |c| c.controlled_by?(US) }.
        size
    end
  )
]

KitchenDebates = [
  AwardVictoryPoints(
    player: US,
    amount: lambda do |game|
      battlegrounds = game.countries.select { |c| c.battleground? }

      ussr = battlegrounds.select { |c| c.controlled_by?(USSR) }
      us   = battlegrounds.select { |c| c.controlled_by?(US) }

      us > ussr ? 2 : 0
    end
  )
]

IranIraqWar = [
  War(
    ops: 2,
    player: lambda { player },
    countries: [Iran, Iraq],
    subtract: lambda do |invaded_country|
      invaded_country.neighbors.
        select { |c| c.controlled_by?(player.opponent) }.
        size
    end,
    victory_rolls: 4..6,
    victory_vp: 2
  )
]

BrushWar = [
  War(
    ops: 3,
    player: lambda { player },
    countries: lambda do |game|
      # Remove US-controlled EU countries if Nato is in effect
      countries = game.played?(Nato, :event) ?
        Countries.reject { |c| c.in?(Europe) && c.controlled_by?(US) } :
        Countries.all

      countries.select { |c| [1,2].include?(c.stability) }
    end,
    subtract: lambda do |invaded_country|
      invaded_country.neighbors.
        select { |c| c.controlled_by?(player.opponent) }.
        size
    end,
    victory_rolls: 3..6,
    victory_vp: 1
  )
]

ArabIsraeliWar = [
  PreventedBy(CampDavidAccords),
  War(
    ops: 2,
    player: USSR,
    countries: [Israel],
    subtract: lambda do |invaded_country|
      [invaded_country, *invaded_country.neighbors].
        select { |c| c.controlled_by?(US) }.
        size
    end,
    victory_rolls: 4..6,
    victory_vp: 2
  )
]

IndoPakistaniWar = [
  War(
    player: lambda { player },
    ops: 2,
    countries: [India, Pakistan],
    subtract: lambda do |invaded_country|
      invaded_country.neighbors.
        select { |c| c.controlled_by?(player.opponent) }.
        size
    end,
    victory_rolls: 4..6,
    victory_vp: 2
  )
]

KoreanWar = [
  War(
    player: USSR,
    ops: 2,
    countries: [SouthKorea],
    subtract: lambda do |invaded_country|
      invaded_country.neighbors.
        select { |c| c.controlled_by?(US) }.
        size
    end,
    victory_rolls: 4..6,
    victory_vp: 2
  )
]

OrtegaElectedInNicaragua = [
  RemoveInfluence(
    player: USSR,
    influence: US,
    countries: [Nicaragua],
    limit_per_country: all_influence(US)
  ),
  Either(
    FreeCoup(
      player: USSR,
      countries: [Nicaragua],
      ops: 2
    ),
    Noop()
  )
]

TearDownThisWall = [
  Cancels(WillyBrandt),
  AddInfluence(
    player: US,
    influence: US,
    countries: [EastGermany],
    limit_per_country: 3
  ),
  Either(
    FreeCoup(
      player: US,
      countries: [Europe],
      ops: 3
    ),
    Realignment(
      # TODO
    ),
    Noop()
  )
]

Junta = [
  AddInfluence(
    player: lambda { player },
    influence: lambda { player },
    countries: [CentralAmerica, SouthAmerica],
    limit_per_country: 2,
    total_countries: 1
  ),
  Either(
    FreeCoup(
      player: lambda { player },
      countries: [CentralAmerica, SouthAmerica],
      ops: 2
    ),
    Realignment(
      # TODO
    ),
    Noop()
  )
]

NuclearTestBan = [
  AwardVictoryPoints(
    player: lambda { player },
    amount: lambda { game.defcon - 2 }
  ),
  ChangeDefcon(amount: 2)
]

DuckAndCover = [
  ChangeDefcon(amount: -1),
  AwardVictoryPoints(
    player: US,
    amount: lambda { 5 - game.defcon }
  )
]

CapturedNaziScientist = [
  AdvanceSpaceRace(amount: 1)
]

OneSmallStep = [
  AdvanceSpaceRace(
    amount: lambda {
      game.space_race(player) < game.space_race(player.opponent) ? 2 : 0
    }
  )
]

HowILearnedToStopWorrying = [
  ExpectMove(
    move: ChangeDefcon,
    player: lambda { player }
  ),
  AddMilitaryOps(
    player: lambda { player },
    amount: 5
  )
]

ArmsRace = [
  AwardVictoryPoints(
    player: lambda { player },
    amount: lambda {
      more = game.military_ops(player) > game.military_ops(player.opponent)
      met  = game.military_ops(player) >= game.required_military_ops

      if    more && met then 3
      elsif met         then 1
      else  0
      end
    }
  )
]

## Modifiers

FlowerPower = [
  PreventedBy(AnEvilEmpire),
  AddModifier(Modifiers::FlowerPower)
]

WAR_CARDS = [
  ArabIsraeliWar, KoreanWar, BrushWar, IndoPakistaniWar, IranIraqWar
]

# - on us play of any war card (or any war card except arab-israeli if camp
#   david has been played)
# - award the USSR 2 vp.
Modifiers::FlowerPower = [
  Modifier(
    on: CardPlay(
      player: US,
      played_for: [:event, :operations], # operations: (influence,coup,realign)
      card: lambda {
        game.played?(CampDavidAccords, :event) ?
          WAR_CARDS - [ArabIsraeliWar] :
          WAR_CARDS
      }
    ),
    actions: [
      AwardVictoryPoints(player: USSR, amount: 2)
    ]
  )
]

BearTrap = [
  AddModifier(Modifiers::BearTrap)
]

# - fires before each USSR action round
# - cancelled by discarding >= 2 ops AND die roll 1-4
# - if not cancelled, USSR can play a zero-op (scoring) card if they have one.
Modifiers::BearTrap = [
  Modifier(
    before: ActionRound(player: USSR),
    cancel_challenge: [
      Discard(player: USSR, ops: 2),
      DieRoll(player: USSR, value: 1..4)
    ],
    cancel_failure: [
      CardPlay(player: USSR, max_ops: 0), # USSR must satisfy this if they
                                          # have a suitable card
      ActionRoundEnd(player: USSR)
    ]
  )
]

Quagmire = [
  AddModifier(Modifiers::Quagmire)
]

# TODO: Same as bear trap, just swap USSR for US.
Modifiers::Quagmire = Modifiers::BearTrap

CubanMissileCrisis = [
  SetDefcon(amount: 2),
  AddModifier(Modifiers::CubanMissileCrisis)
]

# - A coup anywhere by anyone
# - Triggers a game end for the opponent (they lose)
# - Canceled at any time by USSR removing 2 influence from Cuba, or
#   US removing 2 influence from WG or Turkey
Modifiers::CubanMissileCrisis = [
  Modifier(
    on: Coup(),
    triggers: GameEnd(
      player: lambda { player.opponent }
    ),
    cancel: [ # Checks event history on each 'tick' for any of these matches
      Either(
        Match(
          item: RemoveInfluence,
          player: USSR,
          country: Cuba,
          amount: 2
        ),
        Match(
          item: RemoveInfluence,
          player: US,
          country: WestGermany,
          amount: 2
        ),
        Match(
          item: RemoveInfluence,
          player: US,
          country: Turkey,
          amount: 2
        ),
        Match(
          item: TurnEnd
        )
      )
    ]

  )
]

Containment = [
  AddModifier(Containment)
]

Modifiers::Containment = [
  ScoreModifier(
    player: US,
    type: :ops, # anywhere an ops score is evaluated.
    amount: +1,
    max: 4,
    cancel: TurnEnd
  )
]

BrezhnevDoctrine = [
  AddModifier(Modifiers::BrezhnevDoctrine)
]

Modifiers::BrezhnevDoctrine = [
  ScoreModifier(
    player: USSR,
    type: :ops,
    amount: +1,
    max: 4,
    cancel: TurnEnd
  )
]

RedScarePurge = [
  AddModifier(Modifiers::RedScarePurge)
]

Modifiers::RedScarePurge = [
  ScoreModifier(
    player: lambda { player },
    type: :ops,
    amount: -1,
    mininum: 1,
    cancel: TurnEnd
  )
]

LatinAmericanDeathSquads = [
  AddModifier(Modifiers::LatinAmericanDeathSquads)
]

Modifiers::LatinAmericanDeathSquads = [
  ScoreModifier(
    player: lambda { player },
    type: :coup,
    countries: [CentralAmerica, SouthAmerica],
    amount: +1,
    cancel: TurnEnd
  ),
  ScoreModifier(
    player: lambda { player.opponent },
    type: :coup,
    countries: [CentralAmerica, SouthAmerica],
    amount: -1,
    cancel: TurnEnd
  )
]

VietnamRevolts = [
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: [Vietnam],
    limit_per_country: 2
  ),
  AddModifier(Modifiers::VietnamRevolts)
]

Modifiers::VietnamRevolts = [
  ScoreModifier(
    player: USSR,
    type: :ops,
    countries: [SoutheastAsia],
    amount: +1,
    cancel: TurnEnd
  )
]

IranContraScandal = [
  AddModifier(Modifiers::IranContraScandal)
]

Modifiers::IranContraScandal = [
  ScoreModifier(
    player: US,
    type: :realignment,
    amount: -1,
    cancel: TurnEnd
  )
]

SaltNegotiations = [
  ChangeDefcon(amount: 2),
  AddModifier(Modifiers::SaltNegotiations),
  # getting cards from pile - TODO
]

Modifiers::SaltNegotiations = [
  ScoreModifier(
    player: nil, # this affects both players!
    type: :coup,
    amount: -1,
    cancel: TurnEnd
  )
]


TheReformer = [
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: [Europe],
    limit_per_country: 2,
    total_influence: lambda { |game| game.vp < 0 ? 6: 4 }
  ),
  AddModifier(Modifiers::TheReformer) #TODO
]

WillyBrandt = [
  PreventedBy(TearDownThisWall),
  AwardVictoryPoints(
    player: USSR,
    amount: 1
  ),
  AddInfluence(
    player: USSR,
    influence: USSR,
    countries: [WestGermany],
    limit_per_country: 1
  ),
  AddModifier(Modifiers::WillyBrandt) #TODO
]


