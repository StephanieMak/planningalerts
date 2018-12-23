# frozen_string_literal: true

require File.dirname(__FILE__) + "/../spec_helper"

describe "GeocodeService" do
  describe "valid location" do
    before :each do
      @result = double(success: true, all: [double(country_code: "AU", lat: -33.772609, lng: 150.624263, accuracy: 6, city: "Glenbrook", state: "NSW", zip: "2773", full_address: "24 Bruce Road, Glenbrook, NSW 2773, Australia")])
      expect(Geokit::Geocoders::GoogleGeocoder).to receive(:geocode).with("24 Bruce Road, Glenbrook, NSW 2773", bias: "au").and_return(@result)
      @loc = GeocodeService.call("24 Bruce Road, Glenbrook, NSW 2773")
    end

    it "should geocode an address into a latitude and longitude by using the Google service" do
      expect(@loc.top.lat).to eq(-33.772609)
      expect(@loc.top.lng).to eq(150.624263)
    end

    it "should not error" do
      expect(@loc.error).to be_nil
    end
  end

  it "should return nil if the address to geocode isn't valid" do
    expect(Geokit::Geocoders::GoogleGeocoder).to receive(:geocode).with("", bias: "au").and_return(double(success: false, lat: nil, lng: nil, country_code: nil, accuracy: nil, all: []))
    l = GeocodeService.call("")
    expect(l.top).to be_nil
  end

  it "should error if the address is empty" do
    allow(Geokit::Geocoders::GoogleGeocoder).to receive(:geocode).and_return(double(success: false, all: [], lat: nil, lng: nil, country_code: nil, accuracy: nil))

    l = GeocodeService.call("")
    expect(l.error).to eq("Please enter a street address")
  end

  it "should error if the address is not valid" do
    allow(Geokit::Geocoders::GoogleGeocoder).to receive(:geocode).and_return(double(success: false, lat: nil, lng: nil, country_code: nil, accuracy: nil, all: []))

    l = GeocodeService.call("rxsd23dfj")
    expect(l.error).to eq("Sorry we don’t understand that address. Try one like ‘1 Sowerby St, Goulburn, NSW’")
  end

  it "should error if the street address is not in australia" do
    allow(Geokit::Geocoders::GoogleGeocoder).to receive(:geocode).and_return(double(success: true, lat: 1, lng: 2, country_code: "US", city: "New York", state: "NY", zip: nil, full_address: "New York, NY", accuracy: nil, all: [double(lat: 1, lng: 2, country_code: "US", city: "New York", state: "NY", zip: nil, full_address: "New York, NY", accuracy: nil)]))

    l = GeocodeService.call("New York")
    expect(l.error).to eq("Unfortunately we only cover Australia. It looks like that address is in another country.")
  end

  it "should not error if there are multiple matches from the geocoder" do
    allow(Geokit::Geocoders::GoogleGeocoder).to receive(:geocode).and_return(double(success: true, all:
      [double(country_code: "AU", lat: 1, lng: 2, accuracy: 6, city: "Glenbrook", state: "NSW", zip: nil, full_address: "Bruce Road, Glenbrook, NSW, Australia"), double(country_code: "AU", lat: 1.1, lng: 2.1, accuracy: 6, city: "Somewhere else", state: "VIC", zip: nil, full_address: "Bruce Road, Somewhere else, VIC, Australia")]))

    l = GeocodeService.call("Bruce Road")
    expect(l.error).to be_nil
  end

  it "should error if the address is not a full street address but rather a suburb name or similar" do
    allow(Geokit::Geocoders::GoogleGeocoder).to receive(:geocode).and_return(double(success: true, all: [double(country_code: "AU", lat: 1, lng: 2, accuracy: 4, city: "Glenbrook", state: "NSW", zip: nil, full_address: "Glenbrook NSW, Australia")]))

    l = GeocodeService.call("Glenbrook, NSW")
    expect(l.error).to eq("Please enter a full street address like ‘36 Sowerby St, Goulburn, NSW’")
  end

  it "should list potential matches and they should be in Australia" do
    m = double(full_address: "Bathurst Rd, Orange NSW 2800, Australia", country_code: "AU", lat: nil, lng: nil, city: "Orange", state: "NSW", zip: "2800", accuracy: nil, success: true)
    all = [
      m,
      double(full_address: "Bathurst Rd, Katoomba NSW 2780, Australia", country_code: "AU", lat: nil, lng: nil, city: "Katoomba", state: "NSW", zip: "2780", accuracy: nil),
      double(full_address: "Bathurst Rd, Staplehurst, Kent TN12 0, UK", country_code: "UK", lat: nil, lng: nil, city: "Staplehurst", state: "Kent", zip: "TN12 0", accuracy: nil),
      double(full_address: "Bathurst Rd, Cape Town 7708, South Africa", country_code: "ZA", lat: nil, lng: nil, city: "Cape Town", state: nil, zip: "7708", accuracy: nil),
      double(full_address: "Bathurst Rd, Winnersh, Wokingham RG41 5, UK", country_code: "UK", lat: nil, lng: nil, city: "Winnersh", state: "Wokingham", zip: "RG41 5", accuracy: nil),
      double(full_address: "Bathurst Rd, Catonsville, MD 21228, USA", country_code: "US", lat: nil, lng: nil, city: "Catonsville", state: "MD", zip: "21228", accuracy: nil),
      double(full_address: "Bathurst Rd, Durban South 4004, South Africa", country_code: "ZA", lat: nil, lng: nil, city: "Durban South", state: nil, zip: "4004", accuracy: nil),
      double(full_address: "Bathurst Rd, Port Kennedy WA 6172, Australia", country_code: "AU", lat: nil, lng: nil, city: "Port Kennedy", state: "WA", zip: "6172", accuracy: nil),
      double(full_address: "Bathurst Rd, Campbell River, BC V9W, Canada", country_code: "CA", lat: nil, lng: nil, city: "Campbell River", state: "BC", zip: "V9W", accuracy: nil),
      double(full_address: "Bathurst Rd, Riverside, CA, USA", country_code: "US", lat: nil, lng: nil, city: "Riverside", state: "CA", zip: nil, accuracy: nil)
    ]
    allow(m).to receive_messages(all: all)
    allow(Geokit::Geocoders::GoogleGeocoder).to receive(:geocode).and_return(double(success: true, all: all))
    l = GeocodeService.call("Bathurst Rd")
    all = l.all
    expect(all.count).to eq(3)
    expect(all[0].full_address).to eq("Bathurst Rd, Orange NSW 2800")
    expect(all[1].full_address).to eq("Bathurst Rd, Katoomba NSW 2780")
    expect(all[2].full_address).to eq("Bathurst Rd, Port Kennedy WA 6172")
  end

  it "the first match should only return addresses in Australia" do
    m = double(full_address: "Sowerby St, Garfield NSW 2580, Australia", country_code: "AU", lat: nil, lng: nil, city: "Garfield", state: "NSW", zip: "2580", accuracy: nil, success: true)
    all = [
      double(full_address: "Sowerby St, Lawrence 9532, New Zealand", country_code: "NZ", lat: nil, lng: nil, city: "Lawrence", state: nil, zip: "9532", accuracy: nil),
      m,
      double(full_address: "Sowerby St, Sowerby, Halifax, Calderdale HX6 3, UK", country_code: "UK", lat: nil, lng: nil, city: "Sowerby", state: "Calderdale", zip: "HX6 3", accuracy: nil),
      double(full_address: "Sowerby St, Burnley, Lancashire BB12 8, UK", country_code: "UK", lat: nil, lng: nil, city: "Burnley", state: "Lancashire", zip: "BB12 8", accuracy: nil)
    ]
    allow(m).to receive_messages(all: all)
    allow(Geokit::Geocoders::GoogleGeocoder).to receive(:geocode).and_return(double(success: true, full_address: "Sowerby St, Lawrence 9532, New Zealand", all: all))
    l = GeocodeService.call("Sowerby St")
    expect(l.top.full_address).to eq("Sowerby St, Garfield NSW 2580")
    all = l.all
    expect(all.count).to eq(1)
    expect(all[0].full_address).to eq("Sowerby St, Garfield NSW 2580")
  end
end
