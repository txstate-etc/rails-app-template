class ApplicationController < ActionController::Base
  before_filter :authenticate
  protect_from_forgery with: :exception
  
  helper_method :current_user
  helper_method :cas_user
  helper_method :login_path

  protected
  def authenticate
    return true if current_user.is_a? User

    # redirect to omniauth provider
    redirect_to "#{login_path}?url=#{request.url}"
    return false    
  end

  def login_path
    '/auth/cas'
  end

  private
  def current_user
    unless defined? @_current_user
      @_current_user = AuthSession.authenticated_user(session[:user], session[:credentials])
    end
    @_current_user
  end

  def cas_user
    session[ :auth_user ]
  end
  
end
