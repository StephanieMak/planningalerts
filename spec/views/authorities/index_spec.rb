require "spec_helper"

describe "authorities/index.haml" do
  it "should show a list of the authorities" do
    a1 = mock_model(Authority, full_name: "Wombat District Council", short_name_encoded: "wombat", morph_url: nil, broken?: false, covered?: false)
    a2 = mock_model(Authority, full_name: "Kangaroo City Council", short_name_encoded: "kangaroo", morph_url: nil, broken?: false, covered?: false)
    assign(:authorities, [["NSW", [a1, a2]]])
    render
    expect(rendered).to have_content(a1.full_name)
    expect(rendered).to have_content(a2.full_name)
  end
end
