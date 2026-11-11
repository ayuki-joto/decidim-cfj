# frozen_string_literal: true

# Build the permission context of a GraphQL object from that object's own
# space and component instead of reusing whatever an earlier field of the
# same query stored in the shared context.
#
# Backport of decidim/decidim#17915 (0.32.2). The guard fails the boot from
# that version on so this file and its spec get removed with the upgrade.
raise "api_permission_context_override.rb and its spec should be removed (decidim/decidim#17915)" if Gem::Version.new(Decidim::Core.version) >= Gem::Version.new("0.32.2")

Rails.application.config.to_prepare do
  module DecidimApiPermissionContextPatch
    def local_context(object, context)
      participatory_space = participatory_space_for(object)
      component = component_for(object)

      context[:current_participatory_space] = participatory_space if participatory_space
      context[:current_component] = component if component

      context.to_h
    end

    private

    def participatory_space_for(object)
      return object.participatory_space if object.respond_to?(:participatory_space)
      return object if object.is_a?(Decidim::Participable)

      component_for(object)&.participatory_space
    end

    def component_for(object)
      return object if object.is_a?(Decidim::Component)

      object.component if object.respond_to?(:component)
    end
  end

  Decidim::Api::GraphqlPermissions::ClassMethods.prepend(DecidimApiPermissionContextPatch)
end
