module Utils
  require 'base64'
  require 'digest'

  def self.calculate_hash(data)
    Digest::SHA256.hexdigest(data)
  end

  def self.to_base64(binary)
    Base64.encode64(binary)
  end
end