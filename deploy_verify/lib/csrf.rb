# frozen_string_literal: true

module DeployVerify
  module Csrf
    module_function

    def extract_token(html)
      html = html.to_s
      # meta name="csrf-token"
      if (m = html.match(/name=["']csrf-token["']\s+content=["']([^"']+)["']/i)) ||
         (m = html.match(/content=["']([^"']+)["']\s+name=["']csrf-token["']/i))
        return m[1]
      end
      # input authenticity_token
      if (m = html.match(/name=["']authenticity_token["'][^>]*value=["']([^"']+)["']/i)) ||
         (m = html.match(/value=["']([^"']+)["'][^>]*name=["']authenticity_token["']/i))
        return m[1]
      end
      nil
    end
  end
end
