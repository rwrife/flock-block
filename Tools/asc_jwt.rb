#!/usr/bin/env ruby
# frozen_string_literal: true
# Ported from rwrife/cook-console Tools/asc_jwt.rb; ES256 JWS uses raw r||s.
require 'base64'
require 'json'
require 'openssl'

key = OpenSSL::PKey::EC.new(File.read(ENV.fetch('ASC_KEY_FILE')))
now = Time.now.to_i
encode = ->(value) { Base64.urlsafe_encode64(value, padding: false) }
header = encode.call(JSON.generate(alg: 'ES256', kid: ENV.fetch('ASC_KEY_ID'), typ: 'JWT'))
payload = encode.call(JSON.generate(iss: ENV.fetch('ASC_ISSUER_ID'), aud: 'appstoreconnect-v1', iat: now, exp: now + 600))
input = "#{header}.#{payload}"
digest = OpenSSL::Digest::SHA256.digest(input)
der = if key.respond_to?(:dsa_sign_asn1)
        key.dsa_sign_asn1(digest)
      else
        key.sign(OpenSSL::Digest::SHA256.new, input)
      end
signature = OpenSSL::ASN1.decode(der)
raw = signature.value.map { |integer| [integer.value.to_i.to_s(16).rjust(64, '0')].pack('H*') }.join
abort 'Invalid ES256 signature' unless raw.bytesize == 64
puts "#{input}.#{encode.call(raw)}"
