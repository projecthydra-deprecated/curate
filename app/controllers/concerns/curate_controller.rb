#require File.expand_path("../../helpers/application_helper", __FILE__)
require 'breadcrumbs_on_rails'
module CurateController
  extend ActiveSupport::Concern
  # # Adds a few additional behaviors into the application controller
  # include Blacklight::Controller
  # # Adds Hydra behaviors into the application controller
  # include Hydra::Controller::ControllerBehavior
  # # Adds Sufia behaviors into the application controller

  # def current_ability
  #   user_signed_in? ? current_user.ability : super
  # end
  # protected :current_ability

  # def groups
  #   @groups ||= user_signed_in? ? current_user.groups : []
  # end
  # protected :groups

  included do
    include BreadcrumbsOnRails::ActionController
    include Curate::ThemedLayoutController
    add_breadcrumb "Dashboard", :dashboard_index_path

    rescue_from StandardError, with: :exception_handler

    before_filter :configure_permitted_parameters, if: :devise_controller?
    helper_method :sufia
  end


  # Please be sure to impelement current_user and user_session. Blacklight depends on
  # these methods in order to perform user specific actions.

   def sufia
     self
   end

  # helper ApplicationHelper

  def exception_handler(exception)
    raise exception if Rails.configuration.consider_all_requests_local
    raise exception unless ActionDispatch::ExceptionWrapper.rescue_responses[exception.class.name]

    wrapper = ActionDispatch::ExceptionWrapper.new(env, exception)
    render_response_for_error(wrapper)
  end
  protected :exception_handler

  def set_return_location_from_status_code(status_code)
    if status_code == 401
      session['user_return_to'] = env['ORIGINAL_FULLPATH']
    end
  end
  protected :set_return_location_from_status_code

  def render_response_for_error(wrapper)
    capture_exception(wrapper.exception) if respond_to?(:capture_exception)
    set_return_location_from_status_code(wrapper.status_code)
    render "/errors/#{wrapper.status_code}", status: wrapper.status_code, layout: !request.xhr?
  end
  protected :render_response_for_error

  def configure_permitted_parameters
    full_list = [:email, :password, :password_confirmation, :current_password, :name] + Person.registered_attribute_names
    devise_parameter_sanitizer.for(:account_update) { |u| u.permit(full_list) }
  end
  protected :configure_permitted_parameters

  protected

  def force_update_user_profile!
    return true unless current_user
    if current_user.user_does_not_require_profile_update?
      return true
    else
      redirect_to edit_user_registration_path
      return false
    end
  end

  def agreed_to_terms_of_service!
    return false unless current_user
    if current_user.agreed_to_terms_of_service?
      return current_user
    else
      redirect_to new_terms_of_service_agreement_path
      return false
    end
  end

end
