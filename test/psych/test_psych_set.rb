# frozen_string_literal: true
require_relative 'helper'

module Psych
  class TestPsychSet < TestCase
    def setup
      super
      @set = Psych::Set.new
      @set['foo'] = 'bar'
      @set['bar'] = 'baz'
    end

    def test_dump
      assert_match(/!set/, Psych.dump(@set))
    end

    def test_roundtrip
      assert_cycle(@set)
    end

    ###
    # FIXME: Syck should also support !!set as shorthand
    def test_load_from_yaml
      loaded = Psych.unsafe_load(<<-eoyml)
--- !set
foo: bar
bar: baz
      eoyml
      assert_equal(@set, loaded)
    end

    def test_loaded_class
      assert_instance_of(Psych::Set, Psych.unsafe_load(Psych.dump(@set)))
    end

    def test_set_shorthand
      loaded = Psych.unsafe_load(<<-eoyml)
--- !!set
foo: bar
bar: baz
      eoyml
      assert_instance_of(Psych::Set, loaded)
    end

    def test_set_self_reference
      @set['self'] = @set
      assert_cycle(@set)
    end

    def test_stringify_names
      @set[:symbol] = :value

      assert_match(/^:symbol: :value/, Psych.dump(@set))
      assert_match(/^symbol: :value/, Psych.dump(@set, stringify_names: true))
    end
  end
end
