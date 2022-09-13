# frozen_string_literal: true

module ShopifyApp
  class SessionsController < ActionController::Base
    include ShopifyApp::LoginProtection
    include ShopifyApp::RedirectForEmbedded

    layout false, only: :new

    after_action only: [:new, :create] do |controller|
      controller.response.headers.except!("X-Frame-Options")
    end

    def new
      authenticate if sanitized_shop_name.present?
      # sanitized_shop_name comes from ShopifyApp::SanitizedParams which is included by
      # both ShopifyApp::LoginProtection and ShopifyApp::RedirectForEmbedded:
      #
      # ShopifyApp::Utils.sanitize_shop_domain(params[:shop])
      #
      # When visiting install link for first time (i.e. /login), sanitized_shop_name.present?
      # is false, so authenticate is not called and gems/shopify_app-20.1.1/app/views/shopify_app/sessions/new.html.erb is rendered
      # user can enter shop name here
      #
      # When redirected here (aka to "top_level") after POST /login, shop name is present
      # and authenticate is called
    end

    def create
      authenticate
    end

    def top_level_interaction
      @url = login_url_with_optional_shop(top_level: true)
      validate_shop_presence
    end

    def destroy
      reset_session
      flash[:notice] = I18n.t(".logged_out")
      redirect_to(login_url_with_optional_shop)
    end

    private

    def authenticate
      return render_invalid_shop_error unless sanitized_shop_name.present?
      # after enter shop domain and click "Install app", above does not get executed
      # as params[:shop] is present

      copy_return_to_param_to_session
      # this does nothing after POST /login as params[:return_to] is not set
      # also not set after redirect to top level

      # From ShopifyApp::RedirectForEmbedded,
      # ShopifyApp.configuration.embedded_redirect_url.present?
      # we dont set this manually in the config...
      # false during first POST /login
      # false after redirect to top level
      if embedded_redirect_url?
        if embedded_param?
          redirect_for_embedded
        else
          start_oauth
        end
      # false during first POST /login
      # would be true if ShopifyApp.configuration.embedded_app == false
      # otherwise looks for params[:top_level]
      # param is there after redirected to top level
      elsif top_level?
        # executed after redirected to top level
        start_oauth
      else
        # This is executed on first POST /login
        redirect_auth_to_top_level
      end
    end

    def start_oauth
      # We don't set this configuration value manually
      # default is 'auth/shopify/callback'
      callback_url = ShopifyApp.configuration.login_callback_url.gsub(%r{^/}, "")

      auth_attributes = ShopifyAPI::Auth::Oauth.begin_auth(
        shop: sanitized_shop_name,
        redirect_path: "/#{callback_url}",
        is_online: user_session_expected?
      )
      # {
      #   :auth_route=>"https://spacetrumpet.myshopify.com/admin/oauth/authorize?client_id=0a0f08d962a4be0854a0b324dda14cae&scope=read_products&redirect_uri=https%3A%2F%2Fchanges-installed-viewing-marshall.trycloudflare.com%2Fauth%2Fshopify%2Fcallback&state=jaQaiLw1U8YG5Lx&grant_options%5B%5D=",
      #   :cookie=><ShopifyAPI::Auth::Oauth::SessionCookie expires=2022-09-12 23:27:51.166144 +0100, name="shopify_app_session", value="jaQaiLw1U8YG5Lx">
      # }
      #
      # Can update the :auth_route to modify the scopes, and the client ID
      # But then on the other side when we verify, need to use different api_key and secret...
      cookies.encrypted[auth_attributes[:cookie].name] = {
        expires: auth_attributes[:cookie].expires,
        secure: true,
        http_only: true,
        value: auth_attributes[:cookie].value,
      }

      redirect_to(auth_attributes[:auth_route], allow_other_host: true)
    end

    def validate_shop_presence
      @shop = sanitized_shop_name
      unless @shop
        render_invalid_shop_error
        return false
      end

      true
    end

    def copy_return_to_param_to_session
      session[:return_to] = RedirectSafely.make_safe(params[:return_to], "/") if params[:return_to]
    end

    def render_invalid_shop_error
      flash[:error] = I18n.t("invalid_shop_url")
      redirect_to(return_address)
    end

    def top_level?
      return true unless ShopifyApp.configuration.embedded_app?

      !params[:top_level].nil?
    end

    def redirect_auth_to_top_level
      # executed on first POST /login
      #
      # ShopifyApp::LoginProtection.login_url_with_optional_shop
      # Takes ShopifyApp.configuration.login_url
      # We don't set this manually, so must use default
      # Default is '/login'
      # then takes login_url_params(top_level: true)
      # this evaluates to {:shop=>"spacetrumpet.myshopify.com", :top_level=>true}
      # Joins these, returns `/login?shop=spacetrumpet.myshopify.com&top_level=true`
      #
      fullpage_redirect_to(login_url_with_optional_shop(top_level: true))
      # the redirect goes to Processing by ShopifyApp::SessionsController#new as HTML
      #        Parameters: {"shop"=>"spacetrumpet.myshopify.com", "top_level"=>"true"}
    end
  end
end
