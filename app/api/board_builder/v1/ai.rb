require 'stringio'

module BoardBuilder
  module V1
    class Ai < Grape::API
      use ::WineBouncer::OAuth2
      format :json
      content_type :json, 'application/json'

      # Ensure access to Doorkeeper helpers (e.g., doorkeeper_token, resource_owner)
      helpers Doorkeeper::Grape::Helpers

      # Ensure shared helpers (e.g., current_user, current_user_id_hash) are available
      helpers SharedHelpers

      helpers do
        include SharedHelpers  # If needed, matching board_sets.rb

        # Helper method for fetching IP country from ipapi.co
        def fetch_ip_country(client_ip = nil)
          return nil if client_ip.blank?

          begin
            Rails.logger.info("[AI Analytics] Fetching country for IP: #{client_ip}")

            response = Faraday.get("https://ipapi.co/#{client_ip}/json/") do |req|
              req.headers['Accept'] = 'application/json'
              req.options.timeout = 10        # Total timeout for the request
              req.options.open_timeout = 6   # Timeout for establishing connection
            end

            if response.success?
              data = JSON.parse(response.body) rescue {}
              country_code = data['country_code']
              Rails.logger.info("[AI Analytics] Country for IP #{client_ip}: #{country_code}")
              country_code
            else
              Rails.logger.warn("[AI Analytics] Failed to fetch country for IP #{client_ip}: HTTP #{response.status}")
              nil
            end
          rescue Faraday::ConnectionFailed => e
            Rails.logger.warn("[AI Analytics] ipapi.co connection failed for IP #{client_ip}: #{e.message}")
            nil
          rescue Faraday::TimeoutError => e
            Rails.logger.warn("[AI Analytics] ipapi.co timeout for IP #{client_ip}: #{e.message}")
            nil
          rescue => e
            Rails.logger.error("[AI Analytics] Unexpected error fetching IP country: #{e.class} - #{e.message}")
            nil
          end
        end

        # Helper method for Directus CMS integration
        def directus_request(endpoint, body, method: :post, log_prefix: "AI Analytics")
          # Directus CMS configuration
          directus_url = ENV['DIRECTUS_URL']
          directus_token = ENV['DIRECTUS_TOKEN']

          if directus_token.blank?
            Rails.logger.error("[#{log_prefix}] Directus token not configured")
            error!({ detail: 'CMS integration not configured' }, 500)
          end

          Rails.logger.info("[#{log_prefix}] #{method.upcase} request to Directus: #{body.to_json}")

        begin
          # Make request to Directus CMS using Faraday connection
          conn = Faraday.new(url: directus_url) do |faraday|
            faraday.options.timeout = 15
            faraday.options.open_timeout = 10
          end

          response = case method
          when :post
            conn.post do |req|
              req.url "/items/#{endpoint}"
              req.headers['Content-Type'] = 'application/json'
              req.headers['Authorization'] = "Bearer #{directus_token}"
              req.body = body.to_json
            end
          when :patch
            conn.patch do |req|
              req.url "/items/#{endpoint}"
              req.headers['Content-Type'] = 'application/json'
              req.headers['Authorization'] = "Bearer #{directus_token}"
              req.body = body.to_json
            end
          else
            raise "Unsupported HTTP method: #{method}"
          end

          Rails.logger.info("[#{log_prefix}] Directus response status: #{response.status}")

          if response.success?
            directus_response = JSON.parse(response.body) rescue {}
            data = directus_response['data']

            if data && data['id']
              Rails.logger.info("[#{log_prefix}] Successfully processed record with ID: #{data['id']}")
              data
            else
              Rails.logger.error("[#{log_prefix}] Directus returned success but no data")
              error!({ detail: 'Invalid response from CMS' }, 500)
            end
          else
            error_detail = begin
              JSON.parse(response.body)['errors']&.first&.dig('message') rescue nil
            end || 'CMS error'
            Rails.logger.error("[#{log_prefix}] Directus error: #{response.status} - #{error_detail}")
            error!({ detail: "CMS error: #{error_detail}" }, response.status)
          end
          rescue Faraday::Error => e
            Rails.logger.error("[#{log_prefix}] Faraday error: #{e.class} - #{e.message}")
            error!({ detail: 'CMS connection failed' }, 503)
          rescue JSON::ParserError => e
            Rails.logger.error("[#{log_prefix}] JSON parse error: #{e.class} - #{e.message}")
            error!({ detail: 'Invalid CMS response' }, 500)
          rescue => e
            Rails.logger.error("[#{log_prefix}] Unexpected error: #{e.class} - #{e.message}")
            error!({ detail: 'Internal error' }, 500)
          end
        end
      end

      # Toggle to enable/disable mocked responses for testing.
      # Set to true to return a static response without calling the external service.
      MOCK_GENERATE_IMAGE = false

      resource :ai do
        desc 'Check API server health'
        get :health do
          { status: 'healthy' }
        end

        desc 'Generate image from prompt (text-only or image+text)', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          requires :prompt, type: String, desc: 'Text prompt describing the desired images'
          optional :steps, type: Integer, desc: 'Number of inference steps', default: 2
          optional :guidance_scale, type: Float, desc: 'Guidance scale for image generation', default: 7.0
          optional :num_images, type: Integer, desc: 'Number of images to generate', default: 4, values: 1..10
          optional :image, type: String, desc: 'Image data (base64 or URL) for image+text mode'
          optional :adapter_name, type: String, desc: 'Name of the LoRA adapter to use for style fine-tuning'
        end
        post :generate_image, protected: true, oauth2: ['ai:write'] do
          Rails.logger.info("[AI] generate_image start: prompt_len=#{params[:prompt].to_s.length}, steps=#{params[:steps]}, guidance_scale=#{params[:guidance_scale]}, num_images=#{params[:num_images]}, image_present=#{params[:image].present?}, adapter_name=#{params[:adapter_name]}, mock=#{MOCK_GENERATE_IMAGE}")
          #authorize! :manage, :ai  # Use CanCan if needed, per application_controller.rb

          if MOCK_GENERATE_IMAGE
            # Return a fixed set of image URLs for testing
            sleep 5
            requested_count = params[:num_images] || 4
            mock_urls = [
              '/assets/images/aeroplane_3130.png',
              '/assets/images/barbeque_3231.png',
              '/assets/images/bagel_3210.png',
              '/assets/images/apple_3160.png'
            ]
            return {
              image_urls: mock_urls.first(requested_count)
            }
          end

          body = {
            prompt: params[:prompt],
            steps: params[:steps],
            guidance_scale: params[:guidance_scale],
            num_images: params[:num_images]
          }
          body[:image] = params[:image] if params[:image].present?  # Handle image+text mode
          body[:adapter_name] = params[:adapter_name] if params[:adapter_name].present?  # Handle LoRA adapter

          begin
                azure_base = ENV['AZURE_API_BASE']
                azure_key  = ENV['AZURE_API_KEY']


            Rails.logger.info("[AI] Using Azure base=#{azure_base} (key_present=#{azure_key.present?})")

            if azure_base.blank? || azure_key.blank?
              error!({ detail: 'Azure configuration missing: set AZURE_API_BASE and AZURE_API_KEY' }, 500)
            end

            # Log outbound request (mask key, truncate prompt, summarize image)
            sanitized_body = {
              prompt: body[:prompt].to_s[0, 200],
              steps: body[:steps],
              guidance_scale: body[:guidance_scale],
              num_images: body[:num_images],
              image: body[:image].present? ? "[base64: #{(body[:image].bytesize / 1024.0).round(1)}KB]" : nil,
              adapter_name: body[:adapter_name]
            }.compact
            masked_headers = { 'x-api-key' => '[MASKED]', 'Content-Type' => 'application/json' }
            Rails.logger.info("[AI] → Request url=#{azure_base}/generate-image headers=#{masked_headers} body=#{sanitized_body}")

            response = Faraday.post(
              "#{azure_base}/generate-image",
              body.to_json,
              'x-api-key' => azure_key,
              'Content-Type' => 'application/json'
            ) do |req|
              req.options.timeout = 65
              req.options.open_timeout = 5
            end

            Rails.logger.info("[AI] ← Response status=#{response.status} success=#{response.success?} content_type=#{response.headers['content-type']} body_len=#{response.body&.length}")
            Rails.logger.debug("[AI] ← Body preview: #{response.body.to_s[0, 500]}")
            if response.success?
              parsed = JSON.parse(response.body) rescue {}
              image_urls = parsed['image_urls'] || (parsed['image_url'] ? [parsed['image_url']] : [])
              # Testing helper: if API returns a single image, duplicate to match requested num_images
              if image_urls.length == 1 && image_urls.first.present?
                requested_count = params[:num_images] || 4
                image_urls = Array.new(requested_count, image_urls.first)
              end
              present({ image_urls: image_urls })
            else
              error_detail = JSON.parse(response.body)['detail'] rescue nil
              case response.status
              when 401
                error_detail ||= 'Invalid API key'
              when 429
                error_detail ||= 'Server busy, try again later'
              when 503
                error_detail ||= 'Flux server not running'
              else
                error_detail ||= 'Error generating/uploading images'
              end
              error!({ detail: error_detail }, response.status)
            end
          rescue Faraday::Error => e
            Rails.logger.error("[AI] Faraday error: #{e.class} - #{e.message}")
            error!({ detail: 'Flux server not running' }, 503)
          rescue => e
            Rails.logger.error("[AI] Unexpected error: #{e.class} - #{e.message}")
            error!({ detail: 'Internal error' }, 500)
          end
        end

        desc 'Remove background from image', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          optional :image_url, type: String, desc: 'URL of the image to process'
        end
        post :remove_background, protected: true, oauth2: ['ai:write'] do
          Rails.logger.info("[AI] remove_background start: image_url=#{params[:image_url]}, all_params=#{params.inspect}")

          # Check if image_url is provided
          if params[:image_url].blank?
            error!({ detail: 'image_url parameter is required' }, 422)
          end

          begin
            azure_base = 'http://57.154.240.25:8000'
            azure_key  = '11543801-f6f7-4395-8d84-4809effb5725'

            Rails.logger.info("[AI] Using Azure base=#{azure_base} for remove_background (key_present=#{azure_key.present?})")

            if azure_base.blank? || azure_key.blank?
              error!({ detail: 'Azure configuration missing: set AZURE_API_BASE and AZURE_API_KEY' }, 500)
            end

            # Prepare JSON payload with image URL for Azure API
            payload = {
              image_url: params[:image_url]
            }.to_json

            # Log outbound request
            masked_headers = { 'x-api-key' => '[MASKED]', 'Content-Type' => 'application/json' }
            Rails.logger.info("[AI] → Request url=#{azure_base}/remove-background headers=#{masked_headers} image_url=#{params[:image_url]}")

            response = Faraday.post(
              "#{azure_base}/remove-background",
              payload,
              'x-api-key' => azure_key,
              'Content-Type' => 'application/json'
            ) do |req|
              req.options.timeout = 65
              req.options.open_timeout = 5
            end

            Rails.logger.info("[AI] ← Response status=#{response.status} success=#{response.success?} content_type=#{response.headers['content-type']} body_len=#{response.body&.length}")
            Rails.logger.info("[AI] ← Response body preview: #{response.body.to_s[0, 200]}")

            if response.success?
              # Check if response is JSON (contains image URL) or binary (processed image)
              if response.headers['content-type']&.include?('application/json')
                # Parse JSON response for image URL
                parsed = JSON.parse(response.body) rescue {}
                image_url = parsed['image_url'] || parsed['image_urls']&.first || parsed['rembg_url']

                if image_url.present?
                  Rails.logger.info("[AI] Returning processed image URL: #{image_url}")
                  present({ image_url: image_url })
                else
                  Rails.logger.error("[AI] Azure returned JSON but no image_url found")
                  error!({ detail: 'Processing completed but no result URL returned' }, 500)
                end
              else
                # Azure returned binary image data - need to upload it somewhere and return URL
                Rails.logger.info("[AI] Azure returned binary image data, need to upload to storage")
                # For now, return error since we need storage integration
                error!({ detail: 'Binary image response not yet supported - need storage integration' }, 501)
              end
            else
              error_detail = 'Error processing image background removal'
              case response.status
              when 400
                error_detail = 'Invalid image file or unsupported format'
              when 429
                error_detail = 'Server busy, try again later'
              when 503
                error_detail = 'Remove background server not running'
              end
              error!({ detail: error_detail }, response.status)
            end
          rescue Faraday::Error => e
            Rails.logger.error("[AI] Faraday error: #{e.class} - #{e.message}")
            error!({ detail: 'Remove background server not running' }, 503)
          rescue JSON::ParserError => e
            Rails.logger.error("[AI] JSON parse error: #{e.class} - #{e.message}")
            error!({ detail: 'Invalid response from processing server' }, 500)
          rescue => e
            Rails.logger.error("[AI] Unexpected error: #{e.class} - #{e.message}")
            error!({ detail: 'Internal error' }, 500)
          ensure
            # No cleanup needed for base64 approach
          end
        end

        # Analytics endpoints - proxy to CMS system (logging only for now)

        desc 'Create analytics session', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          optional :state, type: String, desc: 'Session state', values: ['active', 'closed', 'abandoned'], default: 'active'
          optional :start_time, type: String, desc: 'Session start time (ISO 8601)'
          optional :end_time, type: String, desc: 'Session end time (ISO 8601)'
          optional :access_point, type: String, desc: 'Access point identifier', default: 'Board Builder'
          optional :language, type: String, desc: 'User language/locale identifier'
          optional :ip_country, type: String, desc: 'User IP country code'
        end
        post :sessions, protected: true, oauth2: ['ai:write'] do
          # Debug log to verify hash presence without exposing raw identifiers
          user_present = !!current_user
          ro_id = respond_to?(:doorkeeper_token) && doorkeeper_token ? doorkeeper_token.resource_owner_id : nil
          db_ro = resource_owner_id_from_tokens
          hash_preview = current_user_id_hash&.slice(0, 12)
          Rails.logger.info("[AI Analytics] user_present=#{user_present} resource_owner_id=#{ro_id.inspect} db_ro=#{db_ro.inspect} user_id_hash_preview=#{hash_preview || 'nil'}")

          # Get IP country - use provided value or fetch from papi.co
          ip_country = if params[:ip_country].present?
                        params[:ip_country]
                      else
                        # Get client IP from request headers
                        client_ip = env['HTTP_X_FORWARDED_FOR']&.split(',')&.first&.strip ||
                                  env['HTTP_X_REAL_IP'] ||
                                  env['REMOTE_ADDR']

                        # For development/testing, provide fallback for local/private IPs
                        if Rails.env.development? && (client_ip&.start_with?('192.168.') || client_ip&.start_with?('10.') || client_ip&.start_with?('172.'))
                          Rails.logger.info("[AI Analytics] Using development fallback for local IP: #{client_ip}")
                          'DEV'  # Development marker for local IPs
                        else
                          fetch_ip_country(client_ip)
                        end
                      end
          Rails.logger.info("[AI Analytics] Using IP country: #{ip_country}")

          # Prepare request body for Directus
          directus_body = {
            env: Rails.env,  # Environment identifier
            state: params[:state],
            start_time: params[:start_time],
            end_time: params[:end_time],
            access_point: params[:access_point],
            language: params[:language],
            ip_country: ip_country,
            user_id_hash: current_user_id_hash
          }

          # Use helper method for Directus integration
          session_data = directus_request('sessions', directus_body)

          present({
            id: session_data['id'],
            state: session_data['state'],
            start_time: session_data['start_time'],
            end_time: session_data['end_time'],
            access_point: session_data['access_point'],
            language: session_data['language'],
            ip_country: session_data['ip_country']
          })
        end

        desc 'Update analytics session', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          requires :session_id, type: Integer, desc: 'Session ID to update'
          optional :state, type: String, desc: 'Session state', values: ['active', 'closed', 'abandoned']
          optional :end_time, type: String, desc: 'Session end time (ISO 8601)'
        end
        patch 'sessions/:session_id', protected: true, oauth2: ['ai:write'] do
          # Prepare request body for Directus (only include fields that are being updated)
          directus_body = {
            state: params[:state],
            end_time: params[:end_time]
          }.compact

          if directus_body.empty?
            Rails.logger.warn("[AI Analytics] No fields to update for session #{params[:session_id]}")
            present({ success: true, id: params[:session_id] })
            return
          end

          # Use helper method for Directus integration
          session_data = directus_request("sessions/#{params[:session_id]}", directus_body, method: :patch)

          present({
            success: true,
            id: params[:session_id],
            state: params[:state],
            end_time: params[:end_time]
          })
        end

        desc 'Create analytics prompt', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          requires :session_id, type: Integer, desc: 'Session ID'
          requires :user_input, type: String, desc: 'User input text'
          requires :full_prompt, type: String, desc: 'Complete AI-generated prompt'
          optional :style, type: String, desc: 'Style parameter'
          optional :culture, type: String, desc: 'Culture parameter'
        end
        post :prompts, protected: true, oauth2: ['ai:write'] do
          # Prepare request body for Directus
          directus_body = {
            session_id: params[:session_id],
            user_input: params[:user_input],
            full_prompt: params[:full_prompt],
            style: params[:style],
            culture: params[:culture]
          }.compact

          # Use helper method for Directus integration
          prompt_data = directus_request('prompts', directus_body)

          present({
            id: prompt_data['id'],
            session_id: prompt_data['session_id'],
            user_input: prompt_data['user_input'],
            full_prompt: prompt_data['full_prompt'],
            style: prompt_data['style'],
            culture: prompt_data['culture']
          })
        end

        desc 'Create analytics generated image', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          requires :prompt_id, type: Integer, desc: 'Prompt ID'
          requires :image_url, type: String, desc: 'Generated image URL'
          requires :position, type: Integer, desc: 'Position in results (1-based)'
          requires :session_id, type: Integer, desc: 'Session ID'
        end
        post :generated_images, protected: true, oauth2: ['ai:write'] do
          # Prepare request body for Directus
          directus_body = {
            prompt_id: params[:prompt_id],
            image_url: params[:image_url],
            position: params[:position],
            session_id: params[:session_id]
          }

          # Use helper method for Directus integration
          image_data = directus_request('generated_images', directus_body)

          present({
            id: image_data['id'],
            prompt_id: image_data['prompt_id'],
            image_url: image_data['image_url'],
            position: image_data['position'],
            session_id: image_data['session_id']
          })
        end

        desc 'Update analytics generated image', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          requires :image_id, type: Integer, desc: 'Generated image ID to update'
          optional :image_url_bg_removed, type: String, desc: 'Background-removed image URL'
        end
        patch 'generated_images/:image_id', protected: true, oauth2: ['ai:write'] do
          # Prepare request body for Directus (only include fields that are being updated)
          directus_body = {
            image_url_bg_removed: params[:image_url_bg_removed]
          }.compact

          if directus_body.empty?
            Rails.logger.warn("[AI Analytics] No fields to update for generated image #{params[:image_id]}")
            present({ success: true, id: params[:image_id] })
            return
          end

          # Use helper method for Directus integration
          image_data = directus_request("generated_images/#{params[:image_id]}", directus_body, method: :patch)

          present({
            success: true,
            id: params[:image_id],
            image_url_bg_removed: params[:image_url_bg_removed]
          })
        end

        desc 'Create analytics action', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          requires :image_id, type: Integer, desc: 'Image ID'
          requires :action_type, type: String, desc: 'Type of action performed', values: ['download png', 'save', 'send to designer', 'selected', 'Remove Background', 'Undo Background Removal']
        end
        post :actions, protected: true, oauth2: ['ai:write'] do
          # Prepare request body for Directus
          directus_body = {
            image_id: params[:image_id],
            action_type: params[:action_type]
          }

          # Use helper method for Directus integration
          action_data = directus_request('actions', directus_body)

          present({
            id: action_data['id'],
            image_id: action_data['image_id'],
            action_type: action_data['action_type']
          })
        end

        desc 'Create analytics image rating', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          requires :image_id, type: Integer, desc: 'Image ID'
          requires :rating_type, type: String, desc: 'Type of rating', values: ['initial', 'prompt accuracy', 'style accuracy']
          requires :value, type: Integer, desc: 'Rating value', values: 1..5
        end
        post :image_ratings, protected: true, oauth2: ['ai:write'] do
          # Prepare request body for Directus
          directus_body = {
            image_id: params[:image_id],
            rating_type: params[:rating_type],
            value: params[:value]
          }

          # Use helper method for Directus integration
          rating_data = directus_request('image_ratings', directus_body)

          present({
            id: rating_data['id'],
            image_id: rating_data['image_id'],
            rating_type: rating_data['rating_type'],
            value: rating_data['value']
          })
        end

        desc 'Update analytics image rating', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          requires :image_rating_id, type: Integer, desc: 'Image Rating ID'
          optional :value, type: Integer, desc: 'Rating value', values: 1..5
        end
        patch 'image_ratings/:image_rating_id', protected: true, oauth2: ['ai:write'] do
          # Prepare request body for Directus (only include fields that are being updated)
          directus_body = {
            value: params[:value]
          }.compact

          if directus_body.empty?
            Rails.logger.warn("[AI Analytics] No fields to update for image rating #{params[:image_rating_id]}")
            present({ success: true, id: params[:image_rating_id] })
            return
          end

          # Use helper method for Directus integration
          rating_data = directus_request("image_ratings/#{params[:image_rating_id]}", directus_body, method: :patch)

          present({
            success: true,
            id: params[:image_rating_id],
            value: rating_data['value']
          })
        end

        desc 'Create analytics error', {
          headers: {
            'Authorization' => { description: 'OAuth2 Bearer token with ai:write scope', required: true }
          }
        }
        params do
          optional :session_id, type: Integer, desc: 'Session ID (always included for consistent reporting)'
          optional :generated_image_id, type: Integer, desc: 'Generated image ID (for background removal errors)'
          optional :http_code, type: String, desc: 'HTTP status code'
          optional :description, type: String, desc: 'Error description'
        end
        post :errors, protected: true, oauth2: ['ai:write'] do
          # Prepare request body for Directus
          directus_body = {
            session_id: params[:session_id],
            generated_image_id: params[:generated_image_id],
            http_code: params[:http_code],
            description: params[:description]
          }.compact

          # Use helper method for Directus integration
          error_data = directus_request('errors', directus_body)

          present({
            id: error_data['id'],
            session_id: error_data['session_id'],
            generated_image_id: error_data['generated_image_id'],
            http_code: error_data['http_code'],
            description: error_data['description']
          })
        end
      end
    end
  end
end