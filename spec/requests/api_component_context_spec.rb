# frozen_string_literal: true

require "rails_helper"

# Covers config/initializers/api_permission_context_override.rb.
RSpec.describe "GraphQL component query across spaces" do
  let(:organization) { create(:organization) }
  let(:public_process) { create(:participatory_process, :published, organization:) }
  let(:restricted_process) { create(:participatory_process, :published, :restricted, organization:) }
  let!(:public_component) { create(:proposal_component, :published, participatory_space: public_process) }
  let!(:restricted_component) { create(:proposal_component, :published, participatory_space: restricted_process) }
  let(:current_user) { nil }
  let(:query) do
    %({
      publicComponent: component(id: "#{public_component.id}") { id }
      restrictedComponent: component(id: "#{restricted_component.id}") { id }
    })
  end
  let(:scopes) { Doorkeeper::OAuth::Scopes.from_string("api:read") }
  let(:result) do
    Decidim::Api::Schema.execute(query, context: { current_organization: organization, current_user:, scopes: }).to_h
  end

  context "when the visitor is anonymous" do
    it "does not expose the component of the restricted space" do
      expect(result["data"]).to eq(
        "publicComponent" => { "id" => public_component.id.to_s },
        "restrictedComponent" => nil
      )
      expect(result["errors"].map { |error| error["extensions"]["code"] }).to eq(["UNAUTHORIZED_OBJECT_ERROR"])
    end

    context "when only the public component is requested" do
      let(:query) { %({ component(id: "#{public_component.id}") { id } }) }

      it "resolves it" do
        expect(result["data"]).to eq("component" => { "id" => public_component.id.to_s })
      end
    end
  end

  context "when the user is an admin of the restricted space" do
    let(:current_user) { create(:user, :confirmed, organization:) }

    before do
      create(:participatory_process_user_role, participatory_process: restricted_process, user: current_user, role: "admin")
    end

    it "resolves both components" do
      expect(result["data"]).to eq(
        "publicComponent" => { "id" => public_component.id.to_s },
        "restrictedComponent" => { "id" => restricted_component.id.to_s }
      )
    end
  end
end
