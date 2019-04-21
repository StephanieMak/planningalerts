# frozen_string_literal: true

class CreateOrUpdateApplicationService < ApplicationService
  def initialize(
    authority:, council_reference:, attributes:
  )
    @authority = authority
    @council_reference = council_reference
    @attributes = attributes.stringify_keys
    # TODO: Do some sanity checking on the keys in attributes
    # TODO: Make sure that authority_id and council_reference are not
    # keys in attributes
  end

  # Returns created or updated application
  def call
    # First check if record already exists or create a new one if it doesn't
    application = Application.find_or_create_by!(
      authority: authority, council_reference: council_reference
    )
    create_version(application)
    application
  end

  private

  attr_reader :authority, :council_reference, :attributes

  def create_version(application)
    previous_version = application.current_version

    # If none of the data has changed don't save a new version
    return if previous_version && attributes == previous_version.attributes.slice(*attributes.keys)

    previous_version&.update(current: false)
    ApplicationVersion.create_version!(
      application_id: application.id,
      previous_version: previous_version,
      attributes: attributes
    )
    application.versions.reload
    application.reload_current_version
  end
end
