# frozen_string_literal: true

module Developer
  class AuthenticationController < ApplicationController
    skip_before_action :authenticate_user!

    def show
      @api_key = APIKey.new(user_type: 'personal')
    end

    def create
      @api_key = APIKey.new(api_key_params)
      @api_key.user_type = @api_key.user_type.to_s
      unless APIKey::USER_TYPES.include?(@api_key.user_type)
        @form_alert = t('developer.authentication.invalid_user_type')
        flash.now[:alert] = nil
        render :show, status: :unprocessable_entity
        return
      end

      raw_key = SecureRandom.hex(32)
      @api_key.key_digest = APIKey.build_key_digest(raw_key)
       @api_key.activation_token = SecureRandom.urlsafe_base64(32)
       @api_key.activation_sent_at = Time.current
      @api_key.email = @api_key.email.to_s.strip.downcase
      @api_key.name = @api_key.name.to_s.strip
      @api_key.purpose = @api_key.purpose.to_s.strip.presence

      if @api_key.save
        APIKeyMailer.activation_email(@api_key, raw_key).deliver_now
        render :create_success
      else
        @form_alert = @api_key.errors.full_messages.to_sentence
        flash.now[:alert] = nil
        render :show, status: :unprocessable_entity
      end
    end

    def re_request
      # Form for existing users to request a new key (email only)
    end

    def re_request_create
      email = params[:email].to_s.strip.downcase
      if email.blank?
        flash.now[:alert] = t('developer.authentication.email_required')
        render :re_request, status: :unprocessable_entity
        return
      end

      existing = APIKey.active.where(email: email).order(created_at: :desc).first
      user_type = existing&.user_type || 'personal'
      name = existing&.name || email.split('@').first

      # One active key per email: revoke any existing active keys before creating the new one
      APIKey.revoke_by_email!(email)

      raw_key = SecureRandom.hex(32)
      key_digest = APIKey.build_key_digest(raw_key)

      @api_key = APIKey.new(
        key_digest: key_digest,
        user_type: user_type,
        name: name,
        email: email,
        purpose: existing&.purpose,
        activation_token: SecureRandom.urlsafe_base64(32),
        activation_sent_at: Time.current
      )

      if @api_key.save
        APIKeyMailer.activation_email(@api_key, raw_key).deliver_now
        render :re_request_success
      else
        flash.now[:alert] = @api_key.errors.full_messages.to_sentence
        render :re_request, status: :unprocessable_entity
      end
    end

    def activate
      token = params[:token].to_s
      @api_key = APIKey.find_by(activation_token: token)

      if @api_key.nil?
        @activation_error = t('developer.authentication.activation_invalid')
        render :activate_result, status: :not_found
        return
      end

      if @api_key.activated_at.present?
        @activation_notice = t('developer.authentication.already_activated')
        render :activate_result
        return
      end

      if @api_key.activation_expired?
        @activation_error = t('developer.authentication.activation_expired_html', email: @api_key.email)
        render :activate_result, status: :gone
        return
      end

      @api_key.update!(activated_at: Time.current)
      @activation_notice = t('developer.authentication.activation_success_html', email: @api_key.email)
      render :activate_result
    end

    private

    def api_key_params
      params.require(:api_key).permit(:user_type, :name, :email, :purpose)
    end
  end
end
