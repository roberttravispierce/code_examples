=begin
Two-way encryption for sensitive (other than user passwords) information in db

USAGE:
  args = :key, :iv, :cipher_type
  Get cipher_types: by 'openssl' at command prompt, then 'help'

Put this inside your model/controller:
include SimpleKryptos

Then you'll have this:
puts q = sk_encrypt("Jose Felix")
puts sk_decrypt q 
=end

SK_KEY = Secret.simple_kryptos_key

module SimpleKryptos
  require 'openssl'
  require 'base64'

  def sk_encrypt(data, args={})
    cipher_type = args[:cipher_type] || "AES-256-ECB"
    aes = OpenSSL::Cipher::Cipher.new(cipher_type)
    aes.encrypt
    aes.key = args[:key] || SK_KEY
    iv = args[:iv]
    aes.iv = iv unless iv.nil?
    Base64.encode64(aes.update(data) + aes.final)
  end

  def sk_decrypt(encrypted_data, args={})
    cipher_type = args[:cipher_type] || "AES-256-ECB"
    aes = OpenSSL::Cipher::Cipher.new(cipher_type)
    aes.decrypt
    aes.key = args[:key] || SK_KEY
    iv = args[:iv]
    aes.iv = iv unless iv.nil?
    aes.update( Base64.decode64(encrypted_data)) + aes.final
  end

end
