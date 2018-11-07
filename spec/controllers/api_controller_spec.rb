require "spec_helper"

describe ApiController do
  shared_examples "an authenticated API" do
    shared_examples "not authorised" do
      it { expect(subject.status).to eq 401 }
      it { expect(subject.body).to eq '{"error":"not authorised - use a valid api key - https://www.openaustraliafoundation.org.au/2015/03/02/planningalerts-api-changes"}' }
    end

    context "no API key is given" do
      subject { get method, params.merge(key: nil) }
      include_examples "not authorised"
    end

    context "invalid API key is given" do
      subject { get method, params.merge(key: "jsdfhsd") }
      include_examples "not authorised"
    end

    context "user has API access disabled" do
      subject do
        user = FactoryGirl.create(:user, api_disabled: true)
        get method, params.merge(key: user.api_key)
      end
      include_examples "not authorised"
    end
  end

  let(:user) { create(:user, email: "foo@bar.com", password: "foofoo") }

  describe "#all" do
    describe "rss" do
      it "should not support rss" do
        expect { get :all, format: "rss", key: user.api_key }.to raise_error ActionController::UnknownFormat
      end
    end

    describe "json" do
      it_behaves_like "an authenticated API" do
        let(:method) { :all }
        let(:params) { { format: "js" } }
      end

      it "should error if valid api key is given but no bulk api access" do
        VCR.use_cassette("planningalerts") do
          result = create(:application, id: 10, date_scraped: Time.utc(2001, 1, 1))
          allow(Application).to receive_message_chain(:where, :paginate).and_return([result])
        end
        get :all, key: user.api_key, format: "js"
        expect(response.status).to eq(401)
        expect(response.body).to eq('{"error":"no bulk api access"}')
      end

      it "should find recent applications if api key is given" do
        user.update_attribute(:bulk_api, true)
        VCR.use_cassette("planningalerts") do
          authority = create(:authority, full_name: "Acme Local Planning Authority")
          result = create(:application, id: 10, date_scraped: Time.utc(2001, 1, 1), authority: authority)
          allow(Application).to receive_message_chain(:where, :paginate).and_return([result])
        end
        get :all, key: user.api_key, format: "js"
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq(
          "application_count" => 1,
          "max_id" => 10,
          "applications" => [{
            "application" => {
              "id" => 10,
              "council_reference" => "001",
              "address" => "A test address",
              "description" => "Pretty",
              "info_url" => "http://foo.com",
              "comment_url" => nil,
              "lat" => nil,
              "lng" => nil,
              "date_scraped" => "2001-01-01T00:00:00.000Z",
              "date_received" => nil,
              "on_notice_from" => nil,
              "on_notice_to" => nil,
              "no_alerted" => nil,
              "authority" => {
                "full_name" => "Acme Local Planning Authority"
              }
            }
          }]
        )
      end
    end
  end

  describe "#postcode" do
    # TODO: Make errors work with rss format
    it_behaves_like "an authenticated API" do
      let(:method) { :postcode }
      let(:params) { { format: "js", postcode: "2780" } }
    end

    it "should find recent applications for a postcode" do
      result = double
      scope = double
      expect(Application).to receive(:where).with(postcode: "2780").and_return(scope)
      expect(scope).to receive(:paginate).with(page: nil, per_page: 100).and_return(result)
      get :postcode, key: user.api_key, format: "rss", postcode: "2780"
      expect(assigns[:applications]).to eq(result)
      expect(assigns[:description]).to eq("Recent applications in postcode 2780")
    end

    it "should support jsonp" do
      VCR.use_cassette("planningalerts") do
        authority = create(:authority, full_name: "Acme Local Planning Authority")
        result = create(:application, id: 10, date_scraped: Time.utc(2001, 1, 1), authority: authority)
        allow(Application).to receive_message_chain(:where, :paginate).and_return([result])
      end
      xhr :get, :postcode, key: user.api_key, format: "js", postcode: "2780", callback: "foobar"
      expect(response.body[0..10]).to eq("/**/foobar(")
      expect(response.body[-1..-1]).to eq(")")
      expect(JSON.parse(response.body[11..-2])).to eq(
        [{
          "application" => {
            "id" => 10,
            "council_reference" => "001",
            "address" => "A test address",
            "description" => "Pretty",
            "info_url" => "http://foo.com",
            "comment_url" => nil,
            "lat" => nil,
            "lng" => nil,
            "date_scraped" => "2001-01-01T00:00:00.000Z",
            "date_received" => nil,
            "on_notice_from" => nil,
            "on_notice_to" => nil,
            "no_alerted" => nil,
            "authority" => {
              "full_name" => "Acme Local Planning Authority"
            }
          }
        }]
      )
    end

    it "should support json api version 2" do
      VCR.use_cassette("planningalerts") do
        authority = create(:authority, full_name: "Acme Local Planning Authority")
        application = create(:application, id: 10, date_scraped: Time.utc(2001, 1, 1), authority: authority)
        result = [application]
        allow(result).to receive(:total_pages).and_return(5)
        allow(Application).to receive_message_chain(:where, :paginate).and_return(result)
      end
      get :postcode, key: user.api_key, format: "js", v: "2", postcode: "2780"
      expect(JSON.parse(response.body)).to eq(
        "application_count" => 1,
        "page_count" => 5,
        "applications" => [{
          "application" => {
            "id" => 10,
            "council_reference" => "001",
            "address" => "A test address",
            "description" => "Pretty",
            "info_url" => "http://foo.com",
            "comment_url" => nil,
            "lat" => nil,
            "lng" => nil,
            "date_scraped" => "2001-01-01T00:00:00.000Z",
            "date_received" => nil,
            "on_notice_from" => nil,
            "on_notice_to" => nil,
            "no_alerted" => nil,
            "authority" => {
              "full_name" => "Acme Local Planning Authority"
            }
          }
        }]
      )
    end
  end

  describe "#point" do
    it_behaves_like "an authenticated API" do
      let(:method) { :point }
      let(:params) { { format: "js", address: "24 Bruce Road Glenbrook", radius: 4000 } }
    end

    describe "failed search by address" do
      it "should error if some unknown parameters are included" do
        get :point, format: "rss", address: "24 Bruce Road Glenbrook", radius: 4000, foo: 200, bar: "fiddle"
        expect(response.body).to eq("Bad request: Invalid parameter(s) used: bar, foo")
        expect(response.code).to eq("400")
      end
    end

    describe "search by address" do
      before :each do
        location = double(lat: 1.0, lng: 2.0, full_address: "24 Bruce Road, Glenbrook NSW 2773")
        @result = double

        expect(Location).to receive(:geocode).with("24 Bruce Road Glenbrook").and_return(location)
        allow(Application).to receive_message_chain(:near, :paginate).and_return(@result)
      end

      it "should find recent applications near the address" do
        get :point, key: user.api_key, format: "rss", address: "24 Bruce Road Glenbrook", radius: 4000
        expect(assigns[:applications]).to eq(@result)
        # Should use the normalised form of the address in the description
        expect(assigns[:description]).to eq("Recent applications within 4 km of 24 Bruce Road, Glenbrook NSW 2773")
      end

      it "should find recent applications near the address using the old parameter name" do
        get :point, key: user.api_key, format: "rss", address: "24 Bruce Road Glenbrook", area_size: 4000
        expect(assigns[:applications]).to eq(@result)
        expect(assigns[:description]).to eq("Recent applications within 4 km of 24 Bruce Road, Glenbrook NSW 2773")
      end

      it "should log the api call" do
        get :point, key: user.api_key, format: "rss", address: "24 Bruce Road Glenbrook", radius: 4000
        a = ApiStatistic.first
        expect(a.ip_address).to eq("0.0.0.0")
        expect(a.query).to eq("/applications.rss?address=24+Bruce+Road+Glenbrook&key=#{CGI.escape(user.api_key)}&radius=4000")
      end

      it "should use a search radius of 2000 when none is specified" do
        result = double
        allow(Application).to receive_message_chain(:near, :paginate).and_return(result)

        get :point, key: user.api_key, address: "24 Bruce Road Glenbrook", format: "rss"
        expect(assigns[:applications]).to eq(result)
        expect(assigns[:description]).to eq("Recent applications within 2 km of 24 Bruce Road, Glenbrook NSW 2773")
      end
    end

    describe "search by lat & lng" do
      before :each do
        @result = double

        allow(Application).to receive_message_chain(:near, :paginate).and_return(@result)
      end

      it "should find recent applications near the point" do
        get :point, key: user.api_key, format: "rss", lat: 1.0, lng: 2.0, radius: 4000
        expect(assigns[:applications]).to eq(@result)
        expect(assigns[:description]).to eq("Recent applications within 4 km of 1.0,2.0")
      end

      it "should find recent applications near the point using the old parameter name" do
        get :point, key: user.api_key, format: "rss", lat: 1.0, lng: 2.0, area_size: 4000
        expect(assigns[:applications]).to eq(@result)
        expect(assigns[:description]).to eq("Recent applications within 4 km of 1.0,2.0")
      end
    end
  end

  describe "#area" do
    it_behaves_like "an authenticated API" do
      let(:method) { :area }
      let(:params) do
        { format: "js", bottom_left_lat: 1.0, bottom_left_lng: 2.0,
          top_right_lat: 3.0, top_right_lng: 4.0 }
      end
    end

    it "should find recent applications in an area" do
      result = double
      scope = double
      expect(Application).to receive(:where).with("lat > ? AND lng > ? AND lat < ? AND lng < ?", 1.0, 2.0, 3.0, 4.0).and_return(scope)
      expect(scope).to receive(:paginate).with(page: nil, per_page: 100).and_return(result)

      get :area,
          key: user.api_key,
          format: "rss",
          bottom_left_lat: 1.0,
          bottom_left_lng: 2.0,
          top_right_lat: 3.0,
          top_right_lng: 4.0
      expect(assigns[:applications]).to eq(result)
      expect(assigns[:description]).to eq("Recent applications in the area (1.0,2.0) (3.0,4.0)")
    end
  end

  describe "#authority" do
    it_behaves_like "an authenticated API" do
      let(:method) { :authority }
      let(:params) { { format: "js", authority_id: "blue_mountains" } }
    end

    it "should find recent applications for an authority" do
      authority = double
      result = double
      scope = double

      expect(Authority).to receive(:find_by_short_name_encoded).with("blue_mountains").and_return(authority)
      expect(authority).to receive(:applications).and_return(scope)
      expect(scope).to receive(:paginate).with(page: nil, per_page: 100).and_return(result)
      expect(authority).to receive(:full_name_and_state).and_return("Blue Mountains City Council")

      get :authority, key: user.api_key, format: "rss", authority_id: "blue_mountains"
      expect(assigns[:applications]).to eq(result)
      expect(assigns[:description]).to eq("Recent applications from Blue Mountains City Council")
    end
  end

  describe "#suburb" do
    it_behaves_like "an authenticated API" do
      let(:method) { :suburb }
      let(:params) { { format: "js", suburb: "Katoomba" } }
    end

    it "should find recent applications for a suburb" do
      result = double
      scope = double
      expect(Application).to receive(:where).with(suburb: "Katoomba").and_return(scope)
      expect(scope).to receive(:paginate).with(page: nil, per_page: 100).and_return(result)
      get :suburb, key: user.api_key, format: "rss", suburb: "Katoomba"
      expect(assigns[:applications]).to eq(result)
      expect(assigns[:description]).to eq("Recent applications in Katoomba")
    end

    describe "search by suburb and state" do
      it "should find recent applications for a suburb and state" do
        result = double
        scope1 = double
        scope2 = double
        expect(Application).to receive(:where).with(suburb: "Katoomba").and_return(scope1)
        expect(scope1).to receive(:where).with(state: "NSW").and_return(scope2)
        expect(scope2).to receive(:paginate).with(page: nil, per_page: 100).and_return(result)
        get :suburb, key: user.api_key, format: "rss", suburb: "Katoomba", state: "NSW"
        expect(assigns[:applications]).to eq(result)
        expect(assigns[:description]).to eq("Recent applications in Katoomba, NSW")
      end
    end
  end

  describe "#date_scraped" do
    it_behaves_like "an authenticated API" do
      let(:method) { :date_scraped }
      let(:params) { { format: "js", date_scraped: "2015-05-06" } }
    end

    context "valid api key is given but no bulk api access" do
      subject { get :date_scraped, key: FactoryGirl.create(:user).api_key, format: "js", date_scraped: "2015-05-06" }

      it { expect(subject.status).to eq 401 }
      it { expect(subject.body).to eq '{"error":"no bulk api access"}' }
    end

    context "valid authentication" do
      let(:user) { FactoryGirl.create(:user, bulk_api: true) }
      before(:each) do
        VCR.use_cassette("planningalerts", allow_playback_repeats: true) do
          FactoryGirl.create_list(:application, 5, date_scraped: DateTime.new(2015, 5, 5, 12, 0, 0))
          FactoryGirl.create_list(:application, 5, date_scraped: DateTime.new(2015, 5, 6, 12, 0, 0))
        end
      end
      subject { get :date_scraped, key: user.api_key, format: "js", date_scraped: "2015-05-06" }

      it { expect(subject).to be_success }
      it { expect(JSON.parse(subject.body).count).to eq 5 }

      context "invalid date" do
        subject { get :date_scraped, key: user.api_key, format: "js", date_scraped: "foobar" }
        it { expect(subject).to_not be_success }
        it { expect(subject.body).to eq '{"error":"invalid date_scraped"}' }
      end
    end
  end
end
