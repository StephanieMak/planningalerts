# frozen_string_literal: true

module SignupHelper
  def draw_box_javascript(size)
    "preview(#{@alert.location.lat}, #{@alert.location.lng}, #{@zone_sizes[size]});"
  end
end
