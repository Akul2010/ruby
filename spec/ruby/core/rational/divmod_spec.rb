require_relative "../../spec_helper"

describe "Rational#divmod when passed a Rational" do
  it "returns the quotient as Integer and the remainder as Rational" do
    Rational(7, 4).divmod(Rational(1, 2)).should eql([3, Rational(1, 4)])
    Rational(7, 4).divmod(Rational(-1, 2)).should eql([-4, Rational(-1, 4)])
    Rational(0, 4).divmod(Rational(4, 3)).should eql([0, Rational(0, 1)])

    Rational(bignum_value, 4).divmod(Rational(4, 3)).should eql([3458764513820540928, Rational(0, 1)])
  end

  it "raises a ZeroDivisionError when passed a Rational with a numerator of 0" do
    -> { Rational(7, 4).divmod(Rational(0, 3)) }.should raise_error(ZeroDivisionError)
  end
end

describe "Rational#divmod when passed an Integer" do
  it "returns the quotient as Integer and the remainder as Rational" do
    Rational(7, 4).divmod(2).should eql([0, Rational(7, 4)])
    Rational(7, 4).divmod(-2).should eql([-1, Rational(-1, 4)])

    Rational(bignum_value, 4).divmod(3).should eql([1537228672809129301, Rational(1, 1)])
  end

  it "raises a ZeroDivisionError when passed 0" do
    -> { Rational(7, 4).divmod(0) }.should raise_error(ZeroDivisionError)
  end
end

describe "Rational#divmod when passed a Float" do
  it "returns the quotient as Integer and the remainder as Float" do
    Rational(7, 4).divmod(0.5).should eql([3, 0.25])
  end

  it "returns the quotient as Integer and the remainder as Float" do
    Rational(7, 4).divmod(-0.5).should eql([-4, -0.25])
  end

  it "raises a ZeroDivisionError when passed 0" do
    -> { Rational(7, 4).divmod(0.0) }.should raise_error(ZeroDivisionError)
  end
end
