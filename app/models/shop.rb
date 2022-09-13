# frozen_string_literal: true

class Shop < ActiveRecord::Base
  def api_version
    ShopifyApp.configuration.api_version
  end
end
