require 'stringio'

module BoardBuilder
  module V1
    class Ai < Grape::API
      use ::WineBouncer::OAuth2
      format :json
      content_type :json, 'application/json'

      helpers SharedHelpers  # If needed, matching board_sets.rb

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
            # azure_base = ENV['AZURE_API_BASE']
            # azure_key  = ENV['AZURE_API_KEY']
            azure_base = 'http://57.154.240.25:8000'
            azure_key  = '11543801-f6f7-4395-8d84-4809effb5725'
            
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
      end
    end
  end
end