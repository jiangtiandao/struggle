class Card
  attr_reader :ref, :id, :name, :phase, :ops, :side
  attr_reader :remove_after_event, :discard_after_event,
              :always_evaluate_first, :prevent_in_headline

  def initialize(**args)
    args.each { |k,v| instance_variable_set("@#{k}", v) }
  end

  def scoring?
    ops.zero?
  end

  def early?
    phase == :early
  end

  def inspect
    star = remove_after_event ? "*" : ""
    underline = "" # display on board until cancelled - TODO?

    "%3s: [%s %4s %-5s] %s%s%s%s" % [
      id, ops, side || '-', phase.to_s.upcase, underline, name, underline, star
    ]
  end

  # Make the getting of ops a special condition. Card ops should be
  # determined using an OpsResolver (TODO)

  private :ops

  def ops!
    @ops
  end

  def china_card?
    ref == "TheChinaCard"
  end

  def contains_event?
    !china_card?
  end
end

